from django.urls import path
from .views import HomeFeedView

urlpatterns = [
    path('home-feed/', HomeFeedView.as_view(), name='home-feed'),
]
