from django.contrib import admin
from django.utils import timezone
from django.utils.html import format_html
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import display

from .models import Refund, ReturnImage, ReturnItem, ReturnPolicy, ReturnRequest


class ReturnItemInline(TabularInline):
    model = ReturnItem
    extra = 0
    show_all_pages = True
    fields = ('order_item', 'quantity', 'condition')
    readonly_fields = ('order_item', 'quantity', 'condition')
    tab = True


class ReturnImageInline(TabularInline):
    model = ReturnImage
    extra = 0
    show_all_pages = True
    fields = ('image', 'thumbnail_preview', 'uploaded_by', 'uploaded_at')
    readonly_fields = ('thumbnail_preview', 'uploaded_at')
    tab = True

    @display(description='Preview')
    def thumbnail_preview(self, obj):
        if obj.image:
            return format_html(
                '<a href="{0}" target="_blank">'
                '<img src="{0}" class="h-14 w-14 rounded object-cover border border-base-200 shadow-xs" />'
                '</a>',
                obj.image.url,
            )
        return "—"


@admin.register(ReturnRequest)
class ReturnRequestAdmin(ModelAdmin):
    list_display = (
        'rma_number',
        'order',
        'customer',
        'vendor',
        'request_type',
        'show_status',
        'reason',
        'fulfillment',
        'refund_method_preference',
        'created_at',
    )
    list_filter = ('status', 'request_type', 'reason', 'fulfillment', 'refund_method_preference')
    list_select_related = ('order', 'customer', 'vendor')
    search_fields = ('rma_number', 'customer__email', 'customer__username', 'vendor__store_name', 'order__id')
    date_hierarchy = 'created_at'
    inlines = [ReturnItemInline, ReturnImageInline]
    actions = ['approve_requests', 'mark_received', 'escalate_dispute']

    fieldsets = (
        ('RMA Request Details', {
            'fields': (
                'rma_number',
                'order',
                'customer',
                'vendor',
                'request_type',
                'status',
            ),
            'classes': ['tab'],
        }),
        ('Reason & Logistics', {
            'fields': (
                'reason',
                'reason_details',
                'fulfillment',
                'refund_method_preference',
                'dropoff_instructions',
                'vendor_note',
                'customer_note',
            ),
            'classes': ['tab'],
        }),
        ('Timestamps', {
            'fields': (
                'created_at',
                'vendor_response_due_at',
                'approved_at',
                'rejected_at',
                'received_at',
                'escalated_at',
                'updated_at',
            ),
            'classes': ['tab'],
        }),
    )

    readonly_fields = (
        'rma_number',
        'created_at',
        'vendor_response_due_at',
        'approved_at',
        'rejected_at',
        'received_at',
        'escalated_at',
        'updated_at',
    )

    @display(description='Status', label={
        ReturnRequest.Status.SUBMITTED: 'warning',
        ReturnRequest.Status.VENDOR_APPROVED: 'info',
        ReturnRequest.Status.VENDOR_REJECTED: 'danger',
        ReturnRequest.Status.PICKUP_SCHEDULED: 'info',
        ReturnRequest.Status.DROPOFF_REQUESTED: 'info',
        ReturnRequest.Status.RECEIVED: 'primary',
        ReturnRequest.Status.REFUND_PENDING: 'warning',
        ReturnRequest.Status.REFUNDED: 'success',
        ReturnRequest.Status.ESCALATED: 'danger',
        ReturnRequest.Status.CLOSED: 'secondary',
        ReturnRequest.Status.CANCELED: 'secondary',
    })
    def show_status(self, obj):
        return obj.status

    @admin.action(description="Approve selected RMA requests")
    def approve_requests(self, request, queryset):
        updated = queryset.filter(status=ReturnRequest.Status.SUBMITTED).update(
            status=ReturnRequest.Status.VENDOR_APPROVED,
            approved_at=timezone.now(),
            updated_at=timezone.now(),
        )
        self.message_user(request, f"{updated} return request(s) approved.")

    @admin.action(description="Mark selected RMA requests as Item Received")
    def mark_received(self, request, queryset):
        updated = queryset.update(
            status=ReturnRequest.Status.RECEIVED,
            received_at=timezone.now(),
            updated_at=timezone.now(),
        )
        self.message_user(request, f"{updated} request(s) marked as received.")

    @admin.action(description="Escalate selected RMA requests to Support Dispute")
    def escalate_dispute(self, request, queryset):
        updated = queryset.update(
            status=ReturnRequest.Status.ESCALATED,
            escalated_at=timezone.now(),
            updated_at=timezone.now(),
        )
        self.message_user(request, f"{updated} request(s) marked as escalated dispute.")


@admin.register(Refund)
class RefundAdmin(ModelAdmin):
    list_display = (
        'id',
        'return_request',
        'order',
        'amount_display',
        'method',
        'show_status',
        'processed_at',
        'created_at',
    )
    list_filter = ('status', 'method')
    list_select_related = ('return_request', 'order')
    search_fields = ('id', 'return_request__rma_number', 'provider_trans_id', 'reference')
    date_hierarchy = 'created_at'
    readonly_fields = ('created_at', 'updated_at')

    @display(description='Amount')
    def amount_display(self, obj):
        return f"৳{obj.amount:,.2f}"

    @display(description='Status', label={
        Refund.Status.PENDING: 'warning',
        Refund.Status.PROCESSING: 'info',
        Refund.Status.COMPLETED: 'success',
        Refund.Status.FAILED: 'danger',
    })
    def show_status(self, obj):
        return obj.status


@admin.register(ReturnPolicy)
class ReturnPolicyAdmin(ModelAdmin):
    list_display = (
        'name',
        'vendor',
        'category',
        'product',
        'return_window_days',
        'allow_return',
        'allow_replace',
        'show_active',
    )
    list_filter = ('is_active', 'allow_return', 'allow_replace')
    list_select_related = ('vendor', 'category', 'product')
    search_fields = ('name', 'vendor__store_name', 'product__name', 'category__name')

    @display(description='Active', label={True: 'success', False: 'secondary'})
    def show_active(self, obj):
        return obj.is_active
