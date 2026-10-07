"""
Automated Product Scraper Service for Cross-Border E-Commerce.

Supports:
1. Amazon (ASIN detection, title, price, dynamic images, weight parsing)
2. AliExpress (Item ID, embedded JSON state, OpenGraph, prices)
3. Alibaba & 1688 (Meta tags, price tiers, images)
4. Universal E-Commerce (Schema.org JSON-LD, Microdata, OpenGraph, Twitter Cards)
"""
from __future__ import annotations

import json
import logging
import re
from decimal import Decimal, InvalidOperation
from typing import Any
from urllib.parse import urlparse

import requests
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

# Headers mimicking real modern desktop and mobile browsers
DEFAULT_HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Safari/537.36'
    ),
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
    'Sec-Ch-Ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
    'Sec-Ch-Ua-Mobile': '?0',
    'Sec-Ch-Ua-Platform': '"macOS"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
}


def _clean_text(text: str | None) -> str:
    if not text:
        return ''
    return re.sub(r'\s+', ' ', text).strip()


def _parse_weight_to_kg(text: str) -> float | None:
    """Extract and convert weights from text like '1.5 lbs', '12 ounces', '450 g', '2.5 kg'."""
    if not text:
        return None

    # Matches number followed by unit
    match = re.search(r'([0-9]+(?:\.[0-9]+)?)\s*(kg|kilograms?|lbs?|pounds?|oz|ounces?|g|grams?)', text, re.IGNORECASE)
    if not match:
        return None

    try:
        val = float(match.group(1))
        unit = match.group(2).lower()
        if unit in ('kg', 'kilogram', 'kilograms'):
            return round(val, 3)
        elif unit in ('lb', 'lbs', 'pound', 'pounds'):
            return round(val * 0.453592, 3)
        elif unit in ('oz', 'ounce', 'ounces'):
            return round(val * 0.0283495, 3)
        elif unit in ('g', 'gram', 'grams'):
            return round(val / 1000.0, 3)
    except (ValueError, TypeError):
        pass
    return None


def _clean_price(price_str: str | float | int | None) -> tuple[float | None, str]:
    """Parse numeric price and currency symbol/code."""
    if price_str is None:
        return None, ''

    raw = str(price_str).strip()
    if not raw:
        return None, ''

    # Detect currency
    currency = 'USD'
    if '€' in raw or 'EUR' in raw.upper():
        currency = 'EUR'
    elif '£' in raw or 'GBP' in raw.upper():
        currency = 'GBP'
    elif '¥' in raw or 'CNY' in raw.upper() or 'RMB' in raw.upper():
        currency = 'CNY'
    elif '৳' in raw or 'BDT' in raw.upper():
        currency = 'BDT'
    elif 'CAD' in raw.upper() or 'C$' in raw:
        currency = 'CAD'

    # Extract first numeric price (handle ranges like "$19.99 - $24.99" -> 19.99)
    # Remove currency symbols and comma separators
    cleaned_num = raw.replace(',', '')
    match = re.search(r'([0-9]+(?:\.[0-9]{1,2})?)', cleaned_num)
    if match:
        try:
            return float(match.group(1)), currency
        except ValueError:
            pass

    return None, currency


class BaseScraper:
    def parse(self, soup: BeautifulSoup, html: str, url: str) -> dict[str, Any]:
        raise NotImplementedError


class AmazonScraper(BaseScraper):
    """Specialized scraper for Amazon product pages."""

    def parse(self, soup: BeautifulSoup, html: str, url: str) -> dict[str, Any]:
        data: dict[str, Any] = {
            'marketplace': 'AMAZON',
            'title': '',
            'description': '',
            'price': None,
            'price_text': '',
            'currency': 'USD',
            'image_url': '',
            'images': [],
            'estimated_weight_kg': None,
            'in_stock': True,
        }

        # 1. Title
        title_el = (
            soup.select_one('#productTitle')
            or soup.select_one('#title')
            or soup.select_one('#ebooksProductTitle')
        )
        if title_el:
            data['title'] = _clean_text(title_el.get_text())

        # 2. Price
        price_el = (
            soup.select_one('#apex_desktop .a-price .a-offscreen')
            or soup.select_one('.a-price.a-text-price .a-offscreen')
            or soup.select_one('.a-price .a-offscreen')
            or soup.select_one('#corePrice_desktop .a-price .a-offscreen')
            or soup.select_one('#priceblock_ourprice')
            or soup.select_one('#priceblock_dealprice')
            or soup.select_one('#price')
        )

        if price_el:
            raw_price = _clean_text(price_el.get_text())
            val, curr = _clean_price(raw_price)
            if val is not None:
                data['price'] = val
                data['price_text'] = f"{val:.2f}"
                data['currency'] = curr

        if data['price'] is None:
            # Whole + fraction fallback
            whole = soup.select_one('.a-price-whole')
            fraction = soup.select_one('.a-price-fraction')
            symbol = soup.select_one('.a-price-symbol')
            if whole:
                w_text = whole.get_text(strip=True).rstrip('.')
                f_text = fraction.get_text(strip=True) if fraction else '00'
                val, curr = _clean_price(f"{w_text}.{f_text}")
                if val is not None:
                    data['price'] = val
                    data['price_text'] = f"{val:.2f}"
                    data['currency'] = 'USD' if not symbol else (symbol.get_text(strip=True) if symbol.get_text(strip=True) != '$' else 'USD')

        # 3. Images (Primary + Gallery from dynamic image JSON)
        images: list[str] = []
        landing_img = soup.select_one('#landingImage') or soup.select_one('#imgBlkFront')
        if landing_img:
            dyn_data = landing_img.get('data-a-dynamic-image')
            if dyn_data:
                try:
                    dyn_map = json.loads(dyn_data)
                    images.extend(dyn_map.keys())
                except Exception:
                    pass
            high_res = landing_img.get('data-old-hires')
            if high_res and high_res not in images:
                images.append(high_res)
            src = landing_img.get('src')
            if src and src not in images and not src.startswith('data:'):
                images.append(src)

        if images:
            data['image_url'] = images[0]
            data['images'] = images[:6]

        # 4. Weight estimation from product details / tech specs
        weight_patterns = [
            'Item Weight', 'Package Dimensions', 'Product Dimensions',
            'Shipping Weight', 'Package Weight'
        ]
        for row in soup.select('table tr, #detailBullets_feature_div li, #prodDetails tr'):
            text = row.get_text(' ', strip=True)
            for wp in weight_patterns:
                if wp.lower() in text.lower():
                    parsed_w = _parse_weight_to_kg(text)
                    if parsed_w:
                        data['estimated_weight_kg'] = parsed_w
                        break
            if data['estimated_weight_kg']:
                break

        # 5. Availability
        avail_el = soup.select_one('#availability')
        if avail_el:
            avail_text = avail_el.get_text(strip=True).lower()
            if 'currently unavailable' in avail_text or 'out of stock' in avail_text:
                data['in_stock'] = False

        # 6. Description
        desc_el = soup.select_one('#feature-bullets') or soup.select_one('#productDescription')
        if desc_el:
            data['description'] = _clean_text(desc_el.get_text())[:400]

        return data


class AliExpressScraper(BaseScraper):
    """Specialized scraper for AliExpress product pages."""

    def parse(self, soup: BeautifulSoup, html: str, url: str) -> dict[str, Any]:
        data: dict[str, Any] = {
            'marketplace': 'ALIEXPRESS',
            'title': '',
            'description': '',
            'price': None,
            'price_text': '',
            'currency': 'USD',
            'image_url': '',
            'images': [],
            'estimated_weight_kg': None,
            'in_stock': True,
        }

        # 1. Search embedded window.runParams / script tags
        script_matches = re.findall(r'window\.runParams\s*=\s*(\{.*?\});', html, re.DOTALL)
        for s in script_matches:
            try:
                parsed = json.loads(s)
                # Try locating priceModule and titleModule
                data_obj = parsed.get('data') or parsed
                title_mod = data_obj.get('titleModule', {})
                if 'subject' in title_mod:
                    data['title'] = _clean_text(title_mod['subject'])

                price_mod = data_obj.get('priceModule', {})
                price_act = price_mod.get('minAmount', {}).get('value') or price_mod.get('formatedActivityPrice')
                if price_act:
                    val, curr = _clean_price(price_act)
                    if val is not None:
                        data['price'] = val
                        data['price_text'] = f"{val:.2f}"
                        data['currency'] = curr or 'USD'

                img_mod = data_obj.get('imageModule', {})
                if 'imagePathList' in img_mod and isinstance(img_mod['imagePathList'], list):
                    data['images'] = [i for i in img_mod['imagePathList'] if isinstance(i, str)]
                    if data['images']:
                        data['image_url'] = data['images'][0]
            except Exception:
                pass

        # 2. Meta and OpenGraph fallbacks
        if not data['title']:
            og_title = soup.find('meta', property='og:title') or soup.find('meta', attrs={'name': 'og:title'})
            if og_title and og_title.get('content'):
                data['title'] = _clean_text(og_title['content'])

        if not data['image_url']:
            og_img = soup.find('meta', property='og:image') or soup.find('meta', attrs={'name': 'og:image'})
            if og_img and og_img.get('content'):
                data['image_url'] = og_img['content']
                if data['image_url'] not in data['images']:
                    data['images'].insert(0, data['image_url'])

        if data['price'] is None:
            # Check itemprop="price"
            meta_price = soup.find('meta', attrs={'itemprop': 'price'})
            if meta_price and meta_price.get('content'):
                val, curr = _clean_price(meta_price['content'])
                if val is not None:
                    data['price'] = val
                    data['price_text'] = f"{val:.2f}"
                    data['currency'] = 'USD'

        return data


class UniversalECommerceScraper(BaseScraper):
    """
    Universal metadata extractor using:
    1. Schema.org JSON-LD (Product, Offer, AggregateOffer)
    2. OpenGraph & Twitter Cards
    3. HTML Microdata
    """

    def parse(self, soup: BeautifulSoup, html: str, url: str) -> dict[str, Any]:
        data: dict[str, Any] = {
            'marketplace': 'OTHER',
            'title': '',
            'description': '',
            'price': None,
            'price_text': '',
            'currency': 'USD',
            'image_url': '',
            'images': [],
            'estimated_weight_kg': None,
            'in_stock': True,
        }

        # 1. Parse JSON-LD scripts
        for script in soup.find_all('script', type='application/ld+json'):
            raw_text = script.string or script.get_text()
            if not raw_text:
                continue
            try:
                payload = json.loads(raw_text.strip())
                self._extract_from_jsonld(payload, data)
                if data['title'] and data['price']:
                    break
            except Exception:
                continue

        # 2. OpenGraph / Twitter Fallbacks
        if not data['title']:
            og_t = soup.find('meta', property='og:title') or soup.find('meta', attrs={'name': 'twitter:title'})
            if og_t and og_t.get('content'):
                data['title'] = _clean_text(og_t['content'])
            elif soup.title:
                data['title'] = _clean_text(soup.title.get_text())

        if not data['image_url']:
            og_img = soup.find('meta', property='og:image') or soup.find('meta', attrs={'name': 'twitter:image'})
            if og_img and og_img.get('content'):
                data['image_url'] = og_img['content']
                if data['image_url'] not in data['images']:
                    data['images'].insert(0, data['image_url'])

        if not data['description']:
            og_d = soup.find('meta', property='og:description') or soup.find('meta', attrs={'name': 'description'})
            if og_d and og_d.get('content'):
                data['description'] = _clean_text(og_d['content'])[:300]

        if data['price'] is None:
            og_price = (
                soup.find('meta', property='product:price:amount')
                or soup.find('meta', property='og:price:amount')
                or soup.find('meta', attrs={'itemprop': 'price'})
            )
            if og_price and og_price.get('content'):
                val, curr = _clean_price(og_price['content'])
                if val is not None:
                    data['price'] = val
                    data['price_text'] = f"{val:.2f}"
                    og_curr = soup.find('meta', property='product:price:currency') or soup.find('meta', property='og:price:currency')
                    if og_curr and og_curr.get('content'):
                        data['currency'] = og_curr['content'].upper()
                    else:
                        data['currency'] = curr or 'USD'

        return data

    def _extract_from_jsonld(self, obj: Any, data: dict[str, Any]) -> None:
        if isinstance(obj, list):
            for item in obj:
                self._extract_from_jsonld(item, data)
            return

        if not isinstance(obj, dict):
            return

        # Check @graph
        if '@graph' in obj and isinstance(obj['@graph'], list):
            for item in obj['@graph']:
                self._extract_from_jsonld(item, data)
            return

        obj_type = obj.get('@type', '')
        if obj_type in ('Product', 'IndividualProduct', 'ProductGroup') or (isinstance(obj_type, list) and 'Product' in obj_type):
            if not data['title'] and 'name' in obj:
                data['title'] = _clean_text(str(obj['name']))

            if not data['description'] and 'description' in obj:
                data['description'] = _clean_text(str(obj['description']))[:300]

            if not data['images'] and 'image' in obj:
                img_val = obj['image']
                if isinstance(img_val, list):
                    data['images'] = [str(x) for x in img_val if isinstance(x, (str, dict))]
                elif isinstance(img_val, str):
                    data['images'] = [img_val]
                elif isinstance(img_val, dict) and 'url' in img_val:
                    data['images'] = [str(img_val['url'])]

                if data['images'] and not data['image_url']:
                    data['image_url'] = data['images'][0]

            if 'weight' in obj:
                w_val = obj['weight']
                if isinstance(w_val, dict):
                    w_text = f"{w_val.get('value', '')} {w_val.get('unitCode', '')}"
                    data['estimated_weight_kg'] = _parse_weight_to_kg(w_text)
                elif isinstance(w_val, (str, int, float)):
                    data['estimated_weight_kg'] = _parse_weight_to_kg(str(w_val))

            # Offers
            offers = obj.get('offers')
            if offers:
                self._extract_offers(offers, data)

    def _extract_offers(self, offers: Any, data: dict[str, Any]) -> None:
        if isinstance(offers, list) and offers:
            offers = offers[0]
        if isinstance(offers, dict):
            price_val = offers.get('price') or offers.get('lowPrice') or offers.get('highPrice')
            if price_val is not None:
                val, curr = _clean_price(price_val)
                if val is not None:
                    data['price'] = val
                    data['price_text'] = f"{val:.2f}"
                    data['currency'] = offers.get('priceCurrency', curr or 'USD').upper()
            avail = offers.get('availability', '')
            if 'OutOfStock' in str(avail):
                data['in_stock'] = False


class ProductScraperService:
    """Master scraper coordinator."""

    @classmethod
    def detect_marketplace(cls, url: str) -> str:
        host = urlparse(url).hostname or ''
        host = host.lower()
        if 'amazon' in host:
            return 'AMAZON'
        if 'aliexpress' in host:
            return 'ALIEXPRESS'
        if 'alibaba' in host:
            return 'ALIBABA'
        if '1688' in host:
            return '1688'
        return 'OTHER'

    @classmethod
    def scrape(cls, url: str, timeout: int = 10) -> dict[str, Any]:
        """
        Fetch and parse product metadata from a foreign e-commerce URL.
        Returns a clean dictionary with:
        {
            'title': str,
            'description': str,
            'price': float | None,
            'price_text': str,
            'currency': str,
            'image_url': str,
            'images': list[str],
            'estimated_weight_kg': float | None,
            'marketplace': str,
            'in_stock': bool,
            'source_url': str
        }
        """
        url = url.strip()
        if not url.startswith(('http://', 'https://')):
            return {'error': 'Invalid URL. Protocol http:// or https:// is required.'}

        marketplace = cls.detect_marketplace(url)

        headers = dict(DEFAULT_HEADERS)
        # Custom referer
        parsed_url = urlparse(url)
        headers['Referer'] = f"{parsed_url.scheme}://{parsed_url.netloc}/"

        try:
            session = requests.Session()
            response = session.get(url, headers=headers, timeout=timeout, allow_redirects=True)
            if response.status_code == 404:
                return {'error': 'Product page not found (HTTP 404). Please verify the link.'}
            response.raise_for_status()
            html = response.text
        except requests.exceptions.Timeout:
            return {'error': 'Request timed out while connecting to the marketplace server.'}
        except requests.exceptions.RequestException as exc:
            logger.warning(f"Failed to fetch {url}: {exc}")
            return {'error': f"Could not connect to URL: {exc}"}

        soup = BeautifulSoup(html, 'lxml')

        # 1. Run Marketplace-specific scraper
        if marketplace == 'AMAZON':
            scraper = AmazonScraper()
        elif marketplace == 'ALIEXPRESS':
            scraper = AliExpressScraper()
        else:
            scraper = UniversalECommerceScraper()

        result = scraper.parse(soup, html, url)

        # 2. If marketplace scraper didn't extract title or price, fall back to UniversalScraper
        if not result.get('title') or result.get('price') is None:
            universal = UniversalECommerceScraper().parse(soup, html, url)
            if not result.get('title') and universal.get('title'):
                result['title'] = universal['title']
            if result.get('price') is None and universal.get('price') is not None:
                result['price'] = universal['price']
                result['price_text'] = universal['price_text']
                result['currency'] = universal['currency']
            if not result.get('image_url') and universal.get('image_url'):
                result['image_url'] = universal['image_url']
                result['images'] = universal.get('images', [])
            if not result.get('description') and universal.get('description'):
                result['description'] = universal['description']
            if not result.get('estimated_weight_kg') and universal.get('estimated_weight_kg'):
                result['estimated_weight_kg'] = universal['estimated_weight_kg']

        # Ensure defaults and clean fields
        result['marketplace'] = marketplace
        result['source_url'] = url
        result['title'] = (result.get('title') or '')[:300]
        result['description'] = (result.get('description') or '')[:500]
        result['currency'] = (result.get('currency') or 'USD').upper()
        if not result.get('images') and result.get('image_url'):
            result['images'] = [result['image_url']]

        # Fallback default weight if not detected
        if result.get('estimated_weight_kg') is None:
            result['estimated_weight_kg'] = 0.5

        return result
