import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/locked_app.dart';

enum BiometricSensorStyle {
  face,
  inDisplayFingerprint,
  sideFingerprint,
  rearFingerprint,
  genericFingerprint,
}

enum AppLockProfile { home, outside, night, guest }

enum RelockTimeoutMode { immediately, afterScreenOff, custom }

enum UnlockMethod { pinOnly, fingerprintSwitch, pinWithHiddenFingerprint }

enum LockVisualTheme { defaultBlue, amoledBlack, purpleNeon, minimalLight, materialPastel, animeSoft }

enum PinGenieTileStyle { expressiveBlob, roundedSquare, circle, compact, randomMaterial }

enum AppListFilter { all, locked, unlocked, system, recent }

enum AppListViewMode { list, grid }

enum AppDisguiseOption {
  original,
  googleHome,
  googleSheets,
  googleWallet,
  googleMeet,
  googleFamilyLink,
  googleFiWireless,
}

class SecurityEvent {
  const SecurityEvent({
    required this.time,
    required this.appLabel,
    required this.packageName,
    required this.method,
    required this.message,
    this.hasSelfie = false,
    this.selfieBase64,
  });

  final DateTime time;
  final String appLabel;
  final String packageName;
  final String method;
  final String message;
  final bool hasSelfie;
  final String? selfieBase64;

  Map<String, Object?> toJson() => {
        'time': time.toIso8601String(),
        'appLabel': appLabel,
        'packageName': packageName,
        'method': method,
        'message': message,
        'hasSelfie': hasSelfie,
        if (selfieBase64 != null) 'selfieBase64': selfieBase64,
      };

  factory SecurityEvent.fromJson(Map<String, Object?> json) {
    return SecurityEvent(
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      appLabel: json['appLabel'] as String? ?? 'Unknown app',
      packageName: json['packageName'] as String? ?? '',
      method: json['method'] as String? ?? 'PIN Genie',
      message: json['message'] as String? ?? 'Authentication event',
      hasSelfie: json['hasSelfie'] == true,
      selfieBase64: json['selfieBase64'] as String?,
    );
  }
}

class AppLockController extends ChangeNotifier {
  static const _pinHashKey = 'pin_hash';
  static const _pinSaltKey = 'pin_salt';
  static const _pinLengthKey = 'pin_length';
  static const _setupCompleteKey = 'setup_complete';
  static const _protectionEnabledKey = 'protection_enabled';
  static const _lockOnLaunchKey = 'lock_on_launch';
  static const _randomizeKeypadKey = 'randomize_keypad';
  static const _darkModeKey = 'dark_mode';
  static const _lockDelaySecondsKey = 'lock_delay_seconds';
  static const _relockTimeoutModeKey = 'relock_timeout_mode';
  static const _unlockMethodKey = 'unlock_method';
  static const _lockedPackagesKey = 'locked_packages';
  static const _perAppDelaySecondsKey = 'per_app_delay_seconds';
  static const _fakeCrashEnabledKey = 'fake_crash_enabled';
  static const _intruderLogEnabledKey = 'intruder_log_enabled';
  static const _intruderSelfieEnabledKey = 'intruder_selfie_enabled';
  static const _privateNotificationEnabledKey = 'private_notification_enabled';
  static const _quickTileEnabledKey = 'quick_tile_enabled';
  static const _activeProfileKey = 'active_profile';
  static const _lockThemeKey = 'lock_theme';
  static const _tileStyleKey = 'tile_style';
  static const _appListViewModeKey = 'app_list_view_mode';
  static const _appDisguiseKey = 'app_disguise';
  static const _failedAttemptsKey = 'failed_attempts';
  static const _nativeSecurityEventsMethod = 'readNativeSecurityEvents';
  static const _clearNativeSecurityEventsMethod = 'clearNativeSecurityEvents';
  static const _captureIntruderSelfieMethod = 'captureIntruderSelfie';
  static const _nativeChannel = MethodChannel('pin_genie/native_app_lock');
  static const _ownPackageName = 'com.siam.pingenie';

  late SharedPreferences _prefs;

  bool _loaded = false;
  bool _setupComplete = false;
  bool _protectionEnabled = true;
  bool _lockOnLaunch = true;
  bool _randomizeKeypad = true;
  bool _darkMode = false;
  bool _sessionUnlocked = false;
  bool _appsLoading = false;
  bool _deviceAppsLoaded = false;
  bool _nativeLockSupported = defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
  bool _nativeLockEnabled = false;
  bool _nativeStatusLoading = false;
  bool _biometricAvailable = false;
  bool _biometricChecking = false;
  bool _externalAuthenticationInProgress = false;
  bool _cameraPermissionGranted = false;
  bool _fakeCrashEnabled = false;
  bool _intruderLogEnabled = true;
  bool _intruderSelfieEnabled = false;
  bool _privateNotificationEnabled = false;
  bool _quickTileEnabled = true;
  BiometricSensorStyle _biometricSensorStyle = BiometricSensorStyle.genericFingerprint;
  AppLockProfile _activeProfile = AppLockProfile.home;
  LockVisualTheme _lockTheme = LockVisualTheme.defaultBlue;
  PinGenieTileStyle _tileStyle = PinGenieTileStyle.randomMaterial;
  AppListViewMode _appListViewMode = AppListViewMode.list;
  AppDisguiseOption _appDisguise = AppDisguiseOption.original;
  int _lockDelaySeconds = 45;
  RelockTimeoutMode _relockTimeoutMode = RelockTimeoutMode.immediately;
  UnlockMethod _unlockMethod = UnlockMethod.fingerprintSwitch;
  int _pinLength = 4;
  String? _pinHash;
  String? _pinSalt;
  String? _appsError;
  String? _nativeLockMessage;
  String? _biometricMessage;
  String? _cameraPermissionMessage;
  Set<String> _lockedPackages = {};
  Map<String, int> _perAppDelaySeconds = {};
  List<SecurityEvent> _securityEvents = [];
  List<LockableApp> _deviceApps = [];

  bool get loaded => _loaded;
  bool get isSetupComplete => _setupComplete;
  bool get protectionEnabled => _protectionEnabled;
  bool get lockOnLaunch => _lockOnLaunch;
  bool get randomizeKeypad => _randomizeKeypad;
  bool get darkMode => _darkMode;
  bool get sessionUnlocked => _sessionUnlocked;
  bool get appsLoading => _appsLoading;
  bool get deviceAppsLoaded => _deviceAppsLoaded;
  bool get nativeLockSupported => _nativeLockSupported;
  bool get nativeLockEnabled => _nativeLockEnabled;
  bool get nativeStatusLoading => _nativeStatusLoading;
  bool get biometricAvailable => _biometricAvailable;
  bool get biometricChecking => _biometricChecking;
  bool get externalAuthenticationInProgress => _externalAuthenticationInProgress;
  bool get cameraPermissionGranted => _cameraPermissionGranted;
  bool get fakeCrashEnabled => _fakeCrashEnabled;
  bool get intruderLogEnabled => _intruderLogEnabled;
  bool get intruderSelfieEnabled => _intruderSelfieEnabled;
  bool get privateNotificationEnabled => _privateNotificationEnabled;
  bool get quickTileEnabled => _quickTileEnabled;
  BiometricSensorStyle get biometricSensorStyle => _biometricSensorStyle;
  AppLockProfile get activeProfile => _activeProfile;
  RelockTimeoutMode get relockTimeoutMode => _relockTimeoutMode;
  UnlockMethod get unlockMethod => _unlockMethod;
  UnlockMethod get effectiveUnlockMethod => _biometricAvailable ? _unlockMethod : UnlockMethod.pinOnly;
  LockVisualTheme get lockTheme => _lockTheme;
  PinGenieTileStyle get tileStyle => _tileStyle;
  AppListViewMode get appListViewMode => _appListViewMode;
  AppDisguiseOption get appDisguise => _appDisguise;
  int get lockDelaySeconds => _lockDelaySeconds;
  int get pinLength => _pinLength;
  String? get appsError => _appsError;
  String? get nativeLockMessage => _nativeLockMessage;
  String? get biometricMessage => _biometricMessage;
  String? get cameraPermissionMessage => _cameraPermissionMessage;
  Set<String> get lockedPackages => Set.unmodifiable(_lockedPackages);
  Map<String, int> get perAppDelaySeconds => Map.unmodifiable(_perAppDelaySeconds);
  List<SecurityEvent> get securityEvents => List.unmodifiable(_securityEvents);
  List<SecurityEvent> get intruderSelfieEvents => _securityEvents.where((event) => event.hasSelfie).toList(growable: false);
  List<LockableApp> get apps => _deviceApps.isNotEmpty ? List.unmodifiable(_deviceApps) : fallbackLockableApps;
  List<LockableApp> get lockedApps => apps.where((app) => _lockedPackages.contains(app.packageName)).toList(growable: false);
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _pinHash = _prefs.getString(_pinHashKey);
    _pinSalt = _prefs.getString(_pinSaltKey);
    _pinLength = _prefs.getInt(_pinLengthKey) ?? 4;
    _setupComplete = _prefs.getBool(_setupCompleteKey) ?? false;
    _protectionEnabled = _prefs.getBool(_protectionEnabledKey) ?? true;
    _lockOnLaunch = _prefs.getBool(_lockOnLaunchKey) ?? true;
    _randomizeKeypad = true;
    await _prefs.setBool(_randomizeKeypadKey, true);
    _darkMode = _prefs.getBool(_darkModeKey) ?? false;
    _lockDelaySeconds = (_prefs.getInt(_lockDelaySecondsKey) ?? 45).clamp(1, 60).toInt();
    _relockTimeoutMode = _enumFromName(
      RelockTimeoutMode.values,
      _prefs.getString(_relockTimeoutModeKey),
      RelockTimeoutMode.immediately,
    );
    _unlockMethod = _enumFromName(
      UnlockMethod.values,
      _prefs.getString(_unlockMethodKey),
      UnlockMethod.fingerprintSwitch,
    );
    _lockedPackages = (_prefs.getStringList(_lockedPackagesKey) ?? [])
        .where((packageName) => packageName.trim().isNotEmpty)
        .toSet();
    _perAppDelaySeconds = _decodeIntMap(_prefs.getString(_perAppDelaySecondsKey));
    _fakeCrashEnabled = _prefs.getBool(_fakeCrashEnabledKey) ?? false;
    _intruderLogEnabled = _prefs.getBool(_intruderLogEnabledKey) ?? true;
    _intruderSelfieEnabled = _prefs.getBool(_intruderSelfieEnabledKey) ?? false;
    _privateNotificationEnabled = _prefs.getBool(_privateNotificationEnabledKey) ?? false;
    _quickTileEnabled = _prefs.getBool(_quickTileEnabledKey) ?? true;
    _activeProfile = _enumFromName(AppLockProfile.values, _prefs.getString(_activeProfileKey), AppLockProfile.home);
    _lockTheme = _enumFromName(LockVisualTheme.values, _prefs.getString(_lockThemeKey), LockVisualTheme.defaultBlue);
    _tileStyle = _enumFromName(PinGenieTileStyle.values, _prefs.getString(_tileStyleKey), PinGenieTileStyle.randomMaterial);
    _appListViewMode = _enumFromName(AppListViewMode.values, _prefs.getString(_appListViewModeKey), AppListViewMode.list);
    _appDisguise = _enumFromName(AppDisguiseOption.values, _prefs.getString(_appDisguiseKey), AppDisguiseOption.original);
    _securityEvents = _decodeEvents(_prefs.getStringList(_failedAttemptsKey) ?? const []);
    await _refreshNativeSecurityEvents(notify: false);
    _loaded = true;
    notifyListeners();
    await _syncNativeLockState();
    await refreshNativeLockState();
    await refreshBiometricState();
    await refreshCameraPermissionState();
    if (_nativeLockSupported) {
      try {
        await _nativeChannel.invokeMethod<void>('applyAppDisguise', {'option': _appDisguise.name});
      } catch (_) {
        // Launcher alias refresh is best-effort only.
      }
    }
  }

  Future<void> loadDeviceApps({bool force = false}) async {
    if (_appsLoading) return;
    if (_deviceAppsLoaded && !force) return;

    _appsLoading = true;
    _appsError = null;
    notifyListeners();

    try {
      final installedApps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: true,
        withIcon: true,
      );

      _deviceApps = installedApps.map(_mapInstalledApp).toList(growable: false)
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

      if (_deviceApps.isEmpty) {
        _appsError = 'No launchable apps were returned by Android.';
      }
    } on MissingPluginException {
      _deviceApps = [];
      _appsError = 'Installed app scanning is available only in a built Android app.';
    } on PlatformException catch (error) {
      _deviceApps = [];
      _appsError = error.message ?? 'Android blocked installed app scanning.';
    } catch (error) {
      _deviceApps = [];
      _appsError = 'Could not read installed apps: $error';
    } finally {
      _appsLoading = false;
      _deviceAppsLoaded = true;
      notifyListeners();
    }
  }

  Future<bool> launchPackage(String packageName) async {
    try {
      final launched = await InstalledApps.startApp(packageName);
      return launched ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncNativeLockState() async {
    if (!_nativeLockSupported) return;
    try {
      await _nativeChannel.invokeMethod<void>('syncLockState', {
        'pinHash': _pinHash,
        'pinSalt': _pinSalt,
        'pinLength': _pinLength,
        'setupComplete': _setupComplete,
        'protectionEnabled': _protectionEnabled,
        'lockDelaySeconds': _lockDelaySeconds,
        'relockTimeoutMode': _relockTimeoutMode.name,
        'unlockMethod': effectiveUnlockMethod.name,
        'lockedPackages': _lockedPackages.where((packageName) => packageName != _ownPackageName).toList()..sort(),
        'perAppDelaySeconds': _perAppDelaySeconds,
        'fakeCrashEnabled': _fakeCrashEnabled,
        'intruderLogEnabled': _intruderLogEnabled,
        'intruderSelfieEnabled': _intruderSelfieEnabled,
        'privateNotificationEnabled': _privateNotificationEnabled,
        'quickTileEnabled': _quickTileEnabled,
        'activeProfile': _activeProfile.name,
        'lockTheme': _lockTheme.name,
        'tileStyle': _tileStyle.name,
      });
    } on MissingPluginException {
      _nativeLockSupported = false;
    } catch (_) {
      // Keep the Flutter app usable even if the native service is unavailable.
    }
  }

  Future<void> refreshNativeLockState() async {
    if (!_nativeLockSupported) return;
    _nativeStatusLoading = true;
    _nativeLockMessage = null;
    notifyListeners();

    try {
      final enabled = await _nativeChannel.invokeMethod<bool>('isAccessibilityEnabled');
      _nativeLockEnabled = enabled ?? false;
      _nativeLockMessage = _nativeLockEnabled
          ? 'Android lock service is enabled.'
          : 'Enable the accessibility lock service to block selected apps outside this app.';
    } on MissingPluginException {
      _nativeLockSupported = false;
      _nativeLockEnabled = false;
      _nativeLockMessage = 'Native Android lock service is not installed in this build.';
    } on PlatformException catch (error) {
      _nativeLockMessage = error.message ?? 'Could not check Android lock service.';
    } catch (error) {
      _nativeLockMessage = 'Could not check Android lock service: $error';
    } finally {
      _nativeStatusLoading = false;
      notifyListeners();
    }
  }

  Future<void> openNativeLockSettings() async {
    if (!_nativeLockSupported) return;
    try {
      await _nativeChannel.invokeMethod<void>('openAccessibilitySettings');
      _nativeLockMessage = 'Turn on “PIN Genie App Lock” in Android Accessibility settings.';
    } on MissingPluginException {
      _nativeLockSupported = false;
      _nativeLockMessage = 'Native Android lock service is not installed in this build.';
    } on PlatformException catch (error) {
      _nativeLockMessage = error.message ?? 'Could not open Android Accessibility settings.';
    } catch (error) {
      _nativeLockMessage = 'Could not open Android Accessibility settings: $error';
    }
    notifyListeners();
  }

  Future<void> openNotificationProtectionSettings() async {
    if (!_nativeLockSupported) return;
    try {
      await _nativeChannel.invokeMethod<void>('openNotificationListenerSettings');
    } catch (_) {
      // Android-only convenience action. Ignore on unsupported builds.
    }
  }

  Future<void> refreshCameraPermissionState() async {
    if (!_nativeLockSupported) {
      _cameraPermissionGranted = false;
      _cameraPermissionMessage = 'Camera permission is available only on Android builds.';
      notifyListeners();
      return;
    }

    try {
      final granted = await _nativeChannel.invokeMethod<bool>('hasCameraPermission');
      _cameraPermissionGranted = granted ?? false;
      _cameraPermissionMessage = _cameraPermissionGranted
          ? 'Camera permission granted for intruder selfies.'
          : 'Camera permission is required before intruder selfies can be enabled.';
    } on MissingPluginException {
      _nativeLockSupported = false;
      _cameraPermissionGranted = false;
      _cameraPermissionMessage = 'Camera permission bridge is not available in this build.';
    } catch (error) {
      _cameraPermissionGranted = false;
      _cameraPermissionMessage = 'Could not check camera permission: $error';
    }
    notifyListeners();
  }

  Future<bool> _requestCameraPermission() async {
    if (!_nativeLockSupported) {
      _cameraPermissionGranted = false;
      _cameraPermissionMessage = 'Camera permission is available only on Android builds.';
      notifyListeners();
      return false;
    }

    try {
      final granted = await _nativeChannel.invokeMethod<bool>('requestCameraPermission');
      _cameraPermissionGranted = granted ?? false;
      _cameraPermissionMessage = _cameraPermissionGranted
          ? 'Camera permission granted for intruder selfies.'
          : 'Camera permission was denied. Intruder selfie remains off.';
      notifyListeners();
      return _cameraPermissionGranted;
    } on MissingPluginException {
      _nativeLockSupported = false;
      _cameraPermissionGranted = false;
      _cameraPermissionMessage = 'Camera permission bridge is not available in this build.';
    } catch (error) {
      _cameraPermissionGranted = false;
      _cameraPermissionMessage = 'Could not request camera permission: $error';
    }
    notifyListeners();
    return false;
  }

  Future<void> refreshBiometricState() async {
    if (!_nativeLockSupported) {
      _biometricAvailable = false;
      _biometricChecking = false;
      _biometricSensorStyle = BiometricSensorStyle.genericFingerprint;
      _biometricMessage = 'Biometric unlock is available only on Android builds.';
      notifyListeners();
      return;
    }

    _biometricChecking = true;
    notifyListeners();

    try {
      final profile = await _nativeChannel.invokeMapMethod<String, Object?>('getBiometricProfile');
      if (profile != null) {
        _biometricAvailable = profile['available'] == true;
        _biometricSensorStyle = _parseBiometricSensorStyle(profile['style'] as String?);
        _biometricMessage = _biometricAvailable
            ? (profile['message'] as String? ?? 'Biometric unlock is available on this device.')
            : 'No enrolled fingerprint or face unlock was found on this device.';
      } else {
        final available = await _nativeChannel.invokeMethod<bool>('isBiometricAvailable');
        _biometricAvailable = available ?? false;
        _biometricSensorStyle = BiometricSensorStyle.genericFingerprint;
        _biometricMessage = _biometricAvailable
            ? 'Fingerprint or face unlock is available on this device.'
            : 'No enrolled fingerprint or face unlock was found on this device.';
      }
    } on MissingPluginException {
      _nativeLockSupported = false;
      _biometricAvailable = false;
      _biometricSensorStyle = BiometricSensorStyle.genericFingerprint;
      _biometricMessage = 'Biometric unlock is not available in this build.';
    } catch (error) {
      _biometricAvailable = false;
      _biometricSensorStyle = BiometricSensorStyle.genericFingerprint;
      _biometricMessage = 'Could not check biometric unlock: $error';
    } finally {
      if (!_biometricAvailable && _unlockMethod != UnlockMethod.pinOnly) {
        _unlockMethod = UnlockMethod.pinOnly;
        await _prefs.setString(_unlockMethodKey, _unlockMethod.name);
      }
      _biometricChecking = false;
      await _syncNativeLockState();
      notifyListeners();
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_biometricAvailable) {
      await refreshBiometricState();
    }
    if (!_biometricAvailable || !_nativeLockSupported) return false;

    _externalAuthenticationInProgress = true;
    notifyListeners();

    try {
      final unlocked = await _nativeChannel.invokeMethod<bool>('authenticateBiometric');
      if (unlocked == true) await clearPinFailures();
      return unlocked ?? false;
    } catch (_) {
      return false;
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      _externalAuthenticationInProgress = false;
      notifyListeners();
    }
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    _pinSalt = salt;
    _pinHash = hash;
    _pinLength = pin.length;
    _setupComplete = true;
    _sessionUnlocked = true;
    await _prefs.setString(_pinSaltKey, salt);
    await _prefs.setString(_pinHashKey, hash);
    await _prefs.setInt(_pinLengthKey, pin.length);
    await _prefs.setBool(_setupCompleteKey, true);
    await clearPinFailures();
    await _syncNativeLockState();
    notifyListeners();
  }

  bool verifyPin(String pin) {
    final salt = _pinSalt;
    final hash = _pinHash;
    if (salt == null || hash == null) return false;
    return _constantTimeEquals(_hashPin(pin, salt), hash);
  }

  bool verifyGenieSelections(List<Set<String>> digitSets) {
    final salt = _pinSalt;
    final hash = _pinHash;
    if (salt == null || hash == null || digitSets.length != _pinLength) return false;

    var verified = false;

    void visit(int index, String current) {
      if (verified) return;
      if (index == digitSets.length) {
        verified = _constantTimeEquals(_hashPin(current, salt), hash);
        return;
      }
      for (final digit in digitSets[index]) {
        visit(index + 1, '$current$digit');
        if (verified) return;
      }
    }

    visit(0, '');
    return verified;
  }

  Future<void> markUnlocked({
    String appLabel = 'Pin Genie',
    String packageName = _ownPackageName,
    String method = 'PIN Genie',
  }) async {
    _sessionUnlocked = true;
    await clearPinFailures();
    await registerUnlockEvent(
      appLabel: appLabel,
      packageName: packageName,
      method: method,
      message: 'Unlocked successfully',
    );
    notifyListeners();
  }

  void relockSession() {
    _sessionUnlocked = false;
    notifyListeners();
  }

  Future<void> setProtectionEnabled(bool value) async {
    _protectionEnabled = value;
    if (!value) _sessionUnlocked = true;
    await _prefs.setBool(_protectionEnabledKey, value);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setLockOnLaunch(bool value) async {
    _lockOnLaunch = value;
    await _prefs.setBool(_lockOnLaunchKey, value);
    notifyListeners();
  }

  Future<void> setRandomizeKeypad(bool value) async {
    _randomizeKeypad = true;
    await _prefs.setBool(_randomizeKeypadKey, true);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _prefs.setBool(_darkModeKey, value);
    notifyListeners();
  }

  Future<void> setRelockTimeoutMode(RelockTimeoutMode mode) async {
    if (_relockTimeoutMode == mode) return;
    _relockTimeoutMode = mode;
    await _prefs.setString(_relockTimeoutModeKey, mode.name);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setUnlockMethod(UnlockMethod method) async {
    if (method != UnlockMethod.pinOnly && !_biometricAvailable) {
      await refreshBiometricState();
      if (!_biometricAvailable) {
        _unlockMethod = UnlockMethod.pinOnly;
        await _prefs.setString(_unlockMethodKey, _unlockMethod.name);
        _biometricMessage = 'No enrolled fingerprint or face unlock was found. PIN-only mode is active.';
        await _syncNativeLockState();
        notifyListeners();
        return;
      }
    }

    if (_unlockMethod == method) return;
    _unlockMethod = method;
    await _prefs.setString(_unlockMethodKey, method.name);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setLockDelaySeconds(int value) async {
    final seconds = value.clamp(1, 60).toInt();
    if (_lockDelaySeconds == seconds) return;
    _lockDelaySeconds = seconds;
    await _prefs.setInt(_lockDelaySecondsKey, seconds);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setPerAppDelaySeconds(String packageName, int? value) async {
    if (value == null) {
      _perAppDelaySeconds.remove(packageName);
    } else {
      _perAppDelaySeconds[packageName] = value.clamp(1, 60).toInt();
    }
    await _prefs.setString(_perAppDelaySecondsKey, jsonEncode(_perAppDelaySeconds));
    await _syncNativeLockState();
    notifyListeners();
  }

  int delayForPackage(String packageName) => _perAppDelaySeconds[packageName] ?? _lockDelaySeconds;

  Future<void> toggleLockedPackage(String packageName, bool locked) async {
    if (locked) {
      _lockedPackages.add(packageName);
    } else {
      _lockedPackages.remove(packageName);
      _perAppDelaySeconds.remove(packageName);
      await _prefs.setString(_perAppDelaySecondsKey, jsonEncode(_perAppDelaySeconds));
    }
    await _prefs.setStringList(_lockedPackagesKey, _lockedPackages.toList()..sort());
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> toggleGroup(String category, bool locked) async {
    final targets = apps.where((app) => app.category == category).map((app) => app.packageName);
    if (locked) {
      _lockedPackages.addAll(targets);
    } else {
      for (final packageName in targets) {
        _lockedPackages.remove(packageName);
        _perAppDelaySeconds.remove(packageName);
      }
    }
    await _prefs.setStringList(_lockedPackagesKey, _lockedPackages.toList()..sort());
    await _prefs.setString(_perAppDelaySecondsKey, jsonEncode(_perAppDelaySeconds));
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> lockCriticalSystemApps() async {
    const updateFlowPackages = <String>{
      // These packages must stay unblocked or Android APK update/install/uninstall
      // sessions can fail after PIN verification.
      'com.google.android.packageinstaller',
      'com.android.packageinstaller',
      'com.samsung.android.packageinstaller',
      'com.sec.android.app.packageinstaller',
      'com.miui.packageinstaller',
      'com.coloros.packageinstaller',
      'com.oplus.packageinstaller',
      'com.vivo.packageinstaller',
      'com.google.android.permissioncontroller',
      'com.android.permissioncontroller',
    };

    const packageNames = <String>{
      // Android core screens that are safe to protect.
      'com.android.settings',
      'com.android.settings.intelligence',
      'com.android.vending',

      // Common OEM security / permission managers.
      'com.miui.securitycenter',
      'com.coloros.safecenter',
      'com.oplus.safecenter',
      'com.vivo.permissionmanager',
      'com.iqoo.secure',
      'com.huawei.systemmanager',
      'com.hihonor.systemmanager',
      'com.samsung.android.app.galaxyfinder',
      'com.sec.android.app.samsungapps',
      'com.transsion.phonemaster',
      'com.infinix.xmanager',
      'com.itel.security',
    };

    _lockedPackages
      ..removeAll(updateFlowPackages)
      ..addAll(packageNames);
    await _prefs.setStringList(_lockedPackagesKey, _lockedPackages.toList()..sort());
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setFakeCrashEnabled(bool value) async {
    _fakeCrashEnabled = value;
    await _prefs.setBool(_fakeCrashEnabledKey, value);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setIntruderLogEnabled(bool value) async {
    _intruderLogEnabled = value;
    await _prefs.setBool(_intruderLogEnabledKey, value);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setIntruderSelfieEnabled(bool value) async {
    if (value) {
      final granted = await _requestCameraPermission();
      if (!granted) {
        _intruderSelfieEnabled = false;
        await _prefs.setBool(_intruderSelfieEnabledKey, false);
        await _syncNativeLockState();
        notifyListeners();
        return;
      }
      _intruderLogEnabled = true;
      await _prefs.setBool(_intruderLogEnabledKey, true);
    }

    _intruderSelfieEnabled = value;
    await _prefs.setBool(_intruderSelfieEnabledKey, value);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setPrivateNotificationEnabled(bool value) async {
    _privateNotificationEnabled = value;
    await _prefs.setBool(_privateNotificationEnabledKey, value);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setQuickTileEnabled(bool value) async {
    _quickTileEnabled = value;
    await _prefs.setBool(_quickTileEnabledKey, value);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setActiveProfile(AppLockProfile profile) async {
    _activeProfile = profile;
    _lockDelaySeconds = switch (profile) {
      AppLockProfile.home => 45,
      AppLockProfile.outside => 1,
      AppLockProfile.night => 10,
      AppLockProfile.guest => 1,
    };
    if (profile == AppLockProfile.guest) {
      _fakeCrashEnabled = true;
    }
    await _prefs.setString(_activeProfileKey, profile.name);
    await _prefs.setInt(_lockDelaySecondsKey, _lockDelaySeconds);
    await _prefs.setBool(_fakeCrashEnabledKey, _fakeCrashEnabled);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setLockTheme(LockVisualTheme theme) async {
    _lockTheme = theme;
    await _prefs.setString(_lockThemeKey, theme.name);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setTileStyle(PinGenieTileStyle style) async {
    _tileStyle = style;
    await _prefs.setString(_tileStyleKey, style.name);
    await _syncNativeLockState();
    notifyListeners();
  }

  Future<void> setAppListViewMode(AppListViewMode mode) async {
    if (_appListViewMode == mode) return;
    _appListViewMode = mode;
    await _prefs.setString(_appListViewModeKey, mode.name);
    notifyListeners();
  }

  Future<void> setAppDisguise(AppDisguiseOption option) async {
    if (_appDisguise == option) return;
    _appDisguise = option;
    await _prefs.setString(_appDisguiseKey, option.name);
    if (_nativeLockSupported) {
      try {
        await _nativeChannel.invokeMethod<void>('applyAppDisguise', {'option': option.name});
      } on MissingPluginException {
        _nativeLockSupported = false;
      } catch (_) {
        // Keep the Flutter UI responsive even if native launcher alias updates are unavailable.
      }
    }
    notifyListeners();
  }

  Future<void> registerUnlockEvent({
    String appLabel = 'Pin Genie',
    String packageName = _ownPackageName,
    String method = 'PIN Genie',
    String message = 'Unlocked successfully',
  }) async {
    await _prependSecurityEvent(
      SecurityEvent(
        time: DateTime.now(),
        appLabel: appLabel,
        packageName: packageName,
        method: method,
        message: message,
      ),
    );
    notifyListeners();
  }

  Future<void> refreshLockHistory() => _refreshNativeSecurityEvents();

  Future<void> _refreshNativeSecurityEvents({bool notify = true}) async {
    if (!_nativeLockSupported) return;
    try {
      final raw = await _nativeChannel.invokeListMethod<dynamic>(_nativeSecurityEventsMethod);
      if (raw == null || raw.isEmpty) return;
      final nativeEvents = <SecurityEvent>[];
      for (final item in raw) {
        if (item is Map) {
          nativeEvents.add(SecurityEvent.fromJson(Map<String, Object?>.from(item)));
        }
      }
      if (nativeEvents.isEmpty) return;
      await _mergeSecurityEvents(nativeEvents);
      if (notify) notifyListeners();
    } on MissingPluginException {
      _nativeLockSupported = false;
    } catch (_) {
      // Keep history usable even if native history import is unavailable.
    }
  }

  Future<void> registerFailedAttempt({
    String appLabel = 'Pin Genie',
    String packageName = _ownPackageName,
    String method = 'PIN Genie',
    String message = 'Wrong authentication attempt',
  }) async {
    if (_intruderLogEnabled) {
      final selfieBase64 = _intruderSelfieEnabled ? await _captureIntruderSelfie() : null;
      await _prependSecurityEvent(
        SecurityEvent(
          time: DateTime.now(),
          appLabel: appLabel,
          packageName: packageName,
          method: method,
          message: message,
          hasSelfie: _intruderSelfieEnabled,
          selfieBase64: selfieBase64,
        ),
      );
    }
    notifyListeners();
  }

  Future<String?> _captureIntruderSelfie() async {
    if (!_nativeLockSupported) return null;
    if (!_cameraPermissionGranted) {
      await refreshCameraPermissionState();
    }
    if (!_cameraPermissionGranted) return null;

    try {
      final value = await _nativeChannel.invokeMethod<String>(_captureIntruderSelfieMethod);
      final cleaned = value?.trim();
      return cleaned == null || cleaned.isEmpty ? null : cleaned;
    } on MissingPluginException {
      _nativeLockSupported = false;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPinFailures() async {
    // PIN entry is intentionally unlimited. This method remains for older migrations.
    notifyListeners();
  }

  Future<void> clearSecurityEvents() async {
    _securityEvents = [];
    await _prefs.remove(_failedAttemptsKey);
    if (_nativeLockSupported) {
      try {
        await _nativeChannel.invokeMethod<void>(_clearNativeSecurityEventsMethod);
      } catch (_) {
        // Local history is already cleared.
      }
    }
    notifyListeners();
  }

  Future<void> resetAll() async {
    await _prefs.clear();
    _setupComplete = false;
    _protectionEnabled = true;
    _lockOnLaunch = true;
    _randomizeKeypad = true;
    _darkMode = false;
    _lockDelaySeconds = 45;
    _relockTimeoutMode = RelockTimeoutMode.immediately;
    _unlockMethod = UnlockMethod.fingerprintSwitch;
    _sessionUnlocked = false;
    _pinLength = 4;
    _pinHash = null;
    _pinSalt = null;
    _lockedPackages = {};
    _perAppDelaySeconds = {};
    _fakeCrashEnabled = false;
    _intruderLogEnabled = true;
    _intruderSelfieEnabled = false;
    _privateNotificationEnabled = false;
    _quickTileEnabled = true;
    _activeProfile = AppLockProfile.home;
    _lockTheme = LockVisualTheme.defaultBlue;
    _tileStyle = PinGenieTileStyle.randomMaterial;
    _appDisguise = AppDisguiseOption.original;
    _securityEvents = [];
    await _syncNativeLockState();
    if (_nativeLockSupported) {
      try {
        await _nativeChannel.invokeMethod<void>('applyAppDisguise', {'option': _appDisguise.name});
      } catch (_) {
        // Ignore launcher alias reset failures during app reset.
      }
    }
    notifyListeners();
  }

  LockableApp _mapInstalledApp(AppInfo app) {
    return LockableApp(
      packageName: app.packageName,
      label: app.name.trim().isEmpty ? app.packageName : app.name.trim(),
      category: _formatCategory(app.category.name),
      iconBytes: app.icon,
      isSystem: app.isSystemApp,
      isDeviceApp: true,
    );
  }

  String _formatCategory(String categoryName) {
    if (categoryName == 'undefined') return 'App';
    final spaced = categoryName.replaceAll('_', ' ');
    return spaced
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  BiometricSensorStyle _parseBiometricSensorStyle(String? value) {
    return switch (value) {
      'face' => BiometricSensorStyle.face,
      'in_display_fingerprint' => BiometricSensorStyle.inDisplayFingerprint,
      'side_fingerprint' => BiometricSensorStyle.sideFingerprint,
      'rear_fingerprint' => BiometricSensorStyle.rearFingerprint,
      _ => BiometricSensorStyle.genericFingerprint,
    };
  }

  T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  Future<void> _prependSecurityEvent(SecurityEvent event) async {
    await _mergeSecurityEvents([event]);
  }

  Future<void> _mergeSecurityEvents(List<SecurityEvent> events) async {
    final merged = <SecurityEvent>[...events, ..._securityEvents]
      ..sort((a, b) => b.time.compareTo(a.time));

    final seen = <String>{};
    _securityEvents = [
      for (final event in merged)
        if (seen.add(_eventIdentity(event))) event,
    ].take(100).toList(growable: false);

    await _prefs.setStringList(
      _failedAttemptsKey,
      _securityEvents.map((event) => jsonEncode(event.toJson())).toList(growable: false),
    );
  }

  String _eventIdentity(SecurityEvent event) {
    return '${event.time.millisecondsSinceEpoch}|${event.packageName}|${event.method}|${event.message}';
  }

  Map<String, int> _decodeIntMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, (value as num).toInt().clamp(1, 60).toInt()));
    } catch (_) {
      return {};
    }
  }

  List<SecurityEvent> _decodeEvents(List<String> raw) {
    final events = <SecurityEvent>[];
    for (final item in raw) {
      try {
        events.add(SecurityEvent.fromJson(Map<String, Object?>.from(jsonDecode(item) as Map)));
      } catch (_) {
        // Ignore corrupt log rows.
      }
    }
    return events;
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
