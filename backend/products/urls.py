from django.urls import path
from . import views
from reviews.views import ProductReviewListCreateView

# These are the PUBLIC product endpoints. All start with `/api/products/` base.
urlpatterns = [
    path('', views.PublicProductListView.as_view(), name='public-product-list'),
    path('<int:pk>/', views.PublicProductDetailView.as_view(), name='public-product-detail'),
    path('<int:pk>/reviews/', ProductReviewListCreateView.as_view(), name='product-reviews'),
    
    # Wishlist endpoints
    path('wishlist/', views.WishlistListView.as_view(), name='wishlist-list'),
    path('wishlist/<int:product_id>/toggle/', views.WishlistToggleView.as_view(), name='wishlist-toggle'),

    path('categories/', views.CategoryListView.as_view(), name='category-list'),
]
