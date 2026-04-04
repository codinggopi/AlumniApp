import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Only show local notification for data-only messages.
  // If notification payload exists, Android shows it automatically — don't duplicate.
  if (message.notification == null) {
    _showLocalNotification(message);
  }
}

void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;
  _localNotifications.show(
    notification.hashCode,
    notification.title,
    notification.body,
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

  // Cached token — generated once at startup
  static String? _cachedToken;
  static String? get cachedToken => _cachedToken;

  /// Call once at app start — initializes Firebase, local notifications,
  /// requests permission, and pre-generates the FCM token.
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

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

    FirebaseMessaging.onMessage.listen(_showLocalNotification);
  }

  /// Request notification permission during splash screen.
  /// Returns true if granted.
  static Future<bool> requestPermission(BuildContext context) async {
    if (!context.mounted) return false;

    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isGranted) {
        await _generateToken();
        return true;
      }

      if (status.isPermanentlyDenied) {
        if (!context.mounted) return false;
        final open = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Enable Notifications'),
            content: const Text(
              'Notifications are blocked. Open Settings to enable them so you don\'t miss important updates.',
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

    // iOS
    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized;
    if (granted) await _generateToken();
    return granted;
  }

  /// Pre-generate and cache the FCM token.
  static Future<void> _generateToken() async {
    try {
      _cachedToken = await _messaging.getToken();
      debugPrint('[FCM] Token ready: $_cachedToken');
    } catch (e) {
      debugPrint('[FCM] Token generation error: $e');
    }
  }

  /// Send cached token to backend using the stored JWT (for already-logged-in users).
  static Future<void> refreshTokenForLoggedInUser(int userId) async {
    if (_cachedToken == null) await _generateToken();
    if (_cachedToken == null) return;
    try {
      await ApiService().post('/auth/fcm-token', {
        'user_id': userId,
        'token': _cachedToken,
      });
      debugPrint('[FCM] Token refreshed for user $userId');
    } catch (e) {
      debugPrint('[FCM] Refresh token error: $e');
    }

    // Keep token fresh
    _messaging.onTokenRefresh.listen((newToken) {
      _cachedToken = newToken;
      ApiService().post('/auth/fcm-token', {
        'user_id': userId,
        'token': newToken,
      });
    });
  }
}
