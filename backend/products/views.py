from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import Category, Product
from django.db.models import Q
from django.db import connection
from .serializers import CategorySerializer, ProductSerializer

# ═══════════════════════════════════════════════════════════════════
# PUBLIC VIEWS (Anyone can see these)
# ═══════════════════════════════════════════════════════════════════

def _normalize_match_text(value):
    return (value or "").strip().lower()


def _best_token_similarity(query, text):
    """
    Lightweight fuzzy score in [0..1] based on difflib ratio.
    Uses both the full string and token-level comparisons.
    """
    q = _normalize_match_text(query)
    t = _normalize_match_text(text)
    if not q or not t:
        return 0.0

    from difflib import SequenceMatcher
    import re

    best = SequenceMatcher(None, q, t).ratio()
    for token in re.split(r"[^a-z0-9]+", t):
        if not token:
            continue
        best = max(best, SequenceMatcher(None, q, token).ratio())
    return best


def _top_fuzzy(items, score_fn, *, limit, cutoff):
    scored = []
    for item in items:
        score = float(score_fn(item) or 0.0)
        if score >= cutoff:
            scored.append((score, item))
    scored.sort(key=lambda x: x[0], reverse=True)
    return [item for _, item in scored[:limit]]


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

        # 1. Filter by category ID(s)
        # Expected format: ?category=1 or ?category=1,2,3
        category_param = self.request.query_params.get('category')
        if category_param:
            # allow comma-separated category IDs
            category_ids = [int(cid) for cid in category_param.split(',') if cid.isdigit()]
            if category_ids:
                queryset = queryset.filter(category_id__in=category_ids)

        # 2. Filter by Price Range
        min_price = self.request.query_params.get('min_price')
        max_price = self.request.query_params.get('max_price')
        
        if min_price:
            try:
                queryset = queryset.filter(price__gte=float(min_price))
            except ValueError:
                pass
                
        if max_price:
            try:
                queryset = queryset.filter(price__lte=float(max_price))
            except ValueError:
                pass

        # 3. Search by name/description/vendor (with a fuzzy fallback)
        search_query = (self.request.query_params.get('search') or '').strip()
        used_similarity_order = False
        if search_query:
            direct = queryset.filter(
                Q(name__icontains=search_query) |
                Q(description__icontains=search_query) |
                Q(vendor__store_name__icontains=search_query)
            )

            if direct.exists():
                queryset = direct
            else:
                is_postgres = connection.vendor == 'postgresql'
                if is_postgres:
                    from django.contrib.postgres.search import TrigramSimilarity
                    from django.db.models.functions import Greatest

                    queryset = queryset.annotate(
                        similarity=Greatest(
                            TrigramSimilarity('name', search_query),
                            TrigramSimilarity('description', search_query),
                            TrigramSimilarity('vendor__store_name', search_query),
                        )
                    ).filter(similarity__gt=0.2).order_by('-similarity')
                    used_similarity_order = True
                else:
                    # SQLite/dev fallback: small in-Python fuzzy rank.
                    candidates = list(
                        queryset.select_related('vendor')[:500]
                    )

                    def _score(p):
                        return max(
                            _best_token_similarity(search_query, p.name),
                            _best_token_similarity(
                                search_query,
                                getattr(p.vendor, 'store_name', '') if p.vendor else ''
                            ),
                        )

                    top = _top_fuzzy(
                        candidates,
                        _score,
                        limit=50,
                        cutoff=0.55,
                    )
                    ids = [p.id for p in top]
                    queryset = queryset.filter(id__in=ids) if ids else queryset.none()

                    # If no explicit sort is requested, prefer similarity order.
                    sort_by = (self.request.query_params.get('sort') or '').strip()
                    if not sort_by or sort_by == 'newest':
                        from django.db.models import Case, When, IntegerField
                        preserved = Case(
                            *[When(id=pk, then=pos) for pos, pk in enumerate(ids)],
                            output_field=IntegerField(),
                        )
                        queryset = queryset.order_by(preserved)
                        used_similarity_order = True

        # 4. Sorting
        sort_by = self.request.query_params.get('sort')
        if not used_similarity_order:
            if sort_by == 'price_asc':
                queryset = queryset.order_by('price')
            elif sort_by == 'price_desc':
                queryset = queryset.order_by('-price')
            elif sort_by == 'newest':
                queryset = queryset.order_by('-created_at')
            else:
                # Default sort (newest first or arbitrary)
                queryset = queryset.order_by('-created_at')
            
        return queryset


class PublicProductDetailView(generics.RetrieveAPIView):
    """
    GET /api/products/<id>/
    Returns the details of a single product.
    """
    queryset = Product.objects.filter(is_available=True)
    serializer_class = ProductSerializer
    permission_classes = [permissions.AllowAny]


import time

class SearchSuggestionView(APIView):
    """
    GET /api/products/search/suggestions/?q=term
    Returns a typed list of suggestions (PRODUCT, CATEGORY, VENDOR)
    using pg_trgm similarity if available, with an icontains fallback.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request, *args, **kwargs):
        start_time = time.time()
        query = request.query_params.get('q', '').strip()
        
        if not query or len(query) < 2:
            return Response({
                "query": query,
                "results": [],
                "server_ms": 0
            })

        results = []
        is_postgres = connection.vendor == 'postgresql'

        # 1. Product Matches (Limit 5)
        if is_postgres:
            from django.contrib.postgres.search import TrigramSimilarity
            products = Product.objects.filter(is_available=True).annotate(
                similarity=TrigramSimilarity('name', query)
            ).filter(similarity__gt=0.2).order_by('-similarity')[:5]
        else:
            products = Product.objects.filter(is_available=True, name__icontains=query)[:5]

            if not products:
                candidates = Product.objects.filter(
                    is_available=True
                ).select_related('category')[:500]

                top = _top_fuzzy(
                    candidates,
                    lambda p: _best_token_similarity(query, p.name),
                    limit=5,
                    cutoff=0.55,
                )
                products = top
            
        for p in products:
            results.append({
                "type": "PRODUCT",
                "id": p.id,
                "label": p.name,
                "subtitle": p.category.name if p.category else "Product"
            })

        # 2. Category Matches (Limit 3)
        if is_postgres:
            categories = Category.objects.annotate(
                similarity=TrigramSimilarity('name', query)
            ).filter(similarity__gt=0.3).order_by('-similarity')[:3]
        else:
            categories = Category.objects.filter(name__icontains=query)[:3]

            if not categories:
                candidates = Category.objects.all()[:500]
                categories = _top_fuzzy(
                    candidates,
                    lambda c: _best_token_similarity(query, c.name),
                    limit=3,
                    cutoff=0.55,
                )
            
        for c in categories:
            results.append({
                "type": "CATEGORY",
                "id": c.id,
                "label": c.name,
                "subtitle": "Category"
            })

        # 3. Vendor Matches (Limit 3)
        from vendors.models import Vendor
        if is_postgres:
            vendors = Vendor.objects.filter(is_approved=True).annotate(
                similarity=TrigramSimilarity('store_name', query)
            ).filter(similarity__gt=0.3).order_by('-similarity')[:3]
        else:
            vendors = Vendor.objects.filter(is_approved=True, store_name__icontains=query)[:3]

            if not vendors:
                candidates = Vendor.objects.filter(is_approved=True)[:500]
                vendors = _top_fuzzy(
                    candidates,
                    lambda v: _best_token_similarity(query, v.store_name),
                    limit=3,
                    cutoff=0.55,
                )

        for v in vendors:
            results.append({
                "type": "VENDOR",
                "id": v.id,
                "label": v.store_name,
                "subtitle": f"{v.avg_rating}★ ({v.review_count})" if v.review_count > 0 else "New Store"
            })

        server_ms = int((time.time() - start_time) * 1000)
        
        return Response({
            "query": query,
            "results": results,
            "server_ms": server_ms
        })


# ═══════════════════════════════════════════════════════════════════
# VENDOR VIEWS (Must be logged in and own the product)
# ═══════════════════════════════════════════════════════════════════

from vendors.permissions import IsVendorOwnerOrManager

class VendorProductListCreateView(generics.ListCreateAPIView):
    """
    GET /api/vendors/products/
    POST /api/vendors/products/
    
    Vendors use this to SEE their own products and ADD new products.
    """
    serializer_class = ProductSerializer
    permission_classes = [IsVendorOwnerOrManager]

    def get_queryset(self):
        return Product.objects.filter(vendor=self.request.vendor)

    def perform_create(self, serializer):
        serializer.save(vendor=self.request.vendor)


class VendorProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET /api/vendors/products/<id>/
    PUT/PATCH /api/vendors/products/<id>/
    DELETE /api/vendors/products/<id>/
    
    Vendors use this to edit or delete a specific product.
    """
    serializer_class = ProductSerializer
    permission_classes = [IsVendorOwnerOrManager]

    def get_queryset(self):
        return Product.objects.filter(vendor=self.request.vendor)

    def perform_update(self, serializer):
        from vendors.models import AuditLog
        product = self.get_object()
        old_price = product.price
        old_stock = product.stock_quantity
        
        updated_product = serializer.save()
        
        if old_price != updated_product.price:
            AuditLog.objects.create(
                vendor=updated_product.vendor,
                user=self.request.user,
                action='PRICE_UPDATE',
                details=f"Product '{updated_product.name}' price changed from {old_price} to {updated_product.price}"
            )
            
        if old_stock != updated_product.stock_quantity:
            AuditLog.objects.create(
                vendor=updated_product.vendor,
                user=self.request.user,
                action='STOCK_UPDATE',
                details=f"Product '{updated_product.name}' stock changed from {old_stock} to {updated_product.stock_quantity}"
            )

# ═══════════════════════════════════════════════════════════════════
# WISHLIST VIEWS (Customer Features)
# ═══════════════════════════════════════════════════════════════════
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from .models import Wishlist
from .serializers import WishlistSerializer

class WishlistListView(generics.ListAPIView):
    """
    GET /api/products/wishlist/
    Lists all products in the authenticated user's wishlist.
    """
    serializer_class = WishlistSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Wishlist.objects.filter(user=self.request.user)

class WishlistToggleView(APIView):
    """
    POST /api/products/wishlist/<product_id>/toggle/
    Adds a product to the wishlist if it's not there, removing it if it is.
    Returns: {"status": "added"} or {"status": "removed"}
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, product_id):
        product = get_object_or_404(Product, id=product_id)
        
        # Check if it exists
        wishlist_item, created = Wishlist.objects.get_or_create(
            user=request.user,
            product=product
        )
        
        if not created:
            # It already existed, so the user wants to remove it
            wishlist_item.delete()
            return Response({"status": "removed", "message": "Removed from wishlist."}, status=status.HTTP_200_OK)
            
        return Response({"status": "added", "message": "Added to wishlist."}, status=status.HTTP_201_CREATED)

from .serializers import ProductVariantSerializer
from .models import ProductVariant

class VendorProductVariantListCreateView(generics.ListCreateAPIView):
    """
    GET /api/vendors/products/<product_id>/variants/
    POST /api/vendors/products/<product_id>/variants/
    """
    serializer_class = ProductVariantSerializer
    permission_classes = [IsVendorOwnerOrManager]

    def get_queryset(self):
        return ProductVariant.objects.filter(product__vendor=self.request.vendor, product_id=self.kwargs['product_id'])

    def perform_create(self, serializer):
        product = generics.get_object_or_404(Product, id=self.kwargs['product_id'], vendor=self.request.vendor)
        serializer.save(product=product)

class VendorProductVariantDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET /api/vendors/variants/<id>/
    PUT/PATCH /api/vendors/variants/<id>/
    DELETE /api/vendors/variants/<id>/
    """
    serializer_class = ProductVariantSerializer
    permission_classes = [IsVendorOwnerOrManager]

    def get_queryset(self):
        return ProductVariant.objects.filter(product__vendor=self.request.vendor)
