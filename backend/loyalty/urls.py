from django.urls import path
from . import views

urlpatterns = [
    path('summary/', views.LoyaltySummaryView.as_view(), name='loyalty-summary'),
    path('transactions/', views.LoyaltyTransactionsListView.as_view(), name='loyalty-transactions'),
    path('quote-redemption/', views.QuoteRedemptionView.as_view(), name='loyalty-quote-redemption'),
]
