import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';

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
  final _eduController = TextEditingController();
  final _interestsController = TextEditingController();
  final _statusController = TextEditingController();
  
  String? _profilePictureUrl;
  String? _localImagePath;
  String? _resumeUrl;
  String? _localResumePath;
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
      _eduController.text = user.educationalDetails ?? "";
      _interestsController.text = user.interests ?? "";
      _statusController.text = user.currentStatus ?? "";
      _profilePictureUrl = user.profilePictureUrl;
      _resumeUrl = user.resumeUrl;
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _localImagePath = result.files.single.path;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _localImagePath = null;
      _profilePictureUrl = null;
    });
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _localResumePath = result.files.single.path;
      });
    }
  }

  Future<String?> _uploadFile(String? localPath, String? currentUrl) async {
    if (localPath == null) return currentUrl;
    final api = ApiService();
    try {
      final response = await api.upload('/upload', localPath);
      if (response.statusCode == 200) {
        final data = await response.stream.bytesToString();
        final Map<String, dynamic> decoded = jsonDecode(data);
        if (decoded.containsKey('url')) {
          return decoded['url'];
        }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    }
    return currentUrl;
  }

  void _save() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final api = ApiService();

    try {
      final imageUrl = await _uploadFile(_localImagePath, _profilePictureUrl);
      final newResumeUrl = await _uploadFile(_localResumePath, _resumeUrl);
      
      final Map<String, dynamic> updateData = {
        'full_name': _nameController.text,
        'phone': _phoneController.text,
        'bio': _bioController.text,
        'department': _deptController.text,
        'city': _cityController.text,
        'profile_picture_url': imageUrl,
        'current_status': _statusController.text,
      };

      if (auth.user?.role == 'student') {
        updateData.addAll({
          'educational_details': _eduController.text,
          'interests': _interestsController.text,
          'resume_url': newResumeUrl,
        });
      }

      final response = await api.patch('/profile/${auth.user!.userId}', updateData);

      if (response.statusCode == 200) {
        await auth.checkAuth();
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
    final user = Provider.of<AuthProvider>(context).user;
    bool isStudent = user?.role == 'student';
    bool isAdmin = user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _localImagePath != null
                        ? FileImage(File(_localImagePath!))
                        : (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                            ? NetworkImage(_profilePictureUrl!.startsWith('http') ? _profilePictureUrl! : '${ApiService.baseUrl}$_profilePictureUrl')
                            : null) as ImageProvider?,
                    child: (_localImagePath == null && (_profilePictureUrl == null || _profilePictureUrl!.isEmpty))
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            if (_localImagePath != null || (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty))
              TextButton.icon(
                onPressed: _removeImage,
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                label: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 30),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            if (!isAdmin) ...[
              TextField(controller: _statusController, decoration: const InputDecoration(labelText: 'Current Status (e.g. Seeking Internships)', border: OutlineInputBorder())),
              const SizedBox(height: 15),
            ],
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            if (!isAdmin) ...[
              TextField(controller: _deptController, decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder())),
              const SizedBox(height: 15),
            ],
            if (isStudent) ...[
              TextField(controller: _eduController, maxLines: 2, decoration: const InputDecoration(labelText: 'Educational Details (School/College)', border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _interestsController, decoration: const InputDecoration(labelText: 'Interests / Skills', border: OutlineInputBorder())),
              const SizedBox(height: 20),
              const Align(alignment: Alignment.centerLeft, child: Text('Resume / CV', style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description, color: Colors.blue),
                title: Text(_localResumePath != null ? 'New File Selected' : (_resumeUrl != null ? 'Resume Uploaded' : 'No Resume Added')),
                subtitle: Text(_localResumePath ?? (_resumeUrl ?? 'Upload your resume (PDF/DOCX)')),
                trailing: IconButton(
                  icon: const Icon(Icons.upload_file, color: Colors.blue),
                  onPressed: _pickResume,
                ),
              ),
              const SizedBox(height: 15),
            ],
            TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _bioController, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder())),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
