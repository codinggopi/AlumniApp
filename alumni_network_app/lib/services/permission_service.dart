import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request all required permissions at app start.
  /// Called once during splash screen.
  static Future<void> requestAllPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return;

    // Request notification + media permissions together
    final statuses = await [
      Permission.notification,
      Permission.photos,           // Android 13+ (READ_MEDIA_IMAGES)
      Permission.storage,          // Android < 13 (READ_EXTERNAL_STORAGE)
    ].request();

    // If any media permission permanently denied, show settings dialog
    final photoDenied = statuses[Permission.photos]?.isPermanentlyDenied == true ||
        statuses[Permission.storage]?.isPermanentlyDenied == true;

    if (photoDenied && context.mounted) {
      await _showSettingsDialog(
        context,
        title: 'Media Access Required',
        message:
            'To upload profile pictures and documents, please allow media access in Settings.',
      );
    }
  }

  /// Check if media (photos/storage) permission is granted.
  /// Call this before any file pick operation.
  static Future<bool> checkMediaPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    // Android 13+
    if (await Permission.photos.isGranted) return true;
    // Android < 13
    if (await Permission.storage.isGranted) return true;

    // Try requesting
    final photoResult = await Permission.photos.request();
    if (photoResult.isGranted) return true;

    final storageResult = await Permission.storage.request();
    if (storageResult.isGranted) return true;

    // Permanently denied — open settings
    if (!context.mounted) return false;

    final isPermanent = await Permission.photos.isPermanentlyDenied ||
        await Permission.storage.isPermanentlyDenied;

    if (isPermanent) {
      await _showSettingsDialog(
        context,
        title: 'Media Access Blocked',
        message:
            'Please open Settings and allow media/storage access to upload photos and documents.',
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Media permission is required to upload files.'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    return false;
  }

  static Future<void> _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    if (!context.mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
  }
}
