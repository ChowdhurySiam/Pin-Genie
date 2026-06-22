import 'package:flutter/material.dart';

class ExpressiveCard extends StatelessWidget {
  const ExpressiveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.borderRadius = 28,
    this.highlight = false,
    this.color,
    this.borderColor,
    this.shadowColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final bool highlight;
  final Color? color;
  final Color? borderColor;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (highlight ? colorScheme.primaryContainer : colorScheme.surfaceContainer),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ??
              (highlight ? colorScheme.primary.withValues(alpha: 0.20) : colorScheme.outlineVariant.withValues(alpha: 0.55)),
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor ?? colorScheme.shadow.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.08),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;

    return _Pressable(onTap: onTap, child: card);
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
