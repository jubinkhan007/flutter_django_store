from django.urls import path

from .views import (
    CBAdminDetailView,
    CBAdminListView,
    CBFinalizeCostView,
    CBMarkCustomsHeldView,
    CBMarkDeliveredView,
    CBMarkOrderedView,
    CBMarkShippedView,
)

urlpatterns = [
    path('', CBAdminListView.as_view(), name='cb-admin-list'),
    path('<int:pk>/', CBAdminDetailView.as_view(), name='cb-admin-detail'),
    path('<int:pk>/mark-ordered/', CBMarkOrderedView.as_view(), name='cb-mark-ordered'),
    path('<int:pk>/mark-shipped/', CBMarkShippedView.as_view(), name='cb-mark-shipped'),
    path('<int:pk>/mark-customs-held/', CBMarkCustomsHeldView.as_view(), name='cb-mark-customs-held'),
    path('<int:pk>/mark-delivered/', CBMarkDeliveredView.as_view(), name='cb-mark-delivered'),
    path('<int:pk>/finalize-cost/', CBFinalizeCostView.as_view(), name='cb-finalize-cost'),
]
