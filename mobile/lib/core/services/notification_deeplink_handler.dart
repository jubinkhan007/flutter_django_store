import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/app_navigator.dart';
import '../../features/orders/data/repositories/order_repository.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/order_live_tracking_screen.dart';
import '../../features/returns/data/repositories/return_repository.dart';
import '../../features/returns/presentation/screens/return_detail_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/support/presentation/screens/ticket_chat_screen.dart';
import '../../features/support/presentation/screens/support_center_screen.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/coupons/presentation/screens/coupon_center_screen.dart';
import '../../features/products/domain/repositories/product_repository.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/vendor/presentation/screens/vendor_dashboard_screen.dart';
import '../../features/vendor/presentation/screens/vendor_wallet_screen.dart';
import '../../features/crossborder/presentation/screens/cb_my_orders_screen.dart';

enum DeeplinkType {
  orderTracking,
  orderDetail,
  supportChat,
  conversationsList,
  rmaDetail,
  supportTicket,
  promotions,
  cart,
  productDetail,
  vendorWallet,
  vendorDashboard,
  crossBorderOrders,
  unknown,
}

/// Represents the parsed target destination from a push notification payload or deeplink URI.
class DeeplinkRoute {
  final DeeplinkType type;
  final int? orderId;
  final int? subOrderId;
  final int? conversationId;
  final int? rmaId;
  final int? ticketId;
  final int? productId;
  final int? campaignId;
  final String rawUri;
  final Map<String, dynamic> rawData;

  const DeeplinkRoute({
    required this.type,
    this.orderId,
    this.subOrderId,
    this.conversationId,
    this.rmaId,
    this.ticketId,
    this.productId,
    this.campaignId,
    this.rawUri = '',
    this.rawData = const {},
  });

  @override
  String toString() =>
      'DeeplinkRoute(type: $type, orderId: $orderId, subOrderId: $subOrderId, convId: $conversationId, rmaId: $rmaId, ticketId: $ticketId)';
}

/// Central routing engine for customer push notification payloads and deep-links.
/// Maps incoming FCM payloads directly into Live Order Tracking, Support Chat, or RMA Details.
class NotificationDeeplinkHandler {
  /// Resolves an FCM message payload into a normalized URI string.
  static String resolveDeeplink(Map<String, dynamic> data) {
    final direct = data['deeplink']?.toString().trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final type = data['type']?.toString().toUpperCase() ?? '';
    final orderId = data['order_id'] ?? data['orderId'] ?? data['id'];
    final subOrderId = data['suborder_id'] ??
        data['sub_order_id'] ??
        data['subOrderId'] ??
        data['sub_id'];
    final convId = data['conversation_id'] ??
        data['conversationId'] ??
        data['channel_id'] ??
        data['chat_id'];
    final rmaId = data['return_request_id'] ??
        data['rma_id'] ??
        data['return_id'] ??
        data['rmaId'];
    final ticketId = data['ticket_id'] ?? data['ticketId'];
    final prodId = data['product_id'] ?? data['productId'];

    // 1. Live Order Tracking & Orders
    if (type.contains('TRACKING') ||
        type == 'ORDER_SHIPPED' ||
        type == 'LIVE_TRACKING') {
      if (subOrderId != null) {
        return 'shopease://orders/tracking/$subOrderId';
      }
      if (orderId != null) {
        return 'shopease://orders/$orderId/tracking';
      }
    }
    if (type.contains('ORDER') || type == 'NEW_SUBORDER') {
      if (subOrderId != null && orderId != null) {
        return 'shopease://orders/$orderId?sub_id=$subOrderId';
      }
      if (orderId != null) {
        return 'shopease://orders/$orderId';
      }
      return 'shopease://orders';
    }

    // 2. Chat / In-app messaging
    if (type.contains('CHAT') || type == 'MESSAGE') {
      return convId != null ? 'shopease://chat/$convId' : 'shopease://chat';
    }

    // 3. RMA / Returns
    if (type.contains('RETURN') ||
        type.contains('REFUND') ||
        type.contains('RMA')) {
      return rmaId != null ? 'shopease://rma/$rmaId' : 'shopease://rma';
    }

    // 4. Support Tickets
    if (type.contains('TICKET') || type.contains('SUPPORT')) {
      return ticketId != null
          ? 'shopease://support/tickets/$ticketId'
          : 'shopease://support';
    }

    // 5. Campaigns / Promos / Flash sales
    if (type.contains('PROMO') ||
        type.contains('FLASH_SALE') ||
        type.contains('CAMPAIGN')) {
      final campId = data['campaign_id'] ?? data['flash_sale_id'];
      return campId != null
          ? 'shopease://campaigns/$campId'
          : 'shopease://campaigns';
    }

    // 6. Cart reminders
    if (type.contains('CART')) {
      return 'shopease://cart';
    }

    // 7. Product PDP
    if (type.contains('PRODUCT') && prodId != null) {
      return 'shopease://products/$prodId';
    }

    // 8. Vendor wallet
    if (type.contains('PAYOUT')) {
      return 'shopease://vendor/wallet';
    }

    return '';
  }

  /// Parses an FCM payload dictionary into a typed DeeplinkRoute.
  static DeeplinkRoute parsePayload(Map<String, dynamic> data) {
    final uriStr = resolveDeeplink(data);
    if (uriStr.isNotEmpty) {
      return parseUri(uriStr, data);
    }
    return const DeeplinkRoute(type: DeeplinkType.unknown);
  }

  /// Parses a deep-link URI into a typed DeeplinkRoute.
  static DeeplinkRoute parseUri(
    String uriString, [
    Map<String, dynamic> rawData = const {},
  ]) {
    String raw = uriString.trim();
    if (raw.isEmpty) {
      return DeeplinkRoute(type: DeeplinkType.unknown, rawData: rawData);
    }

    // Normalize schemes: treat app:// and shopease:// equivalently
    if (!raw.startsWith('app://') &&
        !raw.startsWith('shopease://') &&
        !raw.startsWith('http://') &&
        !raw.startsWith('https://')) {
      if (raw.startsWith('/')) {
        raw = 'shopease:/$raw';
      } else {
        raw = 'shopease://$raw';
      }
    }

    Uri? uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      return DeeplinkRoute(
        type: DeeplinkType.unknown,
        rawUri: raw,
        rawData: rawData,
      );
    }

    if (uri.scheme != 'app' && uri.scheme != 'shopease') {
      return DeeplinkRoute(
        type: DeeplinkType.unknown,
        rawUri: raw,
        rawData: rawData,
      );
    }

    final host = uri.host.toLowerCase();
    final seg = uri.pathSegments;
    final query = uri.queryParameters;

    // ── 1. Orders & Live Tracking ──
    if (host == 'orders') {
      final subIdFromQuery = int.tryParse(
        query['sub_id'] ?? query['suborder_id'] ?? '',
      );

      // Path: /orders/tracking/:subOrderId
      if (seg.isNotEmpty && seg.first == 'tracking' && seg.length >= 2) {
        final subId = int.tryParse(seg[1]);
        return DeeplinkRoute(
          type: DeeplinkType.orderTracking,
          subOrderId: subId,
          rawUri: raw,
          rawData: rawData,
        );
      }

      // Path: /orders/:orderId/tracking/:subOrderId
      if (seg.length >= 3 && seg[1] == 'tracking') {
        final orderId = int.tryParse(seg[0]);
        final subId = int.tryParse(seg[2]);
        return DeeplinkRoute(
          type: DeeplinkType.orderTracking,
          orderId: orderId,
          subOrderId: subId,
          rawUri: raw,
          rawData: rawData,
        );
      }

      // Path: /orders/:orderId/tracking
      if (seg.length >= 2 && seg[1] == 'tracking') {
        final orderId = int.tryParse(seg[0]);
        return DeeplinkRoute(
          type: DeeplinkType.orderTracking,
          orderId: orderId,
          subOrderId: subIdFromQuery,
          rawUri: raw,
          rawData: rawData,
        );
      }

      // Path: /orders/:orderId?sub_id=:subOrderId
      if (seg.isNotEmpty) {
        final orderId = int.tryParse(seg[0]);
        if (subIdFromQuery != null) {
          return DeeplinkRoute(
            type: DeeplinkType.orderTracking,
            orderId: orderId,
            subOrderId: subIdFromQuery,
            rawUri: raw,
            rawData: rawData,
          );
        }
        return DeeplinkRoute(
          type: DeeplinkType.orderDetail,
          orderId: orderId,
          rawUri: raw,
          rawData: rawData,
        );
      }

      return DeeplinkRoute(
        type: DeeplinkType.orderDetail,
        rawUri: raw,
        rawData: rawData,
      );
    }

    // Direct tracking host: shopease://tracking/:subOrderId
    if (host == 'tracking' && seg.isNotEmpty) {
      final subId = int.tryParse(seg.first);
      return DeeplinkRoute(
        type: DeeplinkType.orderTracking,
        subOrderId: subId,
        rawUri: raw,
        rawData: rawData,
      );
    }

    // ── 2. Direct Chat & Support Messaging ──
    if (host == 'chat') {
      if (seg.isNotEmpty) {
        final convId = int.tryParse(seg.first);
        return DeeplinkRoute(
          type: DeeplinkType.supportChat,
          conversationId: convId,
          rawUri: raw,
          rawData: rawData,
        );
      }
      return DeeplinkRoute(
        type: DeeplinkType.conversationsList,
        rawUri: raw,
        rawData: rawData,
      );
    }

    // ── 3. RMA & Returns Details ──
    if (host == 'rma' || host == 'returns') {
      if (seg.isNotEmpty) {
        final rmaId = int.tryParse(seg.first);
        return DeeplinkRoute(
          type: DeeplinkType.rmaDetail,
          rmaId: rmaId,
          rawUri: raw,
          rawData: rawData,
        );
      }
      return DeeplinkRoute(
        type: DeeplinkType.rmaDetail,
        rawUri: raw,
        rawData: rawData,
      );
    }

    // ── 4. Support Tickets ──
    if (host == 'support') {
      if (seg.length >= 2 && seg.first == 'tickets') {
        final ticketId = int.tryParse(seg[1]);
        return DeeplinkRoute(
          type: DeeplinkType.supportTicket,
          ticketId: ticketId,
          rawUri: raw,
          rawData: rawData,
        );
      }
      if (seg.isNotEmpty) {
        final ticketId = int.tryParse(seg.first);
        return DeeplinkRoute(
          type: DeeplinkType.supportTicket,
          ticketId: ticketId,
          rawUri: raw,
          rawData: rawData,
        );
      }
      return DeeplinkRoute(
        type: DeeplinkType.supportTicket,
        rawUri: raw,
        rawData: rawData,
      );
    }

    // ── 5. Flash Sales, Campaigns & Promos ──
    if (host == 'campaigns' ||
        host == 'promos' ||
        host == 'flash-sale' ||
        host == 'flash_sale') {
      final campId = seg.isNotEmpty ? int.tryParse(seg.first) : null;
      return DeeplinkRoute(
        type: DeeplinkType.promotions,
        campaignId: campId,
        rawUri: raw,
        rawData: rawData,
      );
    }

    // ── 6. Cart ──
    if (host == 'cart') {
      return DeeplinkRoute(
        type: DeeplinkType.cart,
        rawUri: raw,
        rawData: rawData,
      );
    }

    // ── 7. Products (PDP) ──
    if (host == 'products' && seg.isNotEmpty) {
      final prodId = int.tryParse(seg.first);
      return DeeplinkRoute(
        type: DeeplinkType.productDetail,
        productId: prodId,
        rawUri: raw,
        rawData: rawData,
      );
    }

    // ── 8. Vendor Console ──
    if (host == 'vendor') {
      if (seg.isNotEmpty && (seg.first == 'chat' || seg.first == 'messages')) {
        return DeeplinkRoute(
          type: DeeplinkType.conversationsList,
          rawUri: raw,
          rawData: rawData,
        );
      }
      if (seg.isNotEmpty && seg.first == 'wallet') {
        return DeeplinkRoute(
          type: DeeplinkType.vendorWallet,
          rawUri: raw,
          rawData: rawData,
        );
      }
      if (seg.isNotEmpty && seg.first == 'orders') {
        return DeeplinkRoute(
          type: DeeplinkType.vendorDashboard,
          rawUri: raw,
          rawData: rawData,
        );
      }
    }

    // ── 9. Cross-Border ──
    if (host == 'crossborder') {
      return DeeplinkRoute(
        type: DeeplinkType.crossBorderOrders,
        rawUri: raw,
        rawData: rawData,
      );
    }

    return DeeplinkRoute(
      type: DeeplinkType.unknown,
      rawUri: raw,
      rawData: rawData,
    );
  }

  /// Executes the navigation corresponding to [route] using the provided [context].
  static Future<bool> navigate(
    BuildContext context, {
    String? deeplink,
    Map<String, dynamic>? data,
    DeeplinkRoute? route,
  }) async {
    final targetRoute = route ??
        (data != null
            ? parsePayload(data)
            : parseUri(deeplink ?? '', data ?? const {}));

    if (targetRoute.type == DeeplinkType.unknown) {
      return false;
    }

    try {
      final nav = Navigator.of(context);

      switch (targetRoute.type) {
        // ── 1. Live Order Tracking ──
        case DeeplinkType.orderTracking:
          if (targetRoute.subOrderId != null) {
            nav.push(
              MaterialPageRoute(
                builder: (_) => OrderLiveTrackingScreen(
                  subOrderId: targetRoute.subOrderId!,
                ),
              ),
            );
            return true;
          }

          if (targetRoute.orderId != null) {
            final repo = context.read<OrderRepository>();
            final order = await repo.getOrderDetail(targetRoute.orderId!);
            if (!context.mounted) return false;

            if (order.subOrders.isNotEmpty) {
              final activeSub = order.subOrders.firstWhere(
                (so) => so.status != 'DELIVERED' && so.status != 'CANCELED',
                orElse: () => order.subOrders.first,
              );
              nav.push(
                MaterialPageRoute(
                  builder: (_) => OrderLiveTrackingScreen(
                    subOrderId: activeSub.id,
                    subOrder: activeSub,
                  ),
                ),
              );
            } else {
              nav.push(
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(order: order),
                ),
              );
            }
            return true;
          }
          return false;

        // ── 2. Order Detail ──
        case DeeplinkType.orderDetail:
          if (targetRoute.orderId != null) {
            final repo = context.read<OrderRepository>();
            final order = await repo.getOrderDetail(targetRoute.orderId!);
            if (!context.mounted) return false;
            nav.push(
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(order: order),
              ),
            );
            return true;
          }
          return false;

        // ── 3. Support & Vendor Chat ──
        case DeeplinkType.supportChat:
          nav.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: targetRoute.conversationId,
              ),
            ),
          );
          return true;

        case DeeplinkType.conversationsList:
          nav.push(
            MaterialPageRoute(
              builder: (_) => const ConversationsScreen(),
            ),
          );
          return true;

        // ── 4. RMA / Returns Detail ──
        case DeeplinkType.rmaDetail:
          if (targetRoute.rmaId != null) {
            final repo = context.read<ReturnRepository>();
            final rr = await repo.getReturnDetail(targetRoute.rmaId!);
            if (!context.mounted) return false;
            nav.push(
              MaterialPageRoute(
                builder: (_) => ReturnDetailScreen(returnRequest: rr),
              ),
            );
            return true;
          }
          return false;

        // ── 5. Support Tickets ──
        case DeeplinkType.supportTicket:
          if (targetRoute.ticketId != null) {
            nav.push(
              MaterialPageRoute(
                builder: (_) => TicketChatScreen(
                  ticketId: targetRoute.ticketId!,
                ),
              ),
            );
            return true;
          }
          nav.push(
            MaterialPageRoute(
              builder: (_) => const SupportCenterScreen(),
            ),
          );
          return true;

        // ── 6. Promotions / Flash Sales ──
        case DeeplinkType.promotions:
          nav.push(
            MaterialPageRoute(
              builder: (_) => const CouponCenterScreen(),
            ),
          );
          return true;

        // ── 7. Cart ──
        case DeeplinkType.cart:
          nav.push(
            MaterialPageRoute(
              builder: (_) => const CartScreen(),
            ),
          );
          return true;

        // ── 8. Product Detail ──
        case DeeplinkType.productDetail:
          if (targetRoute.productId != null) {
            final repo = context.read<ProductRepository>();
            final prod = await repo.getProductDetail(targetRoute.productId!);
            if (!context.mounted) return false;
            nav.push(
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: prod),
              ),
            );
            return true;
          }
          return false;

        // ── 9. Vendor Views ──
        case DeeplinkType.vendorWallet:
          nav.push(
            MaterialPageRoute(
              builder: (_) => const VendorWalletScreen(),
            ),
          );
          return true;

        case DeeplinkType.vendorDashboard:
          nav.push(
            MaterialPageRoute(
              builder: (_) => const VendorDashboardScreen(initialIndex: 2),
            ),
          );
          return true;

        // ── 10. Cross-border ──
        case DeeplinkType.crossBorderOrders:
          nav.push(
            MaterialPageRoute(
              builder: (_) => const CbMyOrdersScreen(),
            ),
          );
          return true;

        case DeeplinkType.unknown:
          return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open destination: $e')),
        );
      }
      return false;
    }
  }
}
