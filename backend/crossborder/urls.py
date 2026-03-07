from django.urls import path

from .views import (
    CBAdminDetailView,
    CBAdminListView,
    CBCheckoutView,
    CBFinalizeCostView,
    CBMarkCustomsHeldView,
    CBMarkDeliveredView,
    CBMarkOrderedView,
    CBMarkReceivedView,
    CBMarkShippedView,
    CBProductDetailView,
    CBProductListView,
    CBRequestCreateView,
    CBRequestDetailView,
    CBRequestListView,
    CBShippingConfigView,
)

# Customer URLs
customer_urlpatterns = [
    path('products/', CBProductListView.as_view(), name='cb-product-list'),
    path('products/<int:pk>/', CBProductDetailView.as_view(), name='cb-product-detail'),
    path('shipping-config/', CBShippingConfigView.as_view(), name='cb-shipping-config'),
    path('requests/', CBRequestCreateView.as_view(), name='cb-request-create-list'),
    path('requests/list/', CBRequestListView.as_view(), name='cb-request-list'),
    path('requests/<int:pk>/', CBRequestDetailView.as_view(), name='cb-request-detail'),
    path('requests/<int:pk>/checkout/', CBCheckoutView.as_view(), name='cb-checkout'),
    path('requests/<int:pk>/mark-received/', CBMarkReceivedView.as_view(), name='cb-mark-received'),
]

# Admin/Ops URLs
admin_urlpatterns = [
    path('', CBAdminListView.as_view(), name='cb-admin-list'),
    path('<int:pk>/', CBAdminDetailView.as_view(), name='cb-admin-detail'),
    path('<int:pk>/mark-ordered/', CBMarkOrderedView.as_view(), name='cb-mark-ordered'),
    path('<int:pk>/mark-shipped/', CBMarkShippedView.as_view(), name='cb-mark-shipped'),
    path('<int:pk>/mark-customs-held/', CBMarkCustomsHeldView.as_view(), name='cb-mark-customs-held'),
    path('<int:pk>/mark-delivered/', CBMarkDeliveredView.as_view(), name='cb-mark-delivered'),
    path('<int:pk>/finalize-cost/', CBFinalizeCostView.as_view(), name='cb-finalize-cost'),
]

urlpatterns = customer_urlpatterns
