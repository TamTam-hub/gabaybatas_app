import 'package:flutter/material.dart';

class GbDialog extends StatelessWidget {
  const GbDialog({
    required this.icon,
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF8FAFF),
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE7EEFF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFF3159C9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F2C45),
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
          ),
        ],
      ),
      content: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF607394), height: 1.4),
        child: content,
      ),
      // AlertDialog asserts that its actions list is non-empty when supplied.
      actions: actions.isEmpty ? const [SizedBox.shrink()] : actions,
    );
  }
}
