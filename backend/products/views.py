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

        # 3. Filter by Brand(s)
        brand_param = self.request.query_params.get('brand')
        if brand_param:
            brands = [b.strip() for b in brand_param.split(',') if b.strip()]
            if brands:
                from django.db.models import Q as BrandQ
                brand_q = BrandQ()
                for b in brands:
                    brand_q |= BrandQ(brand__iexact=b)
                queryset = queryset.filter(brand_q)

        # 4. Filter by Minimum Rating
        min_rating = self.request.query_params.get('min_rating')
        if min_rating:
            try:
                queryset = queryset.filter(avg_rating__gte=float(min_rating))
            except ValueError:
                pass

        # 5. Filter by Minimum Discount %
        min_discount = self.request.query_params.get('min_discount')
        if min_discount:
            try:
                queryset = queryset.filter(discount_percent__gte=int(min_discount))
            except ValueError:
                pass

        # 6. Filter by In-Stock availability
        in_stock = self.request.query_params.get('in_stock')
        if in_stock and in_stock.lower() in ('true', '1', 'yes'):
            queryset = queryset.filter(stock_quantity__gt=0)

        # 7. Search by name/description/brand/vendor (with fuzzy fallback)
        search_query = (self.request.query_params.get('search') or '').strip()
        used_similarity_order = False
        if search_query:
            direct = queryset.filter(
                Q(name__icontains=search_query) |
                Q(description__icontains=search_query) |
                Q(brand__icontains=search_query) |
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
                            TrigramSimilarity('brand', search_query),
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
                            _best_token_similarity(search_query, p.brand or ''),
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

        # 8. Sorting
        sort_by = (self.request.query_params.get('sort') or '').strip().lower()
        if not used_similarity_order:
            if sort_by in ('popularity', 'sales'):
                from django.db.models import Sum
                from django.db.models.functions import Coalesce
                queryset = queryset.annotate(
                    sales_volume=Coalesce(Sum('order_items__quantity'), 0)
                ).order_by('-sales_volume', '-review_count', '-avg_rating', '-created_at')
            elif sort_by == 'rating':
                queryset = queryset.order_by('-avg_rating', '-review_count', '-created_at')
            elif sort_by == 'discount':
                queryset = queryset.order_by('-discount_percent', '-price', '-created_at')
            elif sort_by == 'price_asc':
                queryset = queryset.order_by('price')
            elif sort_by == 'price_desc':
                queryset = queryset.order_by('-price')
            elif sort_by == 'newest':
                queryset = queryset.order_by('-created_at')
            else:
                queryset = queryset.order_by('-created_at')
            
        return queryset

    def list(self, request, *args, **kwargs):
        # Record search query history if valid
        search_query = (request.query_params.get('search') or '').strip()
        if search_query and len(search_query) >= 2:
            try:
                from .models import SearchQueryHistory
                u = request.user if request.user.is_authenticated else None
                sqh, created = SearchQueryHistory.objects.get_or_create(user=u, query=search_query)
                if not created:
                    sqh.count += 1
                    sqh.save(update_fields=['count', 'last_searched_at'])
            except Exception:
                pass

        queryset = self.filter_queryset(self.get_queryset())

        # Sponsored Ads Injection
        category_param = request.query_params.get('category')
        cat_id = None
        if category_param:
            first_cat = category_param.split(',')[0].strip()
            if first_cat.isdigit():
                cat_id = int(first_cat)

        try:
            from ads.services import AdAuctionService
            boosted_map = AdAuctionService.get_boosted_campaign_map(
                limit=2,
                category_id=cat_id,
                search_query=search_query if search_query else None
            )
        except Exception:
            boosted_map = {}

        sponsored_products = []
        boosted_pids = list(boosted_map.keys())
        if boosted_pids:
            sponsored_qs = Product.objects.filter(id__in=boosted_pids, is_available=True)
            for prod in sponsored_qs:
                prod.is_sponsored = True
                prod.campaign_id = boosted_map.get(prod.id)
                sponsored_products.append(prod)
            # Prevent duplicate cards in organic feed
            queryset = queryset.exclude(id__in=boosted_pids)

        page = self.paginate_queryset(queryset)
        if page is not None:
            combined = sponsored_products + list(page)
            serializer = self.get_serializer(combined, many=True)
            return self.get_paginated_response(serializer.data)

        combined = sponsored_products + list(queryset)
        serializer = self.get_serializer(combined, many=True)
        return Response(serializer.data)


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

        # 4. Brand Matches (Limit 3)
        brands = (
            Product.objects.filter(is_available=True, brand__icontains=query)
            .values_list('brand', flat=True)
            .distinct()[:3]
        )
        for b in brands:
            if b:
                results.append({
                    "type": "BRAND",
                    "id": None,
                    "label": b,
                    "subtitle": "Brand"
                })

        server_ms = int((time.time() - start_time) * 1000)
        
        return Response({
            "query": query,
            "results": results,
            "server_ms": server_ms
        })


class ProductFacetsView(APIView):
    """
    GET /api/products/facets/
    Calculates dynamic faceted aggregations for brands, categories, price range, ratings, and discounts.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request, *args, **kwargs):
        queryset = Product.objects.filter(is_available=True)

        category_param = request.query_params.get('category')
        if category_param:
            cids = [int(cid) for cid in category_param.split(',') if cid.isdigit()]
            if cids:
                queryset = queryset.filter(category_id__in=cids)

        search_query = (request.query_params.get('search') or '').strip()
        if search_query:
            queryset = queryset.filter(
                Q(name__icontains=search_query) |
                Q(description__icontains=search_query) |
                Q(brand__icontains=search_query) |
                Q(vendor__store_name__icontains=search_query)
            )

        from django.db.models import Count, Min, Max

        # Brands
        brands_data = (
            queryset.exclude(brand='')
            .values('brand')
            .annotate(count=Count('id'))
            .order_by('-count')[:30]
        )
        brands = [{'name': b['brand'], 'count': b['count']} for b in brands_data]

        # Categories
        categories_data = (
            queryset.filter(category__isnull=False)
            .values('category__id', 'category__name')
            .annotate(count=Count('id'))
            .order_by('-count')[:20]
        )
        categories = [
            {'id': c['category__id'], 'name': c['category__name'], 'count': c['count']}
            for c in categories_data
        ]

        # Price range
        price_stats = queryset.aggregate(min_price=Min('price'), max_price=Max('price'))
        min_p = float(price_stats['min_price'] or 0.0)
        max_p = float(price_stats['max_price'] or 10000.0)

        # Ratings
        r4 = queryset.filter(avg_rating__gte=4.0).count()
        r3 = queryset.filter(avg_rating__gte=3.0).count()
        r2 = queryset.filter(avg_rating__gte=2.0).count()

        # Discounts
        d50 = queryset.filter(discount_percent__gte=50).count()
        d25 = queryset.filter(discount_percent__gte=25).count()
        d10 = queryset.filter(discount_percent__gte=10).count()

        in_stock_cnt = queryset.filter(stock_quantity__gt=0).count()
        total_cnt = queryset.count()

        return Response({
            'total_count': total_cnt,
            'in_stock_count': in_stock_cnt,
            'price_range': {
                'min': min_p,
                'max': max_p,
            },
            'brands': brands,
            'categories': categories,
            'rating_counts': {
                '4_plus': r4,
                '3_plus': r3,
                '2_plus': r2,
            },
            'discount_counts': {
                '50_plus': d50,
                '25_plus': d25,
                '10_plus': d10,
            },
        })


class SearchHistoryView(APIView):
    """
    GET /api/products/search/history/
    POST /api/products/search/history/
    DELETE /api/products/search/history/
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request, *args, **kwargs):
        from .models import SearchQueryHistory
        from django.db.models import Sum

        user_history = []
        if request.user.is_authenticated:
            user_history = list(
                SearchQueryHistory.objects.filter(user=request.user)
                .order_by('-last_searched_at')
                .values_list('query', flat=True)[:10]
            )

        trending = list(
            SearchQueryHistory.objects.values('query')
            .annotate(total_searches=Sum('count'))
            .order_by('-total_searches')
            .values_list('query', flat=True)[:8]
        )

        if not trending:
            trending = ["Wireless Earbuds", "Smart Watch", "T-Shirt", "Sneakers", "Backpack", "Bluetooth Speaker"]

        return Response({
            'recent': user_history,
            'trending': trending,
        })

    def post(self, request, *args, **kwargs):
        query = (request.data.get('query') or '').strip()
        if not query or len(query) < 2:
            return Response({'error': 'Query too short'}, status=status.HTTP_400_BAD_REQUEST)

        from .models import SearchQueryHistory
        u = request.user if request.user.is_authenticated else None
        sqh, created = SearchQueryHistory.objects.get_or_create(user=u, query=query)
        if not created:
            sqh.count += 1
            sqh.save(update_fields=['count', 'last_searched_at'])

        return Response({'status': 'ok', 'query': query})

    def delete(self, request, *args, **kwargs):
        if request.user.is_authenticated:
            from .models import SearchQueryHistory
            SearchQueryHistory.objects.filter(user=request.user).delete()
        return Response({'status': 'cleared'})


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
