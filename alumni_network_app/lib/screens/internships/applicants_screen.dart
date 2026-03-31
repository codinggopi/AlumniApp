import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/internship.dart';

class ApplicantsScreen extends StatefulWidget {
  final Internship internship;
  final String userRole;
  const ApplicantsScreen({
    super.key,
    required this.internship,
    required this.userRole,
  });

  @override
  State<ApplicantsScreen> createState() => _ApplicantsScreenState();
}

class _ApplicantsScreenState extends State<ApplicantsScreen> {
  final _api = ApiService();
  List<dynamic> _applicants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApplicants();
  }

  Future<void> _fetchApplicants() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get(
        '/internships/${widget.internship.internshipId}/applicants',
      );
      if (response.statusCode == 200) {
        setState(() => _applicants = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Fetch applicants error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int applicationId, String status) async {
    try {
      final response = await _api.patch('/applications/$applicationId', {
        'status': status,
      });
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Status updated to $status')));
        }
        _fetchApplicants();
      }
    } catch (e) {
      debugPrint('Update status error: $e');
    }
  }

  void _showStatusDialog(int applicationId, String currentStatus) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Application Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Applied', 'Shortlisted', 'Selected', 'Rejected'].map((s) {
            return ListTile(
              title: Text(s),
              leading: Radio<String>(
                value: s,
                groupValue: currentStatus,
                onChanged: (v) {
                  Navigator.pop(context);
                  _updateStatus(applicationId, v!);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'selected':
        return Colors.green;
      case 'shortlisted':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Applicants — ${widget.internship.roleTitle}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applicants.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No applicants yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchApplicants,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _applicants.length,
                itemBuilder: (context, index) {
                  final app = _applicants[index];
                  final student = app['student'];
                  final status = app['status'] ?? 'Applied';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.indigo.shade100,
                                child: Text(
                                  (student?['full_name'] ?? '?')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student?['full_name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      student?['email'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.userRole == 'alumni')
                                GestureDetector(
                                  onTap: () => _showStatusDialog(
                                    app['application_id'],
                                    status,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withAlpha(25),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _statusColor(status),
                                      ),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              if (widget.userRole == 'admin')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _statusColor(status),
                                    ),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: _statusColor(status),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (student?['department'] != null)
                            _infoRow(
                              Icons.school,
                              'Dept: ${student['department']}',
                            ),
                          if (student?['graduation_year'] != null)
                            _infoRow(
                              Icons.calendar_today,
                              'Grad Year: ${student['graduation_year']}',
                            ),
                          if (student?['phone'] != null)
                            _infoRow(Icons.phone, student['phone']),
                          if (student?['city'] != null)
                            _infoRow(Icons.location_on, student['city']),
                          if (student?['skills'] != null)
                            _infoRow(
                              Icons.build_outlined,
                              'Skills: ${student['skills']}',
                            ),
                          if (app['cover_note'] != null &&
                              app['cover_note'].toString().isNotEmpty) ...[
                            const Divider(height: 20),
                            const Text(
                              'Cover Note:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              app['cover_note'],
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (widget.userRole == 'alumni')
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Change Status'),
                                onPressed: () => _showStatusDialog(
                                  app['application_id'],
                                  status,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
