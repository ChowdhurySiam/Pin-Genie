import 'package:flutter/material.dart';

class PhysicsButton extends StatefulWidget {
  const PhysicsButton({
    super.key,
    required this.child,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 22,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final EdgeInsets padding;

  @override
  State<PhysicsButton> createState() => _PhysicsButtonState();
}

class _PhysicsButtonState extends State<PhysicsButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? colorScheme.primary,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: widget.foregroundColor ?? colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
            child: IconTheme.merge(
              data: IconThemeData(color: widget.foregroundColor ?? colorScheme.onPrimary),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
