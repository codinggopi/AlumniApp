import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../models/internship.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'applicants_screen.dart';

class InternshipDetailScreen extends StatefulWidget {
  final Internship internship;
  const InternshipDetailScreen({super.key, required this.internship});

  @override
  State<InternshipDetailScreen> createState() => _InternshipDetailScreenState();
}

class _InternshipDetailScreenState extends State<InternshipDetailScreen> {
  String? _applicationStatus;
  bool _checkingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
  }

  Future<void> _checkApplicationStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user?.role != 'student') {
      setState(() => _checkingStatus = false);
      return;
    }
    try {
      final response = await ApiService().get(
        '/applications?student_id=${auth.user!.userId}',
      );
      if (response.statusCode == 200) {
        final List<dynamic> apps = jsonDecode(response.body);
        final match = apps
            .where((a) => a['internship_id'] == widget.internship.internshipId)
            .firstOrNull;
        if (match != null) {
          setState(() {
            _applicationStatus = match['status'];
          });
        }
      }
    } catch (e) {
      debugPrint('Check status error: $e');
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  void _apply(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = ApiService();

    final coverNote = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Apply for Internship'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Cover Note (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (coverNote != null) {
      final response = await api.post('/applications', {
        'internship_id': widget.internship.internshipId,
        'student_id': auth.user!.userId,
        'cover_note': coverNote,
      });

      if (response.statusCode == 200 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted successfully!')),
        );
        _checkApplicationStatus();
        Navigator.pop(context, true);
      } else if (context.mounted) {
        final errorMsg =
            jsonDecode(response.body)['detail'] ?? 'Failed to apply';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
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
    final user = Provider.of<AuthProvider>(context).user;
    final isAlumniOwner =
        user?.role == 'alumni' && widget.internship.postedBy == user?.userId;
    final canViewApplicants = isAlumniOwner || user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.internship.roleTitle),
        actions: [
          if (canViewApplicants)
            TextButton.icon(
              icon: const Icon(Icons.people, color: Colors.white),
              label: const Text(
                'Applicants',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ApplicantsScreen(
                    internship: widget.internship,
                    userRole: user?.role ?? 'admin',
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.internship.companyName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.internship.location ?? 'Remote',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Colors.indigo,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Posted by ${widget.internship.postedByName.isEmpty || widget.internship.postedByName == "Unknown" ? "Alumni #${widget.internship.postedBy}" : widget.internship.postedByName}',
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Student application status banner
            if (user?.role == 'student') ...[
              if (_checkingStatus)
                const LinearProgressIndicator()
              else if (_applicationStatus != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusColor(_applicationStatus!).withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _statusColor(_applicationStatus!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: _statusColor(_applicationStatus!),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your application status: ${_applicationStatus!.toUpperCase()}',
                        style: TextStyle(
                          color: _statusColor(_applicationStatus!),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // Details
            _section(
              context,
              'Description',
              widget.internship.description ?? 'No description provided.',
            ),
            _detailRow(
              Icons.access_time,
              'Duration',
              widget.internship.duration ?? 'N/A',
            ),
            _detailRow(
              Icons.currency_rupee,
              'Stipend',
              widget.internship.stipend ?? 'N/A',
            ),
            _detailRow(
              Icons.event,
              'Deadline',
              widget.internship.applyDeadline ?? 'N/A',
            ),
            _detailRow(
              Icons.chair,
              'Seats Available',
              '${widget.internship.seatsAvailable}',
            ),
            if (widget.internship.skillsRequired != null)
              _section(
                context,
                'Skills Required',
                widget.internship.skillsRequired!,
              ),

            const SizedBox(height: 24),

            // Apply button for students
            if (user?.role == 'student')
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _applicationStatus != null
                      ? null
                      : () => _apply(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _applicationStatus != null
                        ? Colors.grey
                        : Colors.indigo,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _applicationStatus != null
                        ? 'Already Applied'
                        : 'Apply Now',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Alumni/Admin view applicants button
            if (canViewApplicants)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.people),
                  label: const Text('View Applicants'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ApplicantsScreen(
                        internship: widget.internship,
                        userRole: user?.role ?? 'admin',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(content),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }
}
