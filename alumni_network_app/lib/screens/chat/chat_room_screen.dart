import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../directory/profile_detail.dart';

// ── Wallpaper options ─────────────────────────────────────────────────────────
class _WallpaperOption {
  final String id;
  final String label;
  final Color? solidColor;
  final List<Color>? gradientColors;

  const _WallpaperOption({
    required this.id,
    required this.label,
    this.solidColor,
    this.gradientColors,
  });
}

final _wallpapers = [
  _WallpaperOption(id: 'default', label: 'Default', solidColor: null),
  _WallpaperOption(id: 'midnight', label: 'Midnight', gradientColors: [const Color(0xFF0F172A), const Color(0xFF1E293B)]),
  _WallpaperOption(id: 'ocean', label: 'Ocean', gradientColors: [const Color(0xFF0077B6), const Color(0xFF00B4D8)]),
  _WallpaperOption(id: 'forest', label: 'Forest', gradientColors: [const Color(0xFF1B4332), const Color(0xFF40916C)]),
  _WallpaperOption(id: 'sunset', label: 'Sunset', gradientColors: [const Color(0xFFFF6B6B), const Color(0xFFFFE66D)]),
  _WallpaperOption(id: 'purple', label: 'Purple', gradientColors: [const Color(0xFF6A0572), const Color(0xFFAB83A1)]),
  _WallpaperOption(id: 'rose', label: 'Rose', gradientColors: [const Color(0xFFFF9A9E), const Color(0xFFFECFEF)]),
  _WallpaperOption(id: 'slate', label: 'Slate', solidColor: const Color(0xFF334155)),
  _WallpaperOption(id: 'teal', label: 'Teal', solidColor: const Color(0xFF0D9488)),
  _WallpaperOption(id: 'charcoal', label: 'Charcoal', solidColor: const Color(0xFF1C1C1E)),
];

class ChatRoomScreen extends StatefulWidget {
  final User otherUser;
  const ChatRoomScreen({super.key, required this.otherUser});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ApiService _apiService = ApiService();
  final _messageController = TextEditingController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isMessagingLocked = false;
  String? _lockReason;
  int? _editingMessageId;
  final Set<int> _selectedMessages = {};
  String _wallpaperId = 'default';
  Uint8List? _customImageBytes; // bytes work on both web and mobile

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _loadWallpaper();
  }

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('chat_wallpaper_${widget.otherUser.userId}') ?? 'default';
    // Load stored base64 image bytes if any
    final b64 = prefs.getString('chat_wallpaper_img_${widget.otherUser.userId}');
    Uint8List? bytes;
    if (b64 != null) {
      try { bytes = base64Decode(b64); } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _wallpaperId = saved;
        _customImageBytes = bytes;
      });
    }
  }

  Future<void> _saveWallpaper(String id, {Uint8List? imageBytes}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_wallpaper_${widget.otherUser.userId}', id);
    if (imageBytes != null) {
      // Store as base64 so it persists across sessions
      await prefs.setString('chat_wallpaper_img_${widget.otherUser.userId}', base64Encode(imageBytes));
    } else {
      await prefs.remove('chat_wallpaper_img_${widget.otherUser.userId}');
    }
    setState(() {
      _wallpaperId = id;
      _customImageBytes = imageBytes;
    });
  }

  Future<void> _pickCustomWallpaper() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // always load bytes — works on web + mobile
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      await _saveWallpaper('custom', imageBytes: bytes);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showWallpaperPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              Text('Chat Wallpaper', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              // Custom image from device button
              GestureDetector(
                onTap: _pickCustomWallpaper,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _wallpaperId == 'custom'
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _wallpaperId == 'custom'
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).dividerColor,
                      width: _wallpaperId == 'custom' ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    // Preview thumbnail if custom image is set
                    if (_wallpaperId == 'custom' && _customImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_customImageBytes!, width: 44, height: 44, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.add_photo_alternate_outlined, color: Theme.of(context).primaryColor, size: 24),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Choose from Device',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text('Pick any photo from your gallery',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                      ]),
                    ),
                    if (_wallpaperId == 'custom')
                      Icon(Icons.check_circle, color: Theme.of(context).primaryColor, size: 20),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Text('Presets', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85,
                ),
                itemCount: _wallpapers.length,
                itemBuilder: (_, i) {
                  final w = _wallpapers[i];
                  final isSelected = _wallpaperId == w.id;
                  return GestureDetector(
                    onTap: () {
                      _saveWallpaper(w.id);
                      setSheet(() {});
                      Navigator.pop(ctx);
                    },
                    child: Column(children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: w.solidColor ?? (w.gradientColors == null ? Theme.of(context).scaffoldBackgroundColor : null),
                          gradient: w.gradientColors != null
                              ? LinearGradient(colors: w.gradientColors!, begin: Alignment.topLeft, end: Alignment.bottomRight)
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: w.gradientColors != null || w.solidColor != null ? Colors.white : Theme.of(context).primaryColor, size: 22)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(w.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10), overflow: TextOverflow.ellipsis),
                    ]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _wallpaperDecoration() {
    // Custom image from device — use MemoryImage (works on web + mobile)
    if (_wallpaperId == 'custom' && _customImageBytes != null) {
      return BoxDecoration(
        image: DecorationImage(
          image: MemoryImage(_customImageBytes!),
          fit: BoxFit.cover,
        ),
      );
    }
    final w = _wallpapers.firstWhere((e) => e.id == _wallpaperId, orElse: () => _wallpapers.first);
    if (w.gradientColors != null) {
      return BoxDecoration(
        gradient: LinearGradient(colors: w.gradientColors!, begin: Alignment.topCenter, end: Alignment.bottomCenter),
      );
    }
    if (w.solidColor != null) {
      return BoxDecoration(color: w.solidColor);
    }
    return BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor);
  }

  bool get _hasCustomWallpaper =>
      _wallpaperId != 'default' && _wallpaperId != 'rose';

  Future<void> _fetchMessages() async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    if (currentUser == null) return;

    try {
      final response = await _apiService.get('/messages?user_id=${currentUser.userId}&other_user_id=${widget.otherUser.userId}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _messages = data.map((json) => Message.fromJson(json)).toList();
          _isLoading = false;
          _isMessagingLocked = false;
          _lockReason = null;
        });
        _apiService.patch('/messages/mark-read?sender_id=${widget.otherUser.userId}', {});
      } else if (response.statusCode == 403) {
        final detail = jsonDecode(response.body)['detail'] as String?;
        setState(() {
          _messages = [];
          _isLoading = false;
          _isMessagingLocked = true;
          _lockReason = detail ?? 'Messaging is locked for this chat';
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Fetch messages error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty || _isMessagingLocked) return;
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    final content = _messageController.text;
    if (_editingMessageId != null) { _updateMessage(); return; }
    _messageController.clear();
    try {
      final response = await _apiService.post('/messages', {
        'sender_id': currentUser!.userId,
        'receiver_id': widget.otherUser.userId,
        'content': content,
      });
      if (response.statusCode == 200) {
        _fetchMessages();
      } else if (response.statusCode == 403) {
        final detail = jsonDecode(response.body)['detail'] as String?;
        if (mounted) {
          setState(() { _isMessagingLocked = true; _lockReason = detail ?? 'Messaging is locked'; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_lockReason!)));
        }
      }
    } catch (e) { debugPrint('Send message error: $e'); }
  }

  void _updateMessage() async {
    final content = _messageController.text;
    final msgId = _editingMessageId;
    setState(() { _editingMessageId = null; _messageController.clear(); });
    try {
      final response = await _apiService.patch('/messages/$msgId', {'content': content});
      if (response.statusCode == 200) {
        _fetchMessages();
      } else if (mounted) {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err['detail'] ?? 'Update failed')));
      }
    } catch (e) { debugPrint('Update message error: $e'); }
  }

  void _deleteMessage(int msgId) async {
    try {
      final response = await _apiService.delete('/messages/$msgId');
      if (response.statusCode == 200) {
        _fetchMessages();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message deleted')));
      }
    } catch (e) { debugPrint('Delete message error: $e'); }
  }

  void _bulkDeleteMessages() async {
    final ids = _selectedMessages.toList();
    if (ids.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.post('/messages/bulk-delete', ids);
      if (response.statusCode == 200) {
        _selectedMessages.clear();
        _fetchMessages();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected messages deleted')));
      }
    } catch (e) { debugPrint('Bulk delete error: $e'); setState(() => _isLoading = false); }
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat?'),
        content: const Text('This will delete all messages in this conversation. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () { Navigator.pop(context); _clearChat(); },
            child: Text('CLEAR', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _clearChat() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.delete('/messages/clear?other_user_id=${widget.otherUser.userId}');
      if (response.statusCode == 200) {
        _fetchMessages();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cleared')));
      }
    } catch (e) { debugPrint('Clear chat error: $e'); setState(() => _isLoading = false); }
  }

  void _startEdit(Message msg) {
    setState(() { _editingMessageId = msg.messageId; _messageController.text = msg.content; });
  }

  bool _canEdit(Message msg) => DateTime.now().toUtc().difference(msg.sentAt).inMinutes < 5;
  bool _canDelete(Message msg) => DateTime.now().toUtc().difference(msg.sentAt).inHours < 24;

  void _toggleSelection(int msgId) {
    setState(() {
      if (_selectedMessages.contains(msgId)) { _selectedMessages.remove(msgId); }
      else { _selectedMessages.add(msgId); }
    });
  }

  String _formatIstTime(DateTime utcTime) {
    final ist = utcTime.add(const Duration(hours: 5, minutes: 30));
    return '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')} IST';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).user;
    final isSelectionMode = _selectedMessages.isNotEmpty;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: theme.primaryColor,
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedMessages.clear())),
              title: Text('${_selectedMessages.length} Selected', style: const TextStyle(color: Colors.white)),
              actions: [IconButton(icon: const Icon(Icons.delete), onPressed: _bulkDeleteMessages)],
            )
          : AppBar(
              title: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileDetailScreen(user: widget.otherUser))),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: (widget.otherUser.profilePictureUrl != null && widget.otherUser.profilePictureUrl!.isNotEmpty)
                        ? NetworkImage(widget.otherUser.profilePictureUrl!.startsWith('http')
                            ? widget.otherUser.profilePictureUrl!
                            : '${ApiService.baseUrl}${widget.otherUser.profilePictureUrl}')
                        : null,
                    child: (widget.otherUser.profilePictureUrl == null || widget.otherUser.profilePictureUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 20) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.otherUser.fullName, style: const TextStyle(fontSize: 18))),
                ]),
              ),
              actions: [
                IconButton(icon: const Icon(Icons.call, size: 20), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio call not implemented')))),
                IconButton(icon: const Icon(Icons.videocam, size: 20), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video call not implemented')))),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'clear') _confirmClearChat();
                    else if (value == 'profile') Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileDetailScreen(user: widget.otherUser)));
                    else if (value == 'wallpaper') _showWallpaperPicker();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'profile', child: Text('View Profile')),
                    PopupMenuItem(value: 'wallpaper', child: Row(children: [Icon(Icons.wallpaper, size: 18), SizedBox(width: 10), Text('Wallpaper')])),
                    PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
                  ],
                ),
              ],
            ),
      body: Container(
        decoration: _wallpaperDecoration(),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: _hasCustomWallpaper ? Colors.white54 : theme.iconTheme.color?.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text('No messages yet\nSay hello! 👋',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15, color: _hasCustomWallpaper ? Colors.white70 : theme.textTheme.bodySmall?.color)),
                          ]),
                        )
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final actualMsg = _messages[_messages.length - 1 - index];
                            final isMe = actualMsg.senderId == currentUser?.userId;
                            final isSelected = _selectedMessages.contains(actualMsg.messageId);

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: isSelectionMode ? () => _toggleSelection(actualMsg.messageId) : null,
                                onLongPress: isMe ? () {
                                  if (isSelectionMode) {
                                    _toggleSelection(actualMsg.messageId);
                                  } else {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
                                        ListTile(
                                          leading: Icon(Icons.check_box_outlined, color: theme.primaryColor),
                                          title: const Text('Select Message'),
                                          onTap: () { Navigator.pop(context); _toggleSelection(actualMsg.messageId); },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.edit, color: Colors.teal),
                                          title: const Text('Edit Message'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            if (_canEdit(actualMsg)) { _startEdit(actualMsg); }
                                            else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit after 5 minutes'), duration: Duration(seconds: 2))); }
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.delete, color: Colors.red),
                                          title: const Text('Delete Message'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            if (_canDelete(actualMsg)) { _deleteMessage(actualMsg.messageId); }
                                            else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete after 24 hours'), duration: Duration(seconds: 2))); }
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                      ]),
                                    );
                                  }
                                } : null,
                                child: Stack(children: [
                                  Container(
                                    margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.primaryColor.withValues(alpha: 0.3)
                                          : isMe
                                              ? theme.primaryColor
                                              : _hasCustomWallpaper
                                                  ? Colors.white.withValues(alpha: 0.15)
                                                  : theme.cardColor,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isMe ? 16 : 2),
                                        bottomRight: Radius.circular(isMe ? 2 : 16),
                                      ),
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          actualMsg.content,
                                          style: TextStyle(
                                            color: isMe || _hasCustomWallpaper ? Colors.white : theme.textTheme.bodyMedium?.color,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _formatIstTime(actualMsg.sentAt),
                                          style: TextStyle(
                                            color: isMe || _hasCustomWallpaper ? Colors.white60 : theme.textTheme.bodySmall?.color,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      right: isMe ? 2 : null,
                                      left: !isMe ? 2 : null,
                                      top: 0, bottom: 0,
                                      child: Icon(Icons.check_circle, color: theme.primaryColor, size: 20),
                                    ),
                                ]),
                              ),
                            );
                          },
                        ),
            ),
            // Editing banner
            if (_editingMessageId != null)
              Container(
                color: theme.primaryColor.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Icon(Icons.edit, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Editing...', style: TextStyle(fontStyle: FontStyle.italic, color: theme.primaryColor))),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: theme.iconTheme.color),
                    onPressed: () => setState(() { _editingMessageId = null; _messageController.clear(); }),
                  ),
                ]),
              ),
            // Input bar
            if (!isSelectionMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _hasCustomWallpaper ? Colors.black.withValues(alpha: 0.3) : theme.cardColor,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: _isMessagingLocked
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(children: [
                          Icon(Icons.lock_outline, color: theme.iconTheme.color?.withValues(alpha: 0.6), size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_lockReason ?? 'Messaging is locked for this chat', style: theme.textTheme.bodySmall)),
                        ]),
                      )
                    : Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(color: _hasCustomWallpaper ? Colors.white : theme.textTheme.bodyMedium?.color),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: _hasCustomWallpaper ? Colors.white54 : theme.textTheme.bodySmall?.color),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: _hasCustomWallpaper ? Colors.white.withValues(alpha: 0.12) : theme.scaffoldBackgroundColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: theme.primaryColor,
                          child: IconButton(
                            icon: Icon(_editingMessageId != null ? Icons.check : Icons.send, color: Colors.white, size: 20),
                            onPressed: _sendMessage,
                          ),
                        ),
                      ]),
              ),
          ],
        ),
      ),
    );
  }
}
