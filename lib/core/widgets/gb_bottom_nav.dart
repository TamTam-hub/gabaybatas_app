import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Bottom navigation: a single Royal Blue pill glides to the selected tab,
/// the selected icon swaps to its filled version, and taps get a light press.
class GbBottomNav extends StatelessWidget {
  const GbBottomNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const Duration _duration = Duration(milliseconds: 340);
  static const Curve _curve = Curves.easeOutCubic;
  static const double _pillWidth = 54;
  static const double _pillHeight = 32;

  static const List<_NavItem> _items = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.description_outlined, Icons.description_rounded, 'Track'),
    _NavItem(Icons.gavel_outlined, Icons.gavel_rounded, 'Info'),
    _NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chat'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x161F5BC4),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 10, 8, 8 + bottomInset),
        child: SizedBox(
          height: 58,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: _duration,
                    curve: _curve,
                    left: itemWidth * currentIndex + (itemWidth - _pillWidth) / 2,
                    top: 2,
                    width: _pillWidth,
                    height: _pillHeight,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2F6FD8), Color(0xFF1A4CA3)],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x401F5BC4),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: _items[i],
                            selected: i == currentIndex,
                            onTap: () {
                              if (i == currentIndex) return;
                              HapticFeedback.selectionClick();
                              onTap(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  static const Color _idle = Color(0xFF8592A8);
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return Semantics(
      button: true,
      selected: selected,
      label: widget.item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Icon(
                      selected ? widget.item.selectedIcon : widget.item.icon,
                      key: ValueKey<bool>(selected),
                      size: 23,
                      color: selected ? Colors.white : _idle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.2,
                  letterSpacing: 0.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primaryBlue : _idle,
                ),
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
