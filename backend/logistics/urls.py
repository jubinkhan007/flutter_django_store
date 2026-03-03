from django.urls import path

from . import views


urlpatterns = [
    path('stores/', views.VendorLogisticsStoreListView.as_view(), name='logistics-stores'),
    path('areas/<str:courier>/search/', views.LogisticsAreaSearchView.as_view(), name='logistics-area-search'),

    # Pathao cached areas
    path('pathao/stores/', views.PathaoStoreListView.as_view(), name='pathao-stores'),
    path('pathao/cities/', views.PathaoCityListView.as_view(), name='pathao-cities'),
    path('pathao/zones/', views.PathaoZoneListView.as_view(), name='pathao-zones'),
    path('pathao/areas/', views.PathaoAreaListView.as_view(), name='pathao-areas'),

    # Retry provisioning
    path('sub-orders/<int:sub_order_id>/retry/', views.VendorRetryProvisionView.as_view(), name='logistics-retry'),

    # Webhooks
    path('webhooks/<str:courier>/', views.LogisticsWebhookView.as_view(), name='logistics-webhook'),
]
