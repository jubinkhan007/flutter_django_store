# ═══════════════════════════════════════════════════════════════════
# VENDORS SERIALIZERS
# ═══════════════════════════════════════════════════════════════════

from rest_framework import serializers
from .models import (
    Vendor,
    WalletTransaction,
    PayoutRequest,
    BulkJob,
    LedgerEntry,
    SettlementRecord,
    VendorPayoutMethod,
)


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
            'id',
            'store_name',
            'description',
            'balance',
            'pending_balance',
            'available_balance',
            'held_balance',
            'total_earned_lifetime',
            'total_withdrawn_lifetime',
            'is_approved',
            'cancellation_rate', 'late_shipment_rate', 'avg_handling_time_days',
            'created_at'
        )
        read_only_fields = (
            'id',
            'balance',
            'pending_balance',
            'available_balance',
            'held_balance',
            'total_earned_lifetime',
            'total_withdrawn_lifetime',
            'is_approved',
            'cancellation_rate', 'late_shipment_rate', 'avg_handling_time_days',
        )


class PublicVendorProfileSerializer(serializers.ModelSerializer):
    """
    WHAT: Translates Vendor model ⟷ JSON for PUBLIC viewing
    WHEN USED:
      - Viewing a vendor storefront (GET /api/vendors/public/<id>/)
    NOTE: EXCLUDES financial balances and private SLA metrics.
    """
    class Meta:
        model = Vendor
        fields = (
            'id',
            'store_name',
            'description',
            'logo',
            'cover_image',
            'joined_at',
            'policy_summary',
            'avg_rating',
            'review_count',
        )


class WalletTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = WalletTransaction
        fields = ['id', 'amount', 'transaction_type', 'description', 'reference_id', 'created_at']
        read_only_fields = fields


class PayoutRequestSerializer(serializers.ModelSerializer):
    payout_method_details = serializers.SerializerMethodField()

    class Meta:
        model = PayoutRequest
        fields = [
            'id', 'amount', 'status', 'payout_method', 'payout_method_details',
            'disbursal_channel', 'bank_details', 'gateway_reference', 'gateway_fee',
            'failure_reason', 'is_automated', 'admin_note', 'requested_at', 'processed_at'
        ]
        read_only_fields = [
            'id', 'status', 'disbursal_channel', 'gateway_reference', 'gateway_fee',
            'failure_reason', 'is_automated', 'admin_note', 'requested_at', 'processed_at',
            'payout_method_details'
        ]
        extra_kwargs = {
            'bank_details': {'required': False, 'allow_blank': True},
        }

    def get_payout_method_details(self, obj):
        if obj.payout_method:
            return {
                'id': obj.payout_method.id,
                'method': obj.payout_method.method,
                'label': obj.payout_method.label,
                'is_verified': obj.payout_method.is_verified,
            }
        return None

    def validate(self, attrs):
        if not attrs.get('bank_details') and not attrs.get('payout_method'):
            raise serializers.ValidationError({"bank_details": "Please specify bank/wallet details or select a payout method."})
        if not attrs.get('bank_details') and attrs.get('payout_method'):
            pm = attrs['payout_method']
            attrs['bank_details'] = f"{pm.method} ({pm.label or 'Default'}): {pm.details}"
        return attrs

    def validate_amount(self, value):
        if value <= 0:
            raise serializers.ValidationError("Payout amount must be greater than zero.")
        return value


class VendorPayoutMethodSerializer(serializers.ModelSerializer):
    class Meta:
        model = VendorPayoutMethod
        fields = [
            'id', 'method', 'label', 'details', 'is_verified',
            'verified_at', 'verification_notes', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'is_verified', 'verified_at', 'verification_notes', 'created_at', 'updated_at']


class VendorPayoutSettingsSerializer(serializers.ModelSerializer):
    preferred_payout_method_details = VendorPayoutMethodSerializer(source='preferred_payout_method', read_only=True)

    class Meta:
        model = Vendor
        fields = [
            'is_auto_payout_enabled',
            'auto_payout_schedule',
            'auto_payout_threshold',
            'preferred_payout_method',
            'preferred_payout_method_details',
            'last_payout_at',
        ]
        read_only_fields = ['last_payout_at', 'preferred_payout_method_details']


class LedgerEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = LedgerEntry
        fields = [
            'id',
            'entry_type',
            'bucket',
            'direction',
            'status',
            'amount',
            'reference_type',
            'reference_id',
            'description',
            'created_at',
        ]
        read_only_fields = fields


class SettlementRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = SettlementRecord
        fields = [
            'id',
            'sub_order',
            'gross_amount',
            'platform_fee',
            'net_amount',
            'status',
            'settlement_date',
            'created_at',
            'released_at',
        ]
        read_only_fields = fields


class BulkJobSerializer(serializers.ModelSerializer):
    class Meta:
        model = BulkJob
        fields = ['id', 'job_type', 'status', 'file', 'result_report', 'created_at', 'updated_at']
        read_only_fields = ['id', 'status', 'result_report', 'created_at', 'updated_at']
