import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh bookings when returning to this screen
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
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.school_outlined, size: 64, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('No mentorship slots available yet', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15)),
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
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.event_busy_outlined, size: 64, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('No bookings yet', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15)),
          const SizedBox(height: 6),
          Text('Browse available slots and join a session', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
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
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Alumni info row
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF00897B).withValues(alpha: 0.1),
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
            Text(slot['alumni_name'] ?? '', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
            if (slot['alumni_job_title'] != null || slot['alumni_company'] != null)
              Text(
                [slot['alumni_job_title'], slot['alumni_company']].where((v) => v != null).join(' @ '),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isFull ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF2E7D32).withValues(alpha: 0.1),
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
        Row(children: [
          Icon(Icons.calendar_today_outlined, size: 14, color: theme.iconTheme.color?.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(slot['day'] ?? '', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Icon(Icons.access_time_outlined, size: 14, color: theme.iconTheme.color?.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text('${slot['time_from']} – ${slot['time_to']}', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: slot['max_students'] > 0 ? slot['booked'] / slot['max_students'] : 0,
            backgroundColor: const Color(0xFF00897B).withValues(alpha: 0.1),
            color: isFull ? Colors.red : const Color(0xFF00897B),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (isFull || alreadyBooked) ? null : onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: alreadyBooked
                  ? theme.dividerColor
                  : isFull
                      ? theme.dividerColor
                      : const Color(0xFF00897B),
              foregroundColor: alreadyBooked || isFull
                  ? theme.textTheme.bodySmall?.color
                  : Colors.white,
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

  String _timeLabel(String day, String timeFrom, String timeTo) {
    final now = DateTime.now();
    final days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final targetWeekday = days.indexOf(day) + 1;
    final diff = (targetWeekday - now.weekday + 7) % 7;
    final sessionDate = now.add(Duration(days: diff));
    final fromParts = timeFrom.split(':');
    final toParts = timeTo.split(':');
    if (fromParts.length < 2 || toParts.length < 2) return day;
    final start = DateTime(sessionDate.year, sessionDate.month, sessionDate.day,
        int.parse(fromParts[0]), int.parse(fromParts[1]));
    final end = DateTime(sessionDate.year, sessionDate.month, sessionDate.day,
        int.parse(toParts[0]), int.parse(toParts[1]));
    if (now.isBefore(start)) {
      final mins = start.difference(now).inMinutes;
      if (mins < 60) return 'Starts in ${mins}m';
      if (mins < 1440) return 'Starts in ${start.difference(now).inHours}h';
      return 'Starts $day';
    } else if (now.isAfter(end)) {
      return 'Session ended';
    } else {
      return 'Live now 🔴';
    }
  }

  bool _isLive(String day, String timeFrom, String timeTo) {
    final now = DateTime.now();
    final days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final targetWeekday = days.indexOf(day) + 1;
    final diff = (targetWeekday - now.weekday + 7) % 7;
    final sessionDate = now.add(Duration(days: diff));
    final fromParts = timeFrom.split(':');
    final toParts = timeTo.split(':');
    if (fromParts.length < 2 || toParts.length < 2) return false;
    final start = DateTime(sessionDate.year, sessionDate.month, sessionDate.day,
        int.parse(fromParts[0]), int.parse(fromParts[1]));
    final end = DateTime(sessionDate.year, sessionDate.month, sessionDate.day,
        int.parse(toParts[0]), int.parse(toParts[1]));
    return now.isAfter(start) && now.isBefore(end);
  }

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String;
    final isConfirmed = status == 'confirmed';
    final isCompleted = status == 'completed';
    final hasFeedback = booking['has_feedback'] as bool? ?? false;
    final meetingLink = booking['meeting_link'] as String?;
    final day = booking['day'] as String? ?? '';
    final timeFrom = booking['time_from'] as String? ?? '';
    final timeTo = booking['time_to'] as String? ?? '';
    final live = isConfirmed && _isLive(day, timeFrom, timeTo);
    final timeLabel = isConfirmed ? _timeLabel(day, timeFrom, timeTo) : null;

    final statusColor = isConfirmed
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: live ? Border.all(color: const Color(0xFF2E7D32), width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF00897B).withValues(alpha: 0.1),
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
            Text(booking['alumni_name'] ?? '', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
            if (booking['alumni_job_title'] != null || booking['alumni_company'] != null)
              Text(
                [booking['alumni_job_title'], booking['alumni_company']].where((v) => v != null).join(' @ '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.calendar_today_outlined, size: 12, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text('$day  $timeFrom – $timeTo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
            ]),
            if (timeLabel != null) ...[
              const SizedBox(height: 2),
              Text(timeLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: live ? const Color(0xFF2E7D32) : Theme.of(context).textTheme.bodySmall?.color)),
            ],
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
        const SizedBox(height: 12),
        // Status-based action
        if (status == 'pending')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF57C00).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.hourglass_empty, size: 16, color: Color(0xFFF57C00)),
              SizedBox(width: 6),
              Text('Waiting for approval', style: TextStyle(color: Color(0xFFF57C00), fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          )
        else if (status == 'rejected')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
              SizedBox(width: 6),
              Text('Booking rejected', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          )
        else if (isConfirmed && meetingLink != null && meetingLink.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(meetingLink);
                try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
              },
              icon: const Icon(Icons.videocam, color: Colors.white, size: 18),
              label: Text(live ? 'Join Now 🔴' : 'Open Meeting Link',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: live ? const Color(0xFF2E7D32) : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          )
        else if (isConfirmed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF2E7D32)),
              SizedBox(width: 6),
              Text('Confirmed — meeting link coming soon',
                  style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600, fontSize: 12)),
            ]),
          ),
        // Feedback for completed
        if (isCompleted) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: hasFeedback
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
