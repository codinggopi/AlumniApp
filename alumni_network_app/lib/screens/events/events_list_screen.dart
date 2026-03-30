import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/event_bus.dart';
import '../../models/event.dart';
import '../../widgets/empty_state.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'event_detail.dart';
import '../admin/post_event_screen.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  final ApiService _apiService = ApiService();
  List<Event> _events = [];
  bool _isLoading = true;
  StreamSubscription<void>? _refreshSub;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _refreshSub = EventBus.refreshStream.listen((_) {
      if (mounted) _fetchEvents();
    });
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/events');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final fetched = data.map((json) => Event.fromJson(json)).toList();
        // debug log fetched ids to help diagnose stale data for admins
        debugPrint(
          '[EventsListScreen] fetched ${fetched.length} events: ${fetched.map((e) => e.eventId).toList()}',
        );
        setState(() {
          _events = fetched;
        });
      }
    } catch (e) {
      debugPrint('Fetch events error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ALL Events'),
        content: const Text(
          'Are you sure you want to delete EVERY event and news item? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAllEvents();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'DELETE ALL',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteAllEvents() async {
    setState(() => _isLoading = true);
    final response = await _apiService.delete('/events');
    if (response.statusCode == 200) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All events cleared')));
        _fetchEvents();
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to clear events')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        Provider.of<AuthProvider>(context, listen: false).user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events & News'),
        actions: [
          if (isAdmin && _events.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.red),
              tooltip: 'Delete All',
              onPressed: () => _confirmDeleteAll(context),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? EmptyStateWidget(
              icon: Icons.event_busy,
              title: 'No Events Yet',
              message:
                  'Stay tuned! We will notify you when new events and news are posted.',
              onRetry: _fetchEvents,
            )
          : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    leading: Icon(
                      event.category == 'event'
                          ? Icons.event
                          : Icons.announcement,
                      color: event.category == 'event'
                          ? Colors.blue
                          : Colors.orange,
                    ),
                    title: Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${event.date ?? "No Date"} | ${event.location ?? "Online"}',
                        ),
                        if (event.description != null &&
                            event.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              event.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (event.hasDocument)
                          Icon(
                            Icons.attachment,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                        if (event.hasPhotos)
                          Icon(
                            Icons.insert_photo,
                            size: 20,
                            color: Colors.grey[600],
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailScreen(event: event),
                        ),
                      );
                      // Only refresh when detail screen signals an update (legacy boolean true)
                      if (result == true) {
                        _fetchEvents();
                      }
                    },
                  ),
                );
              },
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PostEventScreen()),
                );
                if (result == true) _fetchEvents();
              },
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }
}
