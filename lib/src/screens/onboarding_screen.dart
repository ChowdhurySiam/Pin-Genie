import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import '../widgets/expressive_card.dart';
import 'create_pin_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 24, 0, 28),
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.90, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: ExpressiveCard(
                  padding: const EdgeInsets.all(28),
                  borderRadius: 38,
                  highlight: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(Icons.lock_person_rounded, size: 40, color: colorScheme.onPrimary),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Protect your apps with PIN Genie',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Set a secure PIN, choose protected apps, and unlock through a randomized PIN Genie-style entry screen.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.45,
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _FeatureRow(
                icon: Icons.shuffle_rounded,
                title: 'Randomized unlock tiles',
                subtitle: 'Digits move between expressive tiles every tap.',
              ),
              const SizedBox(height: 10),
              const _FeatureRow(
                icon: Icons.phonelink_lock_rounded,
                title: 'App protection manager',
                subtitle: 'Select which apps should require authentication.',
              ),
              const SizedBox(height: 10),
              const _FeatureRow(
                icon: Icons.motion_photos_auto_rounded,
                title: 'Fluid Material motion',
                subtitle: 'Animated states, routes, cards, and buttons.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    CreatePinScreen.routeName,
                    arguments: CreatePinMode.create,
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Create PIN'),
              ),
              const SizedBox(height: 12),
              Text(
                'You can change the PIN and lock behavior later from Settings.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExpressiveCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: colorScheme.onSecondaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
