from decimal import Decimal
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from crossborder.models import CrossBorderCostConfig, CrossBorderOrderRequest
from crossborder.scraper_service import (
    AliExpressScraper,
    AmazonScraper,
    ProductScraperService,
    UniversalECommerceScraper,
    _clean_price,
    _parse_weight_to_kg,
)

User = get_user_model()


class ScraperUtilitiesTest(TestCase):
    def test_clean_price_currencies(self):
        # USD
        price, cur = _clean_price('$49.99')
        self.assertEqual(price, 49.99)
        self.assertEqual(cur, 'USD')

        # EUR
        price, cur = _clean_price('€ 19.50')
        self.assertEqual(price, 19.50)
        self.assertEqual(cur, 'EUR')

        # GBP
        price, cur = _clean_price('£120.00')
        self.assertEqual(price, 120.00)
        self.assertEqual(cur, 'GBP')

        # CNY / RMB
        price, cur = _clean_price('¥ 88.50')
        self.assertEqual(price, 88.50)
        self.assertEqual(cur, 'CNY')

        # BDT
        price, cur = _clean_price('৳ 1,500')
        self.assertEqual(price, 1500.0)
        self.assertEqual(cur, 'BDT')

        # None/empty
        price, cur = _clean_price('')
        self.assertIsNone(price)

    def test_parse_weight_to_kg(self):
        # kg
        self.assertAlmostEqual(_parse_weight_to_kg('1.5 kg'), 1.5, places=2)
        # grams
        self.assertAlmostEqual(_parse_weight_to_kg('500 g'), 0.5, places=2)
        # lbs
        self.assertAlmostEqual(_parse_weight_to_kg('2.2 lbs'), 1.0, places=1)
        # oz
        self.assertAlmostEqual(_parse_weight_to_kg('16 oz'), 0.45, places=1)
        # invalid
        self.assertIsNone(_parse_weight_to_kg('no weight here'))


class AmazonScraperTest(TestCase):
    def test_parse_amazon_html(self):
        html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Amazon Product</title></head>
        <body>
            <span id="productTitle">Sony WH-1000XM5 Wireless Noise Canceling Headphones</span>
            <div id="apex_desktop">
                <span class="a-price a-text-price"><span class="a-offscreen">$398.00</span></span>
            </div>
            <img id="landingImage" src="https://m.media-amazon.com/images/I/61+El0y1VpL._AC_SL1500_.jpg"
                 data-a-dynamic-image='{"https://m.media-amazon.com/images/I/61+El0y1VpL._AC_SL1500_.jpg":[1500,1500], "https://m.media-amazon.com/images/I/thumb.jpg":[500,500]}' />
            <table id="productDetails_techSpec_section_1">
                <tr><th>Item Weight</th><td>8.8 ounces</td></tr>
            </table>
            <div id="availability"><span>In Stock</span></div>
            <div id="productDescription"><p>Industry Leading noise cancellation</p></div>
        </body>
        </html>
        """
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(html, 'lxml')
        scraper = AmazonScraper()
        res = scraper.parse(soup, html, 'https://www.amazon.com/dp/B09XS7JWHH')

        self.assertEqual(res['title'], 'Sony WH-1000XM5 Wireless Noise Canceling Headphones')
        self.assertEqual(res['price'], 398.0)
        self.assertEqual(res['currency'], 'USD')
        self.assertTrue(res['image_url'].startswith('https://m.media-amazon.com'))
        self.assertGreaterEqual(len(res['images']), 1)
        self.assertIsNotNone(res['estimated_weight_kg'])
        self.assertAlmostEqual(res['estimated_weight_kg'], 0.25, delta=0.05)
        self.assertTrue(res['in_stock'])


class AliExpressScraperTest(TestCase):
    def test_parse_aliexpress_html(self):
        html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta property="og:title" content="Original Xiaomi GaN 65W Fast Charger" />
            <meta property="og:image" content="https://ae01.alicdn.com/kf/S123456.jpg" />
            <meta property="og:description" content="Type-C fast charger for laptop phone" />
            <meta itemprop="price" content="24.99" />
            <meta itemprop="priceCurrency" content="USD" />
        </head>
        <body>
            <div class="product-weight">0.2 kg</div>
        </body>
        </html>
        """
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(html, 'lxml')
        scraper = AliExpressScraper()
        res = scraper.parse(soup, html, 'https://www.aliexpress.com/item/100500123456.html')

        self.assertEqual(res['title'], 'Original Xiaomi GaN 65W Fast Charger')
        self.assertEqual(res['price'], 24.99)
        self.assertEqual(res['currency'], 'USD')
        self.assertEqual(res['image_url'], 'https://ae01.alicdn.com/kf/S123456.jpg')
        self.assertEqual(res['estimated_weight_kg'], 0.2)


class UniversalECommerceScraperTest(TestCase):
    def test_parse_json_ld(self):
        html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@context": "https://schema.org/",
                "@type": "Product",
                "name": "Anker 737 Power Bank",
                "image": ["https://m.media.com/anker1.jpg", "https://m.media.com/anker2.jpg"],
                "description": "24,000mAh 3-port portable charger",
                "weight": {
                    "@type": "QuantitativeValue",
                    "value": 630,
                    "unitText": "g"
                },
                "offers": {
                    "@type": "Offer",
                    "price": "149.99",
                    "priceCurrency": "USD",
                    "availability": "https://schema.org/InStock"
                }
            }
            </script>
        </head>
        <body>
        </body>
        </html>
        """
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(html, 'lxml')
        scraper = UniversalECommerceScraper()
        res = scraper.parse(soup, html, 'https://www.anker.com/products/a1289')

        self.assertEqual(res['title'], 'Anker 737 Power Bank')
        self.assertEqual(res['price'], 149.99)
        self.assertEqual(res['currency'], 'USD')
        self.assertEqual(res['image_url'], 'https://m.media.com/anker1.jpg')
        self.assertEqual(len(res['images']), 2)
        self.assertEqual(res['estimated_weight_kg'], 0.63)
        self.assertTrue(res['in_stock'])


class CrossBorderApiTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='testcbuser',
            email='testcb@example.com',
            password='testpassword123',
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

        # Set up cost configs
        CrossBorderCostConfig.objects.create(
            shipping_method='AIR',
            rate_per_kg=Decimal('1200.00'),
            service_fee_type='PERCENTAGE',
            service_fee_value=Decimal('8.00'),
            customs_rate_percentage=Decimal('15.00'),
            fx_rate_bdt=Decimal('120.00'),
            is_active=True,
        )

    @patch('crossborder.views.ProductScraperService.scrape')
    def test_link_preview_api(self, mock_scrape):
        mock_scrape.return_value = {
            'title': 'Scraped Product Title',
            'price': 29.99,
            'price_text': '29.99',
            'currency': 'USD',
            'image_url': 'https://example.com/item.jpg',
            'images': ['https://example.com/item.jpg'],
            'description': 'Scraped product description',
            'estimated_weight_kg': 0.45,
            'marketplace': 'AMAZON',
            'source_url': 'https://www.amazon.com/dp/B012345678',
        }

        resp = self.client.get('/api/crossborder/link-preview/', {'url': 'https://www.amazon.com/dp/B012345678'})
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertEqual(resp.data['title'], 'Scraped Product Title')
        self.assertEqual(resp.data['estimated_weight_kg'], 0.45)
        self.assertEqual(resp.data['marketplace'], 'AMAZON')

    @patch('crossborder.views.ProductScraperService.scrape')
    def test_create_link_request_auto_scrape(self, mock_scrape):
        mock_scrape.return_value = {
            'title': 'Auto Scraped Headphones',
            'price': 50.00,
            'price_text': '50.00',
            'currency': 'USD',
            'image_url': 'https://example.com/headphones.jpg',
            'images': ['https://example.com/headphones.jpg'],
            'description': 'Super audio quality',
            'estimated_weight_kg': 0.35,
            'marketplace': 'AMAZON',
            'source_url': 'https://www.amazon.com/dp/B098765432',
        }

        # Create link purchase without item_title or item_price_foreign to test server auto-scraping
        payload = {
            'request_type': 'LINK_PURCHASE',
            'source_url': 'https://www.amazon.com/dp/B098765432',
            'quantity': 1,
            'shipping_method': 'AIR',
        }

        resp = self.client.post('/api/crossborder/requests/', payload, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        data = resp.data
        self.assertEqual(data['title'], 'Auto Scraped Headphones')
        self.assertEqual(data['item_title'], 'Auto Scraped Headphones')
        self.assertEqual(data['item_image_url'], 'https://example.com/headphones.jpg')
        self.assertEqual(data['status'], 'QUOTED')
        self.assertTrue(data['is_quote_valid'])
        self.assertIsNotNone(data['estimated_cost_breakdown'])
        self.assertGreater(data['estimated_cost_breakdown']['total_bdt'], 0)
