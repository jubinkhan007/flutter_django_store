# ═══════════════════════════════════════════════════════════════════
# VENDORS SERIALIZERS
# ═══════════════════════════════════════════════════════════════════

from rest_framework import serializers
from .models import Vendor, WalletTransaction, PayoutRequest, BulkJob


class VendorSerializer(serializers.ModelSerializer):
    """
    WHAT: Translates Vendor model ⟷ JSON
    WHEN USED:
      - Creating a new vendor (POST /api/vendors/onboarding/)
      - Viewing vendor profile (GET /api/vendors/me/)
    """

    class Meta:
        model = Vendor
        fields = (
            'id', 'store_name', 'description', 'balance', 'is_approved', 
            'cancellation_rate', 'late_shipment_rate', 'avg_handling_time_days',
            'created_at'
        )
        read_only_fields = (
            'id', 'balance', 'is_approved', 
            'cancellation_rate', 'late_shipment_rate', 'avg_handling_time_days',
            'created_at'
        )


class WalletTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = WalletTransaction
        fields = ['id', 'amount', 'transaction_type', 'description', 'reference_id', 'created_at']
        read_only_fields = fields


class PayoutRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = PayoutRequest
        fields = ['id', 'amount', 'status', 'bank_details', 'admin_note', 'requested_at', 'processed_at']
        read_only_fields = ['id', 'status', 'admin_note', 'requested_at', 'processed_at']

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError("Payout amount must be greater than zero.")
        return value


class BulkJobSerializer(serializers.ModelSerializer):
    class Meta:
        model = BulkJob
        fields = ['id', 'job_type', 'status', 'file', 'result_report', 'created_at', 'updated_at']
        read_only_fields = ['id', 'status', 'result_report', 'created_at', 'updated_at']
