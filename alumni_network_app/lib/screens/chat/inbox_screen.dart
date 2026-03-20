import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../widgets/empty_state.dart';
import 'chat_room_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _isLoading = true;
  List<User> _conversations = [];

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    final api = ApiService();
    setState(() => _isLoading = true);
    try {
      final response = await api.get('/alumni');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _conversations = data.map((e) => User.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Messages', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.chat_bubble_outline,
                  title: 'No Messages Yet',
                  message: 'Connect with alumni to start chatting and grow your network!',
                  onRetry: _fetchConversations,
                )
              : ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final otherUser = _conversations[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(otherUser.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Tap to open conversation'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(otherUser: otherUser),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
