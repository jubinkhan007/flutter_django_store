from django.urls import path
from . import views

# These are the PUBLIC product endpoints. All start with `/api/products/` base.
urlpatterns = [
    path('', views.PublicProductListView.as_view(), name='public-product-list'),
    path('<int:pk>/', views.PublicProductDetailView.as_view(), name='public-product-detail'),
    path('categories/', views.CategoryListView.as_view(), name='category-list'),
]
