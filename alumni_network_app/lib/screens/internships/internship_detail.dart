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
      case 'selected': return Colors.green;
      case 'shortlisted': return Theme.of(context).primaryColor;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final theme = Theme.of(context);
    final isAlumniOwner = user?.role == 'alumni' && widget.internship.postedBy == user?.userId;
    final canViewApplicants = isAlumniOwner || user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.internship.roleTitle),
        actions: [
          if (canViewApplicants)
            TextButton.icon(
              icon: const Icon(Icons.people),
              label: const Text('Applicants'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ApplicantsScreen(internship: widget.internship, userRole: user?.role ?? 'admin'),
              )),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.internship.companyName,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 14, color: theme.textTheme.bodySmall?.color),
                    const SizedBox(width: 4),
                    Text(widget.internship.location ?? 'Remote', style: theme.textTheme.bodySmall),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.person_outline, size: 14, color: theme.primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'Posted by ${widget.internship.postedByName.isEmpty || widget.internship.postedByName == "Unknown" ? "Alumni #${widget.internship.postedBy}" : widget.internship.postedByName}',
                      style: TextStyle(color: theme.primaryColor, fontSize: 13),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Application status banner (student)
            if (user?.role == 'student') ...[
              if (_checkingStatus)
                const LinearProgressIndicator()
              else if (_applicationStatus != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusColor(_applicationStatus!).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _statusColor(_applicationStatus!)),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: _statusColor(_applicationStatus!)),
                    const SizedBox(width: 8),
                    Text(
                      'Your application: ${_applicationStatus!.toUpperCase()}',
                      style: TextStyle(color: _statusColor(_applicationStatus!), fontWeight: FontWeight.bold),
                    ),
                  ]),
                ),
              const SizedBox(height: 12),
            ],

            // Quick info chips row
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (widget.internship.duration != null && widget.internship.duration!.isNotEmpty)
                _chip(Icons.access_time_outlined, widget.internship.duration!, Colors.blue),
              if (widget.internship.stipend != null && widget.internship.stipend!.isNotEmpty)
                _chip(Icons.currency_rupee, widget.internship.stipend!, Colors.green),
              if (widget.internship.applyDeadline != null && widget.internship.applyDeadline!.isNotEmpty)
                _chip(Icons.event_outlined, 'Deadline: ${widget.internship.applyDeadline!}', Colors.orange),
              _chip(Icons.event_seat_outlined, '${widget.internship.seatsAvailable} seat${widget.internship.seatsAvailable != 1 ? 's' : ''}', theme.primaryColor),
            ]),
            const SizedBox(height: 16),

            // Description
            if (widget.internship.description != null && widget.internship.description!.isNotEmpty) ...[
              _sectionTitle('Description'),
              Text(widget.internship.description!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: 16),
            ],

            // Skills
            if (widget.internship.skillsRequired != null && widget.internship.skillsRequired!.isNotEmpty) ...[
              _sectionTitle('Skills Required'),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: widget.internship.skillsRequired!
                    .split(RegExp(r'[,\n]'))
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 8),

            // Apply button (student)
            if (user?.role == 'student')
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _applicationStatus != null ? null : () => _apply(context),
                  child: Text(
                    _applicationStatus != null ? 'Already Applied' : 'Apply Now',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // View applicants (alumni/admin)
            if (canViewApplicants)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.people),
                  label: const Text('View Applicants'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ApplicantsScreen(internship: widget.internship, userRole: user?.role ?? 'admin'),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
  );

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}
