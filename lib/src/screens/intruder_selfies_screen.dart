import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app.dart';
import '../utils/responsive.dart';
import '../widgets/expressive_card.dart';

class IntruderSelfiesScreen extends StatefulWidget {
  const IntruderSelfiesScreen({super.key});

  @override
  State<IntruderSelfiesScreen> createState() => _IntruderSelfiesScreenState();
}

class _IntruderSelfiesScreenState extends State<IntruderSelfiesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = AppLockScope.of(context);
      await controller.refreshLockHistory();
      await controller.refreshCameraPermissionState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final events = controller.intruderSelfieEvents;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 820,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Intruder selfies',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Refresh',
                    onPressed: () async {
                      await controller.refreshLockHistory();
                      await controller.refreshCameraPermissionState();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ExpressiveCard(
                borderRadius: 34,
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        child: const Icon(Icons.photo_camera_front_rounded),
                      ),
                      title: const Text('Capture failed unlock attempts', style: TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        controller.cameraPermissionMessage ??
                            'Turn this on to request camera permission and save intruder selfie entries.',
                      ),
                      trailing: Switch.adaptive(
                        value: controller.intruderSelfieEnabled,
                        onChanged: (value) => controller.setIntruderSelfieEnabled(value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (events.isEmpty)
                ExpressiveCard(
                  borderRadius: 34,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Column(
                    children: [
                      Icon(Icons.no_photography_rounded, size: 48, color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 14),
                      Text(
                        'No intruder selfies yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'When intruder selfie is enabled, failed unlock attempts will appear here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              else
                ...events.map((event) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _IntruderSelfieCard(event: event),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntruderSelfieCard extends StatelessWidget {
  const _IntruderSelfieCard({required this.event});

  final SecurityEvent event;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageBytes = _decodeImage(event.selfieBase64);

    return ExpressiveCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              child: InkWell(
                onTap: imageBytes == null ? null : () => _openImagePreview(context, imageBytes),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: imageBytes == null
                      ? Icon(Icons.photo_camera_front_rounded, color: colorScheme.onSurfaceVariant, size: 38)
                      : Image.memory(imageBytes, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.appLabel, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  '${event.method} • ${_timeLabel(event.time)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(event.message, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text(
                  imageBytes == null
                      ? 'Capture failed. This entry has no saved photo. Check camera permission, then try a new failed attempt.'
                      : 'Tap the photo to view it full size.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openImagePreview(BuildContext context, Uint8List imageBytes) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Dialog.fullscreen(
          backgroundColor: colorScheme.surface,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          event.appLabel,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(child: Image.memory(imageBytes, fit: BoxFit.contain)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Uint8List? _decodeImage(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
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
