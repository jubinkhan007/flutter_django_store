import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/orders/data/models/live_tracking_model.dart';
import 'package:mobile/features/orders/data/models/order_model.dart';
import 'package:mobile/features/orders/presentation/widgets/delivery_route_map_view.dart';

void main() {
  group('LiveDeliveryTrackingModel Tests', () {
    final sampleJson = {
      'id': 1,
      'sub_order_id': 101,
      'rider_name': 'Tanvir Ahmed',
      'rider_phone': '+8801712345678',
      'rider_photo': '',
      'rider_rating': 4.9,
      'vehicle_type': 'Motorcycle',
      'vehicle_number': 'DHAKA METRO-HA-12-3456',
      'courier_brand': 'Pathao Express',
      'status': 'OUT_FOR_DELIVERY',
      'status_display': 'Out for Delivery',
      'origin_latitude': 23.7925,
      'origin_longitude': 90.4078,
      'origin_name': 'Gulshan Hub',
      'destination_latitude': 23.8103,
      'destination_longitude': 90.4125,
      'destination_name': 'Baridhara DOHS',
      'current_latitude': 23.7990,
      'current_longitude': 90.4098,
      'heading_degrees': 45.0,
      'speed_kmh': 24.0,
      'eta_minutes': 12,
      'distance_km': '1.80',
      'route_waypoints': [
        {'lat': 23.7925, 'lng': 90.4078},
        {'lat': 23.7950, 'lng': 90.4085},
        {'lat': 23.7990, 'lng': 90.4098},
        {'lat': 23.8103, 'lng': 90.4125},
      ],
      'current_waypoint_index': 2,
      'last_location_update': '2026-10-23T12:00:00Z',
    };

    test('Parses JSON correctly into LiveDeliveryTrackingModel', () {
      final model = LiveDeliveryTrackingModel.fromJson(sampleJson);

      expect(model.id, 1);
      expect(model.subOrderId, 101);
      expect(model.riderName, 'Tanvir Ahmed');
      expect(model.riderPhone, '+8801712345678');
      expect(model.riderRating, 4.9);
      expect(model.courierBrand, 'Pathao Express');
      expect(model.status, 'OUT_FOR_DELIVERY');
      expect(model.isOutForDelivery, isTrue);
      expect(model.isDelivered, isFalse);
      expect(model.routeWaypoints.length, 4);
      expect(model.etaMinutes, 12);
      expect(model.distanceKm, 1.80);
      expect(model.speedKmh, 24.0);
    });

    test('SubOrderModel parses hasLiveTracking correctly', () {
      final subOrderJson = {
        'id': 101,
        'order_id': 50,
        'vendor_store_name': 'Gadget Store',
        'package_label': 'Package 1',
        'status': 'SHIPPED',
        'has_live_tracking': true,
        'provision_status': 'COMPLETED',
        'courier_reference_id': 'REF123',
        'last_error': '',
        'payment_status': 'PAID',
        'payment_method': 'ONLINE',
        'total_amount': '1500.00',
        'created_at': '2026-10-23T12:00:00Z',
        'items': [],
        'events': [],
      };

      final subOrder = SubOrderModel.fromJson(subOrderJson);
      expect(subOrder.id, 101);
      expect(subOrder.hasLiveTracking, isTrue);
    });

    testWidgets('DeliveryRouteMapView renders interactive canvas', (tester) async {
      final model = LiveDeliveryTrackingModel.fromJson(sampleJson);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryRouteMapView(tracking: model),
          ),
        ),
      );

      // Verify widget elements
      expect(find.byType(DeliveryRouteMapView), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.textContaining('Pathao Express'), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });
  });
}
