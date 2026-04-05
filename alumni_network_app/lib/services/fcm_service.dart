import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// ─────────────────────────────────────────────
/// 🔥 BACKGROUND HANDLER
/// ─────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // ✅ Always show (data-only)
  _showLocalNotification(
    message.data['title'] ?? 'Alumni Network',
    message.data['body'] ?? '',
    message.data,
  );
}

/// ─────────────────────────────────────────────
/// 🔔 SHOW LOCAL NOTIFICATION
/// ─────────────────────────────────────────────
void _showLocalNotification(
  String title,
  String body,
  Map<String, dynamic> data,
) {
  if (title.isEmpty && body.isEmpty) return;

  _localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'alumni_network_channel',
        'Alumni Network',
        channelDescription: 'Alumni Network notifications',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: jsonEncode(data),
  );
}

/// ─────────────────────────────────────────────
/// 🚀 FCM SERVICE
/// ─────────────────────────────────────────────
class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _cachedToken;

  static String? get cachedToken => _cachedToken;

  /// ── INIT ─────────────────────────
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Init local notifications
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          _handleNavigation(data);
        }
      },
    );

    // Create channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'alumni_network_channel',
            'Alumni Network',
            description: 'Alumni Network notifications',
            importance: Importance.max,
          ),
        );

    // ✅ FOREGROUND (data-only)
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(
        message.data['title'] ?? 'Alumni Network',
        message.data['body'] ?? '',
        message.data,
      );
    });

    // ✅ App opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNavigation(message.data);
    });

    // ✅ App opened from terminated
    _handleInitialMessage();

    // Token
    await _generateToken();
  }

  /// ── HANDLE TERMINATED ─────────────────────────
  static Future<void> _handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      _handleNavigation(message.data);
    }
  }

  /// ── NAVIGATION ─────────────────────────
  static void _handleNavigation(Map<String, dynamic> data) {
    final memoId = data['memo_id'];

    if (memoId != null && memoId.isNotEmpty) {
      debugPrint('[FCM] Navigate to memo: $memoId');

      // 👉 Add your navigation logic here
      // Navigator.push(...)
    }
  }

  /// ── PERMISSION ─────────────────────────
  static Future<bool> requestPermission(BuildContext context) async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;

      if (status.isGranted) {
        return true;
      }

      final result = await Permission.notification.request();
      return result.isGranted;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// ── TOKEN ─────────────────────────
  static Future<void> _generateToken() async {
    try {
      _cachedToken = await _messaging.getToken();
      debugPrint('[FCM] Token: $_cachedToken');
    } catch (e) {
      debugPrint('[FCM] Token error: $e');
    }
  }

  /// ── SEND TOKEN ─────────────────────────
  static Future<void> refreshTokenForLoggedInUser(int userId) async {
    if (_cachedToken == null) await _generateToken();
    if (_cachedToken == null) return;

    try {
      await ApiService().post('/auth/fcm-token', {
        'user_id': userId,
        'token': _cachedToken,
      });
    } catch (e) {
      debugPrint('[FCM] Send error: $e');
    }

    _messaging.onTokenRefresh.listen((newToken) {
      _cachedToken = newToken;

      ApiService().post('/auth/fcm-token', {
        'user_id': userId,
        'token': newToken,
      });
    });
  }
}
