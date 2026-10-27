from decimal import Decimal
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from orders.models import Order, SubOrder
from vendors.models import Vendor
from logistics.models import LiveDeliveryTracking

User = get_user_model()


class LiveDeliveryTrackingTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.customer = User.objects.create_user(
            username='track_cust',
            email='track_cust@example.com',
            password='Password123!',
        )
        self.vendor_user = User.objects.create_user(
            username='track_vendor',
            email='track_vendor@example.com',
            password='Password123!',
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name='Dhaka Gadgets',
        )
        self.order = Order.objects.create(
            customer=self.customer,
            subtotal_amount=Decimal('1500.00'),
            total_amount=Decimal('1500.00'),
            status=Order.Status.PAID,
        )
        self.sub_order = SubOrder.objects.create(
            order=self.order,
            vendor=self.vendor,
            status='SHIPPED',
            courier_code='PATHAO',
            courier_name='Pathao Express',
            tracking_number='PTH-12345678',
        )

    def test_live_tracking_auto_creation_and_api(self):
        self.client.force_authenticate(user=self.customer)
        response = self.client.get(f'/api/logistics/sub-orders/{self.sub_order.id}/live-tracking/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.data

        self.assertEqual(data['sub_order_id'], self.sub_order.id)
        self.assertEqual(data['rider_name'], 'Tanvir Ahmed')
        self.assertEqual(data['courier_brand'], 'Pathao Express')
        self.assertIn('current_latitude', data)
        self.assertIn('current_longitude', data)
        self.assertIn('route_waypoints', data)
        self.assertTrue(len(data['route_waypoints']) >= 4)
        self.assertGreater(data['eta_minutes'], 0)

    def test_simulation_advancement(self):
        self.client.force_authenticate(user=self.customer)
        # First call creates
        res1 = self.client.get(f'/api/logistics/sub-orders/{self.sub_order.id}/live-tracking/')
        self.assertEqual(res1.status_code, status.HTTP_200_OK)
        idx1 = res1.data['current_waypoint_index']

        # Second call with advance=true advances position
        res2 = self.client.get(f'/api/logistics/sub-orders/{self.sub_order.id}/live-tracking/?advance=true')
        self.assertEqual(res2.status_code, status.HTTP_200_OK)
        idx2 = res2.data['current_waypoint_index']
        self.assertGreaterEqual(idx2, idx1)

    def test_update_location_api(self):
        self.client.force_authenticate(user=self.vendor_user)
        payload = {
            'latitude': 23.8055,
            'longitude': 90.4110,
            'speed_kmh': 28.5,
            'heading_degrees': 90.0,
            'eta_minutes': 8,
            'status': 'OUT_FOR_DELIVERY',
        }
        response = self.client.post(
            f'/api/logistics/sub-orders/{self.sub_order.id}/update-location/',
            data=payload,
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.data
        self.assertEqual(data['current_latitude'], 23.8055)
        self.assertEqual(data['current_longitude'], 90.4110)
        self.assertEqual(data['speed_kmh'], 28.5)
        self.assertEqual(data['eta_minutes'], 8)
        self.assertEqual(data['status'], 'OUT_FOR_DELIVERY')
