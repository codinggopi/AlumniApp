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
  final _stipendController = TextEditingController();
  bool _isLoading = false;

  void _submit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);
    
    try {
      final response = await ApiService().post('/internships', {
        'posted_by': auth.user!.userId,
        'role_title': _roleController.text,
        'company': _companyController.text,
        'description': _descController.text,
        'location': _locationController.text,
        'stipend': _stipendController.text,
      });

      if (response.statusCode == 200 && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Post error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post New Internship')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: _roleController, decoration: const InputDecoration(labelText: 'Role Title')),
              TextField(controller: _companyController, decoration: const InputDecoration(labelText: 'Company Name')),
              TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location')),
              TextField(controller: _stipendController, decoration: const InputDecoration(labelText: 'Stipend')),
              TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(onPressed: _submit, child: const Text('Post Listing')),
            ],
          ),
        ),
      ),
    );
  }
}
