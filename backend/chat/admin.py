from django.contrib import admin
from django.utils.html import format_html
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import display

from .models import Conversation, ChatMessage


class ChatMessageInline(TabularInline):
    model = ChatMessage
    extra = 0
    fields = ('sender', 'sender_type', 'message_type', 'text', 'attachment_preview', 'is_read', 'created_at')
    readonly_fields = ('sender', 'sender_type', 'message_type', 'text', 'attachment_preview', 'is_read', 'created_at')
    can_delete = True
    tab = True

    @display(description='Attachment')
    def attachment_preview(self, obj):
        if obj.image:
            return format_html(
                '<a href="{0}" target="_blank">'
                '<img src="{0}" class="h-10 w-10 rounded object-cover border border-base-200" />'
                '</a>',
                obj.image.url,
            )
        return "—"


@admin.register(Conversation)
class ConversationAdmin(ModelAdmin):
    list_display = (
        'id',
        'customer_display',
        'vendor_display',
        'last_message_preview',
        'show_unread_badges',
        'context_display',
        'last_message_at',
    )
    list_filter = ('vendor', 'created_at', 'last_message_at')
    search_fields = (
        'customer__username',
        'customer__email',
        'customer__first_name',
        'customer__last_name',
        'vendor__store_name',
        'last_message_preview',
    )
    readonly_fields = (
        'created_at',
        'updated_at',
        'last_message_at',
        'customer_unread_count',
        'vendor_unread_count',
    )
    inlines = [ChatMessageInline]

    @display(description='Customer')
    def customer_display(self, obj):
        return f"{obj.customer.get_full_name() or obj.customer.username} (#{obj.customer_id})"

    @display(description='Vendor Store')
    def vendor_display(self, obj):
        return obj.vendor.store_name

    @display(description='Unread (Cust / Vend)')
    def show_unread_badges(self, obj):
        cust_badge = f'<span class="badge badge-warning text-xs font-semibold mr-1">{obj.customer_unread_count}</span>' if obj.customer_unread_count else '<span class="text-xs text-base-400">0</span>'
        vend_badge = f'<span class="badge badge-info text-xs font-semibold ml-1">{obj.vendor_unread_count}</span>' if obj.vendor_unread_count else '<span class="text-xs text-base-400">0</span>'
        return format_html(f"{cust_badge} / {vend_badge}")

    @display(description='Context')
    def context_display(self, obj):
        parts = []
        if obj.product:
            parts.append(f"📦 Product #{obj.product_id}")
        if obj.order:
            parts.append(f"🧾 Order #{obj.order_id}")
        return ", ".join(parts) or "—"


@admin.register(ChatMessage)
class ChatMessageAdmin(ModelAdmin):
    list_display = (
        'id',
        'conversation_id',
        'sender',
        'sender_type',
        'text_snippet',
        'has_attachment',
        'is_read',
        'created_at',
    )
    list_filter = ('sender_type', 'message_type', 'is_read', 'created_at')
    search_fields = ('text', 'sender__username', 'sender__email')
    readonly_fields = ('created_at',)

    @display(description='Message')
    def text_snippet(self, obj):
        return (obj.text[:60] + '...') if len(obj.text) > 60 else (obj.text or '—')

    @display(description='Attachment', boolean=True)
    def has_attachment(self, obj):
        return bool(obj.image)
