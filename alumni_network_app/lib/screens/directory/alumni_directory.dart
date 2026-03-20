import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../widgets/empty_state.dart';
import 'profile_detail.dart';

class AlumniDirectoryScreen extends StatefulWidget {
  const AlumniDirectoryScreen({super.key});

  @override
  State<AlumniDirectoryScreen> createState() => _AlumniDirectoryScreenState();
}

class _AlumniDirectoryScreenState extends State<AlumniDirectoryScreen> {
  final ApiService _apiService = ApiService();
  List<User> _alumniList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAlumni();
  }

  Future<void> _fetchAlumni() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/alumni');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _alumniList = data.map((json) => User.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Fetch alumni error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alumni Directory')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alumniList.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: 'No Alumni Found',
                  message: 'It looks like there are no alumni in the directory yet.',
                  onRetry: _fetchAlumni,
                )
              : ListView.builder(
                  itemCount: _alumniList.length,
                  itemBuilder: (context, index) {
                    final alumni = _alumniList[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(alumni.fullName),
                      subtitle: Text('${alumni.department ?? "N/A"} | ${alumni.city ?? "N/A"}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProfileDetailScreen(user: alumni)),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
