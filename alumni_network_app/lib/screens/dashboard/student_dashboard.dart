import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../directory/alumni_directory.dart';
import '../profile/edit_profile_screen.dart';

class StudentDashboard extends StatefulWidget {
  final Function(int)? onTabChange;
  const StudentDashboard({super.key, this.onTabChange});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with RouteAware {
  Map<String, dynamic>? _data;
  bool _apiLoading = true;
  int _streak = 0;
  bool _challengeDone = false;
  final RouteObserver<ModalRoute<void>> _routeObserver = RouteObserver<ModalRoute<void>>();

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    _loadStreak();
    _doCheckIn();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-fetch when navigating back to this screen
    final route = ModalRoute.of(context);
    if (route != null) _routeObserver.subscribe(this, route);
  }

  @override
  void didPopNext() {
    // Called when user comes back to this screen
    _fetchDashboard();
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _fetchDashboard() async {
    try {
      final res = await ApiService().get('/student/dashboard');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _data = jsonDecode(res.body);
          _apiLoading = false;
        });
      } else {
        debugPrint('[StudentDashboard] API error: ${res.statusCode} ${res.body}');
        if (mounted) setState(() => _apiLoading = false);
      }
    } catch (e) {
      debugPrint('[StudentDashboard] Exception: $e');
      if (mounted) setState(() => _apiLoading = false);
    }
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final streak = prefs.getInt('streak_count') ?? 0;
    final done = prefs.getBool('challenge_done_${_weekKey()}') ?? false;
    if (mounted) {
      setState(() {
        _streak = streak;
        _challengeDone = done;
      });
    }
  }

  Future<void> _doCheckIn() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final lastStr = prefs.getString('streak_last_date');

    if (lastStr == todayStr) return; // already checked in today

    int streak = prefs.getInt('streak_count') ?? 0;
    if (lastStr != null) {
      final last = DateTime.tryParse(lastStr);
      if (last != null) {
        final diff = today.difference(last).inDays;
        streak = diff == 1 ? streak + 1 : 1; // consecutive = +1, else reset
      }
    } else {
      streak = 1;
    }

    await prefs.setInt('streak_count', streak);
    await prefs.setString('streak_last_date', todayStr);
    if (mounted) setState(() => _streak = streak);
  }

  String _weekKey() {
    final now = DateTime.now();
    return 'week_${now.year}_${_weekNumber(now)}';
  }

  int _weekNumber(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    return ((date.difference(firstDay).inDays) / 7).ceil();
  }

  Future<void> _markChallengeDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('challenge_done_${_weekKey()}', true);
    setState(() => _challengeDone = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🏆 Challenge completed! Great work!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  int _profileCompletion(User user) {
    final fields = [
      user.fullName.isNotEmpty,
      user.phone?.isNotEmpty ?? false,
      user.department?.isNotEmpty ?? false,
      user.city?.isNotEmpty ?? false,
      user.bio?.isNotEmpty ?? false,
      user.profilePictureUrl?.isNotEmpty ?? false,
      user.educationalDetails?.isNotEmpty ?? false,
      (user.interests?.isNotEmpty ?? false) || (user.skills?.isNotEmpty ?? false),
      user.resumeUrl?.isNotEmpty ?? false,
      user.currentStatus?.isNotEmpty ?? false,
    ];
    return ((fields.where((f) => f).length / fields.length) * 100).round();
  }

  String _missingField(User user) {
    // Return the first missing field in priority order
    if (user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty) return 'profile photo';
    if (user.phone == null || user.phone!.isEmpty) return 'phone number';
    if (user.department == null || user.department!.isEmpty) return 'department';
    if (user.city == null || user.city!.isEmpty) return 'city';
    if (user.currentStatus == null || user.currentStatus!.isEmpty) return 'current status';
    if (user.educationalDetails == null || user.educationalDetails!.isEmpty) return 'educational details';
    final hasSkills = (user.interests?.isNotEmpty ?? false) || (user.skills?.isNotEmpty ?? false);
    if (!hasSkills) return 'skills & interests';
    if (user.resumeUrl == null || user.resumeUrl!.isEmpty) return 'resume';
    if (user.bio == null || user.bio!.isEmpty) return 'bio';
    return 'more details';
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
    } catch (_) {
      return '';
    }
  }

  IconData _activityIcon(String? type) {
    switch (type) {
      case 'message': return Icons.chat_bubble_outline;
      case 'event': return Icons.event_outlined;
      case 'broadcast': return Icons.campaign_outlined;
      case 'connection': return Icons.person_add_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    if (user == null) return const SizedBox.shrink();

    final completion = _profileCompletion(user);
    final notices = (_data?['notices'] as List?) ?? [];
    final featured = _data?['featured_internship'];
    final activity = (_data?['recent_activity'] as List?) ?? [];
    final mentors = (_data?['mentors'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Profile Completion Bar
        if (completion < 100) _buildCompletionBar(completion, user),

        // 2. Daily Streak
        _buildStreakCard(),

        // 3. My Stats Row — always show (zeros while loading)
        _buildStatsRow(_data?['stats'] ?? {'connections': 0, 'unread_messages': 0, 'applications_sent': 0}),
        // 4. Notice Board
        _sectionHeader('📢 Notice Board'),
        _apiLoading ? _buildSkeletonCards() : notices.isNotEmpty
            ? _buildNoticeBoard(notices)
            : _buildEmptyCard('No notices yet. Check back soon!', Icons.campaign_outlined),

        // 5. Featured Internship
        _sectionHeader('💼 Featured Internship'),
        _apiLoading ? _buildSkeletonCard() : featured != null
            ? _buildFeaturedInternship(featured)
            : _buildEmptyCard('No open internships right now.', Icons.work_outline),

        // 6. Weekly Challenge
        _buildWeeklyChallenge(),

        // 7. Find a Mentor
        _sectionHeader('🎓 Find a Mentor'),
        _apiLoading ? _buildSkeletonCard() : mentors.isNotEmpty
            ? _buildMentorSection(mentors)
            : _buildEmptyCard('No mentors available right now.', Icons.school_outlined),

        // 8. My Resume
        _buildResumeCard(user),

        // 9. Recent Activity
        _sectionHeader('🕐 Recent Activity'),
        _apiLoading ? _buildSkeletonCards(count: 3) : activity.isNotEmpty
            ? _buildRecentActivity(activity)
            : _buildEmptyCard('No recent activity yet.', Icons.history),

        const SizedBox(height: 16),
      ],
    );
  }

  // ── Skeleton & Empty ───────────────────────────────────────────────────────
  Widget _buildSkeletonCard() => Container(
    height: 80,
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        const SizedBox(width: 16),
        Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12))),
        const SizedBox(width: 14),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 14, width: 140, color: Colors.grey[200]),
            const SizedBox(height: 8),
            Container(height: 10, width: 100, color: Colors.grey[100]),
          ],
        )),
      ],
    ),
  );

  Widget _buildSkeletonCards({int count = 2}) => Column(
    children: List.generate(count, (_) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _buildSkeletonCard(),
    )),
  );

  Widget _buildEmptyCard(String msg, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
    child: Row(
      children: [
        Icon(icon, color: Colors.grey[400], size: 22),
        const SizedBox(width: 12),
        Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ],
    ),
  );

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
    child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
  );

  // ── 1. Profile Completion ──────────────────────────────────────────────────
  Widget _buildCompletionBar(int pct, User user) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
    child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: Color(0xFF1565C0), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Profile $pct% complete — add your ${_missingField(user)}!',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1565C0)),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Color(0xFF1565C0)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: const Color(0xFFE3F2FD),
              color: const Color(0xFF1565C0),
              minHeight: 6,
            ),
          ),
        ],
      ),
    ),
  );

  // ── 2. Streak ──────────────────────────────────────────────────────────────
  Widget _buildStreakCard() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)]),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Text('🔥', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_streak day streak!',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                _streak == 0 ? 'Open the app daily to build your streak' : 'Keep it up — come back tomorrow!',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
          child: Text('Day $_streak', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ],
    ),
  );

  // ── 3. Stats Row ───────────────────────────────────────────────────────────
  Widget _buildStatsRow(Map stats) {
    final items = [
      {'icon': Icons.people, 'label': 'Connections', 'value': '${stats['connections'] ?? 0}', 'color': const Color(0xFF1565C0)},
      {'icon': Icons.chat_bubble, 'label': 'Unread', 'value': '${stats['unread_messages'] ?? 0}', 'color': const Color(0xFFAD1457)},
      {'icon': Icons.work, 'label': 'Applied', 'value': '${stats['applications_sent'] ?? 0}', 'color': const Color(0xFF2E7D32)},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('My Stats', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            const Spacer(),
            if (_apiLoading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              GestureDetector(
                onTap: _fetchDashboard,
                child: const Icon(Icons.refresh, size: 18, color: Color(0xFF9E9E9E)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: items.map((item) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
                  const SizedBox(height: 6),
                  Text(item['value'] as String, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: item['color'] as Color)),
                  Text(item['label'] as String, style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  // ── 4. Notice Board ────────────────────────────────────────────────────────
  Widget _buildNoticeBoard(List notices) => SizedBox(
    height: 130,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: notices.length,
      itemBuilder: (context, i) {
        final n = notices[i];
        final isEvent = (n['category'] ?? 'event') == 'event';
        return Container(
          width: 220,
          margin: EdgeInsets.only(right: 12, left: i == 0 ? 0 : 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isEvent ? Icons.event : Icons.announcement, size: 14, color: isEvent ? Colors.blue : Colors.orange),
                  const SizedBox(width: 4),
                  Text(n['date'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                ],
              ),
              const SizedBox(height: 6),
              Text(n['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(n['description'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF757575)), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    ),
  );

  // ── 5. Featured Internship ─────────────────────────────────────────────────
  Widget _buildFeaturedInternship(Map f) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f['role_title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(f['company'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (f['deadline'] != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.timer_outlined, size: 12, color: Colors.white60),
                  const SizedBox(width: 4),
                  Text('Deadline: ${f['deadline']}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
              ],
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () => widget.onTabChange?.call(1),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF2E7D32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: const Text('Apply Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ],
    ),
  );

  // ── 6. Weekly Challenge ────────────────────────────────────────────────────
  Widget _buildWeeklyChallenge() => Container(
    margin: const EdgeInsets.only(top: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF7B1FA2).withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Text('🏆', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Weekly Challenge', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF7B1FA2))),
              const SizedBox(height: 2),
              const Text('Connect with 2 alumni this week', style: TextStyle(fontSize: 12, color: Color(0xFF757575))),
            ],
          ),
        ),
        _challengeDone
            ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 28)
            : TextButton(
                onPressed: _markChallengeDone,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF7B1FA2)),
                child: const Text('Done!', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
      ],
    ),
  );

  // ── 7. Find a Mentor ───────────────────────────────────────────────────────
  Widget _buildMentorSection(List mentors) => Column(
    children: [
      ...mentors.map((m) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE3F2FD),
              backgroundImage: (m['profile_picture_url'] != null && m['profile_picture_url'].toString().isNotEmpty)
                  ? NetworkImage(m['profile_picture_url'].toString().startsWith('http')
                      ? m['profile_picture_url']
                      : '${ApiService.baseUrl}${m['profile_picture_url']}')
                  : null,
              child: (m['profile_picture_url'] == null || m['profile_picture_url'].toString().isEmpty)
                  ? const Icon(Icons.person, color: Color(0xFF1565C0), size: 22)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${m['job_title'] ?? ''} @ ${m['company'] ?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      )),
      TextButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlumniDirectoryScreen())),
        icon: const Icon(Icons.search, size: 16),
        label: const Text('Browse All Alumni'),
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF1565C0)),
      ),
    ],
  );

  // ── 8. My Resume ───────────────────────────────────────────────────────────
  Widget _buildResumeCard(User user) {
    final hasResume = user.resumeUrl != null && user.resumeUrl!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasResume ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description, color: hasResume ? const Color(0xFF2E7D32) : const Color(0xFFF57C00), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Resume', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  hasResume ? 'Resume uploaded ✓' : 'No resume uploaded yet',
                  style: TextStyle(fontSize: 12, color: hasResume ? const Color(0xFF2E7D32) : const Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
          if (hasResume)
            TextButton(
              onPressed: () async {
                final url = user.resumeUrl!.startsWith('http') ? user.resumeUrl! : '${ApiService.baseUrl}${user.resumeUrl}';
                try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
              },
              child: const Text('View'),
            )
          else
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              child: const Text('Upload'),
            ),
        ],
      ),
    );
  }

  // ── 9. Recent Activity ─────────────────────────────────────────────────────
  Widget _buildRecentActivity(List activity) => Column(
    children: activity.map((a) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE3F2FD),
            child: Icon(_activityIcon(a['type']), size: 16, color: const Color(0xFF1565C0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(a['message'] ?? '', style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(_timeAgo(a['created_at']), style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
        ],
      ),
    )).toList(),
  );
}
