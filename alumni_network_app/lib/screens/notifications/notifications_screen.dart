import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get('/notifications');
      if (response.statusCode == 200) {
        setState(() => _notifications = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Fetch notifications error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.patch('/notifications/mark-all-read', {});
      if (mounted) {
        Provider.of<NotificationProvider>(context, listen: false).reset();
        _fetchNotifications();
      }
    } catch (e) {
      debugPrint('Mark all read error: $e');
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('This will permanently delete all your notifications. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('/notifications/clear-all');
      if (mounted) {
        Provider.of<NotificationProvider>(context, listen: false).reset();
        setState(() => _notifications = []);
      }
    } catch (e) {
      debugPrint('Clear all error: $e');
    }
  }

  Future<void> _markRead(int notiId, int index) async {
    if (_notifications[index]['is_read'] == true) return;
    try {
      await _api.patch('/notifications/$notiId/read', {});
      setState(() => _notifications[index]['is_read'] = true);
      if (mounted) {
        Provider.of<NotificationProvider>(context, listen: false).fetchCount();
      }
    } catch (_) {}
  }

  Future<void> _delete(int notiId) async {
    try {
      await _api.delete('/notifications/$notiId');
      _fetchNotifications();
      if (mounted) {
        Provider.of<NotificationProvider>(context, listen: false).fetchCount();
      }
    } catch (_) {}
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'broadcast': return Icons.campaign;
      case 'message':   return Icons.chat_bubble_outline;
      case 'connection':return Icons.person_add_outlined;
      case 'event':     return Icons.event_outlined;
      default:          return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['is_read'] == false).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: Navigator.canPop(context)
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))
            : null,
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'mark_read') _markAllRead();
                if (val == 'clear') _clearAll();
              },
              itemBuilder: (_) => [
                if (unread > 0)
                  const PopupMenuItem(
                    value: 'mark_read',
                    child: Row(children: [
                      Icon(Icons.done_all, size: 18, color: Colors.blue),
                      SizedBox(width: 10),
                      Text('Mark all as read'),
                    ]),
                  ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(children: [
                    Icon(Icons.delete_sweep, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Clear all', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No notifications yet',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = n['is_read'] == true;
                      final notiId = n['noti_id'] as int;

                      return Dismissible(
                        key: Key('noti_$notiId'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _delete(notiId),
                        child: ListTile(
                          tileColor: isRead ? null : Colors.blue.withValues(alpha: 0.05),
                          leading: CircleAvatar(
                            backgroundColor: isRead
                                ? Colors.grey.withValues(alpha: 0.15)
                                : Colors.blue.withValues(alpha: 0.15),
                            child: Icon(
                              _iconForType(n['type']),
                              color: isRead ? Colors.grey : Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            n['message'] ?? '',
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            _timeAgo(n['created_at']),
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                          trailing: !isRead
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          onTap: () => _markRead(notiId, index),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
