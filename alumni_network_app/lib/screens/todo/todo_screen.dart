import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Notification plugin (shared instance) ────────────────────────────────────
final _notif = FlutterLocalNotificationsPlugin();

Future<void> initTodoNotifications() async {
  await _notif.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await _notif
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'todo_channel',
          'To-Do Reminders',
          description: 'Reminders for your to-do tasks',
          importance: Importance.max,
        ),
      );
}

// ── Model ─────────────────────────────────────────────────────────────────────
class TodoItem {
  final int id;
  String title;
  String? description;
  DateTime? dueDateTime;
  bool done;
  String priority; // 'low' | 'medium' | 'high'

  TodoItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDateTime,
    this.done = false,
    this.priority = 'medium',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'dueDateTime': dueDateTime?.toIso8601String(),
    'done': done,
    'priority': priority,
  };

  factory TodoItem.fromJson(Map<String, dynamic> j) => TodoItem(
    id: j['id'] as int,
    title: j['title'] as String,
    description: j['description'] as String?,
    dueDateTime: j['dueDateTime'] != null
        ? DateTime.parse(j['dueDateTime'] as String)
        : null,
    done: j['done'] as bool? ?? false,
    priority: j['priority'] as String? ?? 'medium',
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});
  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<TodoItem> _todos = [];
  String _filter = 'all'; // 'all' | 'pending' | 'done'

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Persistence ──────────────────────────────────────────────────────────
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('todos') ?? '[]';
    final list = jsonDecode(raw) as List;
    if (mounted)
      setState(() => _todos = list.map((e) => TodoItem.fromJson(e)).toList());
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'todos',
      jsonEncode(_todos.map((t) => t.toJson()).toList()),
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  Future<void> _scheduleReminder(TodoItem todo) async {
    if (todo.dueDateTime == null) return;
    final remind = todo.dueDateTime!.subtract(const Duration(minutes: 10));
    if (remind.isBefore(DateTime.now())) return;

    final delay = remind.difference(DateTime.now());
    Future.delayed(delay, () async {
      if (!mounted) return;
      // Check if still pending
      final t = _todos.firstWhere((x) => x.id == todo.id, orElse: () => todo);
      if (t.done) return;
      await _notif.show(
        todo.id,
        '⏰ Task Due Soon',
        '"${todo.title}" is due in 10 minutes!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'todo_channel',
            'To-Do Reminders',
            channelDescription: 'Reminders for your to-do tasks',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });
  }

  Future<void> _cancelReminder(int id) async {
    await _notif.cancel(id);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────
  void _addOrEdit({TodoItem? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime? picked = existing?.dueDateTime;
    String priority = existing?.priority ?? 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'Add Task' : 'Edit Task',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Task title *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Due date/time picker
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: picked ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null) return;
                  final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(
                      picked ?? DateTime.now(),
                    ),
                  );
                  if (time == null) return;
                  setSheet(
                    () => picked = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Color(0xFF1565C0),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        picked == null
                            ? 'Set due date & time'
                            : '${picked!.day}/${picked!.month}/${picked!.year}  ${picked!.hour.toString().padLeft(2, '0')}:${picked!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: picked == null
                              ? Colors.grey[600]
                              : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (picked != null)
                        GestureDetector(
                          onTap: () => setSheet(() => picked = null),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Priority
              Row(
                children: [
                  const Text(
                    'Priority:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  ...['low', 'medium', 'high'].map((p) {
                    final colors = {
                      'low': const Color(0xFF2E7D32),
                      'medium': const Color(0xFFF57C00),
                      'high': Colors.red,
                    };
                    final selected = priority == p;
                    return GestureDetector(
                      onTap: () => setSheet(() => priority = p),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors[p]
                              : colors[p]!.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors[p]!.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          p[0].toUpperCase() + p.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : colors[p],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    if (existing != null) {
                      await _cancelReminder(existing.id);
                      setState(() {
                        existing.title = titleCtrl.text.trim();
                        existing.description = descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim();
                        existing.dueDateTime = picked;
                        existing.priority = priority;
                      });
                      await _scheduleReminder(existing);
                    } else {
                      final todo = TodoItem(
                        id: DateTime.now().millisecondsSinceEpoch % 100000,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? null
                            : descCtrl.text.trim(),
                        dueDateTime: picked,
                        priority: priority,
                      );
                      setState(() => _todos.insert(0, todo));
                      await _scheduleReminder(todo);
                    }
                    await _save();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    existing == null ? 'Add Task' : 'Save Changes',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleDone(TodoItem todo) async {
    setState(() => todo.done = !todo.done);
    if (todo.done) await _cancelReminder(todo.id);
    await _save();
  }

  Future<void> _delete(TodoItem todo) async {
    await _cancelReminder(todo.id);
    setState(() => _todos.remove(todo));
    await _save();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _priorityColor(String p) => p == 'high'
      ? Colors.red
      : p == 'medium'
      ? const Color(0xFFF57C00)
      : const Color(0xFF2E7D32);

  String _formatDue(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.isNegative) return 'Overdue · $timeStr';
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes}m · $timeStr';
    if (diff.inHours < 24) return 'In ${diff.inHours}h · $timeStr';
    return '${dt.day}/${dt.month}  $timeStr';
  }

  List<TodoItem> get _filtered {
    switch (_filter) {
      case 'pending':
        return _todos.where((t) => !t.done).toList();
      case 'done':
        return _todos.where((t) => t.done).toList();
      default:
        return _todos;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _todos.where((t) => !t.done).length;
    final done = _todos.where((t) => t.done).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_todos.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear Completed'),
                    content: const Text('Remove all completed tasks?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  for (final t in _todos.where((t) => t.done).toList()) {
                    await _cancelReminder(t.id);
                  }
                  setState(() => _todos.removeWhere((t) => t.done));
                  await _save();
                }
              },
              child: const Text('Clear done'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          if (_todos.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF283593)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _summaryChip('Pending', pending, Colors.orange),
                  const SizedBox(width: 12),
                  _summaryChip('Done', done, Colors.green),
                  const Spacer(),
                  Text(
                    '${(done / _todos.length * 100).round()}% complete',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _chip('All', 'all'),
                const SizedBox(width: 8),
                _chip('Pending', 'pending'),
                const SizedBox(width: 8),
                _chip('Done', 'done'),
              ],
            ),
          ),
          // List
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _filter == 'done'
                              ? 'No completed tasks yet'
                              : 'No tasks yet. Add one!',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _TodoCard(
                      todo: _filtered[i],
                      priorityColor: _priorityColor(_filtered[i].priority),
                      formatDue: _formatDue,
                      onToggle: () => _toggleDone(_filtered[i]),
                      onEdit: () => _addOrEdit(existing: _filtered[i]),
                      onDelete: () => _delete(_filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$count $label',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    ],
  );

  Widget _chip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1565C0) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

// ── Task card ─────────────────────────────────────────────────────────────────
class _TodoCard extends StatelessWidget {
  final TodoItem todo;
  final Color priorityColor;
  final String Function(DateTime) formatDue;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TodoCard({
    required this.todo,
    required this.priorityColor,
    required this.formatDue,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue =
        todo.dueDateTime != null &&
        todo.dueDateTime!.isBefore(DateTime.now()) &&
        !todo.done;

    return Dismissible(
      key: Key('todo_${todo.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: priorityColor, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          leading: GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.done ? const Color(0xFF2E7D32) : Colors.transparent,
                border: Border.all(
                  color: todo.done
                      ? const Color(0xFF2E7D32)
                      : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: todo.done
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              decoration: todo.done ? TextDecoration.lineThrough : null,
              color: todo.done ? Colors.grey[400] : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (todo.description != null && todo.description!.isNotEmpty)
                Text(
                  todo.description!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (todo.dueDateTime != null)
                Row(
                  children: [
                    Icon(
                      isOverdue ? Icons.warning_amber : Icons.access_time,
                      size: 12,
                      color: isOverdue ? Colors.red : Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatDue(todo.dueDateTime!),
                      style: TextStyle(
                        fontSize: 11,
                        color: isOverdue ? Colors.red : Colors.grey[500],
                        fontWeight: isOverdue
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  todo.priority[0].toUpperCase() + todo.priority.substring(1),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: priorityColor,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
