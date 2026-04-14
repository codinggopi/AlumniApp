import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import '../admin/user_list_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _handleRegister() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a role.')));
      return;
    }
    setState(() => _isLoading = true);
    final api = ApiService();

    try {
      final response = await api.post('/auth/register', {
        'email': _emailController.text,
        'password': _passwordController.text,
        'full_name': _nameController.text,
        'role': _selectedRole!,
      });

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful...!'),
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Registration failed.')));
      }
    } catch (e) {
      debugPrint('Register error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleBulkUpload() async {
    // FileType.custom can silently fail on web — use any and validate manually
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    debugPrint('FilePicker result: $result');

    if (result == null || result.files.isEmpty) {
      debugPrint('No file picked');
      return;
    }

    final pickedFile = result.files.single;
    final filename = pickedFile.name.toLowerCase();
    final bytes = pickedFile.bytes;

    debugPrint('File: $filename | bytes: ${bytes?.length}');

    if (!filename.endsWith('.csv') &&
        !filename.endsWith('.xlsx') &&
        !filename.endsWith('.xls')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a .csv or .xlsx file'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read file. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      debugPrint('Sending to /auth/bulk-register...');

      // On web, always use bytes — path is not available
      final http.StreamedResponse response = await api.uploadBytes(
        '/auth/bulk-register',
        bytes,
        pickedFile.name,
      );

      final body = await response.stream.bytesToString();
      debugPrint('Status: ${response.statusCode} | Body: $body');

      if (!mounted) return;

      if (response.statusCode == 401 || response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auth error (${response.statusCode}). Are you logged in as admin?',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${response.statusCode}: $body'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final data = jsonDecode(body);
      final registered = data['registered'] ?? 0;
      final skipped = data['skipped'] ?? 0;
      final errorsCount = data['errors'] ?? 0;
      final details = data['details'] ?? {};
      final successList = List<dynamic>.from(details['success'] ?? []);
      final skippedList = List<dynamic>.from(details['skipped'] ?? []);
      final errorList = List<dynamic>.from(details['errors'] ?? []);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                registered > 0 ? Icons.check_circle : Icons.info_outline,
                color: registered > 0 ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              const Text('Bulk Upload Result'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Summary chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _summaryChip('Registered', registered, Colors.green),
                      _summaryChip('Skipped', skipped, Colors.orange),
                      _summaryChip('Errors', errorsCount, Colors.red),
                    ],
                  ),
                  if (successList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Registered Users:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...successList.map(
                      (u) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${u['email']} (${u['role']})',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (skippedList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Skipped (already exist):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...skippedList.map(
                      (u) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.skip_next,
                              size: 14,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${u['email']}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (errorList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Errors:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...errorList.map(
                      (u) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 14,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Row ${u['row']}: ${u['reason']}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (registered > 0) ...[
              TextButton.icon(
                icon: const Icon(Icons.people),
                label: const Text('View Students'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserListScreen(
                        role: 'student',
                        title: 'All Students',
                      ),
                    ),
                  );
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.school),
                label: const Text('View Alumni'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserListScreen(
                        role: 'alumni',
                        title: 'All Alumni',
                      ),
                    ),
                  );
                },
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Bulk upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bulk upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Register User',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [Colors.indigo, Colors.blueAccent],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_add,
                        size: 50,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Join the Network',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Register As',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select Role'),
                        items: ['student', 'alumni', 'staff', 'admin']
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(role.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedRole = value),
                      ),
                      const SizedBox(height: 30),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _handleRegister,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: const Text(
                                      'REGISTER NOW',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Row(
                                  children: [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        'OR',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: _handleBulkUpload,
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text(
                                      'BULK UPLOAD (CSV / Excel)',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blueAccent,
                                      side: const BorderSide(
                                        color: Colors.blueAccent,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Required: full_name, email, password, role\nOptional: phone, department, graduation_year, city, company, job_title',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                      //const SizedBox(height: 20),
                      //
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
