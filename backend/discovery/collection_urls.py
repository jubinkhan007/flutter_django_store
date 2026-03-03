from django.urls import path

from .views import CollectionDetailView

urlpatterns = [
    path('<slug:slug>/', CollectionDetailView.as_view(), name='collection_detail'),
]

