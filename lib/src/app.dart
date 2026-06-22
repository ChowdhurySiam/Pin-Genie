import 'package:flutter/material.dart';

import 'screens/create_pin_screen.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/unlock_screen.dart';
import 'state/app_lock_controller.dart';
import 'theme/app_theme.dart';

export 'state/app_lock_controller.dart';

class AppLockApp extends StatefulWidget {
  const AppLockApp({super.key, required this.controller});

  final AppLockController controller;

  @override
  State<AppLockApp> createState() => _AppLockAppState();
}

class _AppLockAppState extends State<AppLockApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  DateTime? _backgroundedAt;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = widget.controller;
    if (!controller.isSetupComplete || !controller.protectionEnabled || !controller.lockOnLaunch) {
      return;
    }

    // Android biometric prompts temporarily move the app through inactive/paused
    // lifecycle states. Do not treat that prompt as the user leaving Pin Genie,
    // otherwise a successful biometric scan can immediately route back to unlock.
    if (controller.externalAuthenticationInProgress) {
      _backgroundedAt = null;
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    // Import security events written by the native Android lock screen while
    // Pin Genie was in the background.
    controller.refreshLockHistory();

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null || !controller.sessionUnlocked) return;

    final shouldRelock = switch (controller.relockTimeoutMode) {
      RelockTimeoutMode.immediately => true,
      RelockTimeoutMode.afterScreenOff => false,
      RelockTimeoutMode.custom => DateTime.now().difference(backgroundedAt).inSeconds >= controller.lockDelaySeconds,
    };
    if (!shouldRelock) return;

    controller.relockSession();
    _navigatorKey.currentState?.pushNamedAndRemoveUntil(
      UnlockScreen.routeName,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLockScope(
      controller: widget.controller,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Pin Genie',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: widget.controller.darkMode ? ThemeMode.dark : ThemeMode.light,
        onGenerateRoute: (settings) {
          final route = switch (settings.name) {
            CreatePinScreen.routeName => CreatePinScreen(
                mode: settings.arguments is CreatePinMode
                    ? settings.arguments! as CreatePinMode
                    : CreatePinMode.create,
              ),
            UnlockScreen.routeName => const UnlockScreen(),
            HomeShell.routeName => const HomeShell(),
            _ => widget.controller.isSetupComplete
                ? const _StartupGate()
                : const OnboardingScreen(),
          };

          return _SpringRoute<void>(
            child: route,
            settings: settings,
          );
        },
      ),
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    final controller = AppLockScope.of(context);
    if (controller.protectionEnabled && controller.lockOnLaunch && !controller.sessionUnlocked) {
      return const UnlockScreen();
    }
    return const HomeShell();
  }
}

class AppLockScope extends InheritedWidget {
  const AppLockScope({super.key, required this.controller, required super.child});

  final AppLockController controller;

  static AppLockController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLockScope>();
    assert(scope != null, 'AppLockScope not found');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(AppLockScope oldWidget) => true;
}

class _SpringRoute<T> extends PageRouteBuilder<T> {
  _SpringRoute({required Widget child, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 430),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: animation.drive(Tween<double>(begin: 0, end: 1)),
              child: SlideTransition(
                position: curved.drive(
                  Tween<Offset>(begin: const Offset(0.05, 0.04), end: Offset.zero),
                ),
                child: child,
              ),
            );
          },
        );
}
