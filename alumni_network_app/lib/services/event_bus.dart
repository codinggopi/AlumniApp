import 'dart:async';
import 'package:flutter/foundation.dart';

/// Small app-wide event bus used to broadcast event list changes.
/// This keeps the change local and lightweight instead of adding a full provider.
class EventBus {
  static final StreamController<int> _deletedController =
      StreamController<int>.broadcast();
  static final StreamController<void> _refreshController =
      StreamController<void>.broadcast();

  /// Stream of deleted event ids
  static Stream<int> get deletedStream => _deletedController.stream;
  static Stream<void> get refreshStream => _refreshController.stream;

  /// Emit a deleted event id
  static void emitDeleted(int eventId) {
    try {
      // debug log to help trace broadcasts
      // Use print so it shows in debug console regardless of logging setup
      debugPrint('[EventBus] emitDeleted: $eventId');
      _deletedController.add(eventId);
    } catch (_) {}
  }

  static void emitRefresh() {
    try {
      debugPrint('[EventBus] emitRefresh');
      _refreshController.add(null);
    } catch (_) {}
  }

  /// Dispose the internal controllers (only useful on app teardown)
  static Future<void> dispose() async {
    await _deletedController.close();
    await _refreshController.close();
  }
}
