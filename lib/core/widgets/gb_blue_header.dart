import 'package:flutter/material.dart';

class GbBlueHeader extends StatelessWidget {
  const GbBlueHeader({
    required this.title,
    this.subtitle,
    this.description,
    this.topContent,
    this.showBack = false,
    this.onBack,
    this.bottom,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? description;
  final Widget? topContent;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F6EFF), Color(0xFF2355E7), Color(0xFF1F49D8)],
          stops: [0, 0.58, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -28,
            top: 24,
            child: Transform.rotate(
              angle: -0.28,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
            ),
          ),
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20 + topInset, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topContent != null) ...[
                  topContent!,
                  const SizedBox(height: 14),
                ],
                if (showBack)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                      color: Colors.white,
                    ),
                  ),
                if (showBack) const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 31,
                    height: 1.05,
                    letterSpacing: 0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFFEAF0FF),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
                if (description != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A102E75),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      description!,
                      style: const TextStyle(
                        color: Color(0xFFEAF0FF),
                        height: 1.4,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                if (bottom != null) ...[
                  const SizedBox(height: 16),
                  bottom!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}