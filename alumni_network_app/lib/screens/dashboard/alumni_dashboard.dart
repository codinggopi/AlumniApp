import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../connections/connection_requests_screen.dart';
import 'alumni_leaderboard_screen.dart';
import 'alumni_mentorship_screen.dart';

class AlumniDashboard extends StatefulWidget {
  final Function(int)? onTabChange;
  const AlumniDashboard({super.key, this.onTabChange});
  @override
  State<AlumniDashboard> createState() => _AlumniDashboardState();
}

class _AlumniDashboardState extends State<AlumniDashboard> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _points;
  List<dynamic> _slots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    try {
      final r1 = await ApiService().get('/alumni/dashboard');
      final r2 = await ApiService().get('/alumni/my-points');
      final r3 = user != null ? await ApiService().get('/mentorship/slots/${user.userId}') : null;
      if (mounted) {
        setState(() {
          if (r1.statusCode == 200) _data = jsonDecode(r1.body);
          if (r2.statusCode == 200) _points = jsonDecode(r2.body);
          if (r3 != null && r3.statusCode == 200) _slots = jsonDecode(r3.body);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    if (user == null || _loading) return const Center(child: CircularProgressIndicator());
    final stats = _data?['stats'] ?? {};
    final pending = (_data?['pending_requests'] as List?) ?? [];
    final activity = (_data?['recent_activity'] as List?) ?? [];
    final badges = (_points?['badges'] as List?) ?? [];
    final points = _points?['points'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Impact message
        _buildImpactCard(stats, user.fullName),
        const SizedBox(height: 16),
        // Stats row
        _buildStatsRow(stats),
        const SizedBox(height: 20),
        // Points & Badges
        _buildPointsBadges(points, badges),
        const SizedBox(height: 20),
        // Pending connection requests
        if (pending.isNotEmpty) ...[
          _sectionHeader('🤝 Student Requests', trailing: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionRequestsScreen())),
            child: const Text('See All'),
          )),
          _buildPendingRequests(pending),
          const SizedBox(height: 20),
        ],
        // Mentorship slots
        _sectionHeader('🎓 My Mentorship Slots', trailing: TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlumniMentorshipScreen()))
              .then((_) => _fetch()),
          child: const Text('Manage'),
        )),
        _buildMentorshipSlots(),
        const SizedBox(height: 20),
        // Recent activity
        if (activity.isNotEmpty) ...[
          _sectionHeader('🕐 Recent Activity'),
          _buildActivity(activity),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    ),
  );

  Widget _buildImpactCard(Map stats, String name) {
    final connected = stats['students_connected'] ?? 0;
    final posted = stats['internships_posted'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF00897B).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            const Text('Your Impact', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          if (connected > 0)
            Text('You helped $connected student${connected > 1 ? 's' : ''} this month 🎓',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          if (posted > 0) ...[
            const SizedBox(height: 4),
            Text('You posted $posted internship${posted > 1 ? 's' : ''} 💼',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          if (connected == 0 && posted == 0)
            const Text('Start connecting with students and posting opportunities!',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map stats) {
    final items = [
      {'icon': Icons.work, 'label': 'Posted', 'value': '${stats['internships_posted'] ?? 0}', 'color': const Color(0xFF1565C0)},
      {'icon': Icons.people, 'label': 'Connected', 'value': '${stats['students_connected'] ?? 0}', 'color': const Color(0xFF00897B)},
      {'icon': Icons.chat_bubble, 'label': 'Unread', 'value': '${stats['unread_messages'] ?? 0}', 'color': const Color(0xFFAD1457)},
      {'icon': Icons.inbox, 'label': 'Applicants', 'value': '${stats['new_applicants'] ?? 0}', 'color': const Color(0xFFF57C00)},
    ];
    return Row(
      children: items.map((item) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
          ),
          child: Column(children: [
            Icon(item['icon'] as IconData, color: item['color'] as Color, size: 20),
            const SizedBox(height: 4),
            Text(item['value'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: item['color'] as Color)),
            Text(item['label'] as String, style: const TextStyle(fontSize: 9, color: Color(0xFF9E9E9E))),
          ]),
        ),
      )).toList(),
    );
  }

  Widget _buildPointsBadges(int points, List badges) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('⭐ My Points & Badges', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlumniLeaderboardScreen())),
            child: const Text('Leaderboard →', style: TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Text('🏅', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text('$points pts', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFFF57C00))),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: badges.isEmpty
                ? const Text('Complete actions to earn badges!', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)))
                : Wrap(
                    spacing: 8,
                    children: badges.map<Widget>((b) => Chip(
                      label: Text('${b['icon']} ${b['name']}', style: const TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFFE3F2FD),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
          ),
        ]),
      ],
    ),
  );

  Widget _buildPendingRequests(List pending) => Column(
    children: pending.take(3).map((r) {
      final s = r['student'];
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE3F2FD),
            backgroundImage: (s['profile_picture_url'] != null && s['profile_picture_url'].toString().isNotEmpty)
                ? NetworkImage(s['profile_picture_url'].toString().startsWith('http')
                    ? s['profile_picture_url'] : '${ApiService.baseUrl}${s['profile_picture_url']}')
                : null,
            child: (s['profile_picture_url'] == null || s['profile_picture_url'].toString().isEmpty)
                ? const Icon(Icons.person, size: 20, color: Color(0xFF1565C0)) : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(s['department'] ?? 'Student', style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
          ])),
          Row(children: [
            _actionBtn('Accept', const Color(0xFF2E7D32), () => _respond(r['connection_id'], 'accepted')),
            const SizedBox(width: 6),
            _actionBtn('Decline', Colors.red, () => _respond(r['connection_id'], 'rejected')),
          ]),
        ]),
      );
    }).toList(),
  );

  Widget _actionBtn(String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  );

  Future<void> _respond(int connectionId, String status) async {
    await ApiService().patch('/connections/$connectionId', {'status': status});
    _fetch();
  }

  Widget _buildMentorshipSlots() {
    if (_slots.isEmpty) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlumniMentorshipScreen()))
            .then((_) => _fetch()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00897B).withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add, color: Color(0xFF00897B), size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('No slots added yet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('Tap to add your availability for students', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
            ])),
            const Icon(Icons.chevron_right, color: Color(0xFF00897B)),
          ]),
        ),
      );
    }

    return Column(
      children: _slots.map((s) {
        final booked = s['booked'] as int;
        final max = s['max_students'] as int;
        final available = s['available'] as int;
        final fillRatio = max > 0 ? booked / max : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: available > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.schedule,
                  color: available > 0 ? const Color(0xFF2E7D32) : Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['day']}  ${s['time_from']} – ${s['time_to']}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fillRatio.toDouble(),
                    backgroundColor: const Color(0xFFE8F5E9),
                    color: available > 0 ? const Color(0xFF2E7D32) : Colors.red,
                    minHeight: 5,
                  ),
                )),
                const SizedBox(width: 8),
                Text('$booked/$max',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: available > 0 ? const Color(0xFF2E7D32) : Colors.red)),
              ]),
              Text(available > 0 ? '$available slot${available > 1 ? 's' : ''} available' : 'Fully booked',
                  style: TextStyle(fontSize: 11, color: available > 0 ? const Color(0xFF9E9E9E) : Colors.red)),
            ])),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildActivity(List activity) => Column(
    children: activity.map((a) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFE8F5E9),
          child: Icon(_actIcon(a['type']), size: 16, color: const Color(0xFF00897B)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(a['message'] ?? '', style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text(_timeAgo(a['created_at']), style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
      ]),
    )).toList(),
  );

  IconData _actIcon(String? type) {
    switch (type) {
      case 'message': return Icons.chat_bubble_outline;
      case 'event': return Icons.event_outlined;
      case 'connection': return Icons.person_add_outlined;
      default: return Icons.notifications_outlined;
    }
  }
}
