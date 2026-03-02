from django.contrib import admin

from .models import Ticket, TicketAttachment, TicketMessage


@admin.register(Ticket)
class TicketAdmin(admin.ModelAdmin):
    list_display = ('id', 'ticket_number', 'status', 'customer', 'vendor', 'assigned_to', 'last_activity_at', 'created_at')
    list_filter = ('status', 'is_overdue_first_response', 'is_overdue_resolution')
    search_fields = ('ticket_number', 'subject', 'customer__email', 'vendor__store_name')


@admin.register(TicketMessage)
class TicketMessageAdmin(admin.ModelAdmin):
    list_display = ('id', 'ticket', 'kind', 'sender', 'is_internal_note', 'created_at')
    list_filter = ('kind', 'is_internal_note')
    search_fields = ('ticket__ticket_number', 'text', 'sender__email')


@admin.register(TicketAttachment)
class TicketAttachmentAdmin(admin.ModelAdmin):
    list_display = ('id', 'message', 'file_type', 'size', 'uploaded_at')
    list_filter = ('file_type',)

