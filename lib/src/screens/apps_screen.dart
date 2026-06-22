import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../models/locked_app.dart';
import '../utils/responsive.dart';
import '../widgets/expressive_card.dart';

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  String _query = '';
  AppListFilter _filter = AppListFilter.all;
  bool _showGroups = false;

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
    final controller = AppLockScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = controller.appListViewMode;
    final filtered = controller.apps.where((app) {
      final q = _query.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          app.label.toLowerCase().contains(q) ||
          app.category.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q);
      if (!matchesSearch) return false;
      return switch (_filter) {
        AppListFilter.all => true,
        AppListFilter.locked => controller.lockedPackages.contains(app.packageName),
        AppListFilter.unlocked => !controller.lockedPackages.contains(app.packageName),
        AppListFilter.system => app.isSystem,
        AppListFilter.recent => app.isDeviceApp,
      };
    }).toList(growable: false);

    return ResponsiveCenter(
      maxWidth: 920,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Locked apps',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.8),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.deviceAppsLoaded && controller.appsError == null
                          ? 'Showing launchable apps installed on this Android device.'
                          : 'Select apps that should require PIN Genie authentication before opening.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Refresh device apps',
                onPressed: controller.appsLoading
                    ? null
                    : () => controller.loadDeviceApps(force: true),
                icon: controller.appsLoading
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search apps, categories, or packages',
            ),
          ),
          const SizedBox(height: 10),
          _FilterChips(
            selected: _filter,
            onChanged: (filter) => setState(() => _filter = filter),
            showGroups: _showGroups,
            onToggleGroups: () => setState(() => _showGroups = !_showGroups),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: _showGroups
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _GroupLockPanel(controller: controller),
                  )
                : const SizedBox.shrink(),
          ),
          if (controller.nativeLockSupported && !controller.nativeLockEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _NativeLockNotice(controller: controller),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: controller.appsError == null
                ? const SizedBox(height: 16)
                : Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: _AppScanNotice(
                      message: controller.appsError!,
                      onRefresh: () => controller.loadDeviceApps(force: true),
                    ),
                  ),
          ),
          _ViewModeToggle(
            selected: viewMode,
            onChanged: (mode) => controller.setAppListViewMode(mode),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: controller.appsLoading && !controller.deviceAppsLoaded
                ? const _LoadingAppsState()
                : filtered.isEmpty
                    ? _EmptyAppsState(query: _query)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (viewMode == AppListViewMode.list) {
                            return ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final app = filtered[index];
                                final locked = controller.lockedPackages.contains(app.packageName);
                                return _AppListTile(
                                  app: app,
                                  locked: locked,
                                  delaySeconds: controller.delayForPackage(app.packageName),
                                  customDelay: controller.perAppDelaySeconds.containsKey(app.packageName),
                                  onChanged: (value) => controller.toggleLockedPackage(app.packageName, value),
                                  onDelayTap: locked ? () => _showPerAppDelay(context, app) : null,
                                  onOpen: () => _openApp(context, app, locked),
                                );
                              },
                            );
                          }

                          final columns = adaptiveGridColumns(constraints.maxWidth);
                          return GridView.builder(
                            itemCount: filtered.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: constraints.maxWidth < 460 ? 0.82 : 0.95,
                            ),
                            itemBuilder: (context, index) {
                              final app = filtered[index];
                              final locked = controller.lockedPackages.contains(app.packageName);
                              return _AppCard(
                                app: app,
                                locked: locked,
                                delaySeconds: controller.delayForPackage(app.packageName),
                                customDelay: controller.perAppDelaySeconds.containsKey(app.packageName),
                                onChanged: (value) => controller.toggleLockedPackage(
                                  app.packageName,
                                  value,
                                ),
                                onDelayTap: locked ? () => _showPerAppDelay(context, app) : null,
                                onOpen: () => _openApp(context, app, locked),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }


  Future<void> _showPerAppDelay(BuildContext context, LockableApp app) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _PerAppDelaySheet(app: app),
    );
  }

  Future<void> _openApp(BuildContext context, LockableApp app, bool locked) async {
    final controller = AppLockScope.of(context);
    if (controller.protectionEnabled && locked) {
      final unlocked = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => _AppUnlockPreview(app: app),
      );

      if (unlocked != true || !context.mounted) return;
    }

    final launched = await controller.launchPackage(app.packageName);
    if (!context.mounted) return;
    _showLaunchSnack(context, app.label, launched);
  }

  void _showLaunchSnack(BuildContext context, String label, bool launched) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(launched ? 'Opened $label.' : 'Could not open $label from Android.'),
      ),
    );
  }
}




class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.selected, required this.onChanged});

  final AppListViewMode selected;
  final ValueChanged<AppListViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.72)),
        ),
        child: SegmentedButton<AppListViewMode>(
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          segments: const [
            ButtonSegment<AppListViewMode>(
              value: AppListViewMode.list,
              icon: Icon(Icons.format_list_bulleted_rounded),
              tooltip: 'List view',
            ),
            ButtonSegment<AppListViewMode>(
              value: AppListViewMode.grid,
              icon: Icon(Icons.grid_view_rounded),
              tooltip: 'Grid view',
            ),
          ],
          selected: {selected},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            onChanged(selection.first);
          },
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onChanged,
    required this.showGroups,
    required this.onToggleGroups,
  });

  final AppListFilter selected;
  final ValueChanged<AppListFilter> onChanged;
  final bool showGroups;
  final VoidCallback onToggleGroups;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in AppListFilter.values) ...[
            FilterChip(
              selected: selected == filter,
              onSelected: (_) => onChanged(filter),
              label: Text(_label(filter)),
              avatar: Icon(_icon(filter), size: 18),
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            avatar: Icon(showGroups ? Icons.expand_less_rounded : Icons.category_rounded, size: 18),
            label: const Text('Groups'),
            onPressed: onToggleGroups,
          ),
        ],
      ),
    );
  }

  String _label(AppListFilter filter) {
    return switch (filter) {
      AppListFilter.all => 'All',
      AppListFilter.locked => 'Locked',
      AppListFilter.unlocked => 'Unlocked',
      AppListFilter.system => 'System',
      AppListFilter.recent => 'Recent',
    };
  }

  IconData _icon(AppListFilter filter) {
    return switch (filter) {
      AppListFilter.all => Icons.apps_rounded,
      AppListFilter.locked => Icons.lock_rounded,
      AppListFilter.unlocked => Icons.lock_open_rounded,
      AppListFilter.system => Icons.settings_rounded,
      AppListFilter.recent => Icons.history_rounded,
    };
  }
}

class _GroupLockPanel extends StatelessWidget {
  const _GroupLockPanel({required this.controller});

  final AppLockController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = controller.apps.map((app) => app.category).toSet().toList()..sort();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((category) {
          final apps = controller.apps.where((app) => app.category == category).toList(growable: false);
          final locked = apps.isNotEmpty && apps.every((app) => controller.lockedPackages.contains(app.packageName));
          return FilterChip(
            selected: locked,
            avatar: Icon(locked ? Icons.lock_rounded : Icons.category_rounded, size: 18),
            label: Text('$category (${apps.length})'),
            onSelected: (value) => controller.toggleGroup(category, value),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _PerAppDelaySheet extends StatefulWidget {
  const _PerAppDelaySheet({required this.app});

  final LockableApp app;

  @override
  State<_PerAppDelaySheet> createState() => _PerAppDelaySheetState();
}

class _PerAppDelaySheetState extends State<_PerAppDelaySheet> {
  FixedExtentScrollController? _scrollController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppLockScope.of(context);
    _scrollController ??= FixedExtentScrollController(initialItem: controller.delayForPackage(widget.app.packageName) - 1);
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final selected = controller.delayForPackage(widget.app.packageName);
    final custom = controller.perAppDelaySeconds.containsKey(widget.app.packageName);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _LockableAppIcon(app: widget.app, locked: true, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Per-app lock delay', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      Text(widget.app.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 154,
              child: CupertinoPicker(
                scrollController: _scrollController,
                itemExtent: 44,
                magnification: 1.08,
                useMagnifier: true,
                onSelectedItemChanged: (index) => controller.setPerAppDelaySeconds(widget.app.packageName, index + 1),
                children: List.generate(60, (index) {
                  final seconds = index + 1;
                  return Center(
                    child: Text(
                      seconds == 60 ? '1 minute' : '$seconds second${seconds == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: seconds == selected ? FontWeight.w900 : FontWeight.w700,
                            color: seconds == selected ? colorScheme.primary : colorScheme.onSurface,
                          ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: custom ? () => controller.setPerAppDelaySeconds(widget.app.packageName, null) : null,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Use global delay'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NativeLockNotice extends StatelessWidget {
  const _NativeLockNotice({required this.controller});

  final AppLockController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colorScheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Native lock service is off',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Selecting apps here saves the lock list. To actually block apps opened from the Android launcher, enable the PIN Genie accessibility service.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer.withValues(alpha: 0.86),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: controller.openNativeLockSettings,
                icon: const Icon(Icons.settings_accessibility_rounded),
                label: const Text('Enable service'),
              ),
              OutlinedButton.icon(
                onPressed: controller.refreshNativeLockState,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Check'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppScanNotice extends StatelessWidget {
  const _AppScanNotice({required this.message, required this.onRefresh});

  final String message;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$message Showing fallback sample apps until Android returns the device list.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    height: 1.35,
                  ),
            ),
          ),
          TextButton(onPressed: onRefresh, child: const Text('Retry')),
        ],
      ),
    );
  }
}


class _LoadingAppsState extends StatelessWidget {
  const _LoadingAppsState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Reading installed apps from Android…',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'This should take a moment on the first load.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAppsState extends StatelessWidget {
  const _EmptyAppsState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 44, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            query.trim().isEmpty ? 'No apps found' : 'No apps match “$query”',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Try refreshing the installed app list or clearing the search.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}


class _AppListTile extends StatelessWidget {
  const _AppListTile({
    required this.app,
    required this.locked,
    required this.delaySeconds,
    required this.customDelay,
    required this.onChanged,
    required this.onDelayTap,
    required this.onOpen,
  });

  final LockableApp app;
  final bool locked;
  final int delaySeconds;
  final bool customDelay;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelayTap;
  final VoidCallback onOpen;

  String _formatDelay(int seconds) {
    if (seconds == 60) return '1m';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = locked ? 'PIN • ${_formatDelay(delaySeconds)}${customDelay ? ' custom' : ''}' : 'Unlocked';
    return ExpressiveCard(
      onTap: onOpen,
      highlight: locked,
      borderRadius: locked ? 30 : 26,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _LockableAppIcon(app: app, locked: locked, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  app.isSystem ? '${app.category} • System' : app.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (onDelayTap != null)
            IconButton.filledTonal(
              tooltip: 'Per-app lock delay',
              visualDensity: VisualDensity.compact,
              onPressed: onDelayTap,
              icon: const Icon(Icons.timer_rounded, size: 18),
            ),
          Switch.adaptive(value: locked, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({
    required this.app,
    required this.locked,
    required this.delaySeconds,
    required this.customDelay,
    required this.onChanged,
    required this.onDelayTap,
    required this.onOpen,
  });

  final LockableApp app;
  final bool locked;
  final int delaySeconds;
  final bool customDelay;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDelayTap;
  final VoidCallback onOpen;

  String _formatDelay(int seconds) {
    if (seconds == 60) return '1m';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExpressiveCard(
      onTap: onOpen,
      highlight: locked,
      borderRadius: locked ? 34 : 26,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LockableAppIcon(app: app, locked: locked, size: 54),
              const Spacer(),
              Switch.adaptive(value: locked, onChanged: onChanged),
            ],
          ),
          const Spacer(),
          Text(
            app.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            app.isSystem ? '${app.category} • System' : app.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  locked ? 'PIN • ${_formatDelay(delaySeconds)}${customDelay ? ' custom' : ''}' : 'Unlocked',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              if (onDelayTap != null)
                IconButton(
                  tooltip: 'Per-app lock delay',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelayTap,
                  icon: const Icon(Icons.timer_rounded, size: 18),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LockableAppIcon extends StatelessWidget {
  const _LockableAppIcon({required this.app, required this.locked, required this.size});

  final LockableApp app;
  final bool locked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bytes = app.iconBytes;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: locked ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(locked ? 22 : 18),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null || bytes.isEmpty
          ? Icon(
              app.icon,
              color: locked ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              size: size * 0.52,
            )
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
            ),
    );
  }
}

class _AppUnlockPreview extends StatefulWidget {
  const _AppUnlockPreview({required this.app});

  final LockableApp app;

  @override
  State<_AppUnlockPreview> createState() => _AppUnlockPreviewState();
}

class _AppUnlockPreviewState extends State<_AppUnlockPreview> {
  final _pin = TextEditingController();
  bool _error = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _verify() {
    final controller = AppLockScope.of(context);
    if (controller.verifyPin(_pin.text)) {
      Navigator.of(context).pop(true);
      return;
    }
    controller.registerFailedAttempt(
      appLabel: widget.app.label,
      packageName: widget.app.packageName,
      method: 'PIN',
      message: 'Wrong app preview PIN',
    );
    setState(() {
      _pin.clear();
      _error = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        top: 6,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _LockableAppIcon(app: widget.app, locked: true, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlock ${widget.app.label}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          'Enter the current PIN before Android opens this app.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _pin,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: controller.pinLength,
                decoration: InputDecoration(
                  labelText: 'Current PIN',
                  errorText: _error ? 'Wrong PIN' : null,
                  counterText: '',
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _verify,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Unlock and open app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
