from django.urls import path

from . import views


urlpatterns = [
    path('tickets/', views.TicketListCreateView.as_view(), name='ticket-list-create'),
    path('tickets/<int:pk>/', views.TicketDetailView.as_view(), name='ticket-detail'),
    path('tickets/<int:pk>/messages/', views.TicketMessageCreateView.as_view(), name='ticket-message-create'),
    path('tickets/<int:pk>/assign/', views.TicketAssignView.as_view(), name='ticket-assign'),
    path('tickets/<int:pk>/status/', views.TicketStatusUpdateView.as_view(), name='ticket-status'),
    path('tickets/<int:pk>/close/', views.TicketCloseView.as_view(), name='ticket-close'),
    path('tickets/<int:pk>/reopen/', views.TicketReopenView.as_view(), name='ticket-reopen'),
]

