import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _deptController = TextEditingController();
  final _cityController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = user.phone ?? "";
      _bioController.text = user.bio ?? "";
      _deptController.text = user.department ?? "";
      _cityController.text = user.city ?? "";
    }
  }

  void _save() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = ApiService();

    try {
      final response = await api.patch('/profile/${auth.user!.userId}', {
        'full_name': _nameController.text,
        'phone': _phoneController.text,
        'bio': _bioController.text,
        'department': _deptController.text,
        'city': _cityController.text,
      });

      if (response.statusCode == 200) {
        await auth.checkAuth(); // Refresh user data
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
          Navigator.pop(context);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _deptController, decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _bioController, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder())),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(onPressed: _save, child: const Text('SAVE CHANGES')),
                  ),
          ],
        ),
      ),
    );
  }
}
