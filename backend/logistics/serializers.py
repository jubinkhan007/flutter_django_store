from __future__ import annotations

from rest_framework import serializers

from .models import LogisticsArea, LogisticsStore


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

