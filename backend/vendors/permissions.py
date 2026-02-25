from rest_framework import permissions
from .models import VendorStaff

class IsVendorStaff(permissions.BasePermission):
    """
    Custom permission to check if the user is a vendor owner or a vendor staff member.
    Optionally checks for specific roles.
    """
    allowed_roles = []

    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False

        # If user is the vendor owner (VendorProfile exists)
        if hasattr(request.user, 'vendor_profile'):
            request.vendor = request.user.vendor_profile
            return True

        # Check if user is a VendorStaff
        try:
            staff = VendorStaff.objects.select_related('role', 'vendor').get(user=request.user, is_active=True)
            request.vendor = staff.vendor
            request.vendor_staff = staff
            if self.allowed_roles and staff.role and staff.role.name not in self.allowed_roles:
                return False
            return True
        except VendorStaff.DoesNotExist:
            return False

    def has_object_permission(self, request, view, obj):
        # We need to enforce object-level permissions, usually matching obj.vendor == request.vendor
        # The view should handle fetching the correct queryset (e.g. qs.filter(vendor=request.vendor)),
        # but this is an extra safety layer.
        
        if hasattr(obj, 'vendor'):
            return obj.vendor == request.vendor
        
        # If the object is the vendor itself
        if hasattr(obj, 'store_name') and hasattr(obj, 'balance'):
            return obj == request.vendor
            
        return True

class IsVendorOwnerOrManager(IsVendorStaff):
    allowed_roles = ['Owner', 'Manager']

class IsVendorPackerOrAbove(IsVendorStaff):
    allowed_roles = ['Owner', 'Manager', 'Packer']

class IsVendorSupportOrAbove(IsVendorStaff):
    allowed_roles = ['Owner', 'Manager', 'Support']
