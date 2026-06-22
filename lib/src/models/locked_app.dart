import 'dart:typed_data';

import 'package:flutter/material.dart';

class LockableApp {
  const LockableApp({
    required this.packageName,
    required this.label,
    required this.category,
    this.icon = Icons.apps_rounded,
    this.iconBytes,
    this.isSystem = false,
    this.isDeviceApp = false,
  });

  final String packageName;
  final String label;
  final String category;
  final IconData icon;
  final Uint8List? iconBytes;
  final bool isSystem;
  final bool isDeviceApp;
}

const fallbackLockableApps = <LockableApp>[
  LockableApp(
    packageName: 'com.google.android.gm',
    label: 'Gmail',
    category: 'Productivity',
    icon: Icons.mail_rounded,
  ),
  LockableApp(
    packageName: 'com.android.chrome',
    label: 'Chrome',
    category: 'Browser',
    icon: Icons.travel_explore_rounded,
  ),
  LockableApp(
    packageName: 'com.whatsapp',
    label: 'WhatsApp',
    category: 'Social',
    icon: Icons.chat_bubble_rounded,
  ),
  LockableApp(
    packageName: 'com.facebook.katana',
    label: 'Facebook',
    category: 'Social',
    icon: Icons.groups_rounded,
  ),
  LockableApp(
    packageName: 'com.facebook.orca',
    label: 'Messenger',
    category: 'Social',
    icon: Icons.forum_rounded,
  ),
  LockableApp(
    packageName: 'com.instagram.android',
    label: 'Instagram',
    category: 'Social',
    icon: Icons.photo_camera_rounded,
  ),
  LockableApp(
    packageName: 'com.google.android.youtube',
    label: 'YouTube',
    category: 'Media',
    icon: Icons.smart_display_rounded,
  ),
  LockableApp(
    packageName: 'com.google.android.apps.photos',
    label: 'Photos',
    category: 'Media',
    icon: Icons.photo_library_rounded,
  ),
  LockableApp(
    packageName: 'com.spotify.music',
    label: 'Spotify',
    category: 'Media',
    icon: Icons.graphic_eq_rounded,
  ),
  LockableApp(
    packageName: 'com.android.settings',
    label: 'Settings',
    category: 'System',
    icon: Icons.settings_rounded,
    isSystem: true,
  ),
  LockableApp(
    packageName: 'com.google.android.apps.walletnfcrel',
    label: 'Wallet',
    category: 'Finance',
    icon: Icons.account_balance_wallet_rounded,
  ),
  LockableApp(
    packageName: 'com.bank.mobile',
    label: 'Banking',
    category: 'Finance',
    icon: Icons.account_balance_rounded,
  ),
];
