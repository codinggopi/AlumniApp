import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class PostInternshipScreen extends StatefulWidget {
  const PostInternshipScreen({super.key});

  @override
  State<PostInternshipScreen> createState() => _PostInternshipScreenState();
}

class _PostInternshipScreenState extends State<PostInternshipScreen> {
  final _roleController = TextEditingController();
  final _companyController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _durationController = TextEditingController();
  final _stipendController = TextEditingController();
  final _skillsController = TextEditingController();
  final _seatsController = TextEditingController(text: '1');
  DateTime? _deadline;
  bool _isLoading = false;

  @override
  void dispose() {
    _roleController.dispose();
    _companyController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    _stipendController.dispose();
    _skillsController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  void _submit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (_roleController.text.trim().isEmpty || _companyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role Title and Company Name are required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final seats = int.tryParse(_seatsController.text.trim()) ?? 1;
      final deadlineStr = _deadline != null
          ? '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'
          : null;

      final body = <String, dynamic>{
        'posted_by': auth.user!.userId,
        'role_title': _roleController.text.trim(),
        'company': _companyController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locationController.text.trim(),
        'duration': _durationController.text.trim(),
        'seats_available': seats,
      };
      if (_stipendController.text.trim().isNotEmpty) {
        body['stipend'] = _stipendController.text.trim();
      }
      if (_skillsController.text.trim().isNotEmpty) {
        body['required_skills'] = _skillsController.text.trim();
      }
      if (deadlineStr != null) {
        body['deadline'] = deadlineStr;
      }

      final response = await ApiService().post('/internships', body);
      debugPrint('Post internship response: ${response.statusCode} ${response.body}');
      if ((response.statusCode == 200 || response.statusCode == 201) && mounted) {
        // Store values before async gap
        final role = _roleController.text.trim();
        final company = _companyController.text.trim();
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Internship Posted!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '$role at $company has been posted successfully.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Great!'),
                ),
              ),
            ]),
          ),
        );
        if (mounted) Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed (${response.statusCode}): ${response.body}')),
        );
      }
    } catch (e) {
      debugPrint('Post error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 6)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Post New Internship')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Role Title *'),
            _field(_roleController, 'e.g. UI/UX Designer', Icons.work_outline),
            _label('Company Name *'),
            _field(_companyController, 'e.g. ABC company', Icons.business_outlined),
            _label('Location'),
            _field(_locationController, 'e.g. Chennai / Remote', Icons.location_on_outlined),
            _label('Duration'),
            _field(_durationController, 'e.g. 3 months, 6 months', Icons.access_time_outlined),
            _label('Stipend'),
            _field(_stipendController, 'e.g. ₹3000/month or Unpaid', Icons.currency_rupee),
            _label('Skills Required'),
            _field(_skillsController, 'e.g. Figma, Flutter, Python', Icons.star_outline, maxLines: 2),
            _label('Seats Available'),
            _field(_seatsController, '1', Icons.event_seat_outlined, keyboardType: TextInputType.number),
            _label('Application Deadline'),
            GestureDetector(
              onTap: _pickDeadline,
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: theme.primaryColor),
                  const SizedBox(width: 10),
                  Text(
                    _deadline == null
                        ? 'Select deadline'
                        : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                    style: TextStyle(
                      color: _deadline == null
                          ? theme.textTheme.bodySmall?.color
                          : theme.textTheme.bodyMedium?.color,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (_deadline != null)
                    GestureDetector(
                      onTap: () => setState(() => _deadline = null),
                      child: Icon(Icons.close, size: 16, color: theme.iconTheme.color),
                    ),
                ]),
              ),
            ),
            _label('Description'),
            _field(_descController, 'Describe the role, responsibilities, requirements...', Icons.notes_outlined, maxLines: 4),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Post Internship', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
      );
}
