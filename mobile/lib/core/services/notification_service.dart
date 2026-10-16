import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../features/orders/data/repositories/order_repository.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/returns/data/repositories/return_repository.dart';
import '../../features/returns/presentation/screens/return_detail_screen.dart';
import '../../features/notifications/data/repositories/notification_repository.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../../features/vendor/presentation/screens/vendor_dashboard_screen.dart';
import '../../features/vendor/presentation/screens/vendor_wallet_screen.dart';
import '../../features/support/presentation/screens/ticket_chat_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/coupons/presentation/screens/coupon_center_screen.dart';
import '../../features/products/domain/repositories/product_repository.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/crossborder/presentation/screens/cb_my_orders_screen.dart';
import '../config/app_config.dart';
import '../navigation/app_navigator.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static bool _pushInitialized = false;
  static Future<void>? _pushInitFuture;
  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _messageSub;
  static StreamSubscription<RemoteMessage>? _openedSub;

  static const String _androidChannelId = 'shopease_default';

  static Future<void> ensurePushInitialized(BuildContext context) async {
    if (_pushInitialized) return;
    _pushInitFuture ??= _ensurePushInitializedInner(context);
    await _pushInitFuture;
  }

  static Future<void> _ensurePushInitializedInner(BuildContext context) async {
    try {
      final notificationRepo = context.read<NotificationRepository>();

      await _initLocalNotifications();
      await _requestPermissions();

      // For iOS: ensure foreground notifications can be handled without double-rendering.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: true,
          );

      // Register current token (if any) and refresh on rotation.
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _registerToken(notificationRepo, token);
      }

      _tokenSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        final ctx = appNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        await _registerToken(ctx.read<NotificationRepository>(), t);
      });

      // Foreground messages -> local notification + refresh unread badge.
      _messageSub ??= FirebaseMessaging.onMessage.listen((message) async {
        await _showForegroundNotification(message);
        final ctx = appNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        await ctx.read<NotificationProvider>().refreshUnreadCount();
      });

      // Open from background.
      _openedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((
        message,
      ) async {
        final deeplink = resolveDeeplinkFromData(message.data);
        final ctx = appNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        await openDeeplink(ctx, deeplink);
      });

      // Open from terminated.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        final deeplink = resolveDeeplinkFromData(initial.data);
        final ctx = appNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          await openDeeplink(ctx, deeplink);
        }
      }

      _pushInitialized = true;
    } catch (_) {
      // Best-effort: do not block app startup if Firebase plugins aren't available
      // (e.g., widget tests) or if notification permissions are denied.
      _pushInitialized = false;
    } finally {
      _pushInitFuture = null;
    }
  }

  static String resolveDeeplinkFromData(Map<String, dynamic> data) {
    if (data['deeplink'] != null && data['deeplink'].toString().trim().isNotEmpty) {
      return data['deeplink'].toString().trim();
    }
    final type = data['type']?.toString().toUpperCase() ?? '';
    final id = data['id'] ??
        data['order_id'] ??
        data['conversation_id'] ??
        data['ticket_id'] ??
        data['product_id'] ??
        data['return_id'];

    if (type.contains('CHAT') || type == 'MESSAGE') {
      return id != null ? 'app://chat/$id' : 'app://chat';
    }
    if (type.contains('ORDER') || type == 'NEW_SUBORDER') {
      return id != null ? 'app://orders/$id' : 'app://orders';
    }
    if (type.contains('RETURN') || type.contains('REFUND') || type == 'RMA') {
      return id != null ? 'app://returns/$id' : 'app://returns';
    }
    if (type.contains('TICKET') || type.contains('SUPPORT')) {
      return id != null ? 'app://support/tickets/$id' : 'app://support';
    }
    if (type.contains('PROMO') || type.contains('FLASH_SALE')) {
      return 'app://promos';
    }
    if (type.contains('CART')) {
      return 'app://cart';
    }
    if (type.contains('PRODUCT')) {
      return id != null ? 'app://products/$id' : '';
    }
    if (type.contains('PAYOUT')) {
      return 'app://vendor/wallet';
    }
    return '';
  }

  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload ?? '';
        final ctx = appNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        await openDeeplink(ctx, payload);
      },
    );

    const androidChannel = AndroidNotificationChannel(
      _androidChannelId,
      AppConfig.appName,
      description: 'ShopEase notifications',
      importance: Importance.high,
    );

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  static Future<void> _requestPermissions() async {
    // iOS permission (also covers iPadOS/macCatalyst).
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android 13+ runtime permission.
    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    // iOS local-notifications permission (best-effort).
    final iosPlugin = _local
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'ShopEase';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? '';
    final deeplink = resolveDeeplinkFromData(message.data);

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      AppConfig.appName,
      channelDescription: 'ShopEase notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: deeplink,
    );
  }

  static Future<void> _registerToken(
    NotificationRepository repo,
    String token,
  ) async {
    final pkg = await PackageInfo.fromPlatform();
    final info = DeviceInfoPlugin();

    String deviceId = '';
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      deviceId = android.id;
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      deviceId = ios.identifierForVendor ?? '';
    }

    final platform = Platform.isAndroid
        ? 'ANDROID'
        : Platform.isIOS
        ? 'IOS'
        : 'WEB';
    final appVersion = '${pkg.version}+${pkg.buildNumber}';

    await repo.registerDeviceToken(
      token: token,
      platform: platform,
      deviceId: deviceId,
      appVersion: appVersion,
    );
  }

  static Future<void> openDeeplink(
    BuildContext context,
    String deeplink,
  ) async {
    String raw = deeplink.trim();
    if (raw.isEmpty) return;

    if (!raw.startsWith('app://') &&
        !raw.startsWith('http://') &&
        !raw.startsWith('https://')) {
      if (raw.startsWith('/')) {
        raw = 'app:/$raw';
      } else {
        raw = 'app://$raw';
      }
    }

    Uri? uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      return;
    }
    if (uri.scheme != 'app') return;

    try {
      final host = uri.host;
      final seg = uri.pathSegments;

      // 1. Direct In-App Chat
      if (host == 'chat') {
        if (seg.isNotEmpty) {
          final convId = int.tryParse(seg.first);
          if (convId != null) {
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(conversationId: convId),
              ),
            );
            return;
          }
        }
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ConversationsScreen()),
        );
        return;
      }

      // 2. Orders & Order Tracking
      if (host == 'orders' && seg.isNotEmpty) {
        final orderId = int.tryParse(seg.first);
        if (orderId == null) return;
        final repo = context.read<OrderRepository>();
        final order = await repo.getOrderDetail(orderId);
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
        );
        return;
      }

      // 3. Returns & RMA
      if (host == 'returns' && seg.isNotEmpty) {
        final returnId = int.tryParse(seg.first);
        if (returnId == null) return;
        final repo = context.read<ReturnRepository>();
        final rr = await repo.getReturnDetail(returnId);
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReturnDetailScreen(returnRequest: rr),
          ),
        );
        return;
      }

      // 4. Products / Flash sales
      if (host == 'products' && seg.isNotEmpty) {
        final productId = int.tryParse(seg.first);
        if (productId == null) return;
        final repo = context.read<ProductRepository>();
        final product = await repo.getProductDetail(productId);
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
        return;
      }

      // 5. Vendor Console & Messages
      if (host == 'vendor') {
        if (seg.isNotEmpty && (seg.first == 'chat' || seg.first == 'messages')) {
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ConversationsScreen(isVendorView: true),
            ),
          );
          return;
        }
        if (seg.isNotEmpty && seg.first == 'wallet') {
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VendorWalletScreen()),
          );
          return;
        }
        if (seg.isNotEmpty && seg.first == 'orders') {
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VendorDashboardScreen(initialIndex: 2),
            ),
          );
          return;
        }
      }

      // 6. Support Tickets
      if (host == 'support') {
        if (seg.length >= 2 && seg.first == 'tickets') {
          final ticketId = int.tryParse(seg[1]);
          if (ticketId == null) return;
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TicketChatScreen(ticketId: ticketId),
            ),
          );
          return;
        }
      }

      // 7. Cart
      if (host == 'cart') {
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CartScreen()),
        );
        return;
      }

      // 8. Coupons
      if (host == 'coupons') {
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CouponCenterScreen()),
        );
        return;
      }

      // 9. Cross-border orders
      if (host == 'crossborder') {
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CbMyOrdersScreen()),
        );
        return;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open destination: $e')),
      );
    }
  }
}
