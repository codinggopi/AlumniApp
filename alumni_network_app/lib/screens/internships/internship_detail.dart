import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/internship.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class InternshipDetailScreen extends StatelessWidget {
  final Internship internship;
  const InternshipDetailScreen({super.key, required this.internship});

  void _apply(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = ApiService();
    
    // Simple apply logic with a cover note dialog
    final coverNote = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Apply for Internship'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Cover Note (Optional)'),
            maxLines: 3,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Apply')),
          ],
        );
      },
    );

    if (coverNote != null) {
      final response = await api.post('/applications', {
        'internship_id': internship.internshipId,
        'student_id': auth.user!.userId,
        'cover_note': coverNote,
      });

      if (response.statusCode == 200 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      appBar: AppBar(title: Text(internship.roleTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(internship.companyName, style: Theme.of(context).textTheme.headlineSmall),
            Text(internship.location ?? 'Remote', style: const TextStyle(color: Colors.grey)),
            const Divider(),
            Text('Description:', style: Theme.of(context).textTheme.titleMedium),
            Text(internship.description ?? 'No description provided.'),
            const SizedBox(height: 10),
            Text('Stipend: ${internship.stipend ?? "Unpaid"}'),
            Text('Duration: ${internship.duration ?? "N/A"}'),
            const Spacer(),
            if (user?.role == 'student')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _apply(context),
                  child: const Text('Apply Now'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
