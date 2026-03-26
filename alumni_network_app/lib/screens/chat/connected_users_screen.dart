import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/empty_state.dart';
import '../directory/profile_detail.dart';
import 'chat_room_screen.dart';

class ConnectedUsersScreen extends StatefulWidget {
  const ConnectedUsersScreen({super.key});

  @override
  State<ConnectedUsersScreen> createState() => _ConnectedUsersScreenState();
}

class _ConnectedUsersScreenState extends State<ConnectedUsersScreen> {
  final ApiService _api = ApiService();
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConnectedUsers();
  }

  Future<void> _fetchConnectedUsers() async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _api.get(
        '/connections?user_id=${currentUser.userId}&role=${currentUser.role}&status=accepted',
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }

      final List<dynamic> data = jsonDecode(response.body);
      final peerKey = currentUser.role == 'alumni' ? 'requester' : 'receiver';
      final connectedUsers = data
          .map((item) => item[peerKey])
          .whereType<Map<String, dynamic>>()
          .map(User.fromJson)
          .toList();

      if (currentUser.role == 'alumni') {
        final adminResponse = await _api.get('/admins');
        if (adminResponse.statusCode != 200) {
          throw Exception(
            'Server returned ${adminResponse.statusCode}: ${adminResponse.body}',
          );
        }

        final List<dynamic> adminData = jsonDecode(adminResponse.body);
        final admins = adminData
            .whereType<Map<String, dynamic>>()
            .map(User.fromJson)
            .toList();

        final combined = <User>[
          ...connectedUsers,
          ...admins.where(
            (admin) => !connectedUsers.any((user) => user.userId == admin.userId),
          ),
        ];

        setState(() => _users = combined);
      } else {
        setState(() => _users = connectedUsers);
      }
    } catch (e) {
      debugPrint('Fetch connected users error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading connected users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).user;
    final peerLabel = currentUser?.role == 'alumni' ? 'Students & Admins' : 'Alumni';
    final isAlumni = currentUser?.role == 'alumni';

    return Scaffold(
      appBar: AppBar(title: Text('Connected $peerLabel')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? RefreshIndicator(
                  onRefresh: _fetchConnectedUsers,
                  child: ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      EmptyStateWidget(
                        icon: isAlumni
                            ? Icons.school
                            : Icons.people_outline,
                        title: 'No Connected $peerLabel',
                        message: isAlumni
                            ? 'Connected students and admin contacts will appear here.'
                            : 'Accepted alumni connections will appear here.',
                        onRetry: _fetchConnectedUsers,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchConnectedUsers,
                  child: ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (user.profilePictureUrl != null &&
                                  user.profilePictureUrl!.isNotEmpty)
                              ? NetworkImage(
                                  user.profilePictureUrl!.startsWith('http')
                                      ? user.profilePictureUrl!
                                      : '${ApiService.baseUrl}${user.profilePictureUrl}',
                                )
                              : null,
                          child: (user.profilePictureUrl == null ||
                                  user.profilePictureUrl!.isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (user.role == 'admin')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          user.role == 'admin'
                              ? (user.email)
                              : '${user.department ?? "No Dept"} | ${user.graduationYear ?? "No Year"}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(otherUser: user),
                            ),
                          );
                        },
                        onLongPress: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileDetailScreen(user: user),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
