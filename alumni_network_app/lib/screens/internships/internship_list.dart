import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/internship.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/empty_state.dart';
import 'internship_detail.dart';
import 'post_internship.dart';

class InternshipListScreen extends StatefulWidget {
  const InternshipListScreen({super.key});

  @override
  State<InternshipListScreen> createState() => _InternshipListScreenState();
}

class _InternshipListScreenState extends State<InternshipListScreen> {
  final ApiService _apiService = ApiService();
  List<Internship> _internships = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInternships();
  }

  Future<void> _fetchInternships() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/internships');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _internships = data.map((json) => Internship.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Fetch internships error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Internship Board')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchInternships,
              child: _internships.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.work_outline,
                      title: 'No Internships Available',
                      message: 'Check back soon for new opportunities or posted by alumni.',
                      onRetry: _fetchInternships,
                    )
                  : ListView.builder(
                      itemCount: _internships.length,
                      itemBuilder: (context, index) {
                        final item = _internships[index];
                        return Card(
                          margin: const EdgeInsets.all(8.0),
                          child: ListTile(
                            title: Text(item.roleTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${item.companyName} | ${item.location ?? "Remote"}'),
                            trailing: Text(item.stipend ?? 'Unpaid', style: const TextStyle(color: Colors.green)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => InternshipDetailScreen(internship: item)),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: user?.role == 'alumni'
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PostInternshipScreen()),
                );
                if (result == true) _fetchInternships();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
