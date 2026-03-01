from django.db import models
from django.conf import settings
from django.utils import timezone
from datetime import timedelta

class Vendor(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='vendor_profile')
    store_name = models.CharField(max_length=255, unique=True)
    description = models.TextField(blank=True)
    is_approved = models.BooleanField(default=False)
    balance = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    # Ledger-first cached balances (source of truth is LedgerEntry aggregate)
    pending_balance = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    available_balance = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    held_balance = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    debt_balance = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    total_earned_lifetime = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)
    total_withdrawn_lifetime = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)
    
    # Storefront 2.0 Identity
    logo = models.ImageField(upload_to='vendors/logos/', blank=True, null=True)
    cover_image = models.ImageField(upload_to='vendors/covers/', blank=True, null=True)
    joined_at = models.DateTimeField(default=timezone.now)
    policy_summary = models.TextField(blank=True, help_text="Summary of shipping/return policies")
    
    # Denormalized Aggregates for Performance
    avg_rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.00)
    review_count = models.PositiveIntegerField(default=0)
    
    created_at = models.DateTimeField(auto_now_add=True)

    # SLA metrics
    cancellation_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0.00, help_text="Percentage of canceled orders")
    late_shipment_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0.00, help_text="Percentage of late shipped orders")
    avg_handling_time_days = models.DecimalField(max_digits=5, decimal_places=2, default=0.00, help_text="Average days to ship")

    def __str__(self):
        return self.store_name

    def recache_balance(self, save=True):
        """
        Keep the legacy `balance` field as a cached aggregate for compatibility.
        debt_balance is subtracted so `balance` reflects the vendor's true net position.
        """
        self.balance = (
            (self.pending_balance or 0)
            + (self.available_balance or 0)
            + (self.held_balance or 0)
            - (self.debt_balance or 0)
        )
        if save:
            self.save(update_fields=['balance'])

class Permission(models.Model):
    codename = models.CharField(max_length=50, unique=True)
    description = models.CharField(max_length=255)

    def __str__(self):
        return self.codename

class Role(models.Model):
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='roles')
    name = models.CharField(max_length=50) # e.g. Owner, Manager, Packer, Support
    permissions = models.ManyToManyField(Permission, blank=True)

    class Meta:
        unique_together = ('vendor', 'name')

    def __str__(self):
        return f"{self.vendor.store_name} - {self.name}"

class VendorStaff(models.Model):
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='staff')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='vendor_staff_profile')
    role = models.ForeignKey(Role, on_delete=models.SET_NULL, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('vendor', 'user')

    def __str__(self):
        return f"{self.user.email} - {self.vendor.store_name}"

class AuditLog(models.Model):
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='audit_logs')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    action = models.CharField(max_length=100) # e.g. 'PRICE_CHANGE', 'ORDER_STATUS_UPDATE'
    details = models.TextField() # JSON or text representation of changes
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.action} by {self.user} on {self.created_at}"

class WalletTransaction(models.Model):
    class TransactionType(models.TextChoices):
        CREDIT = 'CREDIT', 'Credit (Earnings/Refund)'
        DEBIT = 'DEBIT', 'Debit (Payout/Charge)'

    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='wallet_transactions')
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    transaction_type = models.CharField(max_length=20, choices=TransactionType.choices)
    description = models.TextField()
    reference_id = models.CharField(max_length=100, blank=True, null=True) # E.g., Order ID, Payout ID
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.get_transaction_type_display()} amount {self.amount} for Vendor '{self.vendor.store_name}'"

class PayoutRequest(models.Model):
    class Status(models.TextChoices):
        REQUESTED = 'REQUESTED', 'Requested'
        APPROVED = 'APPROVED', 'Approved'
        PROCESSING = 'PROCESSING', 'Processing'
        PAID = 'PAID', 'Paid'
        REJECTED = 'REJECTED', 'Rejected'

    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='payout_requests')
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.REQUESTED)
    bank_details = models.TextField() # e.g. "Bank: Chase, Acct: ****1234"
    admin_note = models.TextField(blank=True)
    requested_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Payout {self.amount} for {self.vendor.store_name} ({self.status})"

class VendorPayoutMethod(models.Model):
    class Method(models.TextChoices):
        BANK = 'BANK', 'Bank'
        BKASH = 'BKASH', 'bKash'
        NAGAD = 'NAGAD', 'Nagad'

    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='payout_methods')
    method = models.CharField(max_length=20, choices=Method.choices)
    label = models.CharField(max_length=100, blank=True, help_text="e.g. 'Main bank', 'bKash personal'")
    details = models.JSONField(default=dict, blank=True)
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_verified', '-updated_at']

    def __str__(self):
        return f"{self.vendor.store_name} - {self.method} ({'VERIFIED' if self.is_verified else 'UNVERIFIED'})"


class LedgerEntry(models.Model):
    """
    Ledger-first immutable entries that can reconstruct vendor balances.
    Each entry affects exactly one bucket (pending/available/held).
    """
    class EntryType(models.TextChoices):
        SALE_CREDIT_PENDING = 'SALE_CREDIT_PENDING', 'Sale credit (Pending)'
        SETTLEMENT_RELEASE = 'SETTLEMENT_RELEASE', 'Settlement release'
        PAYOUT_REQUEST_HOLD = 'PAYOUT_REQUEST_HOLD', 'Payout request hold'
        PAYOUT_REJECTED_RELEASE = 'PAYOUT_REJECTED_RELEASE', 'Payout rejected release'
        PAYOUT_PAID = 'PAYOUT_PAID', 'Payout paid'
        REFUND_DEBIT = 'REFUND_DEBIT', 'Refund debit'

    class Bucket(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        AVAILABLE = 'AVAILABLE', 'Available'
        HELD = 'HELD', 'Held'

    class Direction(models.TextChoices):
        CREDIT = 'CREDIT', 'Credit'
        DEBIT = 'DEBIT', 'Debit'

    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        POSTED = 'POSTED', 'Posted'
        FAILED = 'FAILED', 'Failed'

    class ReferenceType(models.TextChoices):
        SUBORDER = 'SUBORDER', 'SubOrder'
        PAYOUT = 'PAYOUT', 'Payout'
        REFUND = 'REFUND', 'Refund'

    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='ledger_entries')
    entry_type = models.CharField(max_length=50, choices=EntryType.choices)
    bucket = models.CharField(max_length=20, choices=Bucket.choices)
    direction = models.CharField(max_length=10, choices=Direction.choices)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.POSTED)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    reference_type = models.CharField(max_length=20, choices=ReferenceType.choices)
    reference_id = models.IntegerField()
    idempotency_key = models.CharField(max_length=80, blank=True, null=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at', '-id']
        constraints = [
            models.UniqueConstraint(
                fields=['idempotency_key', 'entry_type', 'bucket', 'direction'],
                name='vendors_ledger_idempotency_unique',
                condition=models.Q(idempotency_key__isnull=False),
            ),
        ]

    def __str__(self):
        sign = '+' if self.direction == self.Direction.CREDIT else '-'
        return f"{self.vendor.store_name} {self.bucket} {sign}{self.amount} ({self.entry_type})"


class SettlementRecord(models.Model):
    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        RELEASED = 'RELEASED', 'Released'

    sub_order = models.OneToOneField('orders.SubOrder', on_delete=models.CASCADE, related_name='settlement_record')
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='settlement_records')
    gross_amount = models.DecimalField(max_digits=12, decimal_places=2)
    platform_fee = models.DecimalField(max_digits=12, decimal_places=2)
    net_amount = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    settlement_date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)
    released_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Settlement SubOrder #{self.sub_order_id} ({self.status})"

    @classmethod
    def compute_settlement_date(cls, delivered_at, window_days=7):
        base = delivered_at or timezone.now()
        return (base + timedelta(days=window_days)).date()

class BulkJob(models.Model):
    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        PROCESSING = 'PROCESSING', 'Processing'
        COMPLETED = 'COMPLETED', 'Completed'
        FAILED = 'FAILED', 'Failed'
        PARTIAL_SUCCESS = 'PARTIAL_SUCCESS', 'Partial Success'

    class JobType(models.TextChoices):
        PRODUCT_UPLOAD = 'PRODUCT_UPLOAD', 'Product Upload'
        PRICE_UPDATE = 'PRICE_UPDATE', 'Price Update'
        STOCK_UPDATE = 'STOCK_UPDATE', 'Stock Update'

    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='bulk_jobs')
    job_type = models.CharField(max_length=50, choices=JobType.choices)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    file = models.FileField(upload_to='bulk_jobs/')
    result_report = models.JSONField(blank=True, null=True) # To store validation errors / success rows
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"BulkJob {self.id} ({self.job_type}) for {self.vendor.store_name}"

class VendorPerformanceDaily(models.Model):
    vendor = models.ForeignKey(Vendor, on_delete=models.CASCADE, related_name='daily_performance')
    date = models.DateField()
    orders_count = models.PositiveIntegerField(default=0)
    shipped_count = models.PositiveIntegerField(default=0)
    canceled_count = models.PositiveIntegerField(default=0)
    late_shipments = models.PositiveIntegerField(default=0)
    avg_handling_seconds = models.PositiveIntegerField(default=0)
    revenue = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)

    class Meta:
        unique_together = ('vendor', 'date')
        ordering = ['-date']

    def __str__(self):
        return f"Perf {self.date} for {self.vendor.store_name}"
