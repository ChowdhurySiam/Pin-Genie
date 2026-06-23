import 'package:flutter/material.dart';
import '../app.dart';
import '../utils/responsive.dart';
import '../widgets/expressive_card.dart';
import 'about_us_screen.dart';
import 'security_screen.dart';

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
          const _SecurityCard(),
          const SizedBox(height: 16),
          const _DesignCard(),
          const SizedBox(height: 16),
          const _AppDisguiseCard(),
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

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;
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




class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    final recoveryStatus = controller.hasAnyRecoveryMethod ? 'Recovery configured' : 'Recovery not set';
    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(8),
      child: _ActionTile(
        icon: Icons.security_rounded,
        title: 'Security',
        subtitle: 'PIN reset, recovery codes, retry timeout, unlock fallback, and lock history. $recoveryStatus.',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SecurityScreen()),
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
