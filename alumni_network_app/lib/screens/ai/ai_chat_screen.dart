import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Message types ─────────────────────────────────────────────────────────────
enum _MsgType { user, ai, confirm }

class _Msg {
  final String text;
  final _MsgType type;
  final String? source;
  final Map<String, dynamic>? action;

  _Msg(this.text, {required this.type, this.source, this.action});

  Map<String, dynamic> toJson() => {'text': text, 'type': type.name, 'source': source};

  static _Msg fromJson(Map<String, dynamic> j) => _Msg(
    j['text'] as String,
    type: j['type'] == 'user' ? _MsgType.user : _MsgType.ai,
    source: j['source'] as String?,
  );
}

// ── Role-based config ─────────────────────────────────────────────────────────
String _welcomeForRole(String role, String name) {
  switch (role.toLowerCase()) {
    case 'alumni':
      return "Hi $name! 👋 I'm your Alumni Assistant 🤖\n\n"
          "I can help you with:\n"
          "• Manage your mentorship slots\n"
          "• View your posted internships\n"
          "• Connect with students\n"
          "• Update your profile\n\n"
          "What do you need?";
    case 'admin':
      return "Hi $name! 👋 I'm your Admin Assistant 🤖\n\n"
          "I can help you with:\n"
          "• View app statistics\n"
          "• Manage users & events\n"
          "• Send messages to users\n"
          "• App management guidance\n\n"
          "What do you need?";
    default:
      return "Hi $name! 👋 I'm your Career Assistant 🤖\n\n"
          "I can help you with:\n"
          "• Apply for internships\n"
          "• Book mentorship sessions\n"
          "• Create tasks & reminders\n"
          "• Career guidance & tips\n\n"
          "What do you need?";
  }
}

List<String> _suggestionsForRole(String role) {
  switch (role.toLowerCase()) {
    case 'alumni':
      return [
        '🎓  Show my mentorship slots',
        '💼  Show my posted internships',
        '🤝  List my connections',
        '👤  Show my profile',
        '📨  Send message to a student',
        '📋  Create a task',
      ];
    case 'admin':
      return [
        '📊  Show app statistics',
        '👤  Show my profile',
        '📨  Send message to a user',
        '📋  Create a task',
        '📅  How to post an event?',
        '🔔  How to send notifications?',
      ];
    default:
      return [
        '💬  Send message to an alumni',
        '📋  Create a task for tomorrow',
        '🎓  Book a mentorship session',
        '💼  Show open internships',
        '🤝  List my connections',
        '📄  How to upload my resume?',
      ];
  }
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _loading = false;

  static const _storageKey = 'ai_agent_chat_history';

  String get _userRole => Provider.of<AuthProvider>(context, listen: false).user?.role ?? 'student';
  String get _userName => Provider.of<AuthProvider>(context, listen: false).user?.fullName.split(' ').first ?? 'there';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => _Msg.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          setState(() => _messages.addAll(list));
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          return;
        }
      } catch (_) {}
    }
    setState(() => _messages.add(_Msg(_welcomeForRole(_userRole, _userName), type: _MsgType.ai)));
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // Only persist user + ai messages (skip confirm bubbles)
    final toSave = _messages
        .where((m) => m.type != _MsgType.confirm)
        .map((m) => m.toJson())
        .toList();
    await prefs.setString(_storageKey, jsonEncode(toSave));
  }

  @override
  void dispose() {
    _saveHistory();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Send message ──────────────────────────────────────────────────────────
  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _loading) return;

    // Intercept "clear" keyword
    if (msg.toLowerCase() == 'clear') {
      _ctrl.clear();
      _showClearConfirm();
      return;
    }

    _ctrl.clear();

    setState(() {
      _messages.add(_Msg(msg, type: _MsgType.user));
      _loading = true;
    });
    _scrollToBottom();

    final history = _messages
        .where((m) => m.type != _MsgType.confirm)
        .skip(1)
        .where((m) => _messages.indexOf(m) < _messages.length - 1)
        .map((m) => {'role': m.type == _MsgType.user ? 'user' : 'assistant', 'content': m.text})
        .toList();

    try {
      final res = await ApiService().post('/ai/agent', {
        'message': msg,
        'history': history,
      });

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body   = jsonDecode(res.body);
        final reply  = body['reply'] as String;
        final source = body['source'] as String?;
        final action = body['action'] as Map<String, dynamic>?;

        // Detect raw JSON action leaked through as plain text
        final leakedAction = _tryParseLeakedAction(reply);

        if (source == 'confirm_needed' && action != null) {
          setState(() => _messages.add(_Msg(reply, type: _MsgType.confirm, source: source, action: action)));
        } else if (leakedAction != null) {
          final tool = leakedAction['tool'] as String? ?? '';
          final args = (leakedAction['args'] as Map<String, dynamic>?) ?? {};
          final confirmMsg = leakedAction['confirm_message'] as String? ?? 'Perform action: $tool?';
          setState(() => _messages.add(_Msg(confirmMsg, type: _MsgType.confirm, source: 'confirm_needed',
              action: {'tool': tool, 'args': args})));
        } else {
          // If backend executed a task action directly, sync to local storage
          if (source == 'action_executed' && body['executed_tool'] == 'create_task') {
            final executedArgs = (body['executed_args'] as Map<String, dynamic>?) ?? {};
            await _saveTaskLocally(executedArgs);
          }
          setState(() => _messages.add(_Msg(reply, type: _MsgType.ai, source: source)));
        }      } else {
        final detail = jsonDecode(res.body)['detail'] as String? ?? 'AI is temporarily unavailable.';
        setState(() => _messages.add(_Msg('⚠️ $detail', type: _MsgType.ai)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _messages.add(_Msg(
          'Could not reach the AI agent. Check your connection.',
          type: _MsgType.ai,
        )));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
      _saveHistory();
    }
  }

  // ── Execute confirmed action ───────────────────────────────────────────────
  Future<void> _executeAction(Map<String, dynamic> action) async {
    setState(() => _loading = true);
    _scrollToBottom();

    try {
      final res = await ApiService().post('/ai/agent', {
        'message': '',
        'confirmed': true,
        'pending_action': action,
      });

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body  = jsonDecode(res.body);
        final reply = body['reply'] as String;
        // If it was a task creation, also write to local SharedPreferences
        if (action['tool'] == 'create_task' || action['tool'] == 'create_weekly_goal') {
          final taskArgs = Map<String, dynamic>.from(action['args'] as Map? ?? {});
          if (action['tool'] == 'create_weekly_goal') {
            // Convert weekly goal args to task format
            final now = DateTime.now();
            final daysUntilSunday = (7 - now.weekday) % 7 == 0 ? 7 : (7 - now.weekday) % 7;
            taskArgs['title'] = taskArgs['goal'] ?? 'Weekly Goal';
            taskArgs['due_date'] = now.add(Duration(days: daysUntilSunday)).toIso8601String().split('T')[0];
            taskArgs['priority'] = 'medium';
          }
          await _saveTaskLocally(taskArgs);
        }
        setState(() => _messages.add(_Msg(reply, type: _MsgType.ai, source: 'action_executed')));
      } else {
        setState(() => _messages.add(_Msg('⚠️ Action failed. Please try again.', type: _MsgType.ai)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _messages.add(_Msg('Could not execute action. Check your connection.', type: _MsgType.ai)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
      _saveHistory();
    }
  }

  Future<void> _saveTaskLocally(Map<String, dynamic> args) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('todos') ?? '[]';
    final List todos = jsonDecode(raw);

    // Parse due date
    String? dueIso;
    final dueRaw = (args['due_date'] as String? ?? '').toLowerCase();
    if (dueRaw == 'tomorrow') {
      dueIso = DateTime.now().add(const Duration(days: 1))
          .copyWith(hour: 9, minute: 0, second: 0, millisecond: 0)
          .toIso8601String();
    } else if (dueRaw == 'today') {
      dueIso = DateTime.now()
          .copyWith(hour: 23, minute: 59, second: 0, millisecond: 0)
          .toIso8601String();
    } else if (dueRaw.isNotEmpty) {
      try {
        dueIso = DateTime.parse(dueRaw)
            .copyWith(hour: 9, minute: 0)
            .toIso8601String();
      } catch (_) {}
    }

    final newTask = {
      'id': DateTime.now().millisecondsSinceEpoch % 100000,
      'title': args['title'] ?? 'Task',
      'description': null,
      'dueDateTime': dueIso,
      'done': false,
      'priority': args['priority'] ?? 'medium',
    };

    todos.insert(0, newTask);
    await prefs.setString('todos', jsonEncode(todos));
  }

  // ── Detect raw JSON action leaked in AI reply ─────────────────────────────
  Map<String, dynamic>? _tryParseLeakedAction(String text) {
    try {
      final trimmed = text.trim();
      if (!trimmed.contains('"tool"')) return null;
      // Find JSON object in text
      final start = trimmed.indexOf('{');
      final end   = trimmed.lastIndexOf('}');
      if (start == -1 || end == -1) return null;
      final parsed = jsonDecode(trimmed.substring(start, end + 1)) as Map<String, dynamic>;
      if (parsed.containsKey('tool')) {
        // Normalize common key variations
        final args = (parsed['args'] as Map<String, dynamic>?) ?? {};
        if (parsed['tool'] == 'send_message') {
          if (args.containsKey('name') && !args.containsKey('receiver_name')) {
            args['receiver_name'] = args.remove('name');
          }
          if (args.containsKey('text') && !args.containsKey('message')) {
            args['message'] = args.remove('text');
          }
        }
        parsed['args'] = args;
        return parsed;
      }
    } catch (_) {}
    return null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showClearConfirm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('This will clear the current chat screen. Your history will still be saved and accessible from the History option.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearScreen();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _clearScreen() {
    setState(() {
      _messages.clear();
      _messages.add(_Msg(_welcomeForRole(_userRole, _userName), type: _MsgType.ai));
    });
  }


  void _openHistory() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _ChatHistoryScreen(storageKey: _storageKey)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showSuggestions = _messages.length == 1;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
            child: Icon(Icons.smart_toy_rounded, size: 18, color: theme.primaryColor),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Career Assistant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text('Powered by Cloudflare AI', style: TextStyle(fontSize: 10)),
          ]),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'history') _openHistory();
              if (val == 'clear') _showClearConfirm();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'history', child: Row(children: [
                Icon(Icons.history, size: 18),
                SizedBox(width: 10),
                Text('Chat History'),
              ])),
              PopupMenuItem(value: 'clear', child: Row(children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                SizedBox(width: 10),
                Text('Clear Chat', style: TextStyle(color: Colors.red)),
              ])),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            itemCount: _messages.length + (showSuggestions ? 1 : 0) + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (showSuggestions && i == 1) return _buildSuggestions();
              final idx = showSuggestions && i > 1 ? i - 1 : i;
              if (_loading && idx == _messages.length) return _buildTypingIndicator();
              if (idx >= _messages.length) return const SizedBox.shrink();
              final m = _messages[idx];
              if (m.type == _MsgType.confirm) return _buildConfirmBubble(m);
              return _buildBubble(m);
            },
          ),
        ),
        _buildInputBar(theme),
      ]),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildBubble(_Msg msg) {
    final theme  = Theme.of(context);
    final isUser = msg.type == _MsgType.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser ? theme.primaryColor : theme.cardColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : theme.textTheme.bodyMedium?.color,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          if (!isUser && msg.source != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: _sourceBadge(msg.source!),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildConfirmBubble(_Msg msg) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18), topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.bolt_rounded, size: 14, color: theme.primaryColor),
            const SizedBox(width: 4),
            Text('Action Required', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.primaryColor)),
          ]),
          const SizedBox(height: 8),
          Text(msg.text, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color, height: 1.4)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _messages.add(_Msg('❌ Action cancelled.', type: _MsgType.ai)));
                  _scrollToBottom();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _executeAction(msg.action!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('Confirm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _sourceBadge(String source) {
    final theme = Theme.of(context);
    final (label, icon, color) = switch (source) {
      'cloudflare'       => ('Cloudflare AI', Icons.bolt_outlined, Colors.orange),
      'action_executed'  => ('Action Done', Icons.check_circle_outline, Colors.green),
      'confirm_needed'   => ('Needs Confirmation', Icons.bolt_rounded, theme.primaryColor),
      'action'           => ('Action', Icons.check_circle_outline, theme.primaryColor),
      'guide'            => ('App Guide', Icons.menu_book_outlined, Colors.teal),
      _                  => ('AI', Icons.smart_toy_rounded, theme.primaryColor),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildTypingIndicator() {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18), topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [_dot(0), _dot(200), _dot(400)]),
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            maxLines: 4,
            minLines: 1,
            textInputAction: TextInputAction.send,
            onSubmitted: _send,
            decoration: InputDecoration(
              hintText: 'Ask me anything or give a command...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: theme.primaryColor,
          child: IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            onPressed: () => _send(_ctrl.text),
          ),
        ),
      ]),
    );
  }

  Widget _buildSuggestions() {
    final theme = Theme.of(context);
    final suggestions = _suggestionsForRole(_userRole);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Try asking:', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: suggestions.map((s) => GestureDetector(
            onTap: () => _send(s.replaceAll(RegExp(r'^[^\w]+'), '').trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.primaryColor.withValues(alpha: 0.25)),
              ),
              child: Text(s, style: TextStyle(fontSize: 12, color: theme.primaryColor, fontWeight: FontWeight.w500)),
            ),
          )).toList(),
        ),
      ]),
    );
  }
}

// ── Chat History Screen ───────────────────────────────────────────────────────
class _ChatHistoryScreen extends StatefulWidget {
  final String storageKey;
  const _ChatHistoryScreen({required this.storageKey});

  @override
  State<_ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<_ChatHistoryScreen> {
  List<_Msg> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(widget.storageKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => _Msg.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() { _history = list; _loading = false; });
        return;
      } catch (_) {}
    }
    setState(() => _loading = false);
  }

  Future<void> _deleteHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete History'),
        content: const Text('This will permanently delete all chat history. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(widget.storageKey);
      setState(() => _history = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete all history',
              onPressed: _deleteHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.history, size: 64, color: theme.dividerColor),
                    const SizedBox(height: 12),
                    Text('No history yet', style: theme.textTheme.bodySmall?.copyWith(fontSize: 15)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: _history.length,
                  itemBuilder: (_, i) {
                    final m = _history[i];
                    final isUser = m.type == _MsgType.user;
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser ? theme.primaryColor : theme.cardColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isUser ? 18 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 18),
                          ),
                        ),
                        child: Text(
                          m.text,
                          style: TextStyle(
                            color: isUser ? Colors.white : theme.textTheme.bodyMedium?.color,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
