import 'package:flutter/material.dart';

import '../../../core/widgets/gb_blue_header.dart';
import '../../about/data/profile_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.onSubmitTap,
    required this.onTrackTap,
    required this.onInfoTap,
    super.key,
  });

  final VoidCallback onSubmitTap;
  final VoidCallback onTrackTap;
  final VoidCallback onInfoTap;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ProfileService _profileService = ProfileService();

  bool _isLoadingProfile = false;
  String _residentName = 'Resident';

  @override
  void initState() {
    super.initState();
    _loadResidentProfile();
  }

  Future<void> _loadResidentProfile() async {
    if (_isLoadingProfile) return;

    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final profile = await _profileService.fetchProfile();
      if (!mounted || profile == null) return;

      final candidate = profile.name.trim();
      if (candidate.isNotEmpty) {
        setState(() {
          _residentName = candidate;
        });
      }
    } catch (_) {
      // Keep fallback label if profile is unavailable.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GbBlueHeader(
          topContent: const _BrandTopRow(),
          title: 'Welcome, $_residentName',
          subtitle: 'Resident Portal',
          description:
              'Your digital legal companion for filing concerns, tracking progress, and accessing trusted barangay-level legal guidance.',
        ),
        const SizedBox(height: 14),
        _AnimatedItem(
          delay: 0,
          child: _ActionCard(
            title: 'Submit a Case',
            subtitle: 'Report your legal concern',
            color: const Color(0xFF2F6EFF),
            icon: Icons.description_outlined,
            onTap: widget.onSubmitTap,
          ),
        ),
        const SizedBox(height: 12),
        _AnimatedItem(
          delay: 90,
          child: _ActionCard(
            title: 'Track Your Case',
            subtitle: 'Check case status and updates',
            color: const Color(0xFF15B84C),
            icon: Icons.search_rounded,
            onTap: widget.onTrackTap,
          ),
        ),
        const SizedBox(height: 12),
        _AnimatedItem(
          delay: 180,
          child: _ActionCard(
            title: 'Legal Information',
            subtitle: 'Browse legal resources',
            color: const Color(0xFF9B38FF),
            icon: Icons.menu_book_outlined,
            onTap: widget.onInfoTap,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9EC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF3D58B)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFB26400), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Note: This app provides general legal information and guidance. For specific legal advice, please consult a licensed attorney.',
                  style: TextStyle(color: Color(0xFFB26400), height: 1.38),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _BrandTopRow extends StatelessWidget {
  const _BrandTopRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BrandLogoChip(),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GabayBatas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Barangay legal support and case tracking in one trusted app.',
                style: TextStyle(
                  color: Color(0xFFEAF0FF),
                  fontSize: 12.8,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandLogoChip extends StatelessWidget {
  const _BrandLogoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F6EFF), Color(0xFF1F49D8)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x402F6EFF),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
    );
  }
}

class _AnimatedItem extends StatelessWidget {
  const _AnimatedItem({required this.child, required this.delay});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.15)!],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.34), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 29 / 1.6, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xE8FFFFFF), fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}