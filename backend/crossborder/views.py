from __future__ import annotations

import re
from urllib.parse import urlparse

import requests as http_requests
from bs4 import BeautifulSoup
from django.db import transaction
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from orders.models import ShipmentEvent

from .models import CrossBorderCostConfig, CrossBorderOrderRequest, CrossBorderProduct
from .serializers import (
    CBCheckoutSerializer,
    CBFinalizeCostSerializer,
    CBMarkCustomsHeldSerializer,
    CBMarkOrderedSerializer,
    CBMarkShippedSerializer,
    CBRequestCreateSerializer,
    CrossBorderCostConfigSerializer,
    CrossBorderOrderRequestSerializer,
    CrossBorderProductSerializer,
)
from .services import CrossBorderCheckoutService, CrossBorderQuoteService


# ---------------------------------------------------------------------------
# Customer — Catalog
# ---------------------------------------------------------------------------

class CBProductListView(generics.ListAPIView):
    """GET /api/crossborder/products/"""
    serializer_class = CrossBorderProductSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        qs = CrossBorderProduct.objects.filter(is_active=True)
        category = self.request.query_params.get('category')
        marketplace = self.request.query_params.get('marketplace')
        q = self.request.query_params.get('q')
        if category:
            qs = qs.filter(category_id=category)
        if marketplace:
            qs = qs.filter(origin_marketplace=marketplace)
        if q:
            qs = qs.filter(title__icontains=q)
        return qs


class CBProductDetailView(generics.RetrieveAPIView):
    """GET /api/crossborder/products/<id>/"""
    serializer_class = CrossBorderProductSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    queryset = CrossBorderProduct.objects.filter(is_active=True)


class CBShippingConfigView(APIView):
    """GET /api/crossborder/shipping-config/ — Returns active cost configs for UI."""
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        configs = CrossBorderCostConfig.objects.filter(is_active=True)
        return Response(CrossBorderCostConfigSerializer(configs, many=True).data)


# ---------------------------------------------------------------------------
# Customer — Request creation + quote + checkout
# ---------------------------------------------------------------------------

class CBRequestCreateView(APIView):
    """POST /api/crossborder/requests/  — Create and immediately quote a CB request."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = CBRequestCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        cb_product = None
        if data.get('crossborder_product_id'):
            try:
                cb_product = CrossBorderProduct.objects.get(
                    id=data['crossborder_product_id'], is_active=True
                )
            except CrossBorderProduct.DoesNotExist:
                return Response({'error': 'Product not found.'}, status=status.HTTP_404_NOT_FOUND)

        # Determine address snapshot
        address_snapshot = data.get('address_snapshot') or {}
        if data.get('address_id'):
            try:
                from users.models import Address
                addr = Address.objects.get(id=data['address_id'], user=request.user)
                address_snapshot = {
                    'line1': addr.address_line1,
                    'line2': getattr(addr, 'address_line2', ''),
                    'city': addr.city,
                    'state': getattr(addr, 'state', ''),
                    'zip': getattr(addr, 'zip_code', ''),
                    'country': getattr(addr, 'country', 'BD'),
                    'phone': getattr(addr, 'phone', ''),
                }
            except Exception:
                pass

        cb_request = CrossBorderOrderRequest(
            customer=request.user,
            request_type=data['request_type'],
            crossborder_product=cb_product,
            source_url=data.get('source_url', ''),
            marketplace=data.get('marketplace', CrossBorderOrderRequest.Marketplace.OTHER),
            variant_notes=data.get('variant_notes', ''),
            quantity=data['quantity'],
            shipping_method=data['shipping_method'],
            customer_address_snapshot=address_snapshot,
            status=CrossBorderOrderRequest.Status.REQUESTED,
        )

        # Generate immediate quote
        CrossBorderQuoteService.apply_quote_to_request(
            cb_request,
            shipping_method=data['shipping_method'],
            item_price_foreign=data.get('item_price_foreign'),
            currency=data.get('currency'),
            weight_kg=data.get('estimated_weight_kg'),
        )
        cb_request.save()

        return Response(
            CrossBorderOrderRequestSerializer(cb_request).data,
            status=status.HTTP_201_CREATED,
        )


class CBRequestListView(generics.ListAPIView):
    """GET /api/crossborder/requests/  — List authenticated customer's requests."""
    serializer_class = CrossBorderOrderRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return CrossBorderOrderRequest.objects.filter(customer=self.request.user)


class CBRequestDetailView(generics.RetrieveAPIView):
    """GET /api/crossborder/requests/<id>/"""
    serializer_class = CrossBorderOrderRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return CrossBorderOrderRequest.objects.filter(customer=self.request.user)


class CBCheckoutView(APIView):
    """POST /api/crossborder/requests/<id>/checkout/  — Accept quote and place order."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        serializer = CBCheckoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            cb_request = CrossBorderOrderRequest.objects.get(id=pk, customer=request.user)
        except CrossBorderOrderRequest.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            cb_request = CrossBorderCheckoutService.checkout(
                cb_request=cb_request,
                customs_policy_acknowledged=serializer.validated_data['customs_policy_acknowledged'],
            )
        except ValueError as exc:
            return Response({'error': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        # Notify customer
        try:
            from notifications.models import Notification
            from notifications.services import NotificationService
            NotificationService.create(
                user=request.user,
                title='Cross-border order received',
                body=f'Your order has been received and will be quoted shortly.',
                event_type=Notification.Type.CB_ORDER_QUOTED,
                category=Notification.Category.TRANSACTIONAL,
                deeplink=f'app://crossborder/orders/{cb_request.id}',
                data={'cb_request_id': str(cb_request.id)},
                inbox_visible=True,
                push_enabled=True,
            )
        except Exception:
            pass

        return Response(CrossBorderOrderRequestSerializer(cb_request).data)


class CBMarkReceivedView(APIView):
    """POST /api/crossborder/requests/<id>/mark-received/ — Customer confirms delivery."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        try:
            cb_request = CrossBorderOrderRequest.objects.get(id=pk, customer=request.user)
        except CrossBorderOrderRequest.DoesNotExist:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        if cb_request.status not in [
            CrossBorderOrderRequest.Status.IN_TRANSIT,
            CrossBorderOrderRequest.Status.OUT_FOR_DELIVERY,
            CrossBorderOrderRequest.Status.SHIPPED_INTL,
        ]:
            return Response(
                {'error': 'Order must be in transit or out for delivery to mark as received.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():
            cb_request.status = CrossBorderOrderRequest.Status.DELIVERED
            cb_request.delivered_at = timezone.now()
            cb_request.save(update_fields=['status', 'delivered_at', 'updated_at'])

            if cb_request.sub_order_id:
                _add_shipment_event(
                    cb_request.sub_order_id,
                    ShipmentEvent.EventStatus.DELIVERED,
                    'Customer confirmed receipt.',
                    source=ShipmentEvent.Source.SYSTEM,
                )

        return Response(CrossBorderOrderRequestSerializer(cb_request).data)


# ---------------------------------------------------------------------------
# Link preview scraper
# ---------------------------------------------------------------------------

_SCRAPE_HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Safari/537.36'
    ),
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
}

def _detect_marketplace(url: str) -> str:
    host = urlparse(url).hostname or ''
    if 'amazon' in host:
        return 'AMAZON'
    if 'aliexpress' in host:
        return 'ALIEXPRESS'
    if 'alibaba' in host:
        return 'ALIBABA'
    if '1688' in host:
        return '1688'
    return 'OTHER'


def _og(soup: BeautifulSoup, prop: str) -> str:
    tag = soup.find('meta', property=prop) or soup.find('meta', attrs={'name': prop})
    if tag:
        return tag.get('content', '').strip()
    return ''


def _extract_amazon_price(soup: BeautifulSoup) -> tuple[str, str]:
    """Returns (price_text, currency)."""
    # Whole number part
    whole = soup.select_one('.a-price-whole')
    fraction = soup.select_one('.a-price-fraction')
    symbol = soup.select_one('.a-price-symbol')
    if whole:
        price = whole.get_text(strip=True).rstrip('.')
        if fraction:
            price += f'.{fraction.get_text(strip=True)}'
        currency_sym = symbol.get_text(strip=True) if symbol else '$'
        return price, ('USD' if currency_sym == '$' else currency_sym)
    return '', 'USD'


def _extract_preview(url: str) -> dict:
    """Fetch URL and extract product metadata. Returns dict with best-effort fields."""
    try:
        resp = http_requests.get(url, headers=_SCRAPE_HEADERS, timeout=8, allow_redirects=True)
        resp.raise_for_status()
    except Exception as exc:
        return {'error': f'Could not fetch URL: {exc}'}

    soup = BeautifulSoup(resp.content, 'lxml')
    marketplace = _detect_marketplace(url)

    title = (
        _og(soup, 'og:title')
        or (soup.find('title') or {}).get_text('', strip=True)  # type: ignore[union-attr]
    )

    # Amazon-specific title cleanup
    if marketplace == 'AMAZON':
        el = soup.select_one('#productTitle')
        if el:
            title = el.get_text(strip=True)

    image = _og(soup, 'og:image')
    if not image and marketplace == 'AMAZON':
        img_el = soup.select_one('#landingImage, #imgBlkFront')
        if img_el:
            image = img_el.get('data-old-hires') or img_el.get('src', '')

    description = _og(soup, 'og:description')

    price_text = ''
    currency = 'USD'

    # Try OG price tags
    og_price = _og(soup, 'product:price:amount') or _og(soup, 'og:price:amount')
    og_currency = _og(soup, 'product:price:currency') or _og(soup, 'og:price:currency')
    if og_price:
        price_text = og_price
        currency = og_currency or 'USD'

    # Amazon-specific price
    if marketplace == 'AMAZON' and not price_text:
        price_text, currency = _extract_amazon_price(soup)

    # AliExpress fallback — price in meta
    if marketplace == 'ALIEXPRESS' and not price_text:
        meta_price = soup.find('meta', attrs={'itemprop': 'price'})
        if meta_price:
            price_text = meta_price.get('content', '')
            currency = 'USD'

    # Attempt JSON-LD for any marketplace
    if not price_text:
        for script in soup.find_all('script', type='application/ld+json'):
            text = script.string or ''
            m = re.search(r'"price"\s*:\s*"?([0-9.,]+)"?', text)
            cur = re.search(r'"priceCurrency"\s*:\s*"([A-Z]{3})"', text)
            if m:
                price_text = m.group(1)
                currency = cur.group(1) if cur else 'USD'
                break

    # Truncate description
    if len(description) > 300:
        description = description[:297] + '...'

    return {
        'title': title[:200] if title else '',
        'image_url': image,
        'description': description,
        'price_text': price_text,
        'currency': currency,
        'marketplace': marketplace,
    }


class CBLinkPreviewView(APIView):
    """GET /api/crossborder/link-preview/?url=<encoded_url>"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        url = request.query_params.get('url', '').strip()
        if not url:
            return Response({'error': 'url parameter is required.'}, status=status.HTTP_400_BAD_REQUEST)
        if not url.startswith(('http://', 'https://')):
            return Response({'error': 'Invalid URL.'}, status=status.HTTP_400_BAD_REQUEST)

        preview = _extract_preview(url)
        if 'error' in preview:
            return Response(preview, status=status.HTTP_422_UNPROCESSABLE_ENTITY)
        return Response(preview)


# ---------------------------------------------------------------------------
# Admin / Ops endpoints
# ---------------------------------------------------------------------------

class IsAdminUser(permissions.BasePermission):
    def has_permission(self, request, view):
        return bool(
            request.user
            and request.user.is_authenticated
            and getattr(request.user, 'type', None) == 'ADMIN'
        )


class CBAdminListView(generics.ListAPIView):
    """GET /api/admin/crossborder/  — All CB requests for ops staff."""
    serializer_class = CrossBorderOrderRequestSerializer
    permission_classes = [IsAdminUser]

    def get_queryset(self):
        qs = CrossBorderOrderRequest.objects.select_related('customer', 'crossborder_product')
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs


class CBAdminDetailView(generics.RetrieveAPIView):
    serializer_class = CrossBorderOrderRequestSerializer
    permission_classes = [IsAdminUser]
    queryset = CrossBorderOrderRequest.objects.all()


class CBMarkOrderedView(APIView):
    """POST /api/admin/crossborder/<id>/mark-ordered/"""
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        serializer = CBMarkOrderedSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        cb_request = _get_cb_request(pk)
        if not cb_request:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        if cb_request.status != CrossBorderOrderRequest.Status.PAYMENT_RECEIVED:
            return Response({'error': 'Must be in PAYMENT_RECEIVED state.'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            cb_request.status = CrossBorderOrderRequest.Status.ORDERED
            cb_request.supplier_order_id = serializer.validated_data['supplier_order_id']
            cb_request.ops_notes = serializer.validated_data.get('ops_notes', cb_request.ops_notes)
            cb_request.ordered_at = timezone.now()
            cb_request.save()

            if cb_request.sub_order_id:
                _add_shipment_event(
                    cb_request.sub_order_id,
                    ShipmentEvent.EventStatus.ORDERED,
                    f'Ordered from supplier. Ref: {cb_request.supplier_order_id}',
                )

        return Response(CrossBorderOrderRequestSerializer(cb_request).data)


class CBMarkShippedView(APIView):
    """POST /api/admin/crossborder/<id>/mark-shipped/"""
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        serializer = CBMarkShippedSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        cb_request = _get_cb_request(pk)
        if not cb_request:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)
        if cb_request.status not in [
            CrossBorderOrderRequest.Status.ORDERED,
            CrossBorderOrderRequest.Status.CUSTOMS_HELD,
        ]:
            return Response({'error': 'Must be in ORDERED or CUSTOMS_HELD state.'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            cb_request.status = CrossBorderOrderRequest.Status.SHIPPED_INTL
            cb_request.carrier_name = serializer.validated_data['carrier_name']
            cb_request.tracking_number = serializer.validated_data['tracking_number']
            cb_request.tracking_url = serializer.validated_data.get('tracking_url', '')
            cb_request.shipped_intl_at = timezone.now()
            cb_request.save()

            if cb_request.sub_order_id:
                _add_shipment_event(
                    cb_request.sub_order_id,
                    ShipmentEvent.EventStatus.SHIPPED_INTL,
                    f'Shipped via {cb_request.carrier_name}. Tracking: {cb_request.tracking_number}',
                )

        # Notify customer
        try:
            from notifications.models import Notification
            from notifications.services import NotificationService
            NotificationService.create(
                user=cb_request.customer,
                title='Your order has shipped!',
                body=f'Your international order is on its way. Carrier: {cb_request.carrier_name}',
                event_type=Notification.Type.CB_ORDER_SHIPPED,
                category=Notification.Category.TRANSACTIONAL,
                deeplink=f'app://crossborder/orders/{cb_request.id}',
                data={'cb_request_id': str(cb_request.id), 'tracking_url': cb_request.tracking_url},
                inbox_visible=True,
                push_enabled=True,
            )
        except Exception:
            pass

        return Response(CrossBorderOrderRequestSerializer(cb_request).data)


class CBMarkCustomsHeldView(APIView):
    """POST /api/admin/crossborder/<id>/mark-customs-held/"""
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        serializer = CBMarkCustomsHeldSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        cb_request = _get_cb_request(pk)
        if not cb_request:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        with transaction.atomic():
            cb_request.status = CrossBorderOrderRequest.Status.CUSTOMS_HELD
            cb_request.save(update_fields=['status', 'updated_at'])

            if cb_request.sub_order_id:
                _add_shipment_event(
                    cb_request.sub_order_id,
                    ShipmentEvent.EventStatus.CUSTOMS_HELD,
                    serializer.validated_data.get('reason') or 'Held at customs.',
                )

        try:
            from notifications.models import Notification
            from notifications.services import NotificationService
            NotificationService.create(
                user=cb_request.customer,
                title='Order held at customs',
                body='Your international order is being held at customs. We are working to resolve it.',
                event_type=Notification.Type.CB_CUSTOMS_HELD,
                category=Notification.Category.TRANSACTIONAL,
                deeplink=f'app://crossborder/orders/{cb_request.id}',
                data={'cb_request_id': str(cb_request.id)},
                inbox_visible=True,
                push_enabled=True,
            )
        except Exception:
            pass

        return Response(CrossBorderOrderRequestSerializer(cb_request).data)


class CBMarkDeliveredView(APIView):
    """POST /api/admin/crossborder/<id>/mark-delivered/"""
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        cb_request = _get_cb_request(pk)
        if not cb_request:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        with transaction.atomic():
            cb_request.status = CrossBorderOrderRequest.Status.DELIVERED
            cb_request.delivered_at = timezone.now()
            cb_request.save(update_fields=['status', 'delivered_at', 'updated_at'])

            if cb_request.sub_order_id:
                _add_shipment_event(
                    cb_request.sub_order_id,
                    ShipmentEvent.EventStatus.DELIVERED,
                    'Delivered to customer.',
                )

        try:
            from notifications.models import Notification
            from notifications.services import NotificationService
            NotificationService.create(
                user=cb_request.customer,
                title='Order delivered!',
                body='Your international order has been delivered.',
                event_type=Notification.Type.CB_ORDER_DELIVERED,
                category=Notification.Category.TRANSACTIONAL,
                deeplink=f'app://crossborder/orders/{cb_request.id}',
                data={'cb_request_id': str(cb_request.id)},
                inbox_visible=True,
                push_enabled=True,
            )
        except Exception:
            pass

        return Response(CrossBorderOrderRequestSerializer(cb_request).data)


class CBFinalizeCostView(APIView):
    """POST /api/admin/crossborder/<id>/finalize-cost/ — True-up realized costs."""
    permission_classes = [IsAdminUser]

    def post(self, request, pk):
        serializer = CBFinalizeCostSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        cb_request = _get_cb_request(pk)
        if not cb_request:
            return Response({'error': 'Not found.'}, status=status.HTTP_404_NOT_FOUND)

        cb_request.realized_item_cost_bdt = serializer.validated_data['realized_item_cost_bdt']
        cb_request.realized_shipping_bdt = serializer.validated_data['realized_shipping_bdt']
        cb_request.ops_notes = serializer.validated_data.get('ops_notes', cb_request.ops_notes)
        cb_request.save(update_fields=['realized_item_cost_bdt', 'realized_shipping_bdt', 'ops_notes', 'updated_at'])

        return Response(CrossBorderOrderRequestSerializer(cb_request).data)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_cb_request(pk) -> CrossBorderOrderRequest | None:
    try:
        return CrossBorderOrderRequest.objects.select_related('customer', 'sub_order').get(id=pk)
    except CrossBorderOrderRequest.DoesNotExist:
        return None


def _add_shipment_event(sub_order_id: int, event_status: str, description: str, source=None):
    from orders.models import ShipmentEvent, SubOrder
    from django.utils import timezone as tz
    last_seq = ShipmentEvent.objects.filter(sub_order_id=sub_order_id).order_by('-sequence').values_list('sequence', flat=True).first() or 0
    ShipmentEvent.objects.create(
        sub_order_id=sub_order_id,
        status=event_status,
        timestamp=tz.now(),
        description=description,
        sequence=last_seq + 1,
        source=source or ShipmentEvent.Source.SYSTEM,
    )
