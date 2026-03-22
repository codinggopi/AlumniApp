import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomizeDashboardScreen extends StatefulWidget {
  final List<String> currentOrder;
  final List<String> availableIds;
  final String storageKey; // New key to differentiate roles

  const CustomizeDashboardScreen({
    super.key, 
    required this.currentOrder, 
    required this.availableIds,
    required this.storageKey,
  });

  @override
  State<CustomizeDashboardScreen> createState() => _CustomizeDashboardScreenState();
}

class _CustomizeDashboardScreenState extends State<CustomizeDashboardScreen> {
  late List<String> _order;

  @override
  void initState() {
    super.initState();
    _order = List.from(widget.currentOrder);
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(widget.storageKey, _order);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arrange Actions'),
        actions: [
          TextButton(
            onPressed: _saveOrder,
            child: const Text('SAVE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.all(20),
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _order.removeAt(oldIndex);
            _order.insert(newIndex, item);
          });
        },
        children: _order.map((id) {
          return Card(
            key: ValueKey(id),
            margin: const EdgeInsets.only(bottom: 15),
            child: ListTile(
              leading: const Icon(Icons.drag_handle),
              title: Text(_getActionTitle(id)),
              trailing: const Icon(Icons.reorder),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getActionTitle(String id) {
    switch (id) {
      case 'internships': return 'Internships';
      case 'events': return 'Events';
      case 'profile': return 'My Profile';
      case 'register': return 'Register User';
      case 'students': return 'All Students';
      case 'alumni': return 'All Alumni';
      case 'post_event': return 'Post Event';
      case 'messages': return 'Message Inbox';
      default: return id;
    }
  }
}
