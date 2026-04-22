import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/permission_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _deptController = TextEditingController();
  final _cityController = TextEditingController();
  final _eduController = TextEditingController();
  final _interestsController = TextEditingController();
  final _statusController = TextEditingController();
  final _designationController = TextEditingController();
  final _responsibilitiesController = TextEditingController();

  String? _profilePictureUrl;
  String? _localImagePath;
  String? _resumeUrl;
  String? _localResumePath;

  @override
  void initState() {
    super.initState();
    _loadFromUser();
  }

  void _loadFromUser() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    _nameController.text = user.fullName;
    _phoneController.text = user.phone ?? '';
    _bioController.text = user.bio ?? '';
    _deptController.text = user.department ?? '';
    _cityController.text = user.city ?? '';
    _eduController.text = user.educationalDetails ?? '';
    _interestsController.text = user.interests ?? '';
    _statusController.text = user.currentStatus ?? '';
    _designationController.text = user.designation ?? '';
    _responsibilitiesController.text = user.responsibilities ?? '';
    _profilePictureUrl = user.profilePictureUrl;
    _resumeUrl = user.resumeUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _deptController.dispose();
    _cityController.dispose();
    _eduController.dispose();
    _interestsController.dispose();
    _statusController.dispose();
    _designationController.dispose();
    _responsibilitiesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final granted = await PermissionService.checkMediaPermission(context);
    if (!granted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;

    if (file.path != null) {
      // Android / desktop with path available
      setState(() => _localImagePath = file.path);
    } else if (file.bytes != null) {
      // Web or when path not available — write to temp file
      final ext = file.extension ?? 'jpg';
      final tempPath = '${Directory.systemTemp.path}/picked_image_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(tempPath).writeAsBytes(file.bytes!);
      setState(() => _localImagePath = tempPath);
    }
  }




  Future<void> _pickResume() async {
    final granted = await PermissionService.checkMediaPermission(context);
    if (!granted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _localResumePath = result.files.single.path);
    }
  }

  Future<String?> _uploadFile(String? localPath, String? currentUrl) async {
    if (localPath == null) return currentUrl;
    try {
      final response = await ApiService().upload('/upload', localPath);
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        return data['url'] ?? currentUrl;
      } else {
        final body = await response.stream.bytesToString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed ${response.statusCode}: $body'), backgroundColor: Colors.red, duration: const Duration(seconds: 6)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 6)),
        );
      }
    }
    return currentUrl;
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      // Upload new image if picked
      String? imageUrl = _profilePictureUrl;
      if (_localImagePath != null) {
        final uploaded = await _uploadFile(_localImagePath, null);
        if (uploaded != null) {
          // Evict old cached image
          if (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty) {
            final fullOld = _profilePictureUrl!.startsWith('http')
                ? _profilePictureUrl!
                : '${ApiService.baseUrl}$_profilePictureUrl';
            NetworkImage(fullOld).evict();
          }
          imageUrl = uploaded;
        }
        // If upload failed, _uploadFile already showed snackbar — still save other fields
      }

      final newResumeUrl = await _uploadFile(_localResumePath, _resumeUrl);

      final Map<String, dynamic> updateData = {
        'full_name': _nameController.text,
        'phone': _phoneController.text,
        'bio': _bioController.text,
        'department': _deptController.text,
        'city': _cityController.text,
        'profile_picture_url': imageUrl,
        'current_status': _statusController.text,
        'designation': _designationController.text,
        'responsibilities': _responsibilitiesController.text,
      };

      if (auth.user?.role == 'student') {
        updateData.addAll({
          'educational_details': _eduController.text,
          'interests': _interestsController.text,
          'resume_url': newResumeUrl,
        });
      }

      final response = await ApiService().patch('/profile/${auth.user!.userId}', updateData);
      if (response.statusCode == 200) {
        await auth.checkAuth();
        _loadFromUser();
        if (mounted) {
          setState(() {
            _isEditing = false;
            _localImagePath = null;
            _localResumePath = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: ${response.statusCode} ${response.body}'), backgroundColor: Colors.red, duration: const Duration(seconds: 6)),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelEdit() {
    _loadFromUser();
    setState(() {
      _isEditing = false;
      _localImagePath = null;
      _localResumePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final role = user?.role ?? 'student';
    final isStudent = role == 'student';
    final isStaff = role == 'staff';
    final isAdmin = role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'My Profile'),
        leading: Navigator.canPop(context)
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))
            : null,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
              onPressed: () => setState(() => _isEditing = true),
            )
          else ...[
            TextButton(
              onPressed: _cancelEdit,
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _isEditing ? _buildEditForm(isStudent, isStaff, isAdmin) : _buildViewProfile(user, role),
            ),
      bottomNavigationBar: _isEditing
          ? Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
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
            )
          : null,
    );
  }

  // ── VIEW MODE ──────────────────────────────────────────────────────────────

  Widget _buildViewProfile(user, String role) {
    final avatarUrl = _profilePictureUrl;
    final isStudent = role == 'student';
    final isStaff = role == 'staff';
    final isAlumni = role == 'alumni';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar + name header
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey[200],
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl.startsWith('http') ? avatarUrl : '${ApiService.baseUrl}$avatarUrl')
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? const Icon(Icons.person, size: 55, color: Colors.grey)
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                user?.fullName ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 12),

        _viewEmailRow(user?.email ?? '', user?.userId),
        if (user?.phone != null && user!.phone!.isNotEmpty)
          _viewRow(Icons.phone, 'Phone', user.phone!),
        if (user?.city != null && user!.city!.isNotEmpty)
          _viewRow(Icons.location_on, 'City', user.city!),
        if (!isAdmin(role) && user?.department != null && user!.department!.isNotEmpty)
          _viewRow(Icons.business, 'Department', user.department!),
        if (user?.graduationYear != null && role != 'staff' && role != 'admin')
          _viewRow(Icons.calendar_today, 'Graduation Year', '${user!.graduationYear}'),

        // Role-specific
        if (isStaff) ...[
          if (user?.designation != null && user!.designation!.isNotEmpty)
            _viewRow(Icons.badge, 'Designation', user.designation!),
          if (user?.responsibilities != null && user!.responsibilities!.isNotEmpty)
            _viewRow(Icons.assignment_ind, 'Responsibilities', user.responsibilities!),
        ],
        if (isStudent) ...[
          if (user?.currentStatus != null && user!.currentStatus!.isNotEmpty)
            _viewRow(Icons.info_outline, 'Current Status', user.currentStatus!),
          if (user?.educationalDetails != null && user!.educationalDetails!.isNotEmpty)
            _viewRow(Icons.history_edu, 'Educational Details', user.educationalDetails!),
          if (user?.interests != null && user!.interests!.isNotEmpty)
            _viewRow(Icons.star_outline, 'Interests / Skills', user.interests!),
          if (user?.resumeUrl != null && user!.resumeUrl!.isNotEmpty)
            _viewResumeRow(user.resumeUrl!),
        ],
        if (isAlumni) ...[
          if (user?.currentStatus != null && user!.currentStatus!.isNotEmpty)
            _viewRow(Icons.info_outline, 'Current Status', user.currentStatus!),
          if (user?.jobTitle != null && user!.jobTitle!.isNotEmpty)
            _viewRow(Icons.work, 'Job Title', user.jobTitle!),
          if (user?.company != null && user!.company!.isNotEmpty)
            _viewRow(Icons.business_center, 'Company', user.company!),
          if (user?.experienceSummary != null && user!.experienceSummary!.isNotEmpty)
            _viewRow(Icons.notes, 'Experience', user.experienceSummary!),
        ],

        if (user?.bio != null && user!.bio!.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            user.bio!,
            style: TextStyle(color: Colors.grey[700], fontSize: 15, height: 1.5),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  bool isAdmin(String role) => role == 'admin';

  Widget _viewResumeRow(String url) {
    final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}$url';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.description, color: Colors.blue[300], size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resume / CV', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 2),
                const Text('Uploaded', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _launchUrl(fullUrl),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('View'),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open resume')),
        );
      }
    }
  }

  Widget _viewRow(IconData icon, String label, String value) {    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue[300], size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewEmailRow(String email, int? userId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.email, color: Colors.blue[300], size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: userId == null ? null : () => _showEmailChangeDialog(userId, email),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Change', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailChangeDialog(int userId, String currentEmail) {
    final newEmailCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    bool otpSent = false;
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Change Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newEmailCtrl,
                enabled: !otpSent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'New Email Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              if (otpSent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter OTP sent to new email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
              ],
            ],
          ),
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
            else if (!otpSent)
              ElevatedButton(
                onPressed: () async {
                  final newEmail = newEmailCtrl.text.trim();
                  if (newEmail.isEmpty || !newEmail.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid email')),
                    );
                    return;
                  }
                  setDlgState(() => loading = true);
                  final res = await ApiService().post('/profile/request-email-change', {
                    'user_id': userId,
                    'new_email': newEmail,
                  });
                  setDlgState(() => loading = false);
                  if (res.statusCode == 200) {
                    setDlgState(() => otpSent = true);
                  } else {
                    final msg = jsonDecode(res.body)['detail'] ?? 'Failed to send OTP';
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
                child: const Text('Send OTP'),
              )
            else
              ElevatedButton(
                onPressed: () async {
                  final otp = otpCtrl.text.trim();
                  if (otp.isEmpty) return;
                  setDlgState(() => loading = true);
                  final res = await ApiService().post('/profile/verify-email-change', {
                    'user_id': userId,
                    'new_email': newEmailCtrl.text.trim(),
                    'otp': otp,
                  });
                  setDlgState(() => loading = false);
                  if (res.statusCode == 200) {
                    Navigator.pop(ctx);
                    await Provider.of<AuthProvider>(context, listen: false).checkAuth();
                    if (mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Email updated successfully!')),
                      );
                    }
                  } else {
                    final msg = jsonDecode(res.body)['detail'] ?? 'Invalid OTP';
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
                child: const Text('Verify & Update'),
              ),
          ],
        ),
      ),
    );
  }

  // ── EDIT MODE ──────────────────────────────────────────────────────────────

  Widget _buildEditForm(bool isStudent, bool isStaff, bool isAdmin) {
    return Column(
      children: [
        // Avatar picker
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
                        ? NetworkImage(_profilePictureUrl!.startsWith('http')
                            ? _profilePictureUrl!
                            : '${ApiService.baseUrl}$_profilePictureUrl')
                        : null) as ImageProvider?,
                child: (_localImagePath == null &&
                        (_profilePictureUrl == null || _profilePictureUrl!.isEmpty))
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
        if (_localImagePath != null ||
            (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty))
          TextButton.icon(
            onPressed: () => setState(() {
              _localImagePath = null;
              _profilePictureUrl = null;
            }),
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            label: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 24),

        _field(_nameController, 'Full Name', Icons.person),
        if (!isAdmin && !isStaff) _field(_statusController, 'Current Status', Icons.info_outline),
        if (isStaff) ...[
          _field(_designationController, 'Designation', Icons.badge),
          _field(_responsibilitiesController, 'Responsibilities / Office Info', Icons.assignment_ind, maxLines: 2),
        ],
        _field(_phoneController, 'Phone Number', Icons.phone),
        if (!isAdmin) _field(_deptController, 'Department', Icons.business),
        if (isStudent) ...[
          _field(_eduController, 'Educational Details', Icons.history_edu, maxLines: 2),
          _field(_interestsController, 'Interests / Skills', Icons.star_outline),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Resume / CV', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.description, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _localResumePath != null
                            ? 'New File Selected'
                            : (_resumeUrl != null ? 'Resume Uploaded' : 'No Resume'),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _localResumePath != null
                            ? _localResumePath!.split('/').last.split('\\').last
                            : (_resumeUrl != null ? 'Tap View to open' : 'PDF / DOC / DOCX'),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // View button — only if resume already uploaded
                if (_resumeUrl != null && _localResumePath == null)
                  TextButton.icon(
                    onPressed: () {
                      final fullUrl = _resumeUrl!.startsWith('http')
                          ? _resumeUrl!
                          : '${ApiService.baseUrl}$_resumeUrl';
                      _launchUrl(fullUrl);
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                // Upload button
                IconButton(
                  icon: const Icon(Icons.upload_file, color: Colors.blue),
                  tooltip: 'Upload Resume',
                  onPressed: _pickResume,
                ),
              ],
            ),
          ),
        ],
        _field(_cityController, 'City', Icons.location_on),
        _field(_bioController, 'Bio', Icons.notes, maxLines: 3),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
