import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../features/notifications/data/repositories/notification_repository.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../config/app_config.dart';
import '../navigation/app_navigator.dart';
import 'notification_deeplink_handler.dart';

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
        await openDeeplink(ctx, deeplink, message.data);
      });

      // Open from terminated.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        final deeplink = resolveDeeplinkFromData(initial.data);
        final ctx = appNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          await openDeeplink(ctx, deeplink, initial.data);
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
    return NotificationDeeplinkHandler.resolveDeeplink(data);
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
    String deeplink, [
    Map<String, dynamic>? data,
  ]) async {
    await NotificationDeeplinkHandler.navigate(
      context,
      deeplink: deeplink,
      data: data,
    );
  }
}
