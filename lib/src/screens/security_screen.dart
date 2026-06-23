import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../utils/responsive.dart';
import '../widgets/expressive_card.dart';
import 'create_pin_screen.dart';
import 'intruder_selfies_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = AppLockScope.of(context);
      controller.refreshBiometricState();
      controller.refreshCameraPermissionState();
      controller.refreshLockHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 760,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Security',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Manage PIN reset, recovery methods, retry timeout, unlock fallback, and security logs.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              const _PinRecoveryCard(),
              const SizedBox(height: 16),
              const _RetryTimeoutCard(),
              const SizedBox(height: 16),
              const _UnlockFallbackCard(),
              const SizedBox(height: 16),
              const _RelockDelayCard(),
              const SizedBox(height: 16),
              const _AdvancedProtectionCard(),
              const SizedBox(height: 16),
              const _SecurityHistoryCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinRecoveryCard extends StatelessWidget {
  const _PinRecoveryCard();

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.lock_reset_rounded,
            title: 'Reset PIN',
            subtitle: 'Verify current PIN before creating a new 4-digit PIN.',
            onTap: () => _resetPin(context),
          ),
          _Divider(color: colorScheme.outlineVariant),
          _ActionTile(
            icon: Icons.password_rounded,
            title: 'Recovery codes',
            subtitle: controller.recoveryCodesEnabled
                ? '${controller.recoveryCodeCount} one-time recovery code${controller.recoveryCodeCount == 1 ? '' : 's'} available.'
                : 'Generate one-time codes for PIN recovery.',
            trailing: _StatusPill(label: controller.recoveryCodesEnabled ? 'Enabled' : 'Off'),
            onTap: () => _manageRecoveryCodes(context),
          ),
          _Divider(color: colorScheme.outlineVariant),
          _ActionTile(
            icon: Icons.help_rounded,
            title: 'Security question',
            subtitle: controller.securityQuestionEnabled
                ? controller.securityQuestion ?? 'Custom recovery question is configured.'
                : 'Add a custom question-and-answer fallback.',
            trailing: _StatusPill(label: controller.securityQuestionEnabled ? 'Enabled' : 'Off'),
            onTap: () => _manageSecurityQuestion(context),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPin(BuildContext context) async {
    final controller = AppLockScope.of(context);
    final verified = await _verifyCurrentPin(context, controller);
    if (!verified || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreatePinScreen(mode: CreatePinMode.change),
      ),
    );
  }

  Future<bool> _verifyCurrentPin(BuildContext context, AppLockController controller) async {
    final pinController = TextEditingController();
    var hasError = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              icon: const Icon(Icons.verified_user_rounded),
              title: const Text('Verify current PIN'),
              content: TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: controller.pinLength,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Current PIN',
                  counterText: '',
                  errorText: hasError ? 'Wrong PIN' : null,
                ),
                onSubmitted: (_) {
                  final ok = controller.verifyPin(pinController.text.trim());
                  if (ok) {
                    Navigator.of(dialogContext).pop(true);
                  } else {
                    setDialogState(() => hasError = true);
                  }
                },
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    final ok = controller.verifyPin(pinController.text.trim());
                    if (ok) {
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      setDialogState(() => hasError = true);
                    }
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
    pinController.dispose();
    return result ?? false;
  }

  Future<void> _manageRecoveryCodes(BuildContext context) async {
    final controller = AppLockScope.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.password_rounded),
          title: const Text('Recovery codes'),
          content: Text(
            controller.recoveryCodesEnabled
                ? 'Recovery codes are stored as salted hashes. They can only be viewed when newly generated. Regenerate codes to view and save a fresh set.'
                : 'Generate one-time recovery codes. Copy and keep them somewhere safe. Each code can be used once from the lock screen.',
          ),
          actions: [
            if (controller.recoveryCodesEnabled)
              TextButton.icon(
                onPressed: () async {
                  await controller.clearRecoveryCodes();
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Clear'),
              ),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () async {
                final codes = await controller.generateRecoveryCodes();
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (context.mounted) await _showGeneratedCodes(context, codes);
              },
              icon: const Icon(Icons.vpn_key_rounded),
              label: Text(controller.recoveryCodesEnabled ? 'Regenerate' : 'Generate'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showGeneratedCodes(BuildContext context, List<String> codes) async {
    final text = codes.join('\n');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.security_rounded),
          title: const Text('Save these recovery codes'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'These codes are shown once. They are stored only as hashes after this dialog closes.',
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: SelectableText(
                    text,
                    style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Recovery codes copied.')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy all'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _manageSecurityQuestion(BuildContext context) async {
    final controller = AppLockScope.of(context);
    final questionController = TextEditingController(text: controller.securityQuestion ?? '');
    final answerController = TextEditingController();
    var hasError = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              icon: const Icon(Icons.help_rounded),
              title: const Text('Security question'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Custom question'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: answerController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Answer',
                        errorText: hasError ? 'Enter a question and answer.' : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The answer is saved as a salted hash. It is not stored as readable text.',
                      style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                            color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (controller.securityQuestionEnabled)
                  TextButton.icon(
                    onPressed: () async {
                      await controller.clearSecurityQuestion();
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Clear'),
                  ),
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final saved = await controller.setSecurityQuestion(
                      question: questionController.text,
                      answer: answerController.text,
                    );
                    if (!saved) {
                      setDialogState(() => hasError = true);
                      return;
                    }
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    questionController.dispose();
    answerController.dispose();
  }
}

class _RetryTimeoutCard extends StatelessWidget {
  const _RetryTimeoutCard();

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: _ActionTile(
        icon: Icons.timer_off_rounded,
        title: 'Custom retry timeout',
        subtitle:
            'Block PIN input for ${_formatDuration(controller.pinRetryTimeoutSeconds)} after ${controller.pinFailureThreshold} failed attempt${controller.pinFailureThreshold == 1 ? '' : 's'}.',
        trailing: _StatusPill(label: _formatDuration(controller.pinRetryTimeoutSeconds)),
        onTap: () => _openRetryDialog(context),
      ),
    );
  }

  Future<void> _openRetryDialog(BuildContext context) async {
    final controller = AppLockScope.of(context);
    var threshold = controller.pinFailureThreshold;
    var timeout = controller.pinRetryTimeoutSeconds;
    final timeoutController = TextEditingController(text: timeout.toString());
    final thresholdController = FixedExtentScrollController(initialItem: threshold - 1);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void setTimeout(int value) {
              timeout = value.clamp(5, 3600).toInt();
              timeoutController.text = timeout.toString();
              setDialogState(() {});
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              icon: const Icon(Icons.timer_off_rounded),
              title: const Text('Retry timeout'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Failed attempt threshold',
                        style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 130,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: CupertinoPicker(
                          scrollController: thresholdController,
                          itemExtent: 42,
                          magnification: 1.08,
                          useMagnifier: true,
                          onSelectedItemChanged: (index) => threshold = index + 1,
                          children: [
                            for (var value = 1; value <= 10; value++)
                              Center(child: Text('$value failed attempt${value == 1 ? '' : 's'}')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Timeout duration',
                        style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in const [5, 15, 30, 60, 300, 900, 1800, 3600])
                            ChoiceChip(
                              label: Text(_formatDuration(value)),
                              selected: timeout == value,
                              onSelected: (_) => setTimeout(value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: timeoutController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Custom seconds',
                          helperText: 'Allowed range: 5 seconds to 60 minutes.',
                        ),
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed != null) timeout = parsed.clamp(5, 3600).toInt();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final parsed = int.tryParse(timeoutController.text.trim());
                    await controller.setRetryPolicy(
                      failureThreshold: threshold,
                      timeoutSeconds: parsed ?? timeout,
                    );
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    timeoutController.dispose();
    thresholdController.dispose();
  }
}

class _UnlockFallbackCard extends StatelessWidget {
  const _UnlockFallbackCard();

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: _ActionTile(
        icon: Icons.lock_open_rounded,
        title: 'Unlock fallback',
        subtitle: controller.biometricAvailable
            ? _unlockMethodDescription(controller.effectiveUnlockMethod)
            : 'Biometric fallback is unavailable. PIN-only mode is active.',
        trailing: _StatusPill(label: _unlockMethodLabel(controller.effectiveUnlockMethod)),
        onTap: () => _openUnlockMethodDialog(context),
      ),
    );
  }

  Future<void> _openUnlockMethodDialog(BuildContext context) async {
    final controller = AppLockScope.of(context);
    await controller.refreshBiometricState();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: controller,
          builder: (dialogContext, _) {
            final biometricEnabled = controller.biometricAvailable;
            return AlertDialog(
              icon: const Icon(Icons.lock_open_rounded),
              title: const Text('Unlock fallback'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChoiceTile(
                      selected: controller.effectiveUnlockMethod == UnlockMethod.pinOnly,
                      title: 'PIN only',
                      subtitle: 'Use only randomized PIN Genie input.',
                      onTap: () => controller.setUnlockMethod(UnlockMethod.pinOnly),
                    ),
                    _ChoiceTile(
                      selected: controller.effectiveUnlockMethod == UnlockMethod.fingerprintSwitch,
                      enabled: biometricEnabled,
                      title: 'PIN with fingerprint switch',
                      subtitle: 'Show a small fingerprint or face unlock switch.',
                      onTap: () => controller.setUnlockMethod(UnlockMethod.fingerprintSwitch),
                    ),
                    _ChoiceTile(
                      selected: controller.effectiveUnlockMethod == UnlockMethod.pinWithHiddenFingerprint,
                      enabled: biometricEnabled,
                      title: 'PIN + hidden fingerprint',
                      subtitle: 'Run biometric unlock while the PIN screen remains visible.',
                      onTap: () => controller.setUnlockMethod(UnlockMethod.pinWithHiddenFingerprint),
                    ),
                    if (controller.biometricMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          controller.biometricMessage!,
                          style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: controller.refreshBiometricState, child: const Text('Check again')),
                FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Done')),
              ],
            );
          },
        );
      },
    );
  }
}

class _RelockDelayCard extends StatelessWidget {
  const _RelockDelayCard();

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: _ActionTile(
        icon: Icons.lock_clock_rounded,
        title: 'Lock after leaving',
        subtitle: _modeDescription(controller),
        trailing: _StatusPill(label: _modeLabel(controller)),
        onTap: () => _openRelockDialog(context),
      ),
    );
  }

  Future<void> _openRelockDialog(BuildContext context) async {
    final controller = AppLockScope.of(context);
    var tempMode = controller.relockTimeoutMode;
    var tempSeconds = controller.lockDelaySeconds;
    final scrollController = FixedExtentScrollController(initialItem: (tempSeconds - 1).clamp(0, 59).toInt());

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              icon: const Icon(Icons.lock_clock_rounded),
              title: const Text('Lock after leaving'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ChoiceTile(
                        selected: tempMode == RelockTimeoutMode.immediately,
                        title: 'Immediately',
                        subtitle: 'Lock protected apps as soon as the session ends.',
                        onTap: () => setDialogState(() => tempMode = RelockTimeoutMode.immediately),
                      ),
                      _ChoiceTile(
                        selected: tempMode == RelockTimeoutMode.afterScreenOff,
                        title: 'After screen off',
                        subtitle: 'Wait until the display is turned off before relocking.',
                        onTap: () => setDialogState(() => tempMode = RelockTimeoutMode.afterScreenOff),
                      ),
                      _ChoiceTile(
                        selected: tempMode == RelockTimeoutMode.custom,
                        title: 'Custom: ${_formatDuration(tempSeconds)}',
                        subtitle: 'Use the selected delay before the app locks again.',
                        onTap: () => setDialogState(() => tempMode = RelockTimeoutMode.custom),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        child: tempMode == RelockTimeoutMode.custom
                            ? Container(
                                height: 160,
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: colorScheme.outlineVariant),
                                ),
                                child: CupertinoPicker(
                                  scrollController: scrollController,
                                  itemExtent: 44,
                                  magnification: 1.08,
                                  useMagnifier: true,
                                  onSelectedItemChanged: (index) => setDialogState(() => tempSeconds = index + 1),
                                  children: [
                                    for (var i = 1; i <= 60; i++) Center(child: Text(_formatDuration(i))),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    await controller.setLockDelaySeconds(tempSeconds);
                    await controller.setRelockTimeoutMode(tempMode);
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    scrollController.dispose();
  }

  String _modeLabel(AppLockController controller) {
    return switch (controller.relockTimeoutMode) {
      RelockTimeoutMode.immediately => 'Immediately',
      RelockTimeoutMode.afterScreenOff => 'Screen off',
      RelockTimeoutMode.custom => _formatDuration(controller.lockDelaySeconds),
    };
  }

  String _modeDescription(AppLockController controller) {
    return switch (controller.relockTimeoutMode) {
      RelockTimeoutMode.immediately => 'Relock as soon as you leave a protected app.',
      RelockTimeoutMode.afterScreenOff => 'Keep unlocked until the screen turns off.',
      RelockTimeoutMode.custom => 'Relock after ${_formatDuration(controller.lockDelaySeconds)}.',
    };
  }
}

class _AdvancedProtectionCard extends StatelessWidget {
  const _AdvancedProtectionCard();

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _SwitchTile(
            icon: Icons.camera_front_rounded,
            title: 'Intruder attempt log',
            subtitle: 'Save failed unlock attempts with time, method, and app name.',
            value: controller.intruderLogEnabled,
            onChanged: controller.setIntruderLogEnabled,
          ),
          _Divider(color: colorScheme.outlineVariant),
          _SwitchTile(
            icon: Icons.photo_camera_rounded,
            title: 'Intruder selfies',
            subtitle: controller.cameraPermissionMessage ?? 'Capture failed unlock attempts with the front camera.',
            value: controller.intruderSelfieEnabled,
            onChanged: controller.setIntruderSelfieEnabled,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const IntruderSelfiesScreen()),
            ),
            showChevron: true,
          ),
          _Divider(color: colorScheme.outlineVariant),
          _SwitchTile(
            icon: Icons.warning_amber_rounded,
            title: 'Fake crash screen',
            subtitle: 'Hide the lock behind a fake app-crash message before authentication.',
            value: controller.fakeCrashEnabled,
            onChanged: controller.setFakeCrashEnabled,
          ),
          _Divider(color: colorScheme.outlineVariant),
          _SwitchTile(
            icon: Icons.notifications_off_rounded,
            title: 'Private notification protection',
            subtitle: 'Optional and off by default. Hide sensitive notification text for locked apps.',
            value: controller.privateNotificationEnabled,
            onChanged: controller.setPrivateNotificationEnabled,
          ),
          if (controller.privateNotificationEnabled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(74, 0, 14, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: controller.openNotificationProtectionSettings,
                  icon: const Icon(Icons.notification_important_rounded),
                  label: const Text('Open notification permission'),
                ),
              ),
            ),
          ],
          _Divider(color: colorScheme.outlineVariant),
          _SwitchTile(
            icon: Icons.add_to_home_screen_rounded,
            title: 'Quick Settings tile',
            subtitle: 'Adds Lock now / pause control from Android Quick Settings.',
            value: controller.quickTileEnabled,
            onChanged: controller.setQuickTileEnabled,
          ),
        ],
      ),
    );
  }
}

class _SecurityHistoryCard extends StatelessWidget {
  const _SecurityHistoryCard();

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: _ActionTile(
        icon: Icons.history_rounded,
        title: 'Lock history',
        subtitle:
            '${controller.securityEvents.length} recorded security event${controller.securityEvents.length == 1 ? '' : 's'}.',
        onTap: () => _openHistoryDialog(context),
      ),
    );
  }

  Future<void> _openHistoryDialog(BuildContext context) async {
    final controller = AppLockScope.of(context);
    await controller.refreshLockHistory();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final events = controller.securityEvents;
            final colorScheme = Theme.of(dialogContext).colorScheme;
            return AlertDialog(
              icon: const Icon(Icons.history_rounded),
              title: const Text('Lock history'),
              content: SizedBox(
                width: 520,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 460),
                  child: events.isEmpty
                      ? Text(
                          'No lock history recorded yet.',
                          style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: events.length,
                          separatorBuilder: (_, __) => Divider(color: colorScheme.outlineVariant),
                          itemBuilder: (context, index) {
                            final event = events[index];
                            final isUnlock = event.message.toLowerCase().contains('unlocked');
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: isUnlock ? colorScheme.primaryContainer : colorScheme.errorContainer,
                                child: Icon(
                                  isUnlock ? Icons.check_rounded : Icons.priority_high_rounded,
                                  color: isUnlock ? colorScheme.onPrimaryContainer : colorScheme.onErrorContainer,
                                ),
                              ),
                              title: Text(
                                event.appLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              subtitle: Text(
                                '${event.method} • ${event.message} • ${_timeLabel(event.time)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                ),
              ),
              actions: [
                if (events.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      await controller.clearSecurityEvents();
                      if (dialogContext.mounted) setDialogState(() {});
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Clear'),
                  ),
                FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Done')),
              ],
            );
          },
        );
      },
    );
  }

  String _timeLabel(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final bool selected;
  final bool enabled;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = enabled ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.42);
    final subtitleColor = enabled ? colorScheme.onSurfaceVariant : colorScheme.onSurfaceVariant.withValues(alpha: 0.42);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer.withValues(alpha: 0.58) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? colorScheme.primary.withValues(alpha: 0.45) : colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? colorScheme.primary : subtitleColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        child: Row(
          children: [
            _TileIcon(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onTap,
    this.showChevron = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          _TileIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(value: value, onChanged: onChanged),
          if (showChevron) Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(borderRadius: BorderRadius.circular(26), onTap: onTap, child: row);
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Icon(icon, color: colorScheme.onSecondaryContainer),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 74, endIndent: 14, color: color.withValues(alpha: 0.65));
  }
}

String _unlockMethodLabel(UnlockMethod method) {
  return switch (method) {
    UnlockMethod.pinOnly => 'PIN only',
    UnlockMethod.fingerprintSwitch => 'PIN + Bio',
    UnlockMethod.pinWithHiddenFingerprint => 'Hidden Bio',
  };
}

String _unlockMethodDescription(UnlockMethod method) {
  return switch (method) {
    UnlockMethod.pinOnly => 'Only randomized PIN Genie is shown when unlocking.',
    UnlockMethod.fingerprintSwitch => 'PIN Genie is default, with a fingerprint switch button.',
    UnlockMethod.pinWithHiddenFingerprint => 'PIN Genie stays visible while biometric unlock runs silently.',
  };
}

String _formatDuration(int seconds) {
  if (seconds < 60) return '$seconds second${seconds == 1 ? '' : 's'}';
  if (seconds % 60 == 0) {
    final minutes = seconds ~/ 60;
    return '$minutes minute${minutes == 1 ? '' : 's'}';
  }
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '${minutes}m ${rest}s';
}
