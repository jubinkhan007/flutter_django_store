from django.urls import path

from .views import UserEventLogView

urlpatterns = [
    path('events/', UserEventLogView.as_view(), name='analytics_events'),
]

