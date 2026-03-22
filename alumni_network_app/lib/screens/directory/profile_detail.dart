import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../chat/chat_room_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../internships/internship_list.dart';

class ProfileDetailScreen extends StatelessWidget {
  final User user;
  const ProfileDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      appBar: AppBar(title: Text(user.fullName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.grey[200],
                backgroundImage: (user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty)
                    ? NetworkImage(user.profilePictureUrl!.startsWith('http') ? user.profilePictureUrl! : '${ApiService.baseUrl}${user.profilePictureUrl}')
                    : null,
                child: (user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 70, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 30),
            Text(user.fullName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user.role.toUpperCase(),
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 25),
            const Divider(),
            const SizedBox(height: 20),
            _buildInfoRow(
              context, 
              Icons.info_outline, 
              'Current Status', 
              user.currentStatus ?? (user.role == 'student' ? 'Active Student' : (user.role == 'alumni' ? 'Professional Alumni' : 'Staff'))
            ),
            if (user.role == 'student') ...[
              _buildInfoRow(context, Icons.history_edu, 'Educational Details', user.educationalDetails ?? 'Not Provided'),
              if (user.resumeUrl != null && user.resumeUrl!.isNotEmpty)
                _buildInfoRow(context, Icons.description, 'Resume / CV', 'Available (Tap to View)'),
            ],
            if (user.role == 'alumni') ...[
              _buildInfoRow(context, Icons.work, 'Current Position', user.jobTitle ?? 'Not Specified'),
              _buildInfoRow(context, Icons.business_center, 'Company / Status', user.company ?? 'Internal'),
            ],
            _buildInfoRow(context, Icons.business, 'Department', user.department ?? 'N/A'),
            _buildInfoRow(context, Icons.calendar_today, 'Graduated Year', user.graduationYear?.toString() ?? 'N/A'),
            _buildInfoRow(context, Icons.location_on, 'City', user.city ?? 'N/A'),
            _buildInfoRow(context, Icons.email, 'Email', user.email),
            if (user.phone != null && user.phone!.isNotEmpty)
               _buildInfoRow(context, Icons.phone, 'Phone', user.phone!),
            const SizedBox(height: 25),
            const Text('About', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              user.bio ?? 'This user has not provided a bio yet.',
              style: TextStyle(color: Colors.grey[800], fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 50),
            Column(
              children: [
                if (currentUser != null && currentUser.userId != user.userId)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatRoomScreen(otherUser: user)),
                        );
                      },
                      icon: const Icon(Icons.message, color: Colors.white),
                      label: const Text('MESSAGE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                if (user.role == 'alumni') ...[
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => InternshipListScreen(postedBy: user.userId)),
                        );
                      },
                      icon: const Icon(Icons.work_outline, color: Colors.blue),
                      label: Text('VIEW INTERNSHIPS POSTED BY ${user.fullName.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue[300], size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
