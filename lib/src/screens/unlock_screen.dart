import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../utils/responsive.dart';
import '../widgets/expressive_card.dart';
import '../widgets/pin_dots.dart';
import '../widgets/pin_genie_pad.dart';
import 'home_shell.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  static const routeName = '/unlock';

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

enum _UnlockMethod { pinGenie, biometric }

class _UnlockScreenState extends State<UnlockScreen> with SingleTickerProviderStateMixin {
  final _selections = <Set<String>>[];
  bool _error = false;
  bool _biometricPrompting = false;
  bool _biometricFailed = false;
  bool _hiddenBiometricPromptStarted = false;
  Timer? _retryTimer;
  _UnlockMethod _method = _UnlockMethod.pinGenie;
  late final AnimationController _shakeController;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = AppLockScope.of(context);
      await controller.refreshBiometricState();
      if (!mounted) return;
      if (controller.effectiveUnlockMethod == UnlockMethod.pinWithHiddenFingerprint) {
        await _startHiddenBiometricPrompt();
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _selectBucket(Set<String> digits) async {
    final controller = AppLockScope.of(context);
    if (controller.isPinRetryBlocked) {
      HapticFeedback.mediumImpact();
      _scheduleRetryTick();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      _selections.add(digits);
    });

    if (_selections.length != controller.pinLength) return;

    final ok = controller.verifyGenieSelections(_selections);
    if (ok) {
      await _finishUnlock(method: 'PIN Genie');
      return;
    }

    await controller.registerFailedAttempt(
      method: 'PIN Genie',
      message: 'Wrong PIN Genie pattern',
      countsForRetry: true,
    );
    _scheduleRetryTick();
    HapticFeedback.heavyImpact();
    setState(() {
      _error = true;
      _selections.clear();
    });
    _shakeController.forward(from: 0);
  }


  void _scheduleRetryTick() {
    _retryTimer?.cancel();
    final controller = AppLockScope.of(context);
    if (!controller.isPinRetryBlocked) return;
    final delay = controller.pinRetryRemaining + const Duration(milliseconds: 180);
    _retryTimer = Timer(delay, () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _openRecoveryDialog() async {
    final controller = AppLockScope.of(context);
    if (!controller.hasAnyRecoveryMethod) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Recovery options',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only configured recovery methods are shown here.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                if (controller.recoveryCodesEnabled)
                  ListTile(
                    leading: const Icon(Icons.password_rounded),
                    title: const Text('Use recovery code'),
                    subtitle: Text('${controller.recoveryCodeCount} code${controller.recoveryCodeCount == 1 ? '' : 's'} remaining'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _openRecoveryCodeDialog();
                    },
                  ),
                if (controller.securityQuestionEnabled)
                  ListTile(
                    leading: const Icon(Icons.help_rounded),
                    title: const Text('Answer security question'),
                    subtitle: Text(controller.securityQuestion ?? 'Configured question'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _openSecurityAnswerDialog();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openRecoveryCodeDialog() async {
    final controller = AppLockScope.of(context);
    final codeController = TextEditingController();
    var hasError = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              icon: const Icon(Icons.password_rounded),
              title: const Text('Recovery code'),
              content: TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'One-time recovery code',
                  errorText: hasError ? 'Invalid or already used recovery code' : null,
                ),
                onSubmitted: (_) async {
                  final verified = await controller.verifyAndConsumeRecoveryCode(codeController.text);
                  if (verified) {
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                  } else {
                    setDialogState(() => hasError = true);
                  }
                },
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final verified = await controller.verifyAndConsumeRecoveryCode(codeController.text);
                    if (verified) {
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                    } else {
                      setDialogState(() => hasError = true);
                    }
                  },
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );
    codeController.dispose();
    if (ok == true) {
      await _finishUnlock(method: 'Recovery code');
    } else if (hasError) {
      await controller.registerFailedAttempt(method: 'Recovery code', message: 'Invalid recovery code');
    }
  }

  Future<void> _openSecurityAnswerDialog() async {
    final controller = AppLockScope.of(context);
    final answerController = TextEditingController();
    var hasError = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              icon: const Icon(Icons.help_rounded),
              title: const Text('Security question'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(controller.securityQuestion ?? 'Security question'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: answerController,
                      obscureText: true,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Answer',
                        errorText: hasError ? 'Wrong answer' : null,
                      ),
                      onSubmitted: (_) {
                        final verified = controller.verifySecurityAnswer(answerController.text);
                        if (verified) {
                          Navigator.of(dialogContext).pop(true);
                        } else {
                          setDialogState(() => hasError = true);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    final verified = controller.verifySecurityAnswer(answerController.text);
                    if (verified) {
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      setDialogState(() => hasError = true);
                    }
                  },
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );
    answerController.dispose();
    if (ok == true) {
      await controller.clearPinFailures();
      await _finishUnlock(method: 'Security question');
    } else if (hasError) {
      await controller.registerFailedAttempt(method: 'Security question', message: 'Wrong security answer');
    }
  }

  Future<void> _finishUnlock({required String method}) async {
    final controller = AppLockScope.of(context);
    HapticFeedback.mediumImpact();
    await controller.markUnlocked(method: method);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(HomeShell.routeName, (_) => false);
  }

  Future<void> _startHiddenBiometricPrompt() async {
    if (_hiddenBiometricPromptStarted || _biometricPrompting) return;
    final controller = AppLockScope.of(context);
    if (!controller.biometricAvailable) return;
    _hiddenBiometricPromptStarted = true;
    setState(() {
      _biometricPrompting = true;
      _biometricFailed = false;
    });

    final unlocked = await controller.authenticateWithBiometrics();
    if (!mounted) return;

    setState(() => _biometricPrompting = false);
    if (unlocked) {
      await _finishUnlock(method: 'Biometric');
    }
  }

  Future<void> _toggleUnlockMethod() async {
    final controller = AppLockScope.of(context);
    if (!controller.biometricAvailable) return;

    final shouldOpenBiometricPrompt = _method == _UnlockMethod.pinGenie;
    setState(() {
      _method = shouldOpenBiometricPrompt ? _UnlockMethod.biometric : _UnlockMethod.pinGenie;
      _biometricFailed = false;
      _error = false;
      _selections.clear();
    });

    if (!shouldOpenBiometricPrompt) return;

    // Let the biometric card animate in first, then immediately open Android's
    // system biometric prompt from the fingerprint/face switch button.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted || _method != _UnlockMethod.biometric) return;
    await _authenticateBiometric();
  }

  Future<void> _authenticateBiometric() async {
    if (_biometricPrompting) return;
    final controller = AppLockScope.of(context);
    setState(() {
      _biometricPrompting = true;
      _biometricFailed = false;
    });

    final unlocked = await controller.authenticateWithBiometrics();
    if (!mounted) return;

    setState(() {
      _biometricPrompting = false;
      _biometricFailed = !unlocked;
    });

    if (unlocked) {
      await _finishUnlock(method: 'Biometric');
    } else {
      await controller.registerFailedAttempt(
        method: 'Biometric',
        message: 'Biometric unlock failed',
      );
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final visuals = _LockVisuals.fromTheme(controller.lockTheme, colorScheme);
    final unlockMethod = controller.effectiveUnlockMethod;
    final showBiometricSwitch = controller.biometricAvailable && unlockMethod == UnlockMethod.fingerprintSwitch;
    final showBiometricBody = showBiometricSwitch && _method == _UnlockMethod.biometric;
    if (controller.isPinRetryBlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleRetryTick();
      });
    }

    return Scaffold(
      backgroundColor: visuals.background,
      floatingActionButton: showBiometricSwitch
          ? _UnlockMethodFab(
              method: _method,
              visuals: visuals,
              onTap: _toggleUnlockMethod,
            )
          : null,
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: visuals.chipColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.enhanced_encryption_rounded, size: 18, color: visuals.chipForeground),
                        const SizedBox(width: 8),
                        Text(
                          'PIN Genie',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: visuals.chipForeground,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  child: !showBiometricBody
                      ? _PinGenieUnlockBody(
                          key: const ValueKey('pin'),
                          shake: _shake,
                          error: _error,
                          selections: _selections,
                          controller: controller,
                          visuals: visuals,
                          onBucketSelected: _selectBucket,
                          onRecovery: controller.hasAnyRecoveryMethod ? _openRecoveryDialog : null,
                          retryBlocked: controller.isPinRetryBlocked,
                          retryRemaining: controller.pinRetryRemaining,
                        )
                      : _BiometricUnlockBody(
                          key: const ValueKey('biometric'),
                          shake: _shake,
                          prompting: _biometricPrompting,
                          failed: _biometricFailed,
                          sensorStyle: controller.biometricSensorStyle,
                          visuals: visuals,
                          onScan: _authenticateBiometric,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinGenieUnlockBody extends StatelessWidget {
  const _PinGenieUnlockBody({
    super.key,
    required this.shake,
    required this.error,
    required this.selections,
    required this.controller,
    required this.visuals,
    required this.onBucketSelected,
    required this.retryBlocked,
    required this.retryRemaining,
    this.onRecovery,
  });

  final Animation<double> shake;
  final bool error;
  final List<Set<String>> selections;
  final AppLockController controller;
  final _LockVisuals visuals;
  final ValueChanged<Set<String>> onBucketSelected;
  final bool retryBlocked;
  final Duration retryRemaining;
  final VoidCallback? onRecovery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(shake.value, 0),
            child: child,
          ),
          child: ExpressiveCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            borderRadius: 28,
            highlight: true,
            color: visuals.cardColor,
            borderColor: visuals.borderColor,
            shadowColor: visuals.shadowColor,
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: visuals.iconBackground,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(Icons.lock_rounded, color: visuals.iconForeground, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unlock protection',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: visuals.titleColor,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap the tile containing each hidden PIN digit. Tiles reshuffle after every tap.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: visuals.bodyColor,
                        height: 1.32,
                      ),
                ),
                const SizedBox(height: 14),
                PinDots(
                  filled: selections.length,
                  total: controller.pinLength,
                  hasError: error,
                  filledColor: visuals.iconForeground,
                  emptyColor: visuals.dotEmptyColor,
                  errorColor: visuals.errorColor,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: retryBlocked || error
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            retryBlocked
                                ? 'Too many failed attempts. Try again in ${_formatRetryRemaining(retryRemaining)}.'
                                : 'Wrong PIN pattern. Try again.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: visuals.errorColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (onRecovery != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRecovery,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    label: const Text('Forgot PIN?'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 96),
            child: IgnorePointer(
              ignoring: retryBlocked,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: retryBlocked ? 0.42 : 1,
                child: PinGeniePad(
                  randomize: controller.randomizeKeypad,
                  tileStyle: controller.tileStyle,
                  tileColors: visuals.tileColors,
                  tileForegroundColors: visuals.tileForegrounds,
                  onBucketSelected: onBucketSelected,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


String _formatRetryRemaining(Duration remaining) {
  final seconds = remaining.inSeconds <= 0 ? 1 : remaining.inSeconds;
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return rest == 0 ? '${minutes}m' : '${minutes}m ${rest}s';
}

class _BiometricUnlockBody extends StatelessWidget {
  const _BiometricUnlockBody({
    super.key,
    required this.shake,
    required this.prompting,
    required this.failed,
    required this.sensorStyle,
    required this.visuals,
    required this.onScan,
  });

  final Animation<double> shake;
  final bool prompting;
  final bool failed;
  final BiometricSensorStyle sensorStyle;
  final _LockVisuals visuals;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final copy = _BiometricCopy.fromStyle(sensorStyle);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 96),
        child: AnimatedBuilder(
          animation: shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(shake.value, 0),
            child: child,
          ),
          child: ExpressiveCard(
            padding: const EdgeInsets.all(28),
            borderRadius: 38,
            highlight: true,
            color: visuals.cardColor,
            borderColor: visuals.borderColor,
            shadowColor: visuals.shadowColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BiometricPulse(
                  prompting: prompting,
                  sensorStyle: sensorStyle,
                  visuals: visuals,
                ),
                const SizedBox(height: 22),
                Text(
                  copy.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: visuals.titleColor,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  copy.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: visuals.bodyColor,
                        height: 1.32,
                      ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: prompting ? null : onScan,
                  icon: prompting
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Icon(copy.buttonIcon),
                  label: Text(prompting ? copy.waitingLabel : copy.buttonLabel),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: failed
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            'Biometric unlock failed. Try again or switch back to PIN Genie.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BiometricCopy {
  const _BiometricCopy({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.waitingLabel,
    required this.buttonIcon,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final String waitingLabel;
  final IconData buttonIcon;

  factory _BiometricCopy.fromStyle(BiometricSensorStyle style) {
    return switch (style) {
      BiometricSensorStyle.face => const _BiometricCopy(
          title: 'Face unlock',
          description: 'PIN Genie remains the default. Use face unlock only on devices with enrolled face authentication.',
          buttonLabel: 'Scan face',
          waitingLabel: 'Looking for face',
          buttonIcon: Icons.face_retouching_natural_rounded,
        ),
      BiometricSensorStyle.inDisplayFingerprint => const _BiometricCopy(
          title: 'In-display fingerprint',
          description: 'PIN Genie remains the default. Place your finger on the glowing in-display fingerprint area when prompted.',
          buttonLabel: 'Scan in-display fingerprint',
          waitingLabel: 'Waiting for in-display scan',
          buttonIcon: Icons.fingerprint_rounded,
        ),
      BiometricSensorStyle.sideFingerprint => const _BiometricCopy(
          title: 'Side fingerprint',
          description: 'PIN Genie remains the default. Touch the side-mounted fingerprint sensor when the Android prompt appears.',
          buttonLabel: 'Scan side fingerprint',
          waitingLabel: 'Waiting for side scan',
          buttonIcon: Icons.fingerprint_rounded,
        ),
      BiometricSensorStyle.rearFingerprint => const _BiometricCopy(
          title: 'Rear fingerprint',
          description: 'PIN Genie remains the default. Touch the rear fingerprint sensor when the Android prompt appears.',
          buttonLabel: 'Scan rear fingerprint',
          waitingLabel: 'Waiting for rear scan',
          buttonIcon: Icons.fingerprint_rounded,
        ),
      BiometricSensorStyle.genericFingerprint => const _BiometricCopy(
          title: 'Fingerprint or face unlock',
          description: 'PIN Genie remains the default. Use biometric unlock only when this device has enrolled fingerprint or face authentication.',
          buttonLabel: 'Scan fingerprint or face',
          waitingLabel: 'Waiting for scan',
          buttonIcon: Icons.fingerprint_rounded,
        ),
    };
  }
}

class _BiometricPulse extends StatefulWidget {
  const _BiometricPulse({
    required this.prompting,
    required this.sensorStyle,
    required this.visuals,
  });

  final bool prompting;
  final BiometricSensorStyle sensorStyle;
  final _LockVisuals visuals;

  @override
  State<_BiometricPulse> createState() => _BiometricPulseState();
}

class _BiometricPulseState extends State<_BiometricPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.prompting) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _BiometricPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prompting && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.prompting && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = widget.prompting ? _controller.value : 0.0;
        final scale = 1 + (pulse * 0.045);
        return Transform.scale(
          scale: scale,
          child: _SensorStyleAnimation(
            style: widget.sensorStyle,
            pulse: pulse,
            prompting: widget.prompting,
            colorScheme: colorScheme,
            visuals: widget.visuals,
          ),
        );
      },
    );
  }
}

class _SensorStyleAnimation extends StatelessWidget {
  const _SensorStyleAnimation({
    required this.style,
    required this.pulse,
    required this.prompting,
    required this.colorScheme,
    required this.visuals,
  });

  final BiometricSensorStyle style;
  final double pulse;
  final bool prompting;
  final ColorScheme colorScheme;
  final _LockVisuals visuals;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      height: 136,
      decoration: BoxDecoration(
        color: visuals.iconBackground,
        borderRadius: BorderRadius.circular(42),
        boxShadow: [
          BoxShadow(
            color: visuals.shadowColor.withValues(alpha: prompting ? 0.55 + (pulse * 0.22) : 0.35),
            blurRadius: prompting ? 24 + (pulse * 16) : 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: switch (style) {
        BiometricSensorStyle.face => _FaceSensorAnimation(pulse: pulse, colorScheme: colorScheme),
        BiometricSensorStyle.inDisplayFingerprint => _InDisplaySensorAnimation(pulse: pulse, colorScheme: colorScheme),
        BiometricSensorStyle.sideFingerprint => _SideSensorAnimation(pulse: pulse, colorScheme: colorScheme),
        BiometricSensorStyle.rearFingerprint => _RearSensorAnimation(pulse: pulse, colorScheme: colorScheme),
        BiometricSensorStyle.genericFingerprint => _GenericBiometricAnimation(pulse: pulse, colorScheme: colorScheme),
      },
    );
  }
}

class _FaceSensorAnimation extends StatelessWidget {
  const _FaceSensorAnimation({required this.pulse, required this.colorScheme});

  final double pulse;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 82,
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colorScheme.onPrimaryContainer.withValues(alpha: 0.24), width: 2),
          ),
        ),
        Transform.translate(
          offset: Offset(0, -28 + (pulse * 56)),
          child: Container(
            width: 78,
            height: 3,
            decoration: BoxDecoration(
              color: colorScheme.tertiary.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        Icon(Icons.face_retouching_natural_rounded, size: 58, color: colorScheme.onPrimaryContainer),
      ],
    );
  }
}

class _InDisplaySensorAnimation extends StatelessWidget {
  const _InDisplaySensorAnimation({required this.pulse, required this.colorScheme});

  final double pulse;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 72,
          height: 112,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colorScheme.onPrimaryContainer.withValues(alpha: 0.22)),
          ),
        ),
        Positioned(
          bottom: 22,
          child: Container(
            width: 42 + pulse * 10,
            height: 42 + pulse * 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.38),
              border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.55 + pulse * 0.25), width: 2),
            ),
            child: Icon(Icons.fingerprint_rounded, size: 30, color: colorScheme.onPrimaryContainer),
          ),
        ),
      ],
    );
  }
}

class _SideSensorAnimation extends StatelessWidget {
  const _SideSensorAnimation({required this.pulse, required this.colorScheme});

  final double pulse;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 78,
          height: 108,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colorScheme.onPrimaryContainer.withValues(alpha: 0.22)),
          ),
          child: Icon(Icons.fingerprint_rounded, size: 42, color: colorScheme.onPrimaryContainer.withValues(alpha: 0.62)),
        ),
        Positioned(
          right: 23,
          child: Container(
            width: 10 + pulse * 4,
            height: 58 + pulse * 8,
            decoration: BoxDecoration(
              color: colorScheme.tertiary.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(color: colorScheme.tertiary.withValues(alpha: 0.35), blurRadius: 12 + pulse * 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RearSensorAnimation extends StatelessWidget {
  const _RearSensorAnimation({required this.pulse, required this.colorScheme});

  final double pulse;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 78,
          height: 108,
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colorScheme.onPrimaryContainer.withValues(alpha: 0.22)),
          ),
        ),
        Positioned(
          top: 28,
          child: Container(
            width: 44 + pulse * 8,
            height: 44 + pulse * 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.36),
              border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.55 + pulse * 0.25), width: 2),
            ),
            child: Icon(Icons.fingerprint_rounded, size: 30, color: colorScheme.onPrimaryContainer),
          ),
        ),
      ],
    );
  }
}

class _GenericBiometricAnimation extends StatelessWidget {
  const _GenericBiometricAnimation({required this.pulse, required this.colorScheme});

  final double pulse;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: 1 + pulse * 0.08,
          child: Icon(Icons.face_retouching_natural_rounded, size: 60, color: colorScheme.onPrimaryContainer.withValues(alpha: 0.28)),
        ),
        Icon(Icons.fingerprint_rounded, size: 64, color: colorScheme.onPrimaryContainer),
      ],
    );
  }
}


class _LockVisuals {
  const _LockVisuals({
    required this.background,
    required this.cardColor,
    required this.borderColor,
    required this.titleColor,
    required this.bodyColor,
    required this.chipColor,
    required this.chipForeground,
    required this.iconBackground,
    required this.iconForeground,
    required this.dotEmptyColor,
    required this.errorColor,
    required this.shadowColor,
    required this.tileColors,
    required this.tileForegrounds,
  });

  final Color background;
  final Color cardColor;
  final Color borderColor;
  final Color titleColor;
  final Color bodyColor;
  final Color chipColor;
  final Color chipForeground;
  final Color iconBackground;
  final Color iconForeground;
  final Color dotEmptyColor;
  final Color errorColor;
  final Color shadowColor;
  final List<Color> tileColors;
  final List<Color> tileForegrounds;

  factory _LockVisuals.fromTheme(LockVisualTheme theme, ColorScheme scheme) {
    return switch (theme) {
      LockVisualTheme.defaultBlue => _LockVisuals(
          background: const Color(0xFF111418),
          cardColor: const Color(0xFF3E4A86),
          borderColor: const Color(0xFF5360A3),
          titleColor: const Color(0xFFF0F1FF),
          bodyColor: const Color(0xFFC9CBE0),
          chipColor: const Color(0xFF3E4A86),
          chipForeground: const Color(0xFFF0F1FF),
          iconBackground: const Color(0xFFB7C2FF),
          iconForeground: const Color(0xFF202A5B),
          dotEmptyColor: const Color(0xFF666A7E),
          errorColor: scheme.error,
          shadowColor: Colors.black.withValues(alpha: 0.28),
          tileColors: const [Color(0xFF3E4A86), Color(0xFF4B5267), Color(0xFF6B405D)],
          tileForegrounds: const [Color(0xFFF0F1FF), Color(0xFFE7E9F8), Color(0xFFFFD8EA)],
        ),
      LockVisualTheme.amoledBlack => _LockVisuals(
          background: Colors.black,
          cardColor: const Color(0xFF080A0F),
          borderColor: const Color(0xFF202431),
          titleColor: const Color(0xFFF6F7FF),
          bodyColor: const Color(0xFFBFC3D8),
          chipColor: const Color(0xFF10131D),
          chipForeground: const Color(0xFFE9ECFF),
          iconBackground: const Color(0xFF1F2540),
          iconForeground: const Color(0xFFE9ECFF),
          dotEmptyColor: const Color(0xFF3A3E4D),
          errorColor: scheme.error,
          shadowColor: Colors.black.withValues(alpha: 0.52),
          tileColors: const [Color(0xFF151A29), Color(0xFF202431), Color(0xFF2A2130)],
          tileForegrounds: const [Color(0xFFEFF1FF), Color(0xFFE5E7F4), Color(0xFFF4D9EA)],
        ),
      LockVisualTheme.purpleNeon => _LockVisuals(
          background: const Color(0xFF100B1D),
          cardColor: const Color(0xFF3F246C),
          borderColor: const Color(0xFF805DE0),
          titleColor: const Color(0xFFFFF7FF),
          bodyColor: const Color(0xFFE2D3FF),
          chipColor: const Color(0xFF4A2B7B),
          chipForeground: const Color(0xFFFFF7FF),
          iconBackground: const Color(0xFFE2C7FF),
          iconForeground: const Color(0xFF311653),
          dotEmptyColor: const Color(0xFF776794),
          errorColor: const Color(0xFFFFB4AB),
          shadowColor: const Color(0xFFB065FF).withValues(alpha: 0.24),
          tileColors: const [Color(0xFF4A2B7B), Color(0xFF31315E), Color(0xFF7A356C)],
          tileForegrounds: const [Color(0xFFFFF7FF), Color(0xFFE4E6FF), Color(0xFFFFD8EF)],
        ),
      LockVisualTheme.minimalLight => _LockVisuals(
          background: const Color(0xFFF8F7FC),
          cardColor: const Color(0xFFECE9FF),
          borderColor: const Color(0xFFD5D1EC),
          titleColor: const Color(0xFF1C1B22),
          bodyColor: const Color(0xFF555260),
          chipColor: const Color(0xFFE7E3FF),
          chipForeground: const Color(0xFF252047),
          iconBackground: const Color(0xFF615E9B),
          iconForeground: const Color(0xFFFFFFFF),
          dotEmptyColor: const Color(0xFFC2C0CF),
          errorColor: const Color(0xFFBA1A1A),
          shadowColor: Colors.black.withValues(alpha: 0.10),
          tileColors: const [Color(0xFFE7E3FF), Color(0xFFECEEF7), Color(0xFFFFD8E8)],
          tileForegrounds: const [Color(0xFF252047), Color(0xFF2E3346), Color(0xFF4C2339)],
        ),
      LockVisualTheme.materialPastel => _LockVisuals(
          background: const Color(0xFFF4F7FF),
          cardColor: const Color(0xFFDCE6FF),
          borderColor: const Color(0xFFC5D5F5),
          titleColor: const Color(0xFF172033),
          bodyColor: const Color(0xFF4E586B),
          chipColor: const Color(0xFFDCE6FF),
          chipForeground: const Color(0xFF172033),
          iconBackground: const Color(0xFF9CCAFF),
          iconForeground: const Color(0xFF143047),
          dotEmptyColor: const Color(0xFFACB7C8),
          errorColor: const Color(0xFFBA1A1A),
          shadowColor: const Color(0xFF7C93C7).withValues(alpha: 0.20),
          tileColors: const [Color(0xFFDCE6FF), Color(0xFFD9F0E5), Color(0xFFFFD9E2)],
          tileForegrounds: const [Color(0xFF172033), Color(0xFF163426), Color(0xFF4B2532)],
        ),
      LockVisualTheme.animeSoft => _LockVisuals(
          background: const Color(0xFF160F1F),
          cardColor: const Color(0xFF4D3C78),
          borderColor: const Color(0xFF7D6AAD),
          titleColor: const Color(0xFFFFF8FB),
          bodyColor: const Color(0xFFEADDF2),
          chipColor: const Color(0xFF4D3C78),
          chipForeground: const Color(0xFFFFF8FB),
          iconBackground: const Color(0xFFFFC7E5),
          iconForeground: const Color(0xFF49304D),
          dotEmptyColor: const Color(0xFF897B99),
          errorColor: const Color(0xFFFFB4AB),
          shadowColor: const Color(0xFFFF9BD1).withValues(alpha: 0.20),
          tileColors: const [Color(0xFF4D3C78), Color(0xFF445273), Color(0xFF7B4264)],
          tileForegrounds: const [Color(0xFFFFF8FB), Color(0xFFEAF0FF), Color(0xFFFFE0EF)],
        ),
    };
  }
}

class _UnlockMethodFab extends StatelessWidget {
  const _UnlockMethodFab({required this.method, required this.visuals, required this.onTap});

  final _UnlockMethod method;
  final _LockVisuals visuals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final usingPin = method == _UnlockMethod.pinGenie;
    return FloatingActionButton.small(
      heroTag: 'unlock_method_switcher',
      tooltip: usingPin ? 'Use fingerprint or face unlock' : 'Use PIN Genie',
      onPressed: onTap,
      backgroundColor: visuals.chipColor,
      foregroundColor: visuals.chipForeground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: Icon(
          usingPin ? Icons.fingerprint_rounded : Icons.enhanced_encryption_rounded,
          key: ValueKey(usingPin),
        ),
      ),
    );
  }
}
