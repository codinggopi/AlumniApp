import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _role = '';

  @override
  void initState() {
    super.initState();
    _role = Provider.of<AuthProvider>(context, listen: false).user?.role ?? '';
    final tabCount = _role == 'admin' ? 1 : _role == 'student' ? 2 : 1;
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _buildTabs();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
        bottom: tabs.length > 1
            ? TabBar(controller: _tabController, tabs: tabs.map((t) => Tab(text: t.$1)).toList())
            : null,
      ),
      body: tabs.length > 1
          ? TabBarView(controller: _tabController, children: tabs.map((t) => t.$2).toList())
          : tabs.first.$2,
    );
  }

  List<(String, Widget)> _buildTabs() {
    if (_role == 'student') {
      return [
        ('Submit', _SubmitFeedbackTab()),
        ('My Submissions', _SentFeedbackTab()),
      ];
    } else if (_role == 'alumni' || _role == 'staff') {
      return [('Received Feedback', _ReceivedFeedbackTab())];
    } else if (_role == 'admin') {
      return [('All Feedback', _AdminFeedbackTab())];
    }
    return [('Feedback', const Center(child: Text('Not available')))];
  }
}

// ── Student: Submit ──────────────────────────────────────────────────────────

class _SubmitFeedbackTab extends StatefulWidget {
  @override
  State<_SubmitFeedbackTab> createState() => _SubmitFeedbackTabState();
}

class _SubmitFeedbackTabState extends State<_SubmitFeedbackTab> {
  List<dynamic> _targets = [];
  List<dynamic> _filtered = [];
  Map<int, int> _submittedMap = {}; // target_id -> feedback_id
  bool _loading = true;
  dynamic _selected;
  String _roleFilter = 'all';
  int _rating = 0;
  final _msgCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    try {
      final r1 = await ApiService().get('/alumni');
      final r2 = await ApiService().get('/staff-contacts');
      final r3 = await ApiService().get('/feedback/sent');
      final List alumni = r1.statusCode == 200 ? jsonDecode(r1.body) : [];
      final List staff  = r2.statusCode == 200 ? jsonDecode(r2.body) : [];
      final List sent   = r3.statusCode == 200 ? jsonDecode(r3.body) : [];
      final Map<int, int> submitted = {};
      for (final f in sent) {
        submitted[f['target_id'] as int] = f['feedback_id'] as int;
      }
      final all = [
        ...alumni.map((u) => {...u, 'target_role': 'alumni'}),
        ...staff.map((u) => {...u, 'target_role': 'staff'}),
      ];
      if (mounted) {
        setState(() {
          _targets = all;
          _filtered = _roleFilter == 'all' ? all : all.where((t) => t['target_role'] == _roleFilter).toList();
          _submittedMap = submitted;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilter(String role) {
    setState(() {
      _roleFilter = role;
      _selected = null;
      _filtered = role == 'all' ? _targets : _targets.where((t) => t['target_role'] == role).toList();
    });
  }

  Future<void> _submit() async {
    if (_selected == null) { _snack('Please select a person'); return; }
    if (_rating == 0) { _snack('Please select a rating'); return; }
    setState(() => _submitting = true);
    final res = await ApiService().post('/feedback', {
      'target_id': _selected['user_id'],
      'target_role': _selected['target_role'],
      'rating': _rating,
      'message': _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.statusCode == 200) {
      _snack('Feedback submitted!', color: Colors.green);
      setState(() { _selected = null; _rating = 0; _msgCtrl.clear(); });
      _fetchAll();
    } else {
      _snack(jsonDecode(res.body)['detail'] ?? 'Failed', color: Colors.red);
    }
  }

  Future<void> _deleteFeedback(int feedbackId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Feedback'),
        content: const Text('This will unlock this person so you can submit new feedback. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    final res = await ApiService().delete('/feedback/$feedbackId');
    if (!mounted) return;
    if (res.statusCode == 200) {
      _snack('Deleted. You can now submit again.', color: Colors.orange);
      _fetchAll();
    }
  }

  void _snack(String msg, {Color? color}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Who are you giving feedback to?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 12),
        Row(children: [
          _filterChip('All', 'all'), const SizedBox(width: 8),
          _filterChip('Alumni', 'alumni'), const SizedBox(width: 8),
          _filterChip('Staff', 'staff'),
        ]),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _filtered.isEmpty
              ? const Padding(padding: EdgeInsets.all(16),
                  child: Text('No users found', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final t = _filtered[i];
                    final role = t['target_role'] as String;
                    final targetId = t['user_id'] as int;
                    final isSelected = _selected != null && _selected['user_id'] == targetId;
                    final submittedFbId = _submittedMap[targetId];
                    final isLocked = submittedFbId != null;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: const Color(0xFFF3E5F5),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: role == 'alumni' ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                        backgroundImage: (t['profile_picture_url'] != null && t['profile_picture_url'].toString().isNotEmpty)
                            ? NetworkImage(t['profile_picture_url'].toString().startsWith('http')
                                ? t['profile_picture_url'] : '${ApiService.baseUrl}${t['profile_picture_url']}')
                            : null,
                        child: (t['profile_picture_url'] == null || t['profile_picture_url'].toString().isEmpty)
                            ? Icon(Icons.person, size: 18,
                                color: role == 'alumni' ? const Color(0xFF00897B) : const Color(0xFF1565C0))
                            : null,
                      ),
                      title: Text(t['full_name'] ?? '',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                              color: isLocked ? Colors.grey[400] : null)),
                      trailing: isLocked
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.lock, size: 15, color: Colors.orange),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _deleteFeedback(submittedFbId),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Delete',
                                      style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ])
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: role == 'alumni' ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(role.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                        color: role == 'alumni' ? const Color(0xFF00897B) : const Color(0xFF1565C0))),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.check_circle, color: Color(0xFF7B1FA2), size: 18),
                              ],
                            ]),
                      onTap: isLocked ? null : () => setState(() => _selected = isSelected ? null : t),
                    );
                  },
                ),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.check_circle, color: Color(0xFF7B1FA2), size: 16),
            const SizedBox(width: 6),
            Text('Selected: ${_selected['full_name']}',
                style: const TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ],
        const SizedBox(height: 24),
        const Text('Your Rating', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: () => setState(() => _rating = star),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(star <= _rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFFFC107), size: 40),
              ),
            );
          }),
        ),
        if (_rating > 0) ...[
          const SizedBox(height: 6),
          Center(child: Text(['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][_rating],
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF57C00)))),
        ],
        const SizedBox(height: 24),
        const Text('Message (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        TextField(
          controller: _msgCtrl,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Share your experience...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit Feedback', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _roleFilter == value;
    return GestureDetector(
      onTap: () => _applyFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7B1FA2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF7B1FA2) : Colors.grey[300]!),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[700])),
      ),
    );
  }
}

// ── Student: Sent history ────────────────────────────────────────────────────

class _SentFeedbackTab extends StatefulWidget {
  @override
  State<_SentFeedbackTab> createState() => _SentFeedbackTabState();
}

class _SentFeedbackTabState extends State<_SentFeedbackTab> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService().get('/feedback/sent');
      if (res.statusCode == 200 && mounted) {
        setState(() => _items = jsonDecode(res.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.rate_review_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('No feedback submitted yet', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) => _FeedbackCard(item: _items[i], showTarget: true),
      ),
    );
  }
}

// ── Alumni / Staff: Received ─────────────────────────────────────────────────

class _ReceivedFeedbackTab extends StatefulWidget {
  @override
  State<_ReceivedFeedbackTab> createState() => _ReceivedFeedbackTabState();
}

class _ReceivedFeedbackTabState extends State<_ReceivedFeedbackTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService().get('/feedback/received');
      if (res.statusCode == 200 && mounted) {
        setState(() => _data = jsonDecode(res.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final feedbacks = (_data?['feedbacks'] as List?) ?? [];
    final avg = (_data?['average_rating'] ?? 0.0) as num;
    final total = (_data?['total'] ?? 0) as int;

    if (feedbacks.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.rate_review_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('No feedback received yet', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _buildSummary(avg.toDouble(), total)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _FeedbackCard(item: feedbacks[i], showTarget: false),
              childCount: feedbacks.length,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildSummary(double avg, int total) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
          colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Overall Rating',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(avg.toStringAsFixed(1),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800)),
            const Text(' / 5',
                style: TextStyle(color: Colors.white60, fontSize: 16)),
          ]),
          const SizedBox(height: 4),
          _StarRow(rating: avg.round()),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Icon(Icons.rate_review, color: Colors.white54, size: 36),
        const SizedBox(height: 8),
        Text('$total review${total != 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    ]),
  );
}

// ── Admin: All feedback ───────────────────────────────────────────────────────

class _AdminFeedbackTab extends StatefulWidget {
  @override
  State<_AdminFeedbackTab> createState() => _AdminFeedbackTabState();
}

class _AdminFeedbackTabState extends State<_AdminFeedbackTab> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService().get('/feedback/all');
      if (res.statusCode == 200 && mounted) {
        setState(() => _items = jsonDecode(res.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _respond(int feedbackId, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Admin Response'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write your response...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    await ApiService().patch('/feedback/$feedbackId/respond', {'response': result});
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.rate_review_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('No feedback yet', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) => _FeedbackCard(
          item: _items[i],
          showTarget: true,
          onRespond: () => _respond(
            _items[i]['feedback_id'] as int,
            _items[i]['admin_response'] ?? '',
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final Map item;
  final bool showTarget;
  final VoidCallback? onRespond;
  const _FeedbackCard(
      {required this.item, required this.showTarget, this.onRespond});

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

  @override
  Widget build(BuildContext context) {
    final rating = item['rating'] as int;
    final adminResponse = item['admin_response'] as String?;
    final targetRole = item['target_role'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Student row
        Row(children: [
          _avatar(item['student_picture'], const Color(0xFFE3F2FD),
              const Color(0xFF1565C0)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['student_name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              if (item['student_department'] != null)
                Text(item['student_department'],
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9E9E9E))),
            ]),
          ),
          Text(_timeAgo(item['created_at']),
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
        ]),
        // Target row (shown for admin / student sent view)
        if (showTarget && item['target_name'] != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF9E9E9E)),
            const SizedBox(width: 6),
            _avatar(item['target_picture'],
                targetRole == 'alumni'
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFE3F2FD),
                targetRole == 'alumni'
                    ? const Color(0xFF00897B)
                    : const Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Text(item['target_name'] ?? '',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: targetRole == 'alumni'
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(targetRole.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: targetRole == 'alumni'
                          ? const Color(0xFF00897B)
                          : const Color(0xFF1565C0))),
            ),
          ]),
        ],
        const SizedBox(height: 10),
        _StarRow(rating: rating),
        if (item['message'] != null &&
            item['message'].toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(item['message'],
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF424242),
                  height: 1.4)),
        ],
        // Admin response
        if (adminResponse != null && adminResponse.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.admin_panel_settings,
                  size: 16, color: Color(0xFF7B1FA2)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(adminResponse,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF7B1FA2))),
              ),
            ]),
          ),
        ],
        // Respond button (admin only)
        if (onRespond != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRespond,
              icon: const Icon(Icons.reply, size: 16),
              label: Text(adminResponse != null && adminResponse.isNotEmpty
                  ? 'Edit Response'
                  : 'Respond'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7B1FA2)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _avatar(dynamic url, Color bg, Color iconColor) => CircleAvatar(
    radius: 16,
    backgroundColor: bg,
    backgroundImage: (url != null && url.toString().isNotEmpty)
        ? NetworkImage(url.toString().startsWith('http')
            ? url.toString()
            : '${ApiService.baseUrl}$url')
        : null,
    child: (url == null || url.toString().isEmpty)
        ? Icon(Icons.person, size: 16, color: iconColor)
        : null,
  );
}

class _StarRow extends StatelessWidget {
  final int rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      5,
      (i) => Icon(
        i < rating ? Icons.star : Icons.star_border,
        color: const Color(0xFFFFC107),
        size: 18,
      ),
    ),
  );
}
