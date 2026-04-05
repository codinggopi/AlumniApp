import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// BACKGROUND HANDLER
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Only show notification manually for DATA-ONLY messages
  if (message.notification == null) {
    _showLocalNotification(message);
  }
}

/// LOCAL NOTIFICATION DISPLAY FUNCTION
void _showLocalNotification(RemoteMessage message) {
  String? title;
  String? body;

  // Notification payload
  if (message.notification != null) {
    title = message.notification!.title;
    body = message.notification!.body;
  }

  // Data payload fallback
  if (message.data.isNotEmpty) {
    title ??= message.data['title'];
    body ??= message.data['body'];
  }

  if (title == null && body == null) return;

  _localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'alumni_network_channel',
        'Alumni Network',
        channelDescription: 'Alumni Network notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static String? _cachedToken;
  static String? get cachedToken => _cachedToken;

  /// INITIALIZE EVERYTHING (CALL IN main.dart)
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    /// Background messages
    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);

    /// Local notifications init
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    /// Create notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'alumni_network_channel',
            'Alumni Network',
            description: 'Alumni Network notifications',
            importance: Importance.high,
          ),
        );

    /// FOREGROUND HANDLER (ALWAYS SHOW MANUALLY)
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    /// OPTIONAL: handle when user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] Notification clicked');
    });
  }

  /// REQUEST PERMISSION
  static Future<bool> requestPermission(BuildContext context) async {
    if (!context.mounted) return false;

    if (Platform.isAndroid) {
      final status = await Permission.notification.status;

      if (status.isGranted) {
        await _generateToken();
        return true;
      }

      if (status.isPermanentlyDenied) {
        final open = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Enable Notifications'),
            content: const Text(
              'Notifications are blocked. Open Settings to enable them.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not Now'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (open == true) await openAppSettings();
        return false;
      }

      final result = await Permission.notification.request();

      if (result.isGranted) {
        await _generateToken();
        return true;
      }

      return false;
    }

    /// iOS
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized;

    if (granted) await _generateToken();

    return granted;
  }

  /// GENERATE TOKEN
  static Future<void> _generateToken() async {
    try {
      _cachedToken = await _messaging.getToken();
      debugPrint('[FCM] Token: $_cachedToken');
    } catch (e) {
      debugPrint('[FCM] Token error: $e');
    }
  }

  /// SEND TOKEN TO BACKEND
  static Future<void> refreshTokenForLoggedInUser(int userId) async {
    if (_cachedToken == null) await _generateToken();
    if (_cachedToken == null) return;

    try {
      await ApiService().post('/auth/fcm-token', {
        'user_id': userId,
        'token': _cachedToken,
      });

      debugPrint('[FCM] Token sent for user $userId');
    } catch (e) {
      debugPrint('[FCM] Send token error: $e');
    }

    /// Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _cachedToken = newToken;

      ApiService().post('/auth/fcm-token', {
        'user_id': userId,
        'token': newToken,
      });
    });
  }
}