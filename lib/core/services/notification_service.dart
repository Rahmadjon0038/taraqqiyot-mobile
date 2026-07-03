import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import '../../features/notifications/presentation/notification_detail_page.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {
    // Background isolate may already have Firebase initialized.
  }

  debugPrint('FCM background message: ${message.messageId} ${message.data}');
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'taraqqiyot_high_importance',
    'Taraqqiyot notifications',
    description: 'Foreground push notifications for Taraqqiyot app',
    importance: Importance.high,
  );

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _firebaseEnabled = false;
  Map<String, dynamic>? _pendingNotificationData;

  Future<void> init({required bool firebaseEnabled}) async {
    if (_initialized) return;
    _initialized = true;
    _firebaseEnabled = firebaseEnabled;

    await _initializeLocalNotifications();

    if (!_firebaseEnabled) {
      debugPrint('Firebase Messaging disabled on this platform.');
      return;
    }

    await _requestPermissions();
    await _configureForegroundPresentation();
    await _listenToForegroundMessages();
    await _listenToTapEvents();
    await _printFcmToken();
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(_channel);
  }

  Future<void> _requestPermissions() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macosImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    await macosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _configureForegroundPresentation() async {
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _listenToForegroundMessages() async {
    FirebaseMessaging.onMessage.listen((message) {
      _showForegroundNotification(message);
    });
  }

  Future<void> _listenToTapEvents() async {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleRemoteMessageTap(message);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessageTap(initialMessage);
    }
  }

  Future<void> _printFcmToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('FCM token: $token');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Taraqqiyot';
    final body =
        notification?.body ?? message.data['body']?.toString() ?? '';
    final data = <String, dynamic>{...message.data};

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
  }

  Future<void> showTestNotification({
    required String title,
    required String body,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(<String, dynamic>{
        'route': NotificationDetailPage.routeName,
        'title': title,
        'body': body,
        ...data,
      }),
    );
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    handleNotificationData(<String, dynamic>{...message.data});
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        handleNotificationData(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      handleNotificationData(<String, dynamic>{'body': payload});
    }
  }

  void handleNotificationData(Map<String, dynamic> data) {
    final route = data['route']?.toString();
    if (route == null || route.isEmpty) {
      debugPrint('Notification tapped with data: $data');
      return;
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('Navigator not ready for notification route: $route');
      _pendingNotificationData = data;
      return;
    }

    navigator.pushNamed(route, arguments: data);
  }

  void flushPendingNotification() {
    final pending = _pendingNotificationData;
    if (pending == null) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    _pendingNotificationData = null;
    handleNotificationData(pending);
  }
}
