import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/notification_deeplink_handler.dart';

void main() {
  group('NotificationDeeplinkHandler - URI & Payload Routing', () {
    test('routes Live Order Tracking with subOrderId and orderId correctly', () {
      // 1. Direct tracking path: shopease://orders/tracking/42
      final route1 = NotificationDeeplinkHandler.parseUri(
        'shopease://orders/tracking/42',
      );
      expect(route1.type, equals(DeeplinkType.orderTracking));
      expect(route1.subOrderId, equals(42));

      // 2. Order tracking path: shopease://orders/15/tracking
      final route2 = NotificationDeeplinkHandler.parseUri(
        'shopease://orders/15/tracking',
      );
      expect(route2.type, equals(DeeplinkType.orderTracking));
      expect(route2.orderId, equals(15));

      // 3. SubOrder query param: app://orders/15?sub_id=42
      final route3 = NotificationDeeplinkHandler.parseUri(
        'app://orders/15?sub_id=42',
      );
      expect(route3.type, equals(DeeplinkType.orderTracking));
      expect(route3.orderId, equals(15));
      expect(route3.subOrderId, equals(42));

      // 4. Dedicated tracking host: shopease://tracking/88
      final route4 = NotificationDeeplinkHandler.parseUri(
        'shopease://tracking/88',
      );
      expect(route4.type, equals(DeeplinkType.orderTracking));
      expect(route4.subOrderId, equals(88));

      // 5. Raw payload fallback with ORDER_SHIPPED and suborder_id
      final route5 = NotificationDeeplinkHandler.parsePayload({
        'type': 'ORDER_SHIPPED',
        'order_id': 15,
        'suborder_id': 42,
      });
      expect(route5.type, equals(DeeplinkType.orderTracking));
      expect(route5.subOrderId, equals(42));
    });

    test('routes Vendor-Customer Support & In-App Chat correctly', () {
      // 1. shopease://chat/99
      final route1 = NotificationDeeplinkHandler.parseUri('shopease://chat/99');
      expect(route1.type, equals(DeeplinkType.supportChat));
      expect(route1.conversationId, equals(99));

      // 2. app://chat/99
      final route2 = NotificationDeeplinkHandler.parseUri('app://chat/99');
      expect(route2.type, equals(DeeplinkType.supportChat));
      expect(route2.conversationId, equals(99));

      // 3. shopease://chat (conversations list)
      final route3 = NotificationDeeplinkHandler.parseUri('shopease://chat');
      expect(route3.type, equals(DeeplinkType.conversationsList));

      // 4. Raw payload fallback with CHAT_MESSAGE
      final route4 = NotificationDeeplinkHandler.parsePayload({
        'type': 'CHAT_MESSAGE',
        'conversation_id': 105,
      });
      expect(route4.type, equals(DeeplinkType.supportChat));
      expect(route4.conversationId, equals(105));
    });

    test('routes RMA & Return Request Details correctly', () {
      // 1. shopease://rma/7
      final route1 = NotificationDeeplinkHandler.parseUri('shopease://rma/7');
      expect(route1.type, equals(DeeplinkType.rmaDetail));
      expect(route1.rmaId, equals(7));

      // 2. app://returns/7
      final route2 = NotificationDeeplinkHandler.parseUri('app://returns/7');
      expect(route2.type, equals(DeeplinkType.rmaDetail));
      expect(route2.rmaId, equals(7));

      // 3. Raw payload fallback with REFUND_PROCESSED
      final route3 = NotificationDeeplinkHandler.parsePayload({
        'type': 'REFUND_PROCESSED',
        'return_request_id': 12,
      });
      expect(route3.type, equals(DeeplinkType.rmaDetail));
      expect(route3.rmaId, equals(12));

      // 4. Raw payload fallback with RMA_STATUS
      final route4 = NotificationDeeplinkHandler.parsePayload({
        'type': 'RMA_STATUS',
        'rma_id': 25,
      });
      expect(route4.type, equals(DeeplinkType.rmaDetail));
      expect(route4.rmaId, equals(25));
    });

    test('routes Support Tickets, Campaigns, Cart, and Products correctly', () {
      // Support ticket
      final ticketRoute = NotificationDeeplinkHandler.parseUri(
        'shopease://support/tickets/33',
      );
      expect(ticketRoute.type, equals(DeeplinkType.supportTicket));
      expect(ticketRoute.ticketId, equals(33));

      // Campaigns / Flash sales
      final promoRoute = NotificationDeeplinkHandler.parseUri(
        'shopease://campaigns/5',
      );
      expect(promoRoute.type, equals(DeeplinkType.promotions));
      expect(promoRoute.campaignId, equals(5));

      // Cart
      final cartRoute = NotificationDeeplinkHandler.parseUri('shopease://cart');
      expect(cartRoute.type, equals(DeeplinkType.cart));

      // Product PDP
      final productRoute = NotificationDeeplinkHandler.parseUri(
        'shopease://products/404',
      );
      expect(productRoute.type, equals(DeeplinkType.productDetail));
      expect(productRoute.productId, equals(404));

      // Vendor Wallet
      final walletRoute = NotificationDeeplinkHandler.parseUri(
        'shopease://vendor/wallet',
      );
      expect(walletRoute.type, equals(DeeplinkType.vendorWallet));
    });

    test('handles unknown or empty inputs gracefully', () {
      final routeEmpty = NotificationDeeplinkHandler.parseUri('');
      expect(routeEmpty.type, equals(DeeplinkType.unknown));

      final routeInvalid = NotificationDeeplinkHandler.parseUri('invalid-link');
      expect(routeInvalid.type, equals(DeeplinkType.unknown));

      final routeEmptyPayload = NotificationDeeplinkHandler.parsePayload({});
      expect(routeEmptyPayload.type, equals(DeeplinkType.unknown));
    });
  });
}
