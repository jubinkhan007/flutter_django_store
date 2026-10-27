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


class LiveDeliveryTracking(models.Model):
    class DispatchStatus(models.TextChoices):
        DISPATCHED = 'DISPATCHED', 'Dispatched'
        PICKED_UP = 'PICKED_UP', 'Picked Up'
        IN_TRANSIT = 'IN_TRANSIT', 'In Transit'
        OUT_FOR_DELIVERY = 'OUT_FOR_DELIVERY', 'Out for Delivery'
        ARRIVING_SOON = 'ARRIVING_SOON', 'Arriving Soon'
        DELIVERED = 'DELIVERED', 'Delivered'

    sub_order = models.OneToOneField(
        'orders.SubOrder',
        on_delete=models.CASCADE,
        related_name='live_tracking',
    )
    rider_name = models.CharField(max_length=120, default='Tanvir Ahmed')
    rider_phone = models.CharField(max_length=30, blank=True, default='+8801712345678')
    rider_photo = models.CharField(max_length=500, blank=True, default='')
    rider_rating = models.DecimalField(max_digits=3, decimal_places=1, default=4.9)
    vehicle_type = models.CharField(max_length=50, default='Motorcycle')
    vehicle_number = models.CharField(max_length=50, blank=True, default='DHAKA METRO-HA-12-3456')
    courier_brand = models.CharField(max_length=50, default='Pathao Express')

    status = models.CharField(
        max_length=30,
        choices=DispatchStatus.choices,
        default=DispatchStatus.OUT_FOR_DELIVERY,
    )

    origin_latitude = models.FloatField(default=23.7925)
    origin_longitude = models.FloatField(default=90.4078)
    origin_name = models.CharField(max_length=255, default='Merchant Dispatch Hub')

    destination_latitude = models.FloatField(default=23.8103)
    destination_longitude = models.FloatField(default=90.4125)
    destination_name = models.CharField(max_length=255, default='Customer Delivery Address')

    current_latitude = models.FloatField(default=23.7980)
    current_longitude = models.FloatField(default=90.4095)
    heading_degrees = models.FloatField(default=45.0)
    speed_kmh = models.FloatField(default=24.0)
    eta_minutes = models.IntegerField(default=14)
    distance_km = models.DecimalField(max_digits=6, decimal_places=2, default=2.10)

    route_waypoints = models.JSONField(default=list, blank=True)
    current_waypoint_index = models.IntegerField(default=2)

    last_location_update = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['sub_order', 'status']),
        ]

    def __str__(self) -> str:
        return f'Live Tracking: SubOrder #{self.sub_order_id} ({self.status})'

    def ensure_route_waypoints(self) -> list[dict[str, float]]:
        if self.route_waypoints and len(self.route_waypoints) >= 4:
            return self.route_waypoints

        # Generate realistic curved road waypoints from origin to destination
        points = []
        n_steps = 14
        lat_start, lng_start = self.origin_latitude, self.origin_longitude
        lat_end, lng_end = self.destination_latitude, self.destination_longitude

        import math
        for i in range(n_steps + 1):
            t = i / n_steps
            # Linear interpolation plus subtle urban street curve
            curve = math.sin(t * math.pi) * 0.0032
            lat = round(lat_start + (lat_end - lat_start) * t + curve, 6)
            lng = round(lng_start + (lng_end - lng_start) * t - (curve * 0.7), 6)
            points.append({'lat': lat, 'lng': lng})

        self.route_waypoints = points
        return points

    def advance_simulation(self, steps: int = 1) -> dict:
        waypoints = self.ensure_route_waypoints()
        total_pts = len(waypoints)
        if total_pts == 0:
            return {'status': self.status, 'eta_minutes': self.eta_minutes}

        next_idx = min(self.current_waypoint_index + steps, total_pts - 1)
        self.current_waypoint_index = next_idx
        pt = waypoints[next_idx]
        self.current_latitude = pt['lat']
        self.current_longitude = pt['lng']

        import math
        # Calculate heading to next point
        if next_idx < total_pts - 1:
            nxt = waypoints[next_idx + 1]
            d_lat = nxt['lat'] - pt['lat']
            d_lng = nxt['lng'] - pt['lng']
            angle_rad = math.atan2(d_lng, d_lat)
            self.heading_degrees = round((math.degrees(angle_rad) + 360) % 360, 1)

        # Fraction remaining
        remaining_ratio = max(0.0, 1.0 - (next_idx / (total_pts - 1)))
        from decimal import Decimal
        self.distance_km = Decimal(str(round(remaining_ratio * 3.5, 2)))
        self.eta_minutes = max(1 if remaining_ratio > 0 else 0, int(round(remaining_ratio * 20)))

        if remaining_ratio <= 0.0:
            self.status = self.DispatchStatus.DELIVERED
            self.speed_kmh = 0.0
        elif remaining_ratio <= 0.15:
            self.status = self.DispatchStatus.ARRIVING_SOON
            self.speed_kmh = 14.0
        elif remaining_ratio <= 0.60:
            self.status = self.DispatchStatus.OUT_FOR_DELIVERY
            self.speed_kmh = 26.0
        elif remaining_ratio <= 0.85:
            self.status = self.DispatchStatus.IN_TRANSIT
            self.speed_kmh = 28.0
        else:
            self.status = self.DispatchStatus.PICKED_UP
            self.speed_kmh = 20.0

        self.save()
        return {
            'status': self.status,
            'current_latitude': self.current_latitude,
            'current_longitude': self.current_longitude,
            'eta_minutes': self.eta_minutes,
            'distance_km': str(self.distance_km),
            'heading_degrees': self.heading_degrees,
            'speed_kmh': self.speed_kmh,
        }


