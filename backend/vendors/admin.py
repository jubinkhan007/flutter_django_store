from django.contrib import admin
from django.utils import timezone

from .models import (
    Vendor,
    LedgerEntry,
    SettlementRecord,
    VendorPayoutMethod,
    PayoutRequest,
)
from .financial_service import FinancialService

@admin.register(Vendor)
class VendorAdmin(admin.ModelAdmin):
    list_display = ('store_name', 'user', 'is_approved', 'balance', 'created_at')
    list_filter = ('is_approved',)
    search_fields = ('store_name',)


@admin.register(LedgerEntry)
class LedgerEntryAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'vendor',
        'entry_type',
        'bucket',
        'direction',
        'amount',
        'status',
        'created_at',
    )
    list_filter = ('entry_type', 'bucket', 'direction', 'status')
    search_fields = ('vendor__store_name', 'reference_id', 'idempotency_key')


@admin.register(SettlementRecord)
class SettlementRecordAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'vendor',
        'sub_order',
        'net_amount',
        'status',
        'settlement_date',
        'created_at',
    )
    list_filter = ('status',)
    search_fields = ('vendor__store_name', 'sub_order__id')


@admin.register(VendorPayoutMethod)
class VendorPayoutMethodAdmin(admin.ModelAdmin):
    list_display = ('id', 'vendor', 'method', 'label', 'is_verified', 'updated_at')
    list_filter = ('method', 'is_verified')
    search_fields = ('vendor__store_name', 'label')


@admin.register(PayoutRequest)
class PayoutRequestAdmin(admin.ModelAdmin):
    list_display = ('id', 'vendor', 'amount', 'status', 'requested_at', 'processed_at')
    list_filter = ('status',)
    search_fields = ('vendor__store_name', 'id')
    actions = ['approve_payout', 'reject_and_release', 'mark_as_paid']

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
                # Admin can retry; ledger operations are idempotent by key.
                pass

    @admin.action(description="Mark payout as PAID (debit held)")
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
