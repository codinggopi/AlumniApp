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
  String _searchQuery = '';

  List<User> get _filtered {
    if (_searchQuery.isEmpty) return _users;
    final q = _searchQuery.toLowerCase();
    return _users.where((u) =>
      u.fullName.toLowerCase().contains(q) ||
      u.email.toLowerCase().contains(q) ||
      (u.department ?? '').toLowerCase().contains(q)
    ).toList();
  }

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
      if (currentUser.role == 'admin') {
        final response = await _api.get('/users');
        if (response.statusCode != 200) {
          throw Exception('Server returned ${response.statusCode}: ${response.body}');
        }

        final List<dynamic> data = jsonDecode(response.body);
        final users = data
            .whereType<Map<String, dynamic>>()
            .map(User.fromJson)
            .where((user) => user.userId != currentUser.userId)
            .toList()
          ..sort((a, b) {
            const order = ['alumni', 'student', 'staff', 'admin'];
            final ai = order.indexOf(a.role);
            final bi = order.indexOf(b.role);
            final ra = ai < 0 ? 99 : ai;
            final rb = bi < 0 ? 99 : bi;
            if (ra != rb) return ra.compareTo(rb);
            return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
          });

        setState(() => _users = users);
        return;
      }

      if (currentUser.role == 'staff') {
        final response = await _api.get('/users');
        if (response.statusCode != 200) {
          throw Exception('Server returned ${response.statusCode}: ${response.body}');
        }
        final List<dynamic> data = jsonDecode(response.body);
        final users = data
            .whereType<Map<String, dynamic>>()
            .map(User.fromJson)
            .where((user) => user.userId != currentUser.userId)
            .toList()
          ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        setState(() => _users = users);
        return;
      }

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
        // Alumni: connected students + all admins freely
        final adminResponse = await _api.get('/admins');
        if (adminResponse.statusCode != 200) {
          throw Exception('Server returned ${adminResponse.statusCode}: ${adminResponse.body}');
        }
        final admins = (jsonDecode(adminResponse.body) as List)
            .whereType<Map<String, dynamic>>()
            .map(User.fromJson)
            .toList();

        setState(() => _users = <User>[
          ...connectedUsers,
          ...admins.where((a) => !connectedUsers.any((u) => u.userId == a.userId)),
        ]);
      } else if (currentUser.role == 'student') {
        // Students: only accepted alumni connections + admin/staff freely
        final staffResponse = await _api.get('/staff-contacts');
        final adminResponse = await _api.get('/admins');

        final List<User> staff = staffResponse.statusCode == 200
            ? (jsonDecode(staffResponse.body) as List)
                .whereType<Map<String, dynamic>>()
                .map(User.fromJson)
                .toList()
            : [];

        final List<User> admins = adminResponse.statusCode == 200
            ? (jsonDecode(adminResponse.body) as List)
                .whereType<Map<String, dynamic>>()
                .map(User.fromJson)
                .toList()
            : [];

        final freeContacts = <User>[...admins, ...staff]
            .where((u) => !connectedUsers.any((c) => c.userId == u.userId))
            .toList();

        setState(() => _users = <User>[
          ...connectedUsers,   // accepted alumni connections
          ...freeContacts,     // admin + staff always accessible
        ]);
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

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':    return Colors.orange;
      case 'staff':    return Colors.brown;
      case 'alumni':   return Colors.teal;
      case 'student':  return Colors.indigo;
      default:         return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).user;
    final peerLabel = currentUser?.role == 'alumni'
        ? 'Students & Admins'
        : currentUser?.role == 'admin' || currentUser?.role == 'staff'
        ? 'All Users'
        : currentUser?.role == 'student'
        ? 'Alumni, Admin & Staff'
        : 'Contacts';
    final isAlumni = currentUser?.role == 'alumni';
    final isAdmin = currentUser?.role == 'admin';
    final isStudent = currentUser?.role == 'student';
    final isStaff = currentUser?.role == 'staff';

    return Scaffold(
      appBar: AppBar(
        title: Text('Connected $peerLabel'),
        bottom: (isAdmin || isStaff)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? RefreshIndicator(
                  onRefresh: _fetchConnectedUsers,
                  child: ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      EmptyStateWidget(
                        icon: isAlumni
                            ? Icons.school
                            : isAdmin
                            ? Icons.group
                            : Icons.people_outline,
                        title: _searchQuery.isNotEmpty
                            ? 'No results for "$_searchQuery"'
                            : 'No Connected $peerLabel',
                        message: _searchQuery.isNotEmpty
                            ? 'Try a different name or email.'
                            : isAlumni
                            ? 'Connected students and admin contacts will appear here.'
                            : isAdmin || isStaff
                            ? 'All users will appear here for direct messaging.'
                            : isStudent
                            ? 'Connect with alumni to message them. Admin and staff are always available.'
                            : 'Accepted connections will appear here.',
                        onRetry: _fetchConnectedUsers,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchConnectedUsers,
                  child: ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _filtered[index];
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _roleColor(user.role).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  user.role.toUpperCase(),
                                  style: TextStyle(
                                    color: _roleColor(user.role),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          (user.role == 'admin' || user.role == 'staff')
                              ? user.email
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
