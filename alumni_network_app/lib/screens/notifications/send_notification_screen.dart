import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _logs = [];
  bool _isLoading = true;
  final Set<int> _selected = {};

  bool get _isSelecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get('/notifications/sent');
      if (response.statusCode == 200) {
        setState(() => _logs = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Fetch sent logs error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelect(int logId) {
    setState(() {
      if (_selected.contains(logId)) {
        _selected.remove(logId);
      } else {
        _selected.add(logId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected.addAll(_logs.map<int>((l) => l['log_id'] as int));
    });
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Selected'),
        content: Text('Delete $count selected notification(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final response = await _api.post('/notifications/sent/delete', {
        'log_ids': _selected.toList(),
      });
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _logs.removeWhere((l) => _selected.contains(l['log_id'] as int));
          _selected.clear();
        });
      }
    } catch (e) {
      debugPrint('Delete logs error: $e');
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'student': return Colors.indigo;
      case 'alumni':  return Colors.teal;
      case 'staff':   return Colors.orange;
      default:        return Colors.blue;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'student': return Icons.school;
      case 'alumni':  return Icons.work;
      case 'staff':   return Icons.badge;
      default:        return Icons.groups;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'student': return 'Students';
      case 'alumni':  return 'Alumni';
      case 'staff':   return 'Staff';
      default:        return 'Everyone';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelecting
          ? AppBar(
              backgroundColor: Colors.blue[800],
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text(
                '${_selected.length} selected',
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                if (_selected.length < _logs.length)
                  TextButton(
                    onPressed: _selectAll,
                    child: const Text('Select All', style: TextStyle(color: Colors.white)),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: _deleteSelected,
                ),
              ],
            )
          : AppBar(
              title: const Text('Sent Notifications'),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No notifications sent yet',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Tap + to send your first notification',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchLogs,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final logId = log['log_id'] as int;
                      final role = log['target_role'] ?? 'all';
                      final color = _roleColor(role);
                      final isSelected = _selected.contains(logId);

                      return GestureDetector(
                        onLongPress: () => _toggleSelect(logId),
                        onTap: _isSelecting ? () => _toggleSelect(logId) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: Colors.blue, width: 2)
                                : null,
                          ),
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: isSelected ? 0 : 2,
                            color: isSelected ? Colors.blue.withValues(alpha: 0.07) : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_isSelecting)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12, top: 2),
                                      child: Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: isSelected ? Colors.blue : Colors.grey,
                                        size: 22,
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(_roleIcon(role), size: 14, color: color),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _roleLabel(role),
                                                    style: TextStyle(
                                                        color: color,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _timeAgo(log['created_at']),
                                              style: TextStyle(
                                                  color: Colors.grey[500], fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          log['title'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          log['message'] ?? '',
                                          style: TextStyle(
                                              color: Colors.grey[700], fontSize: 13),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Icon(Icons.people_outline,
                                                size: 14, color: Colors.grey[500]),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${log['recipient_count']} recipient(s)',
                                              style: TextStyle(
                                                  color: Colors.grey[500], fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _isSelecting
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final sent = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _ComposeNotificationScreen()),
                );
                if (sent == true) _fetchLogs();
              },
              icon: const Icon(Icons.add),
              label: const Text('New'),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
    );
  }
}

// ── Compose screen ──────────────────────────────────────────────────────────

class _ComposeNotificationScreen extends StatefulWidget {
  const _ComposeNotificationScreen();

  @override
  State<_ComposeNotificationScreen> createState() =>
      _ComposeNotificationScreenState();
}

class _ComposeNotificationScreenState
    extends State<_ComposeNotificationScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetRole = 'all';
  bool _isLoading = false;

  final _roles = const [
    {'value': 'all',     'label': 'Everyone',     'icon': Icons.groups, 'color': Colors.blue},
    {'value': 'student', 'label': 'Students Only', 'icon': Icons.school, 'color': Colors.indigo},
    {'value': 'alumni',  'label': 'Alumni Only',   'icon': Icons.work,   'color': Colors.teal},
    {'value': 'staff',   'label': 'Staff Only',    'icon': Icons.badge,  'color': Colors.orange},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty) {
      _snack('Please enter a title');
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      _snack('Please enter a message');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService().post('/notifications/broadcast', {
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'target_role': _targetRole,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final count = data['recipients'] ?? 0;
        if (mounted) {
          _snack('Sent to $count recipient(s)');
          Navigator.pop(context, true);
        }
      } else {
        _snack('Failed to send');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Notification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send To',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _roles.map((r) {
                final selected = _targetRole == r['value'];
                final color = r['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() => _targetRole = r['value'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? color : Colors.grey[100],
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: selected ? color : Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(r['icon'] as IconData,
                            size: 18,
                            color: selected ? Colors.white : Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          r['label'] as String,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.grey[700],
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Message *',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _send,
                      icon: const Icon(Icons.send),
                      label: const Text('SEND NOTIFICATION',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
