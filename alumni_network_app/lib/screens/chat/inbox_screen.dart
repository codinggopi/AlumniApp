import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_count_provider.dart';
import '../../widgets/empty_state.dart';
import 'chat_room_screen.dart';
import 'connected_users_screen.dart';

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
    // Refresh unread count when inbox opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MessageCountProvider>(context, listen: false).fetchCount();
    });
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
    final currentUser = Provider.of<AuthProvider>(context).user;
    final peerLabel = currentUser?.role == 'alumni'
        ? 'Connected Students & Admins'
        : currentUser?.role == 'admin'
        ? 'Students & Alumni'
        : 'Connected Alumni';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: Navigator.canPop(context)
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
          ? EmptyStateWidget(
              icon: Icons.chat_bubble_outline,
              title: 'No Conversations',
              message: currentUser?.role == 'alumni'
                  ? 'Start a chat with your connected students or with admin.'
                  : currentUser?.role == 'admin'
                  ? 'Use + to start a direct chat with any student or alumni.'
                  : 'Start a new conversation to connect with others!',
              onRetry: _fetchConversations,
            )
          : ListView.separated(
              itemCount: _conversations.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final otherUser = _conversations[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        (otherUser.profilePictureUrl != null &&
                            otherUser.profilePictureUrl!.isNotEmpty)
                        ? NetworkImage(
                            otherUser.profilePictureUrl!.startsWith('http')
                                ? otherUser.profilePictureUrl!
                                : '${ApiService.baseUrl}${otherUser.profilePictureUrl}',
                          )
                        : null,
                    child:
                        (otherUser.profilePictureUrl == null ||
                            otherUser.profilePictureUrl!.isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    otherUser.fullName,
                    style: TextStyle(
                      fontWeight: otherUser.unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    otherUser.role.toUpperCase(),
                    style: TextStyle(color: Colors.blue[700], fontSize: 12),
                  ),
                  trailing: otherUser.unreadCount > 0
                      ? Badge(
                          label: Text(
                            otherUser.unreadCount > 99
                                ? '99+'
                                : '${otherUser.unreadCount}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.blue,
                          child: const SizedBox.shrink(),
                        )
                      : const Icon(Icons.chevron_right),
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConnectedUsersScreen()),
          ).then((_) => _fetchConversations());
        },
        backgroundColor: Colors.blue,
        tooltip: peerLabel,
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }
}
