from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    class Types(models.TextChoices):
        CUSTOMER = "CUSTOMER", "Customer"
        VENDOR = "VENDOR", "Vendor"
        ADMIN = "ADMIN", "Admin"

    type = models.CharField(
        max_length=50, choices=Types.choices, default=Types.CUSTOMER
    )
    email = models.EmailField(unique=True)
    wallet_balance = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    personalization_enabled = models.BooleanField(
        default=True,
        help_text="If false, the system will not log behavior events for personalization.",
    )
    # Add other fields like avatar here if needed
    
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']

    def __str__(self):
        return self.email


class Address(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='addresses')
    label = models.CharField(max_length=50, help_text="e.g., Home, Office")
    phone_number = models.CharField(max_length=20)
    address_line = models.TextField()
    area = models.CharField(max_length=100)
    city = models.CharField(max_length=100)
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.label} - {self.user.username}"

    class Meta:
        ordering = ['-is_default', '-created_at']


class CustomerWalletTransaction(models.Model):
    class TransactionType(models.TextChoices):
        CREDIT = 'CREDIT', 'Credit'
        DEBIT = 'DEBIT', 'Debit'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='wallet_transactions')
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    transaction_type = models.CharField(max_length=20, choices=TransactionType.choices)
    description = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.transaction_type} {self.amount} for {self.user.email}"
