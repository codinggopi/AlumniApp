import 'package:flutter/material.dart';

class QuickAction {
  final String id;
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  
  QuickAction({
    required this.id,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}
