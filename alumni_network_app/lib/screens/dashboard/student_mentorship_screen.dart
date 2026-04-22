import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'submit_feedback_screen.dart';

class StudentMentorshipScreen extends StatefulWidget {
  const StudentMentorshipScreen({super.key});

  @override
  State<StudentMentorshipScreen> createState() => _StudentMentorshipScreenState();
}

class _StudentMentorshipScreenState extends State<StudentMentorshipScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _available = [];
  List<dynamic> _myBookings = [];
  bool _loadingAvailable = true;
  bool _loadingBookings = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAvailable();
    _fetchMyBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailable() async {
    setState(() => _loadingAvailable = true);
    try {
      final res = await ApiService().get('/mentorship/available');
      if (res.statusCode == 200 && mounted) {
        setState(() => _available = jsonDecode(res.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingAvailable = false);
  }

  Future<void> _fetchMyBookings() async {
    setState(() => _loadingBookings = true);
    try {
      final res = await ApiService().get('/mentorship/my-bookings');
      if (res.statusCode == 200 && mounted) {
        setState(() => _myBookings = jsonDecode(res.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingBookings = false);
  }

  Future<void> _joinSlot(int slotId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join Mentorship Session'),
        content: const Text('Book this mentorship slot? The alumni will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Join')),
        ],
      ),
    );
    if (confirmed != true) return;

    final res = await ApiService().post('/mentorship/slots/$slotId/book', {});
    if (!mounted) return;

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booked successfully!'), backgroundColor: Colors.green),
      );
      _fetchAvailable();
      _fetchMyBookings();
    } else {
      final msg = jsonDecode(res.body)['detail'] ?? 'Failed to book';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentorship Sessions'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Available Slots'),
            Tab(text: 'My Bookings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableTab(),
          _buildMyBookingsTab(),
        ],
      ),
    );
  }

  Widget _buildAvailableTab() {
    if (_loadingAvailable) return const Center(child: CircularProgressIndicator());
    if (_available.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.school_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('No mentorship slots available yet', style: TextStyle(color: Colors.grey, fontSize: 15)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAvailable,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _available.length,
        itemBuilder: (context, i) => _SlotCard(
          slot: _available[i],
          onJoin: () => _joinSlot(_available[i]['slot_id'] as int),
        ),
      ),
    );
  }

  Widget _buildMyBookingsTab() {
    if (_loadingBookings) return const Center(child: CircularProgressIndicator());
    if (_myBookings.isEmpty) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.event_busy_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('No bookings yet', style: TextStyle(color: Colors.grey, fontSize: 15)),
          SizedBox(height: 6),
          Text('Browse available slots and join a session', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchMyBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myBookings.length,
        itemBuilder: (context, i) => _BookingCard(
          booking: _myBookings[i],
          onFeedbackSubmitted: _fetchMyBookings,
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final Map slot;
  final VoidCallback onJoin;
  const _SlotCard({required this.slot, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final available = slot['available'] as int;
    final alreadyBooked = slot['already_booked'] as bool;
    final isFull = available <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Alumni info row
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE8F5E9),
            backgroundImage: (slot['alumni_picture'] != null && slot['alumni_picture'].toString().isNotEmpty)
                ? NetworkImage(slot['alumni_picture'].toString().startsWith('http')
                    ? slot['alumni_picture']
                    : '${ApiService.baseUrl}${slot['alumni_picture']}')
                : null,
            child: (slot['alumni_picture'] == null || slot['alumni_picture'].toString().isEmpty)
                ? const Icon(Icons.person, color: Color(0xFF00897B)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(slot['alumni_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (slot['alumni_job_title'] != null || slot['alumni_company'] != null)
              Text(
                [slot['alumni_job_title'], slot['alumni_company']].where((v) => v != null).join(' @ '),
                style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
                overflow: TextOverflow.ellipsis,
              ),
          ])),
          // availability badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isFull ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isFull ? 'Full' : '$available left',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isFull ? Colors.red : const Color(0xFF2E7D32),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // Slot time info
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF757575)),
          const SizedBox(width: 6),
          Text(slot['day'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          const Icon(Icons.access_time_outlined, size: 14, color: Color(0xFF757575)),
          const SizedBox(width: 6),
          Text('${slot['time_from']} – ${slot['time_to']}', style: const TextStyle(fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: slot['max_students'] > 0 ? slot['booked'] / slot['max_students'] : 0,
            backgroundColor: const Color(0xFFE8F5E9),
            color: isFull ? Colors.red : const Color(0xFF00897B),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 12),
        // Join button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (isFull || alreadyBooked) ? null : onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: alreadyBooked ? Colors.grey[300] : const Color(0xFF00897B),
              foregroundColor: alreadyBooked ? Colors.grey[600] : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(alreadyBooked ? 'Already Joined' : isFull ? 'Slot Full' : 'Join Session'),
          ),
        ),
      ]),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map booking;
  final VoidCallback? onFeedbackSubmitted;
  const _BookingCard({required this.booking, this.onFeedbackSubmitted});

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String;
    final isCompleted = status == 'completed';
    final hasFeedback = booking['has_feedback'] as bool? ?? false;
    final statusColor = status == 'confirmed'
        ? const Color(0xFF2E7D32)
        : isCompleted
            ? Colors.blue
            : status == 'rejected'
                ? Colors.red
                : const Color(0xFFF57C00);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE8F5E9),
            backgroundImage: (booking['alumni_picture'] != null && booking['alumni_picture'].toString().isNotEmpty)
                ? NetworkImage(booking['alumni_picture'].toString().startsWith('http')
                    ? booking['alumni_picture']
                    : '${ApiService.baseUrl}${booking['alumni_picture']}')
                : null,
            child: (booking['alumni_picture'] == null || booking['alumni_picture'].toString().isEmpty)
                ? const Icon(Icons.person, color: Color(0xFF00897B)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(booking['alumni_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (booking['alumni_job_title'] != null || booking['alumni_company'] != null)
              Text(
                [booking['alumni_job_title'], booking['alumni_company']].where((v) => v != null).join(' @ '),
                style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF9E9E9E)),
              const SizedBox(width: 4),
              Text('${booking['day']}  ${booking['time_from']} – ${booking['time_to']}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF757575))),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
            ),
          ),
        ]),
        // Feedback button — only for completed sessions
        if (isCompleted) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: hasFeedback
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    Icon(Icons.check_circle, color: Color(0xFF7B1FA2), size: 16),
                    SizedBox(width: 6),
                    Text('Feedback submitted', style: TextStyle(color: Color(0xFF7B1FA2), fontSize: 13, fontWeight: FontWeight.w600)),
                  ])
                : OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SubmitFeedbackScreen(
                          alumniId: booking['alumni_id'] as int,
                          alumniName: booking['alumni_name'] as String,
                        )),
                      );
                      if (result == true) onFeedbackSubmitted?.call();
                    },
                    icon: const Icon(Icons.rate_review_outlined, color: Color(0xFF7B1FA2), size: 16),
                    label: const Text('Leave Feedback', style: TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF7B1FA2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
          ),
        ],
      ]),
    );
  }
}
