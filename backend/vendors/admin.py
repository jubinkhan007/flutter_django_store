from django.contrib import admin
from django.utils import timezone
from unfold.admin import ModelAdmin
from unfold.decorators import display

from .disbursal_service import VendorDisbursalService
from .financial_service import FinancialService
from .models import (
    LedgerEntry,
    PayoutRequest,
    SettlementRecord,
    Vendor,
    VendorPayoutMethod,
)


@admin.register(Vendor)
class VendorAdmin(ModelAdmin):
    list_display = (
        'store_name', 'user', 'show_approved', 'balance',
        'is_auto_payout_enabled', 'auto_payout_schedule', 'created_at',
    )
    list_filter = ('is_approved', 'is_live', 'is_auto_payout_enabled', 'auto_payout_schedule')
    list_select_related = ('user',)
    search_fields = ('store_name', 'user__email')

    fieldsets = (
        ('Profile', {
            'fields': ('user', 'store_name', 'is_approved', 'is_live', 'balance'),
            'classes': ['tab'],
        }),
        ('Store Details', {
            'fields': ('store_description', 'store_logo', 'location', 'contact_number'),
            'classes': ['tab'],
        }),
        ('Auto Payouts', {
            'fields': (
                'is_auto_payout_enabled', 'auto_payout_schedule',
                'auto_payout_threshold', 'preferred_payout_method', 'last_payout_at',
            ),
            'classes': ['tab'],
        }),
    )

    @display(description='Approved', label={True: 'success', False: 'danger'})
    def show_approved(self, obj):
        return obj.is_approved


@admin.register(LedgerEntry)
class LedgerEntryAdmin(ModelAdmin):
    list_display = (
        'id', 'vendor', 'show_entry_type', 'bucket', 'show_direction',
        'amount', 'show_status', 'created_at',
    )
    list_filter = ('entry_type', 'bucket', 'direction', 'status')
    list_select_related = ('vendor',)
    search_fields = ('vendor__store_name', 'reference_id', 'idempotency_key')
    date_hierarchy = 'created_at'

    @display(description='Type', label=True)
    def show_entry_type(self, obj):
        return obj.entry_type

    @display(description='Direction', label={
        LedgerEntry.Direction.CREDIT: 'success',
        LedgerEntry.Direction.DEBIT: 'danger',
    })
    def show_direction(self, obj):
        return obj.direction

    @display(description='Status', label={
        LedgerEntry.Status.PENDING: 'warning',
        LedgerEntry.Status.POSTED: 'success',
        LedgerEntry.Status.FAILED: 'danger',
    })
    def show_status(self, obj):
        return obj.status


@admin.register(SettlementRecord)
class SettlementRecordAdmin(ModelAdmin):
    list_display = (
        'id', 'vendor', 'sub_order', 'net_amount',
        'show_status', 'settlement_date', 'created_at',
    )
    list_filter = ('status',)
    list_select_related = ('vendor', 'sub_order')
    search_fields = ('vendor__store_name', 'sub_order__id')
    date_hierarchy = 'settlement_date'

    @display(description='Status', label={
        'PENDING': 'warning',
        'RELEASED': 'success',
    })
    def show_status(self, obj):
        return obj.status


@admin.register(VendorPayoutMethod)
class VendorPayoutMethodAdmin(ModelAdmin):
    list_display = ('id', 'vendor', 'method', 'label', 'show_verified', 'verified_at', 'updated_at')
    list_filter = ('method', 'is_verified')
    list_select_related = ('vendor',)
    search_fields = ('vendor__store_name', 'label')
    actions = ['verify_payout_method']

    @display(description='Verified', label={True: 'success', False: 'danger'})
    def show_verified(self, obj):
        return obj.is_verified

    @admin.action(description="Verify selected payout methods")
    def verify_payout_method(self, request, queryset):
        success_count = 0
        for method in queryset:
            if VendorDisbursalService.verify_payout_method(method, notes="Verified by admin action"):
                success_count += 1
        self.message_user(request, f"Successfully verified {success_count} payout method(s).")


@admin.register(PayoutRequest)
class PayoutRequestAdmin(ModelAdmin):
    list_display = (
        'id', 'vendor', 'amount', 'disbursal_channel', 'gateway_reference',
        'show_status', 'show_automated', 'requested_at', 'processed_at',
    )
    list_filter = ('status', 'disbursal_channel', 'is_automated')
    list_select_related = ('vendor', 'payout_method')
    search_fields = ('vendor__store_name', 'id', 'gateway_reference')
    actions = ['disburse_via_gateway', 'approve_payout', 'reject_and_release', 'mark_as_paid']

    @display(description='Status', label={
        PayoutRequest.Status.REQUESTED: 'warning',
        PayoutRequest.Status.APPROVED: 'info',
        PayoutRequest.Status.PROCESSING: 'info',
        PayoutRequest.Status.PAID: 'success',
        PayoutRequest.Status.REJECTED: 'danger',
    })
    def show_status(self, obj):
        return obj.status

    @display(description='Automated', label={True: 'info', False: 'default'})
    def show_automated(self, obj):
        return obj.is_automated

    @admin.action(description="⚡ Disburse via Gateway (bKash/Nagad/Bank)")
    def disburse_via_gateway(self, request, queryset):
        success_count = 0
        error_count = 0
        for payout in queryset:
            if payout.status == PayoutRequest.Status.PAID:
                continue
            res = VendorDisbursalService.disburse_payout(payout)
            if res.get('success'):
                success_count += 1
            else:
                error_count += 1
        self.message_user(
            request,
            f"Gateway Disbursal complete: {success_count} paid successfully, {error_count} failed/rejected."
        )

    @admin.action(description="Approve payout (notify vendor)")
    def approve_payout(self, request, queryset):
        for payout in queryset:
            if payout.status in (PayoutRequest.Status.PAID, PayoutRequest.Status.REJECTED):
                continue
            payout.status = PayoutRequest.Status.APPROVED
            payout.save(update_fields=['status'])
            try:
                from notifications.models import Notification
                from notifications.services import NotificationService

                NotificationService.create(
                    user=payout.vendor.user,
                    title='Payout approved',
                    body=f'Your payout request #{payout.id} has been approved.',
                    event_type=Notification.Type.PAYOUT_APPROVED,
                    category=Notification.Category.TRANSACTIONAL,
                    deeplink='app://vendor/wallet',
                    data={'payout_id': str(payout.id), 'amount': str(payout.amount)},
                    inbox_visible=True,
                    push_enabled=True,
                )
            except Exception:
                pass

    @admin.action(description="Reject payout + release held funds")
    def reject_and_release(self, request, queryset):
        for payout in queryset:
            if payout.status == PayoutRequest.Status.PAID:
                continue
            payout.status = PayoutRequest.Status.REJECTED
            payout.processed_at = timezone.now()
            payout.save(update_fields=['status', 'processed_at'])
            try:
                FinancialService.reject_payout(payout)
            except Exception:
                pass

    @admin.action(description="Mark payout as PAID (manual bypass)")
    def mark_as_paid(self, request, queryset):
        for payout in queryset:
            if payout.status == PayoutRequest.Status.PAID:
                continue
            payout.status = PayoutRequest.Status.PAID
            payout.processed_at = timezone.now()
            payout.save(update_fields=['status', 'processed_at'])
            try:
                FinancialService.mark_payout_paid(payout)
            except Exception:
                pass
