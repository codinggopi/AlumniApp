import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'student';
  bool _isLoading = false;
  bool _otpSent = false;

  void _sendOtp() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final response = await ApiService().post('/send-otp', {'email': _emailController.text});
      if (response.statusCode == 200) {
        setState(() => _otpSent = true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to your email')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _reset() async {
    if (_otpController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final response = await ApiService().post('/auth/reset-password', {
        'email': _emailController.text,
        'role': _selectedRole,
        'otp': _otpController.text,
        'new_password': _passwordController.text,
      });

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!')));
          Navigator.pop(context);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect OTP or expired')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Could not connect to server')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              enabled: !_otpSent,
              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            if (!_otpSent) ...[
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Select Role', border: OutlineInputBorder()),
                items: ['student', 'alumni', 'admin'].map((role) {
                  return DropdownMenuItem(value: role, child: Text(role.toUpperCase()));
                }).toList(),
                onChanged: (val) => setState(() => _selectedRole = val!),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(onPressed: _sendOtp, child: const Text('SEND OTP')),
                    ),
            ] else ...[
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(labelText: 'Enter OTP', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _reset,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        child: const Text('VERIFY & RESET'),
                      ),
                    ),
              TextButton(onPressed: () => setState(() => _otpSent = false), child: const Text('Edit Email')),
            ],
          ],
        ),
      ),
    );
  }
}
