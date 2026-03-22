import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../directory/profile_detail.dart';

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
  int? _editingMessageId;
  final Set<int> _selectedMessages = {};

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

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
        });
      }
    } catch (e) {
      debugPrint('Fetch messages error: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    final content = _messageController.text;
    
    if (_editingMessageId != null) {
      _updateMessage();
      return;
    }

    _messageController.clear();

    try {
      final response = await _apiService.post('/messages', {
        'sender_id': currentUser!.userId,
        'receiver_id': widget.otherUser.userId,
        'content': content,
      });

      if (response.statusCode == 200) {
        _fetchMessages();
      }
    } catch (e) {
      debugPrint('Send message error: $e');
    }
  }

  void _updateMessage() async {
    final content = _messageController.text;
    final msgId = _editingMessageId;
    
    setState(() {
      _editingMessageId = null;
      _messageController.clear();
    });

    try {
      final response = await _apiService.patch('/messages/$msgId', {
        'content': content,
      });

      if (response.statusCode == 200) {
        _fetchMessages();
      } else {
        if (mounted) {
          final err = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err['detail'] ?? 'Update failed')));
        }
      }
    } catch (e) {
      debugPrint('Update message error: $e');
    }
  }

  void _deleteMessage(int msgId) async {
    try {
      final response = await _apiService.delete('/messages/$msgId');
      if (response.statusCode == 200) {
        _fetchMessages();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message deleted')));
      }
    } catch (e) {
      debugPrint('Delete message error: $e');
    }
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
    } catch (e) {
      debugPrint('Bulk delete error: $e');
      setState(() => _isLoading = false);
    }
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
            onPressed: () {
              Navigator.pop(context);
              _clearChat();
            },
            child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
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
    } catch (e) {
      debugPrint('Clear chat error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startEdit(Message msg) {
    setState(() {
      _editingMessageId = msg.messageId;
      _messageController.text = msg.content;
    });
  }

  bool _canEdit(Message msg) {
    final sentLocal = msg.sentAt.toLocal();
    final now = DateTime.now();
    return now.difference(sentLocal).inMinutes < 5;
  }

  bool _canDelete(Message msg) {
    final sentLocal = msg.sentAt.toLocal();
    final now = DateTime.now();
    return now.difference(sentLocal).inHours < 24;
  }

  void _toggleSelection(int msgId) {
    setState(() {
      if (_selectedMessages.contains(msgId)) {
        _selectedMessages.remove(msgId);
      } else {
        _selectedMessages.add(msgId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).user;
    final isSelectionMode = _selectedMessages.isNotEmpty;

    return Scaffold(
      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: Colors.blue[800],
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedMessages.clear()),
              ),
              title: Text('${_selectedMessages.length} Selected', style: const TextStyle(color: Colors.white)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _bulkDeleteMessages,
                ),
              ],
            )
          : AppBar(
              title: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileDetailScreen(user: widget.otherUser))),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: (widget.otherUser.profilePictureUrl != null && widget.otherUser.profilePictureUrl!.isNotEmpty)
                          ? NetworkImage(widget.otherUser.profilePictureUrl!.startsWith('http') ? widget.otherUser.profilePictureUrl! : '${ApiService.baseUrl}${widget.otherUser.profilePictureUrl}')
                          : null,
                      child: (widget.otherUser.profilePictureUrl == null || widget.otherUser.profilePictureUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.otherUser.fullName, style: const TextStyle(fontSize: 18))),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.call, size: 20),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio call not implemented'))),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam, size: 20),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video call not implemented'))),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'clear') {
                      _confirmClearChat();
                    } else if (value == 'profile') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileDetailScreen(user: widget.otherUser)));
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'profile', child: Text('View Profile')),
                    const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
                    const PopupMenuItem(value: 'block', child: Text('Block User')),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
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
                                builder: (context) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.check_box_outlined, color: Colors.blue),
                                      title: const Text('Select Message'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _toggleSelection(actualMsg.messageId);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.edit, color: Colors.teal),
                                      title: const Text('Edit Message'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        if (_canEdit(actualMsg)) {
                                          _startEdit(actualMsg);
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Cannot edit after 5 minutes'), duration: Duration(seconds: 2))
                                          );
                                        }
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete, color: Colors.red),
                                      title: const Text('Delete Message'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        if (_canDelete(actualMsg)) {
                                          _deleteMessage(actualMsg.messageId);
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Cannot delete after 24 hours'), duration: Duration(seconds: 2))
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              );
                            }
                          } : null,
                          child: Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? Colors.blue[100] 
                                      : (isMe ? Colors.blue[600] : Colors.grey[200]),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    bottomLeft: Radius.circular(isMe ? 15 : 0),
                                    bottomRight: Radius.circular(isMe ? 0 : 15),
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      actualMsg.content,
                                      style: TextStyle(color: (isSelected || !isMe) ? Colors.black87 : Colors.white, fontSize: 16),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${actualMsg.sentAt.hour.toString().padLeft(2, '0')}:${actualMsg.sentAt.minute.toString().padLeft(2, '0')} IST",
                                      style: TextStyle(color: (isSelected || !isMe) ? Colors.black45 : Colors.white70, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  right: isMe ? 2 : null,
                                  left: !isMe ? 2 : null,
                                  top: 0,
                                  bottom: 0,
                                  child: Icon(Icons.check_circle, color: Colors.blue[700], size: 20),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_editingMessageId != null)
            Container(
              color: Colors.blue[50],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 16, color: Colors.blue),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Editing...', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blue))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: () => setState(() {
                      _editingMessageId = null;
                      _messageController.clear();
                    }),
                  ),
                ],
              ),
            ),
          if (!isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: IconButton(
                      icon: Icon(_editingMessageId != null ? Icons.check : Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
