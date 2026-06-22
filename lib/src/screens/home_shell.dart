import 'package:flutter/material.dart';

import '../app.dart';
import '../utils/responsive.dart';
import '../widgets/expressive_card.dart';
import 'apps_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const routeName = '/home';

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppLockScope.of(context).loadDeviceApps();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const DashboardScreen(),
      const AppsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(key: ValueKey(_index), child: screens[_index]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shield_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.apps_rounded), label: 'Apps'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final lockedCount = controller.lockedApps.length;

    return ResponsiveCenter(
      maxWidth: 820,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pin Genie',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.protectionEnabled ? 'Protection is active' : 'Protection is paused',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ExpressiveCard(
                  padding: const EdgeInsets.all(26),
                  borderRadius: 38,
                  highlight: controller.protectionEnabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 320),
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: controller.protectionEnabled ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(controller.protectionEnabled ? 31 : 24),
                            ),
                            child: Icon(
                              controller.protectionEnabled ? Icons.verified_user_rounded : Icons.lock_open_rounded,
                              size: 42,
                              color: controller.protectionEnabled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Switch.adaptive(
                            value: controller.protectionEnabled,
                            onChanged: controller.setProtectionEnabled,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        controller.protectionEnabled ? 'Device app protection ready' : 'Protection disabled',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.protectionEnabled
                            ? '$lockedCount selected app${lockedCount == 1 ? '' : 's'} will require PIN Genie authentication when opened.'
                            : 'Turn protection back on to require authentication for locked apps.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.42,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final cards = [
                      _MetricCard(
                        icon: Icons.apps_rounded,
                        value: '${controller.apps.length}',
                        label: 'Available apps',
                      ),
                      _MetricCard(
                        icon: Icons.lock_rounded,
                        value: '$lockedCount',
                        label: 'Locked apps',
                      ),
                      const _MetricCard(
                        icon: Icons.key_rounded,
                        value: 'PIN',
                        label: 'Secure auth',
                      ),
                      _MetricCard(
                        icon: Icons.history_rounded,
                        value: '${controller.securityEvents.length}',
                        label: 'Lock events',
                      ),
                    ];
                    if (compact) {
                      return Column(
                        children: [
                          for (final card in cards) ...[card, const SizedBox(height: 12)],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (final card in cards) Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: card)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExpressiveCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 26,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: colorScheme.onTertiaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
