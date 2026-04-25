import 'package:flutter/material.dart';
import 'dart:convert';
import '../../models/user.dart';
import '../../services/api_service.dart';

class AdminEditProfileScreen extends StatefulWidget {
  final User user;
  const AdminEditProfileScreen({super.key, required this.user});

  @override
  State<AdminEditProfileScreen> createState() => _AdminEditProfileScreenState();
}

class _AdminEditProfileScreenState extends State<AdminEditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _deptCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _statusCtrl;
  late final TextEditingController _designationCtrl;
  late final TextEditingController _responsibilitiesCtrl;
  late final TextEditingController _eduCtrl;
  late final TextEditingController _interestsCtrl;
  late final TextEditingController _gradYearCtrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl             = TextEditingController(text: u.fullName);
    _phoneCtrl            = TextEditingController(text: u.phone ?? '');
    _bioCtrl              = TextEditingController(text: u.bio ?? '');
    _deptCtrl             = TextEditingController(text: u.department ?? '');
    _cityCtrl             = TextEditingController(text: u.city ?? '');
    _statusCtrl           = TextEditingController(text: u.currentStatus ?? '');
    _designationCtrl      = TextEditingController(text: u.designation ?? '');
    _responsibilitiesCtrl = TextEditingController(text: u.responsibilities ?? '');
    _eduCtrl              = TextEditingController(text: u.educationalDetails ?? '');
    _interestsCtrl        = TextEditingController(text: u.interests ?? '');
    _gradYearCtrl         = TextEditingController(text: u.graduationYear?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _bioCtrl, _deptCtrl, _cityCtrl,
        _statusCtrl, _designationCtrl, _responsibilitiesCtrl, _eduCtrl,
        _interestsCtrl, _gradYearCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> data = {
        'full_name':        _nameCtrl.text.trim(),
        'phone':            _phoneCtrl.text.trim(),
        'bio':              _bioCtrl.text.trim(),
        'department':       _deptCtrl.text.trim(),
        'city':             _cityCtrl.text.trim(),
        'current_status':   _statusCtrl.text.trim(),
        'designation':      _designationCtrl.text.trim(),
        'responsibilities': _responsibilitiesCtrl.text.trim(),
      };

      final role = widget.user.role;
      if (_gradYearCtrl.text.trim().isNotEmpty && role != 'staff') {
        data['graduation_year'] = int.tryParse(_gradYearCtrl.text.trim());
      }
      if (role == 'student') {
        data['educational_details'] = _eduCtrl.text.trim();
        data['interests']           = _interestsCtrl.text.trim();
      }

      final response = await ApiService().patch('/profile/${widget.user.userId}', data);
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${response.body}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Admin direct email change — no OTP ────────────────────────────────────
  void _showEmailChangeDialog() {
    final emailCtrl = TextEditingController(text: widget.user.email);
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Row(children: [
            Icon(Icons.email_outlined, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(width: 8),
            const Text('Change Email'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // Admin badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.admin_panel_settings, size: 15, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Admin override — no OTP required',
                    style: TextStyle(fontSize: 12, color: Colors.orange[800], fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'New Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              ElevatedButton(
                onPressed: () async {
                  final newEmail = emailCtrl.text.trim();
                  if (newEmail.isEmpty || !newEmail.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid email address')),
                    );
                    return;
                  }
                  if (newEmail == widget.user.email) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New email is same as current email')),
                    );
                    return;
                  }
                  setDlg(() => loading = true);
                  final res = await ApiService().post('/profile/admin-change-email', {
                    'user_id': widget.user.userId,
                    'new_email': newEmail,
                  });
                  setDlg(() => loading = false);
                  if (res.statusCode == 200) {
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Email updated to $newEmail')),
                      );
                      Navigator.pop(context, true); // refresh user list
                    }
                  } else {
                    final msg = jsonDecode(res.body)['detail'] ?? 'Failed to update email';
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
                  }
                },
                child: const Text('Update Email'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user.role;
    final isStudent = role == 'student';
    final isStaff   = role == 'staff';
    final isAlumni  = role == 'alumni';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit — ${widget.user.fullName}'),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _roleColor(role).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(role.toUpperCase(),
                style: TextStyle(color: _roleColor(role), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Email row with Change button ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.email_outlined, size: 20, color: theme.primaryColor),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Email', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(widget.user.email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        ])),
                        TextButton.icon(
                          onPressed: _showEmailChangeDialog,
                          icon: Icon(Icons.edit, size: 14, color: theme.primaryColor),
                          label: Text('Change', style: TextStyle(fontSize: 12, color: theme.primaryColor)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                      ]),
                    ),
                  ),

                  _field(_nameCtrl, 'Full Name', Icons.person),
                  _field(_phoneCtrl, 'Phone', Icons.phone),
                  if (!isStaff && role != 'admin')
                    _field(_deptCtrl, 'Department', Icons.business),
                  if (!isStaff && role != 'admin')
                    _field(_gradYearCtrl, 'Graduation Year', Icons.calendar_today,
                        keyboardType: TextInputType.number),
                  _field(_cityCtrl, 'City', Icons.location_on),

                  if (isStudent) ...[
                    _field(_statusCtrl, 'Current Status', Icons.info_outline),
                    _field(_eduCtrl, 'Educational Details', Icons.history_edu, maxLines: 2),
                    _field(_interestsCtrl, 'Interests / Skills', Icons.star_outline),
                  ],

                  if (isAlumni)
                    _field(_statusCtrl, 'Current Status', Icons.info_outline),

                  if (isStaff) ...[
                    _field(_designationCtrl, 'Designation', Icons.badge),
                    _field(_responsibilitiesCtrl, 'Responsibilities', Icons.assignment_ind, maxLines: 2),
                  ],

                  _field(_bioCtrl, 'Bio', Icons.notes, maxLines: 3),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':   return Colors.orange;
      case 'staff':   return Colors.brown;
      case 'alumni':  return Colors.teal;
      case 'student': return Colors.indigo;
      default:        return Colors.grey;
    }
  }
}

