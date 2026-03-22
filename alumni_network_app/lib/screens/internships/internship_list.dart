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
  final int? postedBy;
  const InternshipListScreen({super.key, this.postedBy});

  @override
  State<InternshipListScreen> createState() => _InternshipListScreenState();
}

class _InternshipListScreenState extends State<InternshipListScreen> {
  final ApiService _apiService = ApiService();
  List<Internship> _internships = [];
  List<InternshipApplication> _myApplications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInternships();
  }

  Future<void> _fetchInternships() async {
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;

      // Fetch Internships
      final response = await _apiService.get('/internships');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _internships = data
            .map((json) => Internship.fromJson(json))
            .where(
              (i) => widget.postedBy == null || i.postedBy == widget.postedBy,
            )
            .toList();
      }

      // Fetch Applications if student
      if (user?.role == 'student') {
        final appResponse = await _apiService.get(
          '/applications?student_id=${user!.userId}',
        );
        if (appResponse.statusCode == 200) {
          final List<dynamic> appData = jsonDecode(appResponse.body);
          _myApplications = appData
              .map((json) => InternshipApplication.fromJson(json))
              .toList();
        }
      }

      setState(() {});
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
                      message:
                          'Check back soon for new opportunities or posted by alumni.',
                      onRetry: _fetchInternships,
                    )
                  : ListView.builder(
                      itemCount: _internships.length,
                      itemBuilder: (context, index) {
                        final item = _internships[index];
                        final application = _myApplications
                            .where((a) => a.internshipId == item.internshipId)
                            .firstOrNull;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.roleTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (application != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        application.status,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _getStatusColor(
                                          application.status,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      application.status.toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(
                                          application.status,
                                        ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.business,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(item.companyName),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(item.location ?? "Remote"),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.stipend ?? 'Unpaid',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      InternshipDetailScreen(internship: item),
                                ),
                              );
                              if (result == true) _fetchInternships();
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
                  MaterialPageRoute(
                    builder: (_) => const PostInternshipScreen(),
                  ),
                );
                if (result == true) _fetchInternships();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'selected':
        return Colors.green;
      case 'shortlisted':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'applied':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
