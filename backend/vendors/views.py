# ═══════════════════════════════════════════════════════════════════
# VENDORS VIEWS
# ═══════════════════════════════════════════════════════════════════
#
# CONCEPT: What are Views?
# ────────────────────────
# Views are the HEART of your API. Each view answers one question:
#   "What happens when someone sends a request to this URL?"
#
# DRF (Django Rest Framework) gives us pre-built view classes:
#   - CreateAPIView   → handles POST (creating new things)
#   - RetrieveAPIView → handles GET (viewing one thing)
#   - ListAPIView     → handles GET (viewing a list of things)
#   - UpdateAPIView   → handles PUT/PATCH (editing things)
#   - DestroyAPIView  → handles DELETE (removing things)
#
# You can also COMBINE them. For example:
#   - RetrieveUpdateAPIView → handles both GET and PUT/PATCH
#
# NEW CONCEPT: permissions.IsAuthenticated
# ─────────────────────────────────────────
# Unlike registration (which used AllowAny), these vendor endpoints
# REQUIRE a valid JWT token. Only logged-in users can become vendors
# or view their dashboard. DRF checks the token automatically for us.
#
# ═══════════════════════════════════════════════════════════════════

from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import Vendor
from .serializers import VendorSerializer


class VendorOnboardingView(generics.CreateAPIView):
    """
    WHAT: POST /api/vendors/onboarding/
    WHO:  Any logged-in user who wants to become a vendor
    WHY:  A user needs to create a "store" to start selling products

    FLOW:
    1. User sends: {"store_name": "My Shop", "description": "We sell cool stuff"}
    2. We check: Does this user already have a vendor profile?
       - YES → Return error "You already have a store"
       - NO  → Create the vendor profile and link it to the user
    3. Return the created vendor profile as JSON
    """
    serializer_class = VendorSerializer
    permission_classes = [IsAuthenticated]  # Must be logged in (JWT token required)

    def create(self, request, *args, **kwargs):
        # ─── Step 1: Check if user already has a vendor profile ───
        # hasattr() checks if the user object has a 'vendor_profile' attribute.
        # Remember in models.py we defined:
        #   user = OneToOneField(..., related_name='vendor_profile')
        # That 'related_name' lets us access the Vendor FROM the User like this:
        #   user.vendor_profile → returns the Vendor object (or raises an error if none)
        if hasattr(request.user, 'vendor_profile'):
            return Response(
                {"error": "You already have a vendor profile."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # ─── Step 2: Validate the incoming data ──────────────────
        # Pass the JSON data from the request body to our serializer
        serializer = self.get_serializer(data=request.data)

        # is_valid() runs all the validation rules:
        #   - Is store_name provided? Is it unique?
        #   - raise_exception=True means: if validation fails,
        #     automatically return a 400 error with details. We don't
        #     need to write error handling ourselves!
        serializer.is_valid(raise_exception=True)

        # ─── Step 3: Save to database ────────────────────────────
        # serializer.save() calls the serializer's create() method.
        # We pass user=request.user to LINK this vendor to the logged-in user.
        #
        # HOW THIS WORKS:
        # save(user=request.user) adds 'user' to the validated_data dict,
        # then create() does: Vendor.objects.create(**validated_data)
        # So it becomes: Vendor.objects.create(store_name="...", description="...", user=<current_user>)
        serializer.save(user=request.user)

        # ─── Step 4: Update user type to VENDOR ──────────────────
        # When someone creates a store, they transition from CUSTOMER to VENDOR.
        request.user.type = 'VENDOR'
        request.user.save()

        return Response(serializer.data, status=status.HTTP_201_CREATED)


class VendorDashboardView(generics.RetrieveUpdateAPIView):
    """
    WHAT: GET/PUT /api/vendors/me/
    WHO:  Only the vendor themselves
    WHY:  A vendor needs to see and edit their store details

    GET  → Returns: {"id": 1, "store_name": "My Shop", "description": "...", ...}
    PUT  → Accepts: {"store_name": "New Name", "description": "Updated desc"}
           Returns: the updated vendor profile

    NEW CONCEPT: get_object()
    ─────────────────────────
    Normally, RetrieveAPIView needs a URL like /api/vendors/5/ (with an ID).
    But for "my dashboard", the user shouldn't need to know their vendor ID.
    So we override get_object() to say: "don't look at the URL, just return
    the vendor profile for the currently logged-in user."
    """
    serializer_class = VendorSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        # request.user = the logged-in user (decoded from the JWT token)
        # .vendor_profile = the related Vendor object (from our OneToOneField)
        # If the user is NOT a vendor, this will raise a 404 automatically.
        return self.request.user.vendor_profile
