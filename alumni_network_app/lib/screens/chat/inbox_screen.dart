import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../widgets/empty_state.dart';
import 'chat_room_screen.dart';
import '../admin/user_list_screen.dart';

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
      final response = await api.get('/conversations');
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _conversations = data.map((e) => User.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
                  title: 'No Conversations',
                  message: 'Start a new conversation to connect with others!',
                  onRetry: _fetchConversations,
                )
              : ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final otherUser = _conversations[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (otherUser.profilePictureUrl != null && otherUser.profilePictureUrl!.isNotEmpty)
                            ? NetworkImage(otherUser.profilePictureUrl!.startsWith('http') ? otherUser.profilePictureUrl! : '${ApiService.baseUrl}${otherUser.profilePictureUrl}')
                            : null,
                        child: (otherUser.profilePictureUrl == null || otherUser.profilePictureUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(otherUser.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(otherUser.role.toUpperCase(), style: TextStyle(color: Colors.blue[700], fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(otherUser: otherUser),
                          ),
                        ).then((_) => _fetchConversations());
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show a simple dialog to pick role or just go to a list
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Start Conversation With', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const Icon(Icons.school, color: Colors.indigo),
                  title: const Text('Students'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListScreen(role: 'student', title: 'Start Chat with Student')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group_work, color: Colors.teal),
                  title: const Text('Alumni'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListScreen(role: 'alumni', title: 'Start Chat with Alumni')));
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }
}
