import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../widgets/empty_state.dart';
import '../directory/profile_detail.dart';

class UserListScreen extends StatefulWidget {
  final String role; // 'student' or 'alumni'
  final String title;

  const UserListScreen({super.key, required this.role, required this.title});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> with RouteAware {
  final ApiService _apiService = ApiService();
  List<User> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  List<User> get _filtered => _searchQuery.isEmpty
      ? _users
      : _users
            .where(
              (u) =>
                  u.fullName.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  (u.email.toLowerCase().contains(_searchQuery.toLowerCase())),
            )
            .toList();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/users?role=${widget.role}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _users = data.map((json) => User.fromJson(json)).toList();
        });
      } else {
        throw Exception(
          'Server returned ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Fetch users error: $e');
      debugPrint('Stacktrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(int userId) async {
    try {
      final response = await _apiService.delete('/profile/$userId');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully')),
          );
        }
        _fetchUsers();
      } else {
        throw Exception(
          'Server returned ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Delete user error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDelete(int userId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete profile of $name? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(userId);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
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
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
          ? RefreshIndicator(
              onRefresh: _fetchUsers,
              child: ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  EmptyStateWidget(
                    icon: widget.role == 'student'
                        ? Icons.school
                        : Icons.people_outline,
                    title: 'No ${widget.title} Found',
                    message: _searchQuery.isNotEmpty
                        ? 'No results for "$_searchQuery"'
                        : 'There are no users registered as ${widget.role} currently.',
                    onRetry: _fetchUsers,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchUsers,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: _filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = _filtered[index];
                  return ListTile(
                    leading: Hero(
                      tag: 'profile_${user.userId}',
                      child: CircleAvatar(
                        backgroundImage:
                            (user.profilePictureUrl != null &&
                                user.profilePictureUrl!.isNotEmpty)
                            ? NetworkImage(
                                user.profilePictureUrl!.startsWith('http')
                                    ? user.profilePictureUrl!
                                    : '${ApiService.baseUrl}${user.profilePictureUrl}',
                              )
                            : null,
                        child:
                            (user.profilePictureUrl == null ||
                                user.profilePictureUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                    ),
                    title: Text(
                      user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${user.department ?? "No Dept"} | ${user.graduationYear ?? "No Year"}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.grey,
                            size: 20,
                          ),
                          onPressed: () =>
                              _confirmDelete(user.userId, user.fullName),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    onTap: () {
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
