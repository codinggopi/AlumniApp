import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends StatelessWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          if (Provider.of<AuthProvider>(context, listen: false).user?.role == 'admin')
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: event.category == 'event' 
                      ? [Colors.blue, Colors.indigo] 
                      : [Colors.orange, Colors.deepOrange],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      event.category.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    event.title,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(event.date ?? "No date specified", style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(event.location ?? "Online", style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    event.description ?? "No description provided.",
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                  ),
                  const SizedBox(height: 30),
                  
                  if (event.hasDocument || event.hasPhotos) ...[
                    const Divider(),
                    const SizedBox(height: 15),
                    const Text('Attachments & Media', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    if (event.hasPhotos && event.photoUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          '${ApiService.baseUrl}${event.photoUrl}',
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                    Row(
                      children: [
                        if (event.hasDocument && event.documentUrl != null)
                          _buildAttachmentChip(
                            context,
                            Icons.insert_drive_file,
                            "View Document",
                            () => launchUrl(Uri.parse('${ApiService.baseUrl}${event.documentUrl}')),
                          ),
                        if (event.hasDocument && event.hasPhotos) const SizedBox(width: 10),
                        if (event.hasPhotos && event.photoUrl != null)
                          _buildAttachmentChip(
                            context,
                            Icons.photo_library,
                            "View Full Image",
                            () => launchUrl(Uri.parse('${ApiService.baseUrl}${event.photoUrl}')),
                          ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                  const Text(
                    'Posted on',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    DateFormat('MMM d, yyyy • hh:mm a').format(event.createdAt),
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteEvent(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteEvent(BuildContext context) async {
    final response = await ApiService().delete('/events/${event.eventId}');
    if (response.statusCode == 200) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted successfully')));
        Navigator.pop(context, true); // Return true to refresh list
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete event')));
      }
    }
  }

  Widget _buildAttachmentChip(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.blue),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
