from django.urls import path

from .views import DiscoveryHomeView, ProductRecommendationsView

urlpatterns = [
    path('home/', DiscoveryHomeView.as_view(), name='discovery_home'),
    path(
        'product/<int:product_id>/recommendations/',
        ProductRecommendationsView.as_view(),
        name='product_recommendations',
    ),
]

