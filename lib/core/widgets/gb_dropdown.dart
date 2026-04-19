import 'package:flutter/material.dart';

class GbDropdown extends StatefulWidget {
  const GbDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.label,
    this.prefixIcon,
    this.validator,
    this.enabled = true,
    this.hint,
  });

  final List<String> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? label;
  final IconData? prefixIcon;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final String? hint;

  @override
  State<GbDropdown> createState() => _GbDropdownState();
}

class _GbDropdownState extends State<GbDropdown> with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _sizeAnimation;
  final LayerLink _layerLink = LayerLink();
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic);
    _sizeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _closeMenu(force: true);
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu({
    required FormFieldState<String> field,
    required List<String> items,
    required String? selected,
  }) {
    if (_isOpen) {
      _closeMenu();
      return;
    }
    _openMenu(field: field, items: items, selected: selected);
  }

  void _openMenu({
    required FormFieldState<String> field,
    required List<String> items,
    required String? selected,
  }) {
    if (_isOpen || items.isEmpty) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final topLeft = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableBelow = (screenHeight - (topLeft.dy + size.height) - 16).clamp(120.0, 360.0);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
              ),
            ),
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 8),
                child: Material(
                  color: Colors.transparent,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizeTransition(
                      axisAlignment: -1,
                      sizeFactor: _sizeAnimation,
                      child: Container(
                        constraints: BoxConstraints(maxHeight: availableBelow),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD9E4F7)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x190E1A33),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F3FA)),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isSelected = item == selected;

                            return InkWell(
                              onTap: () {
                                field.didChange(item);
                                widget.onChanged?.call(item);
                                _closeMenu();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                color: isSelected ? const Color(0xFFEFF4FF) : Colors.transparent,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: const Color(0xFF22324F),
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_rounded, size: 18, color: Color(0xFF2F6EFF)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
    if (mounted) {
      setState(() {
        _isOpen = true;
      });
    } else {
      _isOpen = true;
    }
    _animationController.forward(from: 0);
  }

  Future<void> _closeMenu({bool force = false}) async {
    if (!_isOpen && !force) return;

    if (!force) {
      await _animationController.reverse();
    }

    _overlayEntry?.remove();
    _overlayEntry = null;
    if (!force && mounted) {
      setState(() {
        _isOpen = false;
      });
    } else {
      _isOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: ValueKey(widget.value),
      initialValue: widget.value,
      validator: widget.validator,
      builder: (field) {
        final selected = field.value;
        final hasError = field.hasError;
        final enabled = widget.enabled;
        final hasValue = selected != null && selected.trim().isNotEmpty;

        final borderColor = hasError
            ? const Color(0xFFD93025)
            : (_isOpen ? const Color(0xFF2F6EFF) : const Color(0xFFD9E4F7));

        return CompositedTransformTarget(
          link: _layerLink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: enabled
                    ? () => _toggleMenu(field: field, items: widget.items, selected: selected)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: enabled ? Colors.white : const Color(0xFFF5F7FD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: _isOpen ? 2 : 1.5),
                  ),
                  child: Row(
                    children: [
                      if (widget.prefixIcon != null) ...[
                        Icon(widget.prefixIcon, color: const Color(0xFF6D84AC), size: 20),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          hasValue ? selected : (widget.hint ?? widget.label ?? 'Select'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasValue ? const Color(0xFF22324F) : const Color(0xFF8EA0BF),
                            fontSize: 14.5,
                            fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 160),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF2F6EFF),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    field.errorText ?? '',
                    style: const TextStyle(color: Color(0xFFD93025), fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class GbDropdownField extends StatelessWidget {
  const GbDropdownField({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.hint,
  });

  final String label;
  final IconData icon;
  final List<String> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF2F6EFF), size: 18),
              const SizedBox(width: 7),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GbDropdown(
            items: items,
            value: value,
            onChanged: onChanged,
            label: null,
            prefixIcon: null,
            validator: validator,
            enabled: enabled,
            hint: hint,
          ),
        ),
      ],
    );
  }
}
