from __future__ import annotations

from rest_framework import serializers

from .models import LiveDeliveryTracking, LogisticsArea, LogisticsStore


class LogisticsStoreSerializer(serializers.ModelSerializer):
    class Meta:
        model = LogisticsStore
        fields = [
            'id',
            'courier',
            'mode',
            'name',
            'contact_name',
            'phone',
            'address',
            'city',
            'area',
            'external_store_id',
        ]


class LogisticsAreaSerializer(serializers.ModelSerializer):
    parent_external_id = serializers.CharField(source='parent.external_id', read_only=True)

    class Meta:
        model = LogisticsArea
        fields = [
            'id',
            'courier',
            'mode',
            'kind',
            'external_id',
            'name',
            'parent_external_id',
        ]


class LiveDeliveryTrackingSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    sub_order_id = serializers.IntegerField(source='sub_order.id', read_only=True)

    class Meta:
        model = LiveDeliveryTracking
        fields = [
            'id',
            'sub_order_id',
            'rider_name',
            'rider_phone',
            'rider_photo',
            'rider_rating',
            'vehicle_type',
            'vehicle_number',
            'courier_brand',
            'status',
            'status_display',
            'origin_latitude',
            'origin_longitude',
            'origin_name',
            'destination_latitude',
            'destination_longitude',
            'destination_name',
            'current_latitude',
            'current_longitude',
            'heading_degrees',
            'speed_kmh',
            'eta_minutes',
            'distance_km',
            'route_waypoints',
            'current_waypoint_index',
            'last_location_update',
        ]

