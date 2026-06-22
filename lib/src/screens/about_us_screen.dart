import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/responsive.dart';
import '../widgets/expressive_card.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const _links = <_AboutLink>[
    _AboutLink(
      title: 'Telegram',
      subtitle: '@Ch0wdhury_Siam',
      url: 'https://t.me/Ch0wdhury_Siam',
      icon: Icon(Icons.send_rounded, size: 22),
    ),
    _AboutLink(
      title: 'Telegram backup',
      subtitle: '@Chowdhury_Siam',
      url: 'https://t.me/Chowdhury_Siam',
      icon: Icon(Icons.near_me_rounded, size: 21),
    ),
    _AboutLink(
      title: 'GitHub',
      subtitle: 'Chowdhury-Siam',
      url: 'https://github.com/Chowdhury-Siam',
      icon: Icon(Icons.code_rounded, size: 22),
    ),
    _AboutLink(
      title: 'MyAnimeList',
      subtitle: 'Siam_Chowdhury',
      url: 'https://myanimelist.net/profile/Siam_Chowdhury',
      icon: _TextBadgeIcon(label: 'MAL'),
    ),
    _AboutLink(
      title: 'AniList',
      subtitle: 'SiamChowdhury',
      url: 'https://anilist.co/user/SiamChowdhury/',
      icon: _TextBadgeIcon(label: 'AL'),
    ),
    _AboutLink(
      title: 'YouTube',
      subtitle: '@SCS_Otaku',
      url: 'https://www.youtube.com/@SCS_Otaku',
      icon: Icon(Icons.smart_display_rounded, size: 22),
    ),
    _AboutLink(
      title: 'X',
      subtitle: '@SiamChowdhuryy',
      url: 'https://x.com/SiamChowdhuryy',
      icon: _TextBadgeIcon(label: 'X'),
    ),
    _AboutLink(
      title: 'Email',
      subtitle: 'ssiam4235@gmail.com',
      url: 'mailto:ssiam4235@gmail.com',
      icon: Icon(Icons.alternate_email_rounded, size: 21),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 760,
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
                      'About us',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ExpressiveCard(
                borderRadius: 36,
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                highlight: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: colorScheme.onPrimary,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Developed by Siam Chowdhury',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pin Genie is a Material 3 app-lock project with randomized PIN Genie authentication, biometric support, and native Android app protection.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ExpressiveCard(
                borderRadius: 32,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _TileBadge(icon: Icons.link_rounded),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Credits and links',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Developer contact and social profiles.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(_links.length, (index) {
                      final link = _links[index];
                      return Column(
                        children: [
                          _AboutLinkTile(link: link),
                          if (index != _links.length - 1)
                            Divider(height: 1, color: colorScheme.outlineVariant),
                        ],
                      );
                    }),
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

class _AboutLink {
  const _AboutLink({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String url;
  final Widget icon;
}

class _AboutLinkTile extends StatelessWidget {
  const _AboutLinkTile({required this.link});

  final _AboutLink link;

  Future<void> _openLink(BuildContext context) async {
    final uri = Uri.parse(link.url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${link.title}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openLink(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            _SocialIcon(child: link.icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    link.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new_rounded, color: colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _TileBadge extends StatelessWidget {
  const _TileBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: colorScheme.onSecondaryContainer),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({required this.child});

  final Widget child;

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
      child: IconTheme.merge(
        data: IconThemeData(color: colorScheme.onSecondaryContainer),
        child: Center(
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TextBadgeIcon extends StatelessWidget {
  const _TextBadgeIcon({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: IconTheme.of(context).color,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
    );
  }
}
