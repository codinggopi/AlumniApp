import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/event.dart';
import '../../widgets/empty_state.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  final ApiService _apiService = ApiService();
  List<Event> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/events');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _events = data.map((json) => Event.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Fetch events error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events & News')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.event_busy,
                  title: 'No Events Yet',
                  message: 'Stay tuned! We will notify you when new events and news are posted.',
                  onRetry: _fetchEvents,
                )
              : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: Icon(
                          event.category == 'event' ? Icons.event : Icons.announcement,
                          color: event.category == 'event' ? Colors.blue : Colors.orange,
                        ),
                        title: Text(event.title),
                        subtitle: Text('${event.date ?? "No Date"} | ${event.location ?? "Online"}'),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}
