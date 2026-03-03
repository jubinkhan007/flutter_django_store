from __future__ import annotations

from django.db import models

from vendors.models import Vendor


class CourierIntegration(models.Model):
    class Courier(models.TextChoices):
        REDX = 'REDX', 'RedX'
        STEADFAST = 'STEADFAST', 'Steadfast'
        PATHAO = 'PATHAO', 'Pathao'

    class OwnerType(models.TextChoices):
        PLATFORM = 'PLATFORM', 'Platform'
        VENDOR = 'VENDOR', 'Vendor'

    class Mode(models.TextChoices):
        SANDBOX = 'SANDBOX', 'Sandbox'
        PROD = 'PROD', 'Production'

    courier = models.CharField(max_length=30, choices=Courier.choices)
    owner_type = models.CharField(max_length=20, choices=OwnerType.choices, default=OwnerType.PLATFORM)
    owner_vendor = models.ForeignKey(Vendor, null=True, blank=True, on_delete=models.CASCADE)
    mode = models.CharField(max_length=20, choices=Mode.choices, default=Mode.SANDBOX)
    is_enabled = models.BooleanField(default=False)

    # For OAuth-style couriers (e.g., Pathao). Secrets stay in env, tokens can be cached here.
    access_token = models.TextField(blank=True, default='')
    refresh_token = models.TextField(blank=True, default='')
    expires_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['courier', 'owner_type', 'mode']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['courier', 'owner_type', 'owner_vendor', 'mode'],
                name='uniq_courier_integration_owner_mode',
            )
        ]

    def __str__(self) -> str:
        owner = self.owner_type
        if self.owner_vendor_id:
            owner = f'{owner}:{self.owner_vendor_id}'
        return f'{self.courier} {self.mode} ({owner})'


class LogisticsStore(models.Model):
    class OwnerType(models.TextChoices):
        PLATFORM = 'PLATFORM', 'Platform'
        VENDOR = 'VENDOR', 'Vendor'

    class Mode(models.TextChoices):
        SANDBOX = 'SANDBOX', 'Sandbox'
        PROD = 'PROD', 'Production'

    courier = models.CharField(max_length=30, choices=CourierIntegration.Courier.choices)
    mode = models.CharField(max_length=20, choices=Mode.choices, default=Mode.SANDBOX)
    owner_type = models.CharField(max_length=20, choices=OwnerType.choices, default=OwnerType.PLATFORM)
    owner_vendor = models.ForeignKey(Vendor, null=True, blank=True, on_delete=models.CASCADE)

    name = models.CharField(max_length=255)
    contact_name = models.CharField(max_length=255, blank=True, default='')
    phone = models.CharField(max_length=50, blank=True, default='')
    address = models.TextField(blank=True, default='')
    city = models.CharField(max_length=120, blank=True, default='')
    area = models.CharField(max_length=120, blank=True, default='')

    external_store_id = models.CharField(max_length=255, blank=True, default='')
    is_active = models.BooleanField(default=True)

    assigned_vendors = models.ManyToManyField(Vendor, related_name='logistics_stores', blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['courier', 'mode', 'is_active']),
        ]

    def __str__(self) -> str:
        return f'{self.courier} store: {self.name}'


class LogisticsArea(models.Model):
    class Kind(models.TextChoices):
        CITY = 'CITY', 'City'
        ZONE = 'ZONE', 'Zone'
        AREA = 'AREA', 'Area'

    class Mode(models.TextChoices):
        SANDBOX = 'SANDBOX', 'Sandbox'
        PROD = 'PROD', 'Production'

    courier = models.CharField(max_length=30, choices=CourierIntegration.Courier.choices)
    mode = models.CharField(max_length=20, choices=Mode.choices, default=Mode.SANDBOX)
    kind = models.CharField(max_length=20, choices=Kind.choices)

    external_id = models.CharField(max_length=255)
    name = models.CharField(max_length=255)
    parent = models.ForeignKey('self', null=True, blank=True, on_delete=models.SET_NULL, related_name='children')

    raw = models.JSONField(default=dict, blank=True)
    last_synced_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['courier', 'mode', 'kind', 'external_id']),
            models.Index(fields=['courier', 'mode', 'kind', 'name']),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['courier', 'mode', 'kind', 'external_id'],
                name='uniq_logistics_area_key',
            )
        ]

    def __str__(self) -> str:
        return f'{self.courier} {self.kind} {self.name}'

