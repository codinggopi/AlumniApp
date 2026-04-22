import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AlumniQAScreen extends StatefulWidget {
  const AlumniQAScreen({super.key});
  @override
  State<AlumniQAScreen> createState() => _AlumniQAScreenState();
}

class _AlumniQAScreenState extends State<AlumniQAScreen> {
  List<dynamic> _feedbacks = [];
  double _avgRating = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/feedback/received');
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as List;
        final avg = data.isEmpty
            ? 0.0
            : data.map((f) => (f['rating'] as int)).reduce((a, b) => a + b) / data.length;
        setState(() {
          _feedbacks = data;
          _avgRating = avg;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Feedback'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _feedbacks.isEmpty
              ? const Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No feedback yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    SizedBox(height: 6),
                    Text('Students will leave feedback after mentorship sessions',
                        style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildSummary()),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _FeedbackCard(feedback: _feedbacks[i]),
                            childCount: _feedbacks.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummary() => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Overall Rating', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_avgRating.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
          const Text(' / 5', style: TextStyle(color: Colors.white60, fontSize: 16)),
        ]),
        const SizedBox(height: 4),
        _StarRow(rating: _avgRating.round()),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Icon(Icons.rate_review, color: Colors.white54, size: 36),
        const SizedBox(height: 8),
        Text('${_feedbacks.length} review${_feedbacks.length != 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    ]),
  );
}

class _FeedbackCard extends StatelessWidget {
  final Map feedback;
  const _FeedbackCard({required this.feedback});

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
    final rating = feedback['rating'] as int;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE3F2FD),
            backgroundImage: (feedback['student_picture'] != null &&
                    feedback['student_picture'].toString().isNotEmpty)
                ? NetworkImage(feedback['student_picture'].toString().startsWith('http')
                    ? feedback['student_picture']
                    : '${ApiService.baseUrl}${feedback['student_picture']}')
                : null,
            child: (feedback['student_picture'] == null ||
                    feedback['student_picture'].toString().isEmpty)
                ? const Icon(Icons.person, color: Color(0xFF1565C0), size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(feedback['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (feedback['student_department'] != null)
              Text(feedback['student_department'], style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
          ])),
          Text(_timeAgo(feedback['created_at']),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
        ]),
        const SizedBox(height: 10),
        _StarRow(rating: rating),
        if (feedback['message'] != null && feedback['message'].toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(feedback['message'], style: const TextStyle(fontSize: 13, color: Color(0xFF424242), height: 1.4)),
        ],
      ]),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Icon(
        i < rating ? Icons.star : Icons.star_border,
        color: const Color(0xFFFFC107),
        size: 18,
      )),
    );
  }
}
