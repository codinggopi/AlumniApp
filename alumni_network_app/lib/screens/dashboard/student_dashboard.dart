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
import 'student_mentorship_screen.dart';
import '../todo/todo_screen.dart';

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
  int _longestStreak = 0;
  List<String> _checkinHistory = [];
  bool _challengeDone = false;
  final RouteObserver<ModalRoute<void>> _routeObserver = RouteObserver<ModalRoute<void>>();

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
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

  Future<void> _doCheckIn() async {
    try {
      final res = await ApiService().post('/student/checkin', {});
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _streak = data['streak'] ?? 0;
          _longestStreak = data['longest'] ?? 0;
          _checkinHistory = List<String>.from(data['history'] ?? []);
        });
      }
    } catch (_) {}
  }

  int _weekNumber(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    return ((date.difference(firstDay).inDays) / 7).floor() + 1;
  }

  Future<void> _markChallengeDone() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final weekKey = 'challenge_done_week_${now.year}_${_weekNumber(now)}';
    await prefs.setBool(weekKey, true);
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

        // 7. My Tasks quick card
        _buildTodoQuickCard(),

        // 8. Find a Mentor
        _sectionHeader('🎓 Find a Mentor'),
        _apiLoading ? _buildSkeletonCard() : mentors.isNotEmpty
            ? _buildMentorSection(mentors)
            : Column(children: [
                _buildEmptyCard('No mentors available right now.', Icons.school_outlined),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentMentorshipScreen())),
                    icon: const Icon(Icons.school, size: 16),
                    label: const Text('Browse Mentorship Sessions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),

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
  Widget _buildStreakCard() {
    final milestones = [3, 7, 14, 30, 60, 100];
    final nextMilestone = milestones.firstWhere((m) => m > _streak, orElse: () => 0);
    final progressToNext = nextMilestone > 0 ? _streak / nextMilestone : 1.0;

    // Build last 7 days check-in strip
    final today = DateTime.now();
    final historySet = _checkinHistory.toSet();
    final last7 = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      return (d, historySet.contains(key));
    });

    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return GestureDetector(
      onTap: () => _showStreakDetail(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFFFF6F00).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '$_streak day streak!',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                _streak == 0
                    ? 'Open the app daily to build your streak'
                    : nextMilestone > 0
                        ? '${nextMilestone - _streak} more days to reach $_streak→$nextMilestone 🎯'
                        : 'Amazing! 100+ day streak! 🏆',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Best: $_longestStreak',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(height: 4),
              const Text('tap for details', style: TextStyle(color: Colors.white54, fontSize: 10)),
            ]),
          ]),
          const SizedBox(height: 14),
          // Progress to next milestone
          if (nextMilestone > 0) ...[
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressToNext.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    color: Colors.white,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$nextMilestone 🎯',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
          ],
          // 7-day strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final (date, checked) = last7[i];
              final isToday = date.day == today.day &&
                  date.month == today.month &&
                  date.year == today.year;
              final dayLabel = dayLabels[date.weekday - 1];
              return Column(children: [
                Text(dayLabel,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: checked
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    border: isToday
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: checked
                        ? const Text('🔥', style: TextStyle(fontSize: 14))
                        : Text('${date.day}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ]);
            }),
          ),
        ]),
      ),
    );
  }

  void _showStreakDetail() {
    final milestones = {3: '🥉', 7: '🥈', 14: '🥇', 30: '💎', 60: '👑', 100: '🏆'};
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🔥 Your Streak', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(children: [
            _statBox('Current', '$_streak days', const Color(0xFFFF6F00)),
            const SizedBox(width: 12),
            _statBox('Best', '$_longestStreak days', const Color(0xFF1565C0)),
            const SizedBox(width: 12),
            _statBox('Check-ins', '${_checkinHistory.length}', const Color(0xFF2E7D32)),
          ]),
          const SizedBox(height: 20),
          const Text('Milestones', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: milestones.entries.map((e) {
              final reached = _longestStreak >= e.key;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: reached ? const Color(0xFFFFF8E1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: reached ? const Color(0xFFFFC107) : Colors.grey[300]!),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.value, style: TextStyle(fontSize: 16, color: reached ? null : const Color(0xFFBDBDBD))),
                  const SizedBox(width: 6),
                  Text('${e.key} days',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: reached ? const Color(0xFFF57C00) : Colors.grey[400])),
                ]),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
      ]),
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

  // ── 7. To-Do Quick Card ────────────────────────────────────────────────────
  Widget _buildTodoQuickCard() {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final prefs = snap.data!;
        final raw = prefs.getString('todos') ?? '[]';
        final List todos = jsonDecode(raw);
        final pending = todos.where((t) => t['done'] == false).length;
        final overdue = todos.where((t) {
          if (t['done'] == true || t['dueDateTime'] == null) return false;
          return DateTime.parse(t['dueDateTime']).isBefore(DateTime.now());
        }).length;

        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodoScreen())),
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.checklist_rounded, color: Color(0xFF1565C0), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('My Tasks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  pending == 0
                      ? 'All done! Great work 🎉'
                      : overdue > 0
                          ? '$overdue overdue · $pending pending'
                          : '$pending task${pending != 1 ? 's' : ''} pending',
                  style: TextStyle(
                      fontSize: 12,
                      color: overdue > 0 ? Colors.red : const Color(0xFF9E9E9E)),
                ),
              ])),
              const Icon(Icons.chevron_right, color: Color(0xFF1565C0)),
            ]),
          ),
        );
      },
    );
  }

  // ── 8. Find a Mentor ───────────────────────────────────────────────────────
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
      Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlumniDirectoryScreen())),
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Browse All Alumni'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF1565C0)),
            ),
          ),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentMentorshipScreen())),
              icon: const Icon(Icons.school, size: 16),
              label: const Text('Book a Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
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
