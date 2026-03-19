import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../chat/chat_room_screen.dart';

class ProfileDetailScreen extends StatelessWidget {
  final User user;
  const ProfileDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(user.fullName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: CircleAvatar(radius: 60, child: Icon(Icons.person, size: 60)),
            ),
            const SizedBox(height: 20),
            Text('Full Name: ${user.fullName}', style: Theme.of(context).textTheme.titleLarge),
            Text('Role: ${user.role.toUpperCase()}', style: const TextStyle(color: Colors.blue)),
            const Divider(),
            if (user.department != null) Text('Department: ${user.department}'),
            if (user.graduationYear != null) Text('Graduation Year: ${user.graduationYear}'),
            if (user.city != null) Text('City: ${user.city}'),
            const SizedBox(height: 10),
            Text('Bio:', style: Theme.of(context).textTheme.titleMedium),
            Text(user.bio ?? 'No bio provided.'),
            const Spacer(),
            if (user.role == 'alumni')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChatRoomScreen(otherUser: user)),
                    );
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Send Message'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
