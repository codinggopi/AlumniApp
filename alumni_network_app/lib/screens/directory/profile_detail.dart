import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user.dart';
import '../chat/chat_room_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../internships/internship_list.dart';

class ProfileDetailScreen extends StatefulWidget {
  final User user;
  const ProfileDetailScreen({super.key, required this.user});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final ApiService _api = ApiService();
  String _connectionStatus = 'none';
  int? _connectionId;
  bool _connectLoading = false;

  // Full profile fetched from /profile/{id}
  User? _fullUser;
  bool _profileLoading = true;

  User get _user => _fullUser ?? widget.user;

  bool get _isStudentAlumniPair {
    final me = Provider.of<AuthProvider>(context, listen: false).user;
    if (me == null) return false;
    return (me.role == 'student' && _user.role == 'alumni') ||
        (me.role == 'alumni' && _user.role == 'student');
  }

  @override
  void initState() {
    super.initState();
    _fetchFullProfile();
    _checkConnectionStatus();
  }

  // ── Fetch complete profile from single source of truth ────────────────────
  Future<void> _fetchFullProfile() async {
    try {
      final response = await _api.get('/profile/${widget.user.userId}');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _fullUser = User.fromJson(jsonDecode(response.body));
          _profileLoading = false;
        });
      } else {
        if (mounted) setState(() => _profileLoading = false);
      }
    } catch (e) {
      debugPrint('Fetch full profile error: $e');
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _checkConnectionStatus() async {
    final me = Provider.of<AuthProvider>(context, listen: false).user;
    if (me == null || !_isStudentAlumniPair) return;
    try {
      final roleQuery = me.role == 'student' ? 'student' : 'alumni&status=accepted';
      final response = await _api.get('/connections?user_id=${me.userId}&role=$roleQuery');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (final c in data) {
          final peer = me.role == 'student' ? c['receiver'] : c['requester'];
          if (peer != null && peer['user_id'] == widget.user.userId) {
            if (mounted) setState(() { _connectionId = c['connection_id']; _connectionStatus = c['status']; });
            break;
          }
        }
      }
    } catch (e) { debugPrint('Check connection error: $e'); }
  }

  Future<void> _sendRequest() async {
    final me = Provider.of<AuthProvider>(context, listen: false).user;
    if (me == null) return;
    setState(() => _connectLoading = true);
    try {
      final response = await _api.post('/connections', {'requester_id': me.userId, 'receiver_id': _user.userId});
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() { _connectionStatus = 'pending'; _connectionId = data['connection_id']; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection request sent!')));
      } else if (mounted) {
        final msg = jsonDecode(response.body)['detail'] ?? 'Could not send request';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) { debugPrint('Send connection error: $e'); }
    finally { if (mounted) setState(() => _connectLoading = false); }
  }

  Future<void> _cancelRequest() async {
    if (_connectionId == null) return;
    setState(() => _connectLoading = true);
    try {
      final response = await _api.delete('/connections/$_connectionId');
      if (response.statusCode == 200 && mounted) {
        setState(() { _connectionStatus = 'none'; _connectionId = null; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection request withdrawn')));
      }
    } catch (e) { debugPrint('Cancel connection error: $e'); }
    finally { if (mounted) setState(() => _connectLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final me = Provider.of<AuthProvider>(context).user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_user.fullName)),
      body: _profileLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Avatar + name ──────────────────────────────────────────
                  Center(
                    child: Column(children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: theme.cardColor,
                        backgroundImage: (_user.profilePictureUrl != null && _user.profilePictureUrl!.isNotEmpty)
                            ? NetworkImage(_user.profilePictureUrl!.startsWith('http')
                                ? _user.profilePictureUrl!
                                : '${ApiService.baseUrl}${_user.profilePictureUrl}')
                            : null,
                        child: (_user.profilePictureUrl == null || _user.profilePictureUrl!.isEmpty)
                            ? Icon(Icons.person, size: 60, color: theme.iconTheme.color)
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Text(_user.fullName, style: theme.textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_user.role.toUpperCase(),
                            style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── Contact info ───────────────────────────────────────────
                  _row(Icons.email_outlined, 'Email', _user.email),
                  if (_user.phone?.isNotEmpty == true)
                    _row(Icons.phone_outlined, 'Phone', _user.phone!),
                  if (_user.city?.isNotEmpty == true)
                    _row(Icons.location_on_outlined, 'City', _user.city!),
                  if (_user.role != 'admin' && _user.department?.isNotEmpty == true)
                    _row(Icons.business_outlined, 'Department', _user.department!),
                  if (_user.role != 'staff' && _user.role != 'admin' && _user.graduationYear != null)
                    _row(Icons.school_outlined, 'Graduation Year', '${_user.graduationYear}'),

                  // ── Role-specific fields ───────────────────────────────────
                  if (_user.role == 'student') ...[
                    if (_user.currentStatus?.isNotEmpty == true)
                      _row(Icons.info_outline, 'Current Status', _user.currentStatus!),
                    if (_user.educationalDetails?.isNotEmpty == true)
                      _row(Icons.history_edu_outlined, 'Educational Details', _user.educationalDetails!),
                    if ((_user.interests?.isNotEmpty == true) || (_user.skills?.isNotEmpty == true))
                      _row(Icons.star_outline, 'Skills / Interests',
                          [_user.skills, _user.interests].where((v) => v?.isNotEmpty == true).join(', ')),
                    if (_user.resumeUrl?.isNotEmpty == true)
                      _resumeRow(_user.resumeUrl!),
                  ],

                  if (_user.role == 'alumni') ...[
                    if (_user.currentStatus?.isNotEmpty == true)
                      _row(Icons.info_outline, 'Current Status', _user.currentStatus!),
                    if (_user.jobTitle?.isNotEmpty == true)
                      _row(Icons.work_outline, 'Job Title', _user.jobTitle!),
                    if (_user.company?.isNotEmpty == true)
                      _row(Icons.business_center_outlined, 'Company', _user.company!),
                    if (_user.experienceSummary?.isNotEmpty == true)
                      _row(Icons.notes_outlined, 'Experience', _user.experienceSummary!),
                  ],

                  if (_user.role == 'staff') ...[
                    if (_user.designation?.isNotEmpty == true)
                      _row(Icons.badge_outlined, 'Designation', _user.designation!),
                    if (_user.responsibilities?.isNotEmpty == true)
                      _row(Icons.assignment_ind_outlined, 'Responsibilities', _user.responsibilities!),
                  ],

                  // ── Bio ────────────────────────────────────────────────────
                  if (_user.bio?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text('About', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_user.bio!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 16),

                  // ── Action buttons ─────────────────────────────────────────
                  if (me != null && me.userId != _user.userId) ...[
                    if (me.role == 'student' && _user.role == 'alumni') ...[
                      _buildConnectButton(),
                      const SizedBox(height: 12),
                      _buildMessageWidget(me),
                    ] else if (me.role == 'alumni' && _user.role == 'student') ...[
                      _buildMessageWidget(me),
                    ] else ...[
                      _messageButton(),
                    ],
                    if (_user.role == 'alumni') ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => InternshipListScreen(postedBy: _user.userId))),
                          icon: Icon(Icons.work_outline, color: theme.primaryColor),
                          label: Text('View Internships by ${_user.fullName}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.primaryColor, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Theme.of(context).primaryColor, size: 20),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ])),
    ]),
  );

  Widget _resumeRow(String url) {
    final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}$url';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.description_outlined, color: Theme.of(context).primaryColor, size: 20),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Resume / CV', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          const Text('Uploaded', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ])),
        TextButton.icon(
          onPressed: () async {
            try { await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication); }
            catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open resume'))); }
          },
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('View'),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).primaryColor),
        ),
      ]),
    );
  }

  Widget _messageButton() => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton.icon(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(otherUser: _user))),
      icon: const Icon(Icons.message),
      label: const Text('Message', style: TextStyle(fontWeight: FontWeight.bold)),
    ),
  );

  Widget _buildConnectButton() {
    if (_connectLoading) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
    final theme = Theme.of(context);
    switch (_connectionStatus) {
      case 'pending':
        return SizedBox(width: double.infinity, height: 50,
          child: OutlinedButton.icon(
            onPressed: _cancelRequest,
            icon: const Icon(Icons.hourglass_empty, color: Colors.orange),
            label: const Text('Request Pending — Tap to Cancel', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ));
      case 'accepted':
        return SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle),
            label: const Text('Connected', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ));
      default:
        return SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton.icon(
            onPressed: _sendRequest,
            icon: const Icon(Icons.person_add),
            label: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ));
    }
  }

  Widget _buildMessageWidget(User me) {
    if (_connectionStatus == 'accepted') return _messageButton();
    final isStudent = me.role == 'student';
    final lockText = _connectionStatus == 'pending'
        ? (isStudent ? 'Messaging unlocks once alumni accepts your request' : 'Messaging unlocks after you accept this student request')
        : (isStudent ? 'Connect with this alumni to start messaging' : 'Accept this student connection request to start messaging');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lock_outline, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(lockText, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13), textAlign: TextAlign.center)),
      ]),
    );
  }
}
