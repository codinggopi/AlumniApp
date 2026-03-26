import 'dart:convert';
import 'package:flutter/material.dart';
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
  String _connectionStatus = 'none'; // none | pending | accepted | rejected
  int? _connectionId;
  bool _connectLoading = false;

  bool get _isStudentAlumniPair {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    if (currentUser == null) return false;
    return (currentUser.role == 'student' && widget.user.role == 'alumni') ||
        (currentUser.role == 'alumni' && widget.user.role == 'student');
  }

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    if (currentUser == null || !_isStudentAlumniPair) return;

    try {
      final roleQuery = currentUser.role == 'student'
          ? 'student'
          : 'alumni&status=accepted';
      final response =
          await _api.get('/connections?user_id=${currentUser.userId}&role=$roleQuery');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        dynamic match;
        for (final connection in data) {
          final peer = currentUser.role == 'student'
              ? connection['receiver']
              : connection['requester'];
          if (peer != null && peer['user_id'] == widget.user.userId) {
            match = connection;
            break;
          }
        }
        if (match != null && mounted) {
          setState(() {
            _connectionId = match['connection_id'];
            _connectionStatus = match['status'];
          });
        }
      }
    } catch (e) {
      debugPrint('Check connection status error: $e');
    }
  }

  Future<void> _sendRequest() async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    if (currentUser == null) return;

    setState(() => _connectLoading = true);
    try {
      final response = await _api.post('/connections', {
        'requester_id': currentUser.userId,
        'receiver_id': widget.user.userId,
      });

      debugPrint('Send connection status: ${response.statusCode}');
      debugPrint('Send connection body: ${response.body}');

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _connectionStatus = 'pending';
          _connectionId = data['connection_id'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection request sent!'), backgroundColor: Colors.blue),
        );
      } else if (mounted) {
        final msg = jsonDecode(response.body)['detail'] ?? 'Could not send request';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint('Send connection error: $e');
    } finally {
      if (mounted) setState(() => _connectLoading = false);
    }
  }

  Future<void> _cancelRequest() async {
    if (_connectionId == null) return;
    setState(() => _connectLoading = true);
    try {
      final response = await _api.delete('/connections/$_connectionId');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _connectionStatus = 'none';
          _connectionId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection request withdrawn')),
        );
      }
    } catch (e) {
      debugPrint('Cancel connection error: $e');
    } finally {
      if (mounted) setState(() => _connectLoading = false);
    }
  }

  Widget _buildConnectButton() {
    if (_connectLoading) {
      return const SizedBox(height: 55, child: Center(child: CircularProgressIndicator()));
    }

    switch (_connectionStatus) {
      case 'pending':
        return SizedBox(
          width: double.infinity,
          height: 55,
          child: OutlinedButton.icon(
            onPressed: _cancelRequest,
            icon: const Icon(Icons.hourglass_empty, color: Colors.orange),
            label: const Text('REQUEST PENDING — Tap to Cancel', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orange, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        );
      case 'accepted':
        return SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text('CONNECTED', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        );
      case 'rejected':
        return SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _sendRequest,
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('SEND REQUEST AGAIN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        );
      default:
        return SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _sendRequest,
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('CONNECT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      appBar: AppBar(title: Text(widget.user.fullName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.grey[200],
                backgroundImage: (widget.user.profilePictureUrl != null && widget.user.profilePictureUrl!.isNotEmpty)
                    ? NetworkImage(widget.user.profilePictureUrl!.startsWith('http')
                        ? widget.user.profilePictureUrl!
                        : '${ApiService.baseUrl}${widget.user.profilePictureUrl}')
                    : null,
                child: (widget.user.profilePictureUrl == null || widget.user.profilePictureUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 70, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 30),
            Text(widget.user.fullName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.user.role.toUpperCase(),
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 25),
            const Divider(),
            const SizedBox(height: 20),
            _buildInfoRow(
              context,
              Icons.info_outline,
              'Current Status',
              widget.user.currentStatus ?? (widget.user.role == 'student'
                  ? 'Active Student'
                  : (widget.user.role == 'alumni' ? 'Professional Alumni' : 'Staff')),
            ),
            if (widget.user.role == 'student') ...[
              _buildInfoRow(context, Icons.history_edu, 'Educational Details', widget.user.educationalDetails ?? 'Not Provided'),
              if (widget.user.resumeUrl != null && widget.user.resumeUrl!.isNotEmpty)
                _buildInfoRow(context, Icons.description, 'Resume / CV', 'Available (Tap to View)'),
            ],
            if (widget.user.role == 'alumni') ...[
              _buildInfoRow(context, Icons.work, 'Current Position', widget.user.jobTitle ?? 'Not Specified'),
              _buildInfoRow(context, Icons.business_center, 'Company / Status', widget.user.company ?? 'Internal'),
            ],
            _buildInfoRow(context, Icons.business, 'Department', widget.user.department ?? 'N/A'),
            _buildInfoRow(context, Icons.calendar_today, 'Graduated Year', widget.user.graduationYear?.toString() ?? 'N/A'),
            _buildInfoRow(context, Icons.location_on, 'City', widget.user.city ?? 'N/A'),
            _buildInfoRow(context, Icons.email, 'Email', widget.user.email),
            if (widget.user.phone != null && widget.user.phone!.isNotEmpty)
              _buildInfoRow(context, Icons.phone, 'Phone', widget.user.phone!),
            const SizedBox(height: 25),
            const Text('About', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              widget.user.bio ?? 'This user has not provided a bio yet.',
              style: TextStyle(color: Colors.grey[800], fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 30),
            if (currentUser != null && currentUser.userId != widget.user.userId) ...[
              // Connect button (students → alumni only)
              if (currentUser.role == 'student' && widget.user.role == 'alumni') ...[
                _buildConnectButton(),
                const SizedBox(height: 15),
                _buildMessageAccessWidget(),
              ] else if (currentUser.role == 'alumni' && widget.user.role == 'student') ...[
                _buildMessageAccessWidget(),
              ] else ...[
                // For non-student→alumni combos (alumni→student, etc.) show Message freely
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ChatRoomScreen(otherUser: widget.user)),
                      );
                    },
                    icon: const Icon(Icons.message, color: Colors.white),
                    label: const Text('MESSAGE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
              // View internships (alumni only)
              if (widget.user.role == 'alumni') ...[
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => InternshipListScreen(postedBy: widget.user.userId)),
                      );
                    },
                    icon: const Icon(Icons.work_outline, color: Colors.blue),
                    label: Text(
                      'VIEW INTERNSHIPS BY ${widget.user.fullName.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageAccessWidget() {
    if (_connectionStatus == 'accepted') {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatRoomScreen(otherUser: widget.user)),
            );
          },
          icon: const Icon(Icons.message, color: Colors.white),
          label: const Text('MESSAGE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      );
    }

    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    final isStudent = currentUser?.role == 'student';
    final lockText = _connectionStatus == 'pending'
        ? (isStudent
            ? 'Messaging unlocks once alumni accepts your request'
            : 'Messaging unlocks after you accept this student request')
        : (isStudent
            ? 'Connect with this alumni to start messaging'
            : 'Accept this student connection request to start messaging');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: Colors.grey[400], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lockText,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue[300], size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
