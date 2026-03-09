from django.contrib import admin
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import display

from .models import Ticket, TicketAttachment, TicketMessage


class TicketMessageInline(TabularInline):
    model = TicketMessage
    extra = 0
    show_all_pages = True
    max_num = 0
    readonly_fields = ('kind', 'sender', 'text', 'is_internal_note', 'created_at')
    ordering = ('-created_at',)
    tab = True


class TicketAttachmentInline(TabularInline):
    model = TicketAttachment
    extra = 0
    readonly_fields = ('file', 'file_type', 'size', 'uploaded_at')
    fk_name = 'message'
    tab = True


@admin.register(Ticket)
class TicketAdmin(ModelAdmin):
    list_display = (
        'ticket_number', 'subject_short', 'show_status', 'customer', 'vendor',
        'assigned_to', 'show_sla', 'last_activity_at',
    )
    list_filter = ('status', 'is_overdue_first_response', 'is_overdue_resolution')
    list_select_related = ('customer', 'vendor', 'assigned_to')
    search_fields = ('ticket_number', 'subject', 'customer__email', 'vendor__store_name')
    date_hierarchy = 'created_at'
    inlines = [TicketMessageInline]

    fieldsets = (
        ('Ticket Info', {
            'fields': ('ticket_number', 'subject', 'status', 'customer', 'vendor', 'assigned_to'),
            'classes': ['tab'],
        }),
        ('SLA & Tracking', {
            'fields': (
                'is_overdue_first_response', 'is_overdue_resolution',
                'first_response_at', 'resolved_at', 'last_activity_at',
            ),
            'classes': ['tab'],
        }),
        ('Context', {
            'fields': ('return_request', 'order', 'context_snapshot'),
            'classes': ['tab'],
        }),
    )

    def subject_short(self, obj):
        return obj.subject[:50] + '…' if len(obj.subject) > 50 else obj.subject
    subject_short.short_description = 'Subject'

    @display(description='Status', label={
        'OPEN': 'warning',
        'IN_PROGRESS': 'info',
        'WAITING_CUSTOMER': 'info',
        'RESOLVED': 'success',
        'CLOSED': 'success',
    })
    def show_status(self, obj):
        return obj.status

    @display(description='SLA', label=True)
    def show_sla(self, obj):
        if obj.is_overdue_resolution:
            return 'OVERDUE'
        if obj.is_overdue_first_response:
            return 'FIRST RESP OVERDUE'
        return 'OK'


@admin.register(TicketMessage)
class TicketMessageAdmin(ModelAdmin):
    list_display = ('id', 'ticket', 'kind', 'sender', 'is_internal_note', 'created_at')
    list_filter = ('kind', 'is_internal_note')
    list_select_related = ('ticket', 'sender')
    search_fields = ('ticket__ticket_number', 'text', 'sender__email')


@admin.register(TicketAttachment)
class TicketAttachmentAdmin(ModelAdmin):
    list_display = ('id', 'message', 'file_type', 'size', 'uploaded_at')
    list_filter = ('file_type',)
