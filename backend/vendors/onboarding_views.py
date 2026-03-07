from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from vendors.models import Vendor
from logistics.models import LogisticsStore # Assuming logistics store exists for pickup
from products.models import Product

class VendorOnboardingProgressView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        """
        Returns a checklist for vendor onboarding readiness.
        """
        try:
            vendor = request.user.vendor_profile
        except Vendor.DoesNotExist:
            # User is authenticated but hasn't created a vendor profile yet.
            # Return an "all false" checklist so the client can render onboarding steps.
            return Response(
                {
                    "has_vendor_profile": False,
                    "store_created": False,
                    "payout_method_added": False,
                    "pickup_store_linked": False,
                    "first_product_with_variant": False,
                    "is_ready": False,
                    "is_live": False,
                },
                status=200,
            )
            
        store_created = bool(vendor.store_name)
        
        # Check Payout Method
        payout_method_added = vendor.payout_methods.filter(is_verified=True).exists() if hasattr(vendor, 'payout_methods') else False
        
        # Check Pickup Store
        pickup_store_linked = False
        try:
            pickup_store_linked = LogisticsStore.objects.filter(owner_vendor=vendor).exists()
        except:
            pass # Logistics module might not handle vendors this way directly
            
        # Check First Product with Variant
        first_product_with_variant = Product.objects.filter(vendor=vendor, variants__isnull=False).exists()
        
        # Overall Readiness
        is_ready = store_created and payout_method_added and pickup_store_linked and first_product_with_variant
        
        # Auto-activate if all pass, or just report status
        if is_ready and not vendor.is_live:
            # Depending on business rules, we might want admin approval first. 
            # We will just report for now, but client could use this to show "You are ready!"
            pass

        return Response({
            "has_vendor_profile": True,
            "store_created": store_created,
            "payout_method_added": payout_method_added,
            "pickup_store_linked": pickup_store_linked,
            "first_product_with_variant": first_product_with_variant,
            "is_ready": is_ready,
            "is_live": vendor.is_live
        })
