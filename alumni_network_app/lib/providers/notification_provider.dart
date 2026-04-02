import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  int _unreadCount = 0;
  Timer? _timer;
  final ApiService _api = ApiService();

  int get unreadCount => _unreadCount;

  void startPolling() {
    fetchCount();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => fetchCount());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> fetchCount() async {
    try {
      final response = await _api.get('/notifications/unread-count');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final count = data['unread_count'] ?? 0;
        if (count != _unreadCount) {
          _unreadCount = count;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void reset() {
    _unreadCount = 0;
    notifyListeners();
  }
}
