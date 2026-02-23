from rest_framework import generics, permissions, status
from rest_framework.response import Response
from .models import Category, Product
from .serializers import CategorySerializer, ProductSerializer

# ═══════════════════════════════════════════════════════════════════
# PUBLIC VIEWS (Anyone can see these)
# ═══════════════════════════════════════════════════════════════════

class CategoryListView(generics.ListAPIView):
    """
    GET /api/products/categories/
    Returns a list of all product categories.
    """
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny]


class PublicProductListView(generics.ListAPIView):
    """
    GET /api/products/
    Returns a list of all products.
    Optional: Filter by category ID. Example: /api/products/?category=2
    """
    serializer_class = ProductSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        # Start with all available products
        queryset = Product.objects.filter(is_available=True)
        
        # Check if they are searching for a specific category
        category_id = self.request.query_params.get('category')
        if category_id:
            queryset = queryset.filter(category_id=category_id)
            
        return queryset


class PublicProductDetailView(generics.RetrieveAPIView):
    """
    GET /api/products/<id>/
    Returns the details of a single product.
    """
    queryset = Product.objects.filter(is_available=True)
    serializer_class = ProductSerializer
    permission_classes = [permissions.AllowAny]


# ═══════════════════════════════════════════════════════════════════
# VENDOR VIEWS (Must be logged in and own the product)
# ═══════════════════════════════════════════════════════════════════

class VendorProductListCreateView(generics.ListCreateAPIView):
    """
    GET /api/vendors/products/
    POST /api/vendors/products/
    
    Vendors use this to SEE their own products and ADD new products.
    """
    serializer_class = ProductSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # We only return products that belong to the logged-in vendor
        try:
            return self.request.user.vendor_profile.products.all()
        except AttributeError:
            # If the user is authenticated but somehow isn't a vendor, return nothing
            return Product.objects.none()

    def perform_create(self, serializer):
        # When a vendor CREATES a product (POST), we automatically set the 'vendor' field
        # to the currently logged-in user's vendor profile.
        # This is CRITICAL for security so vendors can't add products to competing stores.
        vendor = self.request.user.vendor_profile
        serializer.save(vendor=vendor)


class VendorProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET /api/vendors/products/<id>/
    PUT/PATCH /api/vendors/products/<id>/
    DELETE /api/vendors/products/<id>/
    
    Vendors use this to edit or delete a specific product.
    """
    serializer_class = ProductSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Restrict the queryset so they can ONLY edit products they own.
        # If they try to edit product ID 5, but product 5 belongs to someone else,
        # they will get a 404 Not Found error (as if it doesn't exist).
        try:
            return self.request.user.vendor_profile.products.all()
        except AttributeError:
            return Product.objects.none()
