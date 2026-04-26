import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

// ── Message model ─────────────────────────────────────────────────────────────
class _Msg {
  final String text;
  final bool isUser;
  final String? source; // 'openai' | 'cloudflare' | 'action' | null

  _Msg(this.text, {required this.isUser, this.source});
}

// ── Suggested prompts ─────────────────────────────────────────────────────────
const _suggestions = [
  '💼  How to prepare for interviews?',
  '📄  Tips for building a strong resume',
  '🎓  Best skills for CSE students?',
  '🤝  How to find a good mentor?',
  '🚀  Top internship tips for freshers',
];

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

  @override
  void initState() {
    super.initState();
    _messages.add(_Msg(
      "Hi! I'm your Smart Career Assistant 🤖\n\n"
      "I can help with career guidance, internships, resume tips, "
      "interview prep, and more. What would you like to know?",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _loading) return;
    _ctrl.clear();

    setState(() {
      _messages.add(_Msg(msg, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    final user = Provider.of<AuthProvider>(context, listen: false).user;

    // Build history (skip welcome, exclude last user msg)
    final history = _messages
        .skip(1)
        .where((m) => _messages.indexOf(m) < _messages.length - 1)
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    try {
      final res = await ApiService().post('/ai/chat', {
        'message': msg,
        'role': user?.role ?? 'student',
        'user_id': user?.userId,
        'department': user?.department,
        'skills': user?.skills ?? user?.interests,
        'history': history,
      });

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body   = jsonDecode(res.body);
        final reply  = body['reply'] as String;
        final source = body['source'] as String?;
        setState(() => _messages.add(_Msg(reply, isUser: false, source: source)));
      } else {
        final detail = jsonDecode(res.body)['detail'] as String? ?? 'AI is temporarily unavailable.';
        setState(() => _messages.add(_Msg('⚠️ $detail', isUser: false)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _messages.add(_Msg(
          'Could not reach the AI assistant. Check your connection.',
          isUser: false,
        )));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
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

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(_Msg(
        "Hi! I'm your Smart Career Assistant 🤖\n\n"
        "I can help with career guidance, internships, resume tips, "
        "interview prep, and more. What would you like to know?",
        isUser: false,
      ));
    });
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
            child: Icon(Icons.auto_awesome, size: 18, color: theme.primaryColor),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Career Assistant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text('Powered by - Cloudflare', style: TextStyle(fontSize: 08)),
          ]),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), tooltip: 'Clear chat', onPressed: _clearChat),
        ],
      ),
      body: Column(children: [
        // ── Message list ────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            itemCount: _messages.length
                + (showSuggestions ? 1 : 0)
                + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (showSuggestions && i == 1) return _buildSuggestions();
              final idx = showSuggestions && i > 1 ? i - 1 : i;
              if (_loading && idx == _messages.length) return _buildTypingIndicator();
              if (idx >= _messages.length) return const SizedBox.shrink();
              return _buildBubble(_messages[idx]);
            },
          ),
        ),

        // ── Input bar ───────────────────────────────────────────────────────
        Container(
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
                  hintText: 'Ask me anything about your career...',
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
        ),
      ]),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildBubble(_Msg msg) {
    final theme  = Theme.of(context);
    final isUser = msg.isUser;

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
          // Source badge for AI messages
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

  Widget _sourceBadge(String source) {
    final theme = Theme.of(context);
    final (label, icon, color) = switch (source) {
      'cloudflare'          => ('Cloudflare AI', Icons.bolt_outlined, Colors.orange),
      'cloudflare_fallback' => ('Cloudflare AI', Icons.bolt_outlined, Colors.orange),
      'action'              => ('Action', Icons.check_circle_outline, theme.primaryColor),
      _                     => ('AI', Icons.auto_awesome, theme.primaryColor),
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _dot(0), _dot(200), _dot(400),
        ]),
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

  Widget _buildSuggestions() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Try asking:', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _suggestions.map((s) => GestureDetector(
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