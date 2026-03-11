from django.core.cache import cache
from django.test import TestCase
from rest_framework.test import APIClient

from .cache_utils import CMS_BOOTSTRAP_CACHE_KEY
from .html_utils import sanitize_html
from .models import Banner, FAQ, Page, SiteSetting


class CmsApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        SiteSetting.objects.create(
            key='support_email',
            value='help@example.com',
            group=SiteSetting.Group.CONTACT,
            setting_type=SiteSetting.SettingType.TEXT,
            is_public=True,
        )
        Page.objects.create(
            title='Privacy Policy',
            slug='privacy-policy',
            page_type=Page.PageType.PRIVACY,
            content='<p>Privacy</p>',
            is_active=True,
        )
        FAQ.objects.create(
            category=FAQ.Category.ORDERS,
            question='Where is my order?',
            answer='Track it from orders.',
            is_active=True,
        )

    def test_bootstrap_returns_expected_sections(self):
        response = self.client.get('/api/cms/bootstrap/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('site_settings', response.data)
        self.assertIn('pages', response.data)
        self.assertIn('faqs', response.data)
        self.assertTrue(cache.get(CMS_BOOTSTRAP_CACHE_KEY))

    def test_page_resolve_by_slug(self):
        response = self.client.get('/api/cms/pages/resolve/?slug=privacy-policy')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['page_type'], Page.PageType.PRIVACY)

    def test_html_sanitizer_strips_script(self):
        cleaned = sanitize_html('<p>Hello</p><script>alert(1)</script>')
        self.assertEqual(cleaned, '<p>Hello</p>alert(1)')

