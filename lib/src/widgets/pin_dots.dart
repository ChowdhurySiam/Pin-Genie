import 'package:flutter/material.dart';

class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    required this.total,
    this.hasError = false,
    this.filledColor,
    this.emptyColor,
    this.errorColor,
  });

  final int filled;
  final int total;
  final bool hasError;
  final Color? filledColor;
  final Color? emptyColor;
  final Color? errorColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isFilled = index < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          width: isFilled ? 26 : 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: hasError
                ? (errorColor ?? colorScheme.error)
                : isFilled
                    ? (filledColor ?? colorScheme.primary)
                    : (emptyColor ?? colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
