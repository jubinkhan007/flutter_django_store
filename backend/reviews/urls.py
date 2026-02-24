from django.urls import path
from . import views

urlpatterns = [
    path('<int:pk>/reply/', views.ReviewReplyView.as_view(), name='review-reply'),
]
