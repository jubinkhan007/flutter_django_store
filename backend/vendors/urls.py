# ═══════════════════════════════════════════════════════════════════
# VENDORS URLS
# ═══════════════════════════════════════════════════════════════════
#
# CONCEPT: URL Routing
# ────────────────────
# URLs are the "address book" of your API. They map a URL path to a View.
#
# path('onboarding/', VendorOnboardingView.as_view())
#   ↑ URL pattern       ↑ Which view handles it
#
# .as_view() converts a class-based view into a function that Django can call.
# (Django's URL system expects functions, but we write classes for cleaner code.)
#
# These URLs will be prefixed with 'api/vendors/' because in config/urls.py
# we'll include them as: path('api/vendors/', include('vendors.urls'))
#
# So the full URLs will be:
#   POST /api/vendors/onboarding/  → Create a store
#   GET  /api/vendors/me/          → View my store dashboard
#   PUT  /api/vendors/me/          → Edit my store details
# ═══════════════════════════════════════════════════════════════════

from django.urls import path
from .views import VendorOnboardingView, VendorDashboardView, VendorStatsView
from products.views import VendorProductListCreateView, VendorProductDetailView
from orders.views import VendorOrderListView, VendorUpdateOrderStatusView

urlpatterns = [
    path('onboarding/', VendorOnboardingView.as_view(), name='vendor-onboarding'),
    path('me/', VendorDashboardView.as_view(), name='vendor-dashboard'),
    path('products/', VendorProductListCreateView.as_view(), name='vendor-product-list'),
    path('products/<int:pk>/', VendorProductDetailView.as_view(), name='vendor-product-detail'),
    path('orders/', VendorOrderListView.as_view(), name='vendor-order-list'),
    path('orders/<int:pk>/', VendorUpdateOrderStatusView.as_view(), name='vendor-order-update'),
    path('stats/', VendorStatsView.as_view(), name='vendor-stats'),
]
