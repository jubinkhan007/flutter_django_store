"""
URL configuration for config project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/4.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('users.urls')),
    path('api/vendors/', include('vendors.urls')),  # Vendor endpoints
    path('api/products/', include('products.urls')), # Public product endpoints
    path('api/orders/', include('orders.urls')),       # Customer order endpoints
    path('api/reviews/', include('reviews.urls')),     # Review reply endpoint
    path('api/coupons/', include('coupons.urls')),     # Coupon validation endpoint
    path('api/returns/', include('returns.urls')),     # Return/RMA endpoints
    path('api/promotions/', include('promotions.urls')),  # Promotions/Home feed
    path('api/notifications/', include('notifications.urls')),  # Notifications/Inbox/Push
    path('api/support/', include('support.urls')),  # Support tickets / disputes
    path('api/logistics/', include('logistics.urls')),  # Courier integrations / webhooks
    path('api/analytics/', include('analytics.urls')),  # User events / personalization analytics
    path('api/discovery/', include('discovery.urls')),  # Discovery / recommendations
    path('api/collections/', include('discovery.collection_urls')),  # Scheduled collections
    path('api/cms/', include('cms.urls')),
    path('api/crossborder/', include('crossborder.urls')),           # Cross-border sourcing (customer)
    path(
        'api/admin/crossborder/',
        include(('crossborder.admin_urls', 'crossborder_admin'), namespace='cb-admin'),
    ),  # CB ops admin
]

# Serve media files during development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
