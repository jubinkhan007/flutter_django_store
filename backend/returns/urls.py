from django.urls import path

from . import views

urlpatterns = [
    path('', views.CustomerReturnListCreateView.as_view(), name='return-list-create'),
    path('<int:pk>/', views.CustomerReturnDetailView.as_view(), name='return-detail'),
    path('<int:pk>/cancel/', views.CustomerReturnCancelView.as_view(), name='return-cancel'),
    path('<int:pk>/images/', views.CustomerReturnImageUploadView.as_view(), name='return-images'),
    path('<int:pk>/escalate/', views.CustomerReturnEscalateView.as_view(), name='return-escalate'),
]
