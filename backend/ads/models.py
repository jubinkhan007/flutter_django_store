from django.db import models
from django.conf import settings
from django.utils import timezone
from decimal import Decimal
import uuid

class AdCampaign(models.Model):
    class Status(models.TextChoices):
        DRAFT = 'DRAFT', 'Draft'
        ACTIVE = 'ACTIVE', 'Active'
        PAUSED = 'PAUSED', 'Paused'
        EXHAUSTED = 'EXHAUSTED', 'Exhausted'

    vendor = models.ForeignKey('vendors.Vendor', on_delete=models.CASCADE, related_name='ad_campaigns')
    product = models.ForeignKey('products.Product', on_delete=models.CASCADE, related_name='ad_campaigns')
    
    budget_total = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'))
    budget_spent = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'))
    daily_budget = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    
    cost_per_click = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal('0.00'))
    
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    
    starts_at = models.DateTimeField(default=timezone.now)
    ends_at = models.DateTimeField(null=True, blank=True)
    
    keywords = models.JSONField(default=list, blank=True)
    target_categories = models.ManyToManyField('products.Category', blank=True, related_name='targeted_ad_campaigns')
    
    is_sponsored_label_required = models.BooleanField(default=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def is_active(self) -> bool:
        now = timezone.now()
        return (
            self.status == self.Status.ACTIVE and
            self.starts_at <= now and
            (self.ends_at is None or self.ends_at >= now) and
            self.budget_spent < self.budget_total
        )

    def __str__(self):
        return f"Campaign {self.id} for Product {self.product_id} (Vendor {self.vendor_id})"

class AdImpression(models.Model):
    campaign = models.ForeignKey(AdCampaign, on_delete=models.CASCADE, related_name='impressions')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    session_id = models.UUIDField(db_index=True)
    source = models.CharField(max_length=50) # HOME, SEARCH, COLLECTION
    minute_bucket = models.DateTimeField(db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['campaign', 'session_id', 'source', 'minute_bucket'],
                name='unique_ad_impression_per_minute'
            )
        ]

    def __str__(self):
        return f"Impression for Campaign {self.campaign_id} at {self.created_at}"

class AdClick(models.Model):
    campaign = models.ForeignKey(AdCampaign, on_delete=models.CASCADE, related_name='clicks')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    session_id = models.UUIDField(db_index=True)
    click_id = models.UUIDField(unique=True, help_text="Client-generated UUID for idempotency")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Click for Campaign {self.campaign_id} at {self.created_at}"
