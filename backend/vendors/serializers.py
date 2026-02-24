# ═══════════════════════════════════════════════════════════════════
# VENDORS SERIALIZERS
# ═══════════════════════════════════════════════════════════════════
#
# CONCEPT: What is a Serializer?
# ──────────────────────────────
# Remember from users/serializers.py — a serializer is a TRANSLATOR.
# It converts between Python objects (Django models) ⟷ JSON (for the API).
#
# But serializers also do VALIDATION:
#   - Is store_name provided? Is it unique?
#   - Is the data in the correct format?
# Think of a serializer as a SECURITY GUARD at the entrance of your database.
# It checks every piece of data before letting it in.
#
# ═══════════════════════════════════════════════════════════════════

from rest_framework import serializers
from .models import Vendor


class VendorSerializer(serializers.ModelSerializer):
    """
    WHAT: Translates Vendor model ⟷ JSON
    WHEN USED:
      - Creating a new vendor (POST /api/vendors/onboarding/)
      - Viewing vendor profile (GET /api/vendors/me/)
    """

    class Meta:
        model = Vendor
        fields = ('id', 'store_name', 'description', 'balance', 'is_approved', 'created_at')
        read_only_fields = ('id', 'balance', 'is_approved', 'created_at')

    # ─── WHY NO create() override here? ─────────────────────────
    # Unlike UserRegistrationSerializer, we DON'T override create().
    # That's because the default ModelSerializer.create() works fine here.
    # We'll handle linking the vendor to the user in the VIEW, not the serializer.
    # Rule of thumb: Serializer = data validation. View = business logic.
