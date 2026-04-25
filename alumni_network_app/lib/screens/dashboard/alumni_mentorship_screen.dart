import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AlumniMentorshipScreen extends StatefulWidget {
  const AlumniMentorshipScreen({super.key});
  @override
  State<AlumniMentorshipScreen> createState() => _AlumniMentorshipScreenState();
}

class _AlumniMentorshipScreenState extends State<AlumniMentorshipScreen> {
  List<dynamic> _slots = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/mentorship/slots/${user.userId}');
      if (res.statusCode == 200 && mounted) {
        setState(() { _slots = jsonDecode(res.body); _loading = false; });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _addSlot() {
    String day = 'Saturday';
    final fromCtrl = TextEditingController(text: '17:00');
    final toCtrl = TextEditingController(text: '19:00');
    final maxCtrl = TextEditingController(text: '3');
    final linkCtrl = TextEditingController();
    final days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];

    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: const Text('Add Mentorship Slot'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: day,
            decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder()),
            items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setDlg(() => day = v!),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: fromCtrl, decoration: const InputDecoration(labelText: 'From (HH:MM)', border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: toCtrl, decoration: const InputDecoration(labelText: 'To (HH:MM)', border: OutlineInputBorder(), isDense: true))),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: maxCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Max Students', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: linkCtrl,
            decoration: const InputDecoration(
              labelText: 'Meeting Link (optional)',
              hintText: 'https://meet.google.com/...',
              border: OutlineInputBorder(),
              isDense: true,
              prefixIcon: Icon(Icons.videocam_outlined),
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final maxStudents = int.tryParse(maxCtrl.text.trim()) ?? 3;
              await ApiService().post('/mentorship/slots', {
                'day': day,
                'time_from': fromCtrl.text,
                'time_to': toCtrl.text,
                'max_students': maxStudents,
                if (linkCtrl.text.trim().isNotEmpty) 'meeting_link': linkCtrl.text.trim(),
              });
              if (ctx.mounted) { Navigator.pop(ctx); _fetch(); }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ));
  }

  Future<void> _viewStudents(Map slot) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SlotStudentsSheet(slot: slot, onRefresh: _fetch),
    );
  }

  Future<void> _editMeetingLink(int slotId, String? current) async {
    final ctrl = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Meeting Link'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Google Meet / Zoom link',
            hintText: 'https://meet.google.com/...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.videocam_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ApiService().patch('/mentorship/slots/$slotId/meeting-link', {'meeting_link': result});
    _fetch();
  }

  Future<void> _deleteSlot(int slotId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Slot'),
        content: const Text('Are you sure you want to delete this mentorship slot?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiService().delete('/mentorship/slots/$slotId');
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎓 Mentorship Slots'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _slots.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.school_outlined, size: 64, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text('No slots yet', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              Text('Add your availability so students can book sessions', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13), textAlign: TextAlign.center),
            ]))
          : RefreshIndicator(
              onRefresh: _fetch,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _slots.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final s = _slots[i];
                  final available = s['available'] as int;
                  final booked = s['booked'] as int;
                  return InkWell(
                    onTap: booked > 0 ? () => _viewStudents(s) : null,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.schedule, color: Color(0xFF2E7D32), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s['day']}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text('${s['time_from']} – ${s['time_to']}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.people_outline, size: 14, color: available > 0 ? const Color(0xFF2E7D32) : Colors.red),
                          const SizedBox(width: 4),
                          Text('$booked booked · $available available',
                              style: TextStyle(fontSize: 12, color: available > 0 ? const Color(0xFF2E7D32) : Colors.red)),
                          if (booked > 0) ...[
                            const SizedBox(width: 6),
                            Text('· tap to view', style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor)),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.videocam_outlined, size: 14,
                              color: (s['meeting_link'] != null && s['meeting_link'].toString().isNotEmpty)
                                  ? Theme.of(context).primaryColor : Theme.of(context).iconTheme.color?.withValues(alpha: 0.4)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(
                            (s['meeting_link'] != null && s['meeting_link'].toString().isNotEmpty)
                                ? s['meeting_link']
                                : 'No meeting link yet',
                            style: TextStyle(
                                fontSize: 11,
                                color: (s['meeting_link'] != null && s['meeting_link'].toString().isNotEmpty)
                                    ? Theme.of(context).primaryColor : Theme.of(context).iconTheme.color?.withValues(alpha: 0.4)),
                            overflow: TextOverflow.ellipsis,
                          )),
                          GestureDetector(
                            onTap: () => _editMeetingLink(s['slot_id'] as int, s['meeting_link'] as String?),
                            child: Icon(Icons.edit, size: 14, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: s['max_students'] > 0 ? booked / s['max_students'] : 0,
                            backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                            color: const Color(0xFF2E7D32),
                            minHeight: 5,
                          ),
                        ),
                      ])),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete slot',
                        onPressed: () => _deleteSlot(s['slot_id'] as int),
                      ),
                    ]),
                  ));
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSlot,
        icon: const Icon(Icons.add),
        label: const Text('Add Slot'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _SlotStudentsSheet extends StatefulWidget {
  final Map slot;
  final VoidCallback? onRefresh;
  const _SlotStudentsSheet({required this.slot, this.onRefresh});

  @override
  State<_SlotStudentsSheet> createState() => _SlotStudentsSheetState();
}

class _SlotStudentsSheetState extends State<_SlotStudentsSheet> {
  List<dynamic> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService().get('/mentorship/slots/${widget.slot['slot_id']}/students');
      if (res.statusCode == 200 && mounted) {
        setState(() => _students = jsonDecode(res.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateStatus(int bookingId, String status) async {
    final slotId = widget.slot['slot_id'] as int;
    final currentLink = widget.slot['meeting_link'] as String?;

    // If accepting and no meeting link yet, prompt for one
    String? meetingLink;
    if (status == 'confirmed' && (currentLink == null || currentLink.isEmpty)) {
      final ctrl = TextEditingController();
      meetingLink = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Add Meeting Link'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Add a meeting link so the student can join the session.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Google Meet / Zoom link',
                hintText: 'https://meet.google.com/...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.videocam_outlined),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Skip for now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save & Accept'),
            ),
          ],
        ),
      );
    }

    final body = {'status': status};
    if (meetingLink != null && meetingLink.isNotEmpty) {
      body['meeting_link'] = meetingLink;
    }

    await ApiService().patch('/mentorship/bookings/$bookingId/status', body);

    // If we saved a meeting link, also update the slot locally
    if (meetingLink != null && meetingLink.isNotEmpty) {
      await ApiService().patch('/mentorship/slots/$slotId/meeting-link', {'meeting_link': meetingLink});
      widget.onRefresh?.call();
    }

    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final booked = widget.slot['booked'] as int;
    final max = widget.slot['max_students'] as int;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2)),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${widget.slot['day']}  ${widget.slot['time_from']} – ${widget.slot['time_to']}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 2),
              Text('$booked / $max students joined',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$booked joined',
                  style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
        ),
        const Divider(height: 1),
        // Student list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _students.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.people_outline, size: 48, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.4)),
                        const SizedBox(height: 10),
                        Text('No students yet', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: _students.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final s = _students[i];
                        final status = s['status'] as String;
                        final isPending = status == 'pending';
                        final statusColor = status == 'confirmed'
                            ? const Color(0xFF2E7D32)
                            : status == 'completed'
                                ? Colors.blue
                                : status == 'rejected'
                                    ? Colors.red
                                    : const Color(0xFFF57C00);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                backgroundImage: (s['student_picture'] != null && s['student_picture'].toString().isNotEmpty)
                                    ? NetworkImage(s['student_picture'].toString().startsWith('http')
                                        ? s['student_picture']
                                        : '${ApiService.baseUrl}${s['student_picture']}')
                                    : null,
                                child: (s['student_picture'] == null || s['student_picture'].toString().isEmpty)
                                    ? Icon(Icons.person, color: Theme.of(context).primaryColor) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s['student_name'] ?? '', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
                                Text(s['student_email'] ?? '', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
                                if (s['student_department'] != null)
                                  Text(s['student_department'], style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
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
                            // Accept / Reject buttons for pending
                            if (isPending) ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _updateStatus(s['booking_id'] as int, 'rejected'),
                                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                    label: const Text('Reject', style: TextStyle(color: Colors.red)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _updateStatus(s['booking_id'] as int, 'confirmed'),
                                    icon: const Icon(Icons.check, size: 16, color: Colors.white),
                                    label: const Text('Accept', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ]),
                            ],
                          ]),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
