from decimal import Decimal
from django.contrib import admin
from django.db import transaction
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import display

from .models import Address, CustomerWalletTransaction, User


class AddressInline(TabularInline):
    model = Address
    extra = 0
    show_all_pages = True
    fields = ('label', 'phone_number', 'city', 'area', 'address_line', 'is_default')
    tab = True


class CustomerWalletTransactionInline(TabularInline):
    model = CustomerWalletTransaction
    extra = 0
    show_all_pages = True
    max_num = 0
    readonly_fields = ('show_transaction_type', 'amount', 'description', 'created_at')
    ordering = ('-created_at',)
    tab = True

    @display(description='Type', label={
        CustomerWalletTransaction.TransactionType.CREDIT: 'success',
        CustomerWalletTransaction.TransactionType.DEBIT: 'danger',
    })
    def show_transaction_type(self, obj):
        return obj.transaction_type


@admin.register(User)
class UserAdmin(ModelAdmin):
    list_display = (
        'email',
        'username',
        'show_type',
        'show_wallet_balance',
        'show_is_active',
        'date_joined',
    )
    list_filter = ('type', 'is_active', 'is_staff')
    search_fields = ('email', 'username')
    date_hierarchy = 'date_joined'
    inlines = [AddressInline, CustomerWalletTransactionInline]
    actions = ['credit_wallet_100', 'credit_wallet_500']

    fieldsets = (
        ('Account Credentials', {
            'fields': ('email', 'username', 'type', 'is_active', 'is_staff', 'is_superuser'),
            'classes': ['tab'],
        }),
        ('Customer Wallet', {
            'fields': ('wallet_balance',),
            'classes': ['tab'],
        }),
        ('Preferences & Personalization', {
            'fields': ('personalization_enabled',),
            'classes': ['tab'],
        }),
        ('Timestamps', {
            'fields': ('last_login', 'date_joined'),
            'classes': ['tab'],
        }),
    )

    @display(description='Type', label={
        User.Types.CUSTOMER: 'info',
        User.Types.VENDOR: 'warning',
        User.Types.ADMIN: 'danger',
    })
    def show_type(self, obj):
        return obj.type

    @display(description='Wallet Balance')
    def show_wallet_balance(self, obj):
        return f"৳{obj.wallet_balance:,.2f}"

    @display(description='Active', label={True: 'success', False: 'danger'})
    def show_is_active(self, obj):
        return obj.is_active

    @admin.action(description="Credit ৳100 Store Credit to Selected Users")
    def credit_wallet_100(self, request, queryset):
        self._credit_wallet_amount(request, queryset, Decimal('100.00'), "Admin promotional store credit (৳100)")

    @admin.action(description="Credit ৳500 Store Credit to Selected Users")
    def credit_wallet_500(self, request, queryset):
        self._credit_wallet_amount(request, queryset, Decimal('500.00'), "Admin courtesy store credit (৳500)")

    def _credit_wallet_amount(self, request, queryset, amount: Decimal, desc: str):
        count = 0
        with transaction.atomic():
            for user in queryset:
                user.wallet_balance += amount
                user.save(update_fields=['wallet_balance'])
                CustomerWalletTransaction.objects.create(
                    user=user,
                    amount=amount,
                    transaction_type=CustomerWalletTransaction.TransactionType.CREDIT,
                    description=desc,
                )
                count += 1
        self.message_user(request, f"Successfully credited ৳{amount:,.2f} to {count} user(s).")


@admin.register(CustomerWalletTransaction)
class CustomerWalletTransactionAdmin(ModelAdmin):
    list_display = (
        'id',
        'user',
        'show_transaction_type',
        'amount_display',
        'description',
        'created_at',
    )
    list_filter = ('transaction_type',)
    list_select_related = ('user',)
    search_fields = ('user__email', 'user__username', 'description')
    date_hierarchy = 'created_at'
    readonly_fields = ('user', 'amount', 'transaction_type', 'description', 'created_at')

    @display(description='Type', label={
        CustomerWalletTransaction.TransactionType.CREDIT: 'success',
        CustomerWalletTransaction.TransactionType.DEBIT: 'danger',
    })
    def show_transaction_type(self, obj):
        return obj.transaction_type

    @display(description='Amount')
    def amount_display(self, obj):
        prefix = "+" if obj.transaction_type == CustomerWalletTransaction.TransactionType.CREDIT else "-"
        return f"{prefix}৳{obj.amount:,.2f}"

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(Address)
class AddressAdmin(ModelAdmin):
    list_display = ('id', 'user', 'label', 'phone_number', 'city', 'area', 'show_default', 'created_at')
    list_filter = ('is_default', 'city')
    list_select_related = ('user',)
    search_fields = ('user__email', 'user__username', 'phone_number', 'address_line')
    date_hierarchy = 'created_at'

    @display(description='Default', label={True: 'success', False: 'secondary'})
    def show_default(self, obj):
        return obj.is_default
