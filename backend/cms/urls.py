from django.urls import path

from .views import CmsBootstrapView, CmsPageResolveView

urlpatterns = [
    path('bootstrap/', CmsBootstrapView.as_view(), name='cms-bootstrap'),
    path('pages/resolve/', CmsPageResolveView.as_view(), name='cms-page-resolve'),
]

