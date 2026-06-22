import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../utils/responsive.dart';
import '../widgets/expressive_card.dart';
import '../widgets/pin_dots.dart';
import 'home_shell.dart';

enum CreatePinMode { create, change }

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key, required this.mode});

  static const routeName = '/create-pin';

  final CreatePinMode mode;

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  static const _pinLength = 4;

  String _firstPin = '';
  String _currentPin = '';
  bool _confirming = false;
  bool _error = false;

  void _append(String digit) {
    if (_currentPin.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      _currentPin += digit;
    });
    if (_currentPin.length == _pinLength) {
      Future<void>.delayed(const Duration(milliseconds: 180), _advance);
    }
  }

  void _backspace() {
    if (_currentPin.isEmpty) return;
    setState(() {
      _error = false;
      _currentPin = _currentPin.substring(0, _currentPin.length - 1);
    });
  }

  Future<void> _advance() async {
    if (!_confirming) {
      setState(() {
        _firstPin = _currentPin;
        _currentPin = '';
        _confirming = true;
      });
      return;
    }

    if (_currentPin != _firstPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _currentPin = '';
        _firstPin = '';
        _confirming = false;
        _error = true;
      });
      return;
    }

    final controller = AppLockScope.of(context);
    await controller.setPin(_currentPin);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(HomeShell.routeName, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isChange = widget.mode == CreatePinMode.change;
    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (isChange)
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _confirming ? 'Step 2 of 2' : 'Step 1 of 2',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ExpressiveCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 34,
                child: Column(
                  children: [
                    Icon(
                      _confirming ? Icons.verified_user_rounded : Icons.password_rounded,
                      size: 50,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _confirming ? 'Confirm your PIN' : isChange ? 'Create a new PIN' : 'Create your PIN',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _confirming
                          ? 'Enter the same PIN again to finish setup.'
                          : 'Use a 4-digit PIN. Unlocking later uses the PIN Genie randomized tiles.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 24),
                    PinDots(filled: _currentPin.length, total: _pinLength, hasError: _error),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: _error
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                'PIN did not match. Start again.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _NumberPad(onDigit: _append, onBackspace: _backspace),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        if (key.isEmpty) return const SizedBox.shrink();
        return _KeyButton(
          label: key,
          onTap: key == 'back' ? onBackspace : () => onDigit(key),
        );
      },
    );
  }
}

class _KeyButton extends StatefulWidget {
  const _KeyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _pressed = true);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBack = widget.label == 'back';

    return Semantics(
      button: true,
      label: isBack ? 'Delete digit' : 'Digit ${widget.label}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(isBack ? 24 : 30),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: isBack
                  ? Icon(Icons.backspace_rounded, color: colorScheme.onSurfaceVariant)
                  : Text(
                      widget.label,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
