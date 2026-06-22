import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../utils/responsive.dart';
import '../widgets/expressive_card.dart';
import 'about_us_screen.dart';
import 'intruder_selfies_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = AppLockScope.of(context);
      controller.refreshLockHistory();
      controller.refreshBiometricState();
      controller.refreshCameraPermissionState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return ResponsiveCenter(
      maxWidth: 760,
      child: ListView(
        children: [
          Text(
            'Settings',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.8),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage PIN, protection, and interface preferences.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 18),
          ExpressiveCard(
            borderRadius: 32,
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.shield_rounded,
                  title: 'Enable app lock protection',
                  subtitle: 'Require authentication for selected apps.',
                  trailing: Switch.adaptive(
                    value: controller.protectionEnabled,
                    onChanged: controller.setProtectionEnabled,
                  ),
                ),
                _Divider(color: colorScheme.outlineVariant),
                _SettingTile(
                  icon: Icons.screen_lock_portrait_rounded,
                  title: 'Lock on launch',
                  subtitle: 'Ask for PIN Genie when opening this app.',
                  trailing: Switch.adaptive(
                    value: controller.lockOnLaunch,
                    onChanged: controller.setLockOnLaunch,
                  ),
                ),
                _Divider(color: colorScheme.outlineVariant),
                _SettingTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark mode',
                  subtitle: 'Use a darker expressive color surface.',
                  trailing: Switch.adaptive(
                    value: controller.darkMode,
                    onChanged: controller.setDarkMode,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _UnlockMethodCard(),
          const SizedBox(height: 16),
          const _LockDelayCard(),
          const SizedBox(height: 16),
          const _AdvancedSecurityCard(),
          const SizedBox(height: 16),
          const _DesignCard(),
          const SizedBox(height: 16),
          const _AppDisguiseCard(),
          const SizedBox(height: 16),
          const _SecurityLogCard(),
          const SizedBox(height: 16),
          ExpressiveCard(
            borderRadius: 32,
            padding: const EdgeInsets.all(8),
            child: _ActionTile(
              icon: Icons.lock_reset_rounded,
              title: 'Relock current session',
              subtitle: 'Show the PIN Genie screen again.',
              onTap: () {
                controller.relockSession();
                Navigator.of(context).pushNamedAndRemoveUntil('/unlock', (_) => false);
              },
            ),
          ),
          const SizedBox(height: 16),
          const _AboutUsCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _UnlockMethodCard extends StatelessWidget {
  const _UnlockMethodCard();

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: _SettingTile(
        icon: Icons.lock_open_rounded,
        title: 'Unlock Method',
        subtitle: controller.biometricAvailable
            ? _unlockMethodDescription(controller.effectiveUnlockMethod)
            : 'Fingerprint or face unlock is unavailable. PIN-only mode is active.',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(label: _unlockMethodLabel(controller.effectiveUnlockMethod)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () => _openUnlockMethodDialog(context, controller),
      ),
    );
  }

  Future<void> _openUnlockMethodDialog(BuildContext context, AppLockController controller) async {
    await controller.refreshBiometricState();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: Row(
            children: [
              const Expanded(child: Text('Unlock Method')),
              IconButton.filledTonal(
                tooltip: 'Check biometric availability',
                onPressed: controller.refreshBiometricState,
                icon: controller.biometricChecking
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.3, color: colorScheme.primary),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final biometricEnabled = controller.biometricAvailable;
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _UnlockMethodRadioTile(
                        value: UnlockMethod.pinOnly,
                        selected: controller.effectiveUnlockMethod,
                        enabled: true,
                        icon: Icons.enhanced_encryption_rounded,
                        title: 'PIN only',
                        subtitle: 'Show only the PIN Genie randomized PIN entry screen.',
                        onChanged: (value) { controller.setUnlockMethod(value); },
                      ),
                      _Divider(color: colorScheme.outlineVariant),
                      _UnlockMethodRadioTile(
                        value: UnlockMethod.fingerprintSwitch,
                        selected: controller.effectiveUnlockMethod,
                        enabled: biometricEnabled,
                        icon: Icons.fingerprint_rounded,
                        title: 'PIN with fingerprint switch',
                        subtitle: 'Start with PIN Genie and show a small fingerprint button to switch modes.',
                        onChanged: (value) { controller.setUnlockMethod(value); },
                      ),
                      _Divider(color: colorScheme.outlineVariant),
                      _UnlockMethodRadioTile(
                        value: UnlockMethod.pinWithHiddenFingerprint,
                        selected: controller.effectiveUnlockMethod,
                        enabled: biometricEnabled,
                        icon: Icons.visibility_off_rounded,
                        title: 'PIN + hidden fingerprint',
                        subtitle: 'Keep the PIN screen visible while Android biometric unlock runs in the background.',
                        onChanged: (value) { controller.setUnlockMethod(value); },
                      ),
                      if ((controller.biometricMessage ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              controller.biometricMessage!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  static String _unlockMethodLabel(UnlockMethod method) {
    return switch (method) {
      UnlockMethod.pinOnly => 'PIN only',
      UnlockMethod.fingerprintSwitch => 'Switch',
      UnlockMethod.pinWithHiddenFingerprint => 'PIN + Bio',
    };
  }

  static String _unlockMethodDescription(UnlockMethod method) {
    return switch (method) {
      UnlockMethod.pinOnly => 'Only randomized PIN Genie is shown when unlocking.',
      UnlockMethod.fingerprintSwitch => 'PIN Genie is default, with a fingerprint switch button.',
      UnlockMethod.pinWithHiddenFingerprint => 'PIN Genie stays visible while biometric unlock runs silently.',
    };
  }
}

class _UnlockMethodRadioTile extends StatelessWidget {
  const _UnlockMethodRadioTile({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final UnlockMethod value;
  final UnlockMethod selected;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<UnlockMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: enabled ? () => onChanged(value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: enabled ? null : colorScheme.onSurfaceVariant.withValues(alpha: 0.58),
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: enabled ? 1.0 : 0.56),
                        ),
                  ),
                ],
              ),
            ),
            _RadioMark(
              selected: value == selected,
              enabled: enabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected, this.enabled = true});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = enabled ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    final inactiveColor = colorScheme.outline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? activeColor : inactiveColor,
          width: selected ? 3 : 2,
        ),
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        scale: selected ? 1 : 0,
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _RelockTimeoutOption extends StatelessWidget {
  const _RelockTimeoutOption({
    required this.value,
    required this.selected,
    required this.title,
    required this.onChanged,
    this.subtitle,
  });

  final RelockTimeoutMode value;
  final RelockTimeoutMode selected;
  final String title;
  final String? subtitle;
  final ValueChanged<RelockTimeoutMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            _RadioMark(selected: isSelected),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockDelayCard extends StatelessWidget {
  const _LockDelayCard();

  Future<void> _openRelockDialog(BuildContext context, AppLockController controller) async {
    var tempMode = controller.relockTimeoutMode;
    var tempSeconds = controller.lockDelaySeconds;
    final initialIndex = (tempSeconds - 1).clamp(0, 59);
    final scrollController = FixedExtentScrollController(initialItem: initialIndex);

    await showDialog<void>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveAndClose() async {
              await controller.setLockDelaySeconds(tempSeconds);
              await controller.setRelockTimeoutMode(tempMode);
              if (context.mounted) Navigator.of(context).pop();
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 6),
              contentPadding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              title: Text(
                'Relock Timeout',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.8,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RelockTimeoutOption(
                        value: RelockTimeoutMode.immediately,
                        selected: tempMode,
                        title: 'Immediately',
                        onChanged: (value) => setDialogState(() => tempMode = value),
                      ),
                      _RelockTimeoutOption(
                        value: RelockTimeoutMode.afterScreenOff,
                        selected: tempMode,
                        title: 'After screen off',
                        onChanged: (value) => setDialogState(() => tempMode = value),
                      ),
                      _RelockTimeoutOption(
                        value: RelockTimeoutMode.custom,
                        selected: tempMode,
                        title: 'Custom',
                        subtitle: _formatDelay(tempSeconds),
                        onChanged: (value) => setDialogState(() => tempMode = value),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: tempMode == RelockTimeoutMode.custom
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                                child: Container(
                                  height: 178,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: colorScheme.outlineVariant),
                                  ),
                                  child: CupertinoPicker(
                                    scrollController: scrollController,
                                    itemExtent: 46,
                                    magnification: 1.1,
                                    useMagnifier: true,
                                    squeeze: 1.04,
                                    selectionOverlay: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 18),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: colorScheme.primary.withValues(alpha: 0.22),
                                        ),
                                      ),
                                    ),
                                    onSelectedItemChanged: (index) {
                                      setDialogState(() => tempSeconds = index + 1);
                                    },
                                    children: List.generate(60, (index) {
                                      final seconds = index + 1;
                                      final selected = seconds == tempSeconds;
                                      return Center(
                                        child: Text(
                                          _formatDelay(seconds),
                                          style: textTheme.titleLarge?.copyWith(
                                            color: selected ? colorScheme.primary : colorScheme.onSurface,
                                            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saveAndClose,
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);

    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: _SettingTile(
        icon: Icons.timer_rounded,
        title: 'Lock after leaving',
        subtitle: _modeDescription(controller),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(label: _modeLabel(controller)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () => _openRelockDialog(context, controller),
      ),
    );
  }

  String _modeLabel(AppLockController controller) {
    return switch (controller.relockTimeoutMode) {
      RelockTimeoutMode.immediately => 'Immediately',
      RelockTimeoutMode.afterScreenOff => 'Screen off',
      RelockTimeoutMode.custom => _formatDelay(controller.lockDelaySeconds),
    };
  }

  String _modeDescription(AppLockController controller) {
    return switch (controller.relockTimeoutMode) {
      RelockTimeoutMode.immediately => 'Relock as soon as you leave a protected app.',
      RelockTimeoutMode.afterScreenOff => 'Keep unlocked until the screen turns off.',
      RelockTimeoutMode.custom => 'Relock after ${_formatDelay(controller.lockDelaySeconds)}.',
    };
  }

  static String _formatDelay(int seconds) {
    if (seconds == 60) return '1 minute';
    if (seconds == 1) return '1 second';
    return '$seconds seconds';
  }
}

class _AdvancedSecurityCard extends StatelessWidget {
  const _AdvancedSecurityCard();

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _SettingTile(
            icon: Icons.camera_front_rounded,
            title: 'Intruder attempt log',
            subtitle: 'Save failed unlock attempts with time, method, and app name.',
            trailing: Switch.adaptive(value: controller.intruderLogEnabled, onChanged: controller.setIntruderLogEnabled),
          ),
          _Divider(color: colorScheme.outlineVariant),
          _SettingTile(
            icon: Icons.photo_camera_rounded,
            title: 'Intruder selfies',
            subtitle: controller.cameraPermissionMessage ??
                'Open captured intruder photos and manage camera permission.',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch.adaptive(
                  value: controller.intruderSelfieEnabled,
                  onChanged: (value) => controller.setIntruderSelfieEnabled(value),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const IntruderSelfiesScreen(),
              ),
            ),
          ),
          _Divider(color: colorScheme.outlineVariant),
          _SettingTile(
            icon: Icons.warning_amber_rounded,
            title: 'Fake crash screen',
            subtitle: 'Hide the lock behind a fake app-crash message before authentication.',
            trailing: Switch.adaptive(value: controller.fakeCrashEnabled, onChanged: controller.setFakeCrashEnabled),
          ),
          _Divider(color: colorScheme.outlineVariant),
          _SettingTile(
            icon: Icons.notifications_off_rounded,
            title: 'Private notification protection',
            subtitle: 'Optional and off by default. Hide sensitive notification text for locked apps.',
            trailing: Switch.adaptive(value: controller.privateNotificationEnabled, onChanged: controller.setPrivateNotificationEnabled),
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
          _SettingTile(
            icon: Icons.add_to_home_screen_rounded,
            title: 'Quick Settings tile',
            subtitle: 'Adds Lock now / pause control from Android Quick Settings.',
            trailing: Switch.adaptive(value: controller.quickTileEnabled, onChanged: controller.setQuickTileEnabled),
          ),
        ],
      ),
    );
  }
}

class _DesignCard extends StatelessWidget {
  const _DesignCard();

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
            icon: Icons.palette_rounded,
            title: 'Lock screen theme',
            subtitle: _themeLabel(controller.lockTheme),
            onTap: () => _chooseTheme(context),
          ),
          _Divider(color: colorScheme.outlineVariant),
          _ActionTile(
            icon: Icons.interests_rounded,
            title: 'PIN Genie tile style',
            subtitle: _tileStyleLabel(controller.tileStyle),
            onTap: () => _chooseTileStyle(context),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseTheme(BuildContext context) async {
    final controller = AppLockScope.of(context);
    final chosen = await showModalBottomSheet<LockVisualTheme>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ChoiceSheet<LockVisualTheme>(
        title: 'Choose lock theme',
        values: LockVisualTheme.values,
        selected: controller.lockTheme,
        labelBuilder: _themeLabel,
        iconBuilder: (value) => Icons.palette_rounded,
      ),
    );
    if (chosen != null) await controller.setLockTheme(chosen);
  }

  Future<void> _chooseTileStyle(BuildContext context) async {
    final controller = AppLockScope.of(context);
    final chosen = await showModalBottomSheet<PinGenieTileStyle>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ChoiceSheet<PinGenieTileStyle>(
        title: 'Choose tile style',
        values: PinGenieTileStyle.values,
        selected: controller.tileStyle,
        labelBuilder: _tileStyleLabel,
        iconBuilder: (value) => Icons.interests_rounded,
      ),
    );
    if (chosen != null) await controller.setTileStyle(chosen);
  }

  String _themeLabel(LockVisualTheme theme) {
    return switch (theme) {
      LockVisualTheme.defaultBlue => 'Default blue',
      LockVisualTheme.amoledBlack => 'AMOLED black',
      LockVisualTheme.purpleNeon => 'Purple neon',
      LockVisualTheme.minimalLight => 'Minimal light',
      LockVisualTheme.materialPastel => 'Material pastel',
      LockVisualTheme.animeSoft => 'Anime soft',
    };
  }

  String _tileStyleLabel(PinGenieTileStyle style) {
    return switch (style) {
      PinGenieTileStyle.expressiveBlob => 'Expressive blob',
      PinGenieTileStyle.roundedSquare => 'Rounded square',
      PinGenieTileStyle.circle => 'Circle',
      PinGenieTileStyle.compact => 'Compact',
      PinGenieTileStyle.randomMaterial => 'Random Material shapes',
    };
  }
}


class _SecurityLogCard extends StatelessWidget {
  const _SecurityLogCard();

  Future<void> _openHistoryDialog(BuildContext context, AppLockController controller) async {
    await controller.refreshLockHistory();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            final events = controller.securityEvents;

            Future<void> clearHistory() async {
              await controller.clearSecurityEvents();
              if (context.mounted) setDialogState(() {});
            }

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
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
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
                                backgroundColor: isUnlock
                                    ? colorScheme.primaryContainer
                                    : colorScheme.errorContainer,
                                child: Icon(
                                  isUnlock ? Icons.check_rounded : Icons.priority_high_rounded,
                                  color: isUnlock
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onErrorContainer,
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
                    onPressed: clearHistory,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Clear'),
                  ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
            '${controller.securityEvents.length} recorded security event${controller.securityEvents.length == 1 ? '' : 's'}. Tap to open history.',
        onTap: () => _openHistoryDialog(context, controller),
      ),
    );
  }

  String _timeLabel(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.iconBuilder,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final IconData Function(T value) iconBuilder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...values.map((value) => ListTile(
                  leading: Icon(iconBuilder(value)),
                  title: Text(labelBuilder(value)),
                  trailing: value == selected ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.of(context).pop(value),
                )),
          ],
        ),
      ),
    );
  }
}



class _AppDisguiseCard extends StatelessWidget {
  const _AppDisguiseCard();

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: _SettingTile(
        icon: Icons.apps_rounded,
        title: 'App Disguise',
        subtitle: _subtitle(controller.appDisguise),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(label: _label(controller.appDisguise)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () => _openDisguiseDialog(context, controller),
      ),
    );
  }

  Future<void> _openDisguiseDialog(BuildContext context, AppLockController controller) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: const Text('App Disguise'),
          contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: Text(
                      'Choose a launcher disguise. The selected app name stays active after restart. Android may take a moment to refresh the home-screen icon.',
                      style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  for (final option in AppDisguiseOption.values) ...[
                    _AppDisguiseOptionTile(
                      option: option,
                      selected: controller.appDisguise,
                      onChanged: (value) async {
                        await controller.setAppDisguise(value);
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                        messenger.showSnackBar(
                          SnackBar(content: Text('${_label(value)} disguise applied.')),
                        );
                      },
                    ),
                    if (option != AppDisguiseOption.values.last) _Divider(color: colorScheme.outlineVariant),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  static String _label(AppDisguiseOption option) {
    return switch (option) {
      AppDisguiseOption.original => 'Original',
      AppDisguiseOption.googleHome => 'Google Home',
      AppDisguiseOption.googleSheets => 'Google Sheets',
      AppDisguiseOption.googleWallet => 'Google Wallet',
      AppDisguiseOption.googleMeet => 'Google Meet',
      AppDisguiseOption.googleFamilyLink => 'Google Family Link',
      AppDisguiseOption.googleFiWireless => 'Google Fi Wireless',
    };
  }

  static String _subtitle(AppDisguiseOption option) {
    return switch (option) {
      AppDisguiseOption.original => 'Use the original Pin Genie launcher name and icon.',
      AppDisguiseOption.googleHome => 'Disguise the launcher as Google Home.',
      AppDisguiseOption.googleSheets => 'Disguise the launcher as Google Sheets.',
      AppDisguiseOption.googleWallet => 'Disguise the launcher as Google Wallet.',
      AppDisguiseOption.googleMeet => 'Disguise the launcher as Google Meet.',
      AppDisguiseOption.googleFamilyLink => 'Disguise the launcher as Google Family Link.',
      AppDisguiseOption.googleFiWireless => 'Disguise the launcher as Google Fi Wireless.',
    };
  }
}

class _AppDisguiseOptionTile extends StatelessWidget {
  const _AppDisguiseOptionTile({
    required this.option,
    required this.selected,
    required this.onChanged,
  });

  final AppDisguiseOption option;
  final AppDisguiseOption selected;
  final ValueChanged<AppDisguiseOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (option) {
      AppDisguiseOption.original => 'Restore Pin Genie branding.',
      AppDisguiseOption.googleHome => 'Home automation disguise.',
      AppDisguiseOption.googleSheets => 'Spreadsheet disguise.',
      AppDisguiseOption.googleWallet => 'Wallet disguise.',
      AppDisguiseOption.googleMeet => 'Video chat disguise.',
      AppDisguiseOption.googleFamilyLink => 'Parental controls disguise.',
      AppDisguiseOption.googleFiWireless => 'Wireless provider disguise.',
    };
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => onChanged(option),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _DisguisePreviewIcon(option: option),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _AppDisguiseCard._label(option),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            _RadioMark(selected: selected == option),
          ],
        ),
      ),
    );
  }
}

class _DisguisePreviewIcon extends StatelessWidget {
  const _DisguisePreviewIcon({required this.option});

  final AppDisguiseOption option;

  static String? _assetPath(AppDisguiseOption option) {
    return switch (option) {
      AppDisguiseOption.original => null,
      AppDisguiseOption.googleHome => 'assets/app_icon/disguise/ic_launcher_google_home.png',
      AppDisguiseOption.googleSheets => 'assets/app_icon/disguise/ic_launcher_google_sheets.png',
      AppDisguiseOption.googleWallet => 'assets/app_icon/disguise/ic_launcher_google_wallet.png',
      AppDisguiseOption.googleMeet => 'assets/app_icon/disguise/ic_launcher_google_meet.png',
      AppDisguiseOption.googleFamilyLink => 'assets/app_icon/disguise/ic_launcher_google_family_link.png',
      AppDisguiseOption.googleFiWireless => 'assets/app_icon/disguise/ic_launcher_google_fi_wireless.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final assetPath = _assetPath(option);
    if (assetPath != null) {
      return SizedBox(
        width: 58,
        height: 58,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(Icons.shield_rounded, color: colorScheme.onPrimaryContainer, size: 28),
    );
  }
}

class _AboutUsCard extends StatelessWidget {
  const _AboutUsCard();

  @override
  Widget build(BuildContext context) {
    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: _ActionTile(
        icon: Icons.info_rounded,
        title: 'About us',
        subtitle: 'Developer credits, contact links, and social profiles.',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AboutUsScreen(),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
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

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: content,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = colorScheme.onSurface;
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: foreground,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
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
      child: Icon(
        icon,
        color: colorScheme.onSecondaryContainer,
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
