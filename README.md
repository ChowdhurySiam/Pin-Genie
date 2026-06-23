# Pin Genie

**Pin Genie** is a Flutter-based Android app-lock project with a randomized PIN Genie unlock system, Material 3 interface, native AccessibilityService app guarding, biometric fallback, intruder-selfie logging, fake-crash disguise mode, and launcher app-disguise options.

Current version: **1.2.24+120024**

---

## Highlights

- Randomized PIN Genie unlock screen
- Native Android app-lock screen for selected apps
- Optional biometric unlock switcher
- Dedicated Security page for PIN reset, recovery, retry timeout, and fallback unlock controls
- Installed-app picker and lock management
- Per-app lock delay support
- Intruder history and failed-unlock selfie capture
- Fake crash screen with hidden unlock gesture
- App disguise launcher aliases
- Private notification protection option
- Recovery codes and custom security question fallback
- Configurable failed-PIN retry timeout
- Material 3 responsive UI
- GitHub Actions builds for ARM64, ARM32, and universal release APKs

---

## Project identity

| Item | Value |
| --- | --- |
| App name | Pin Genie |
| Flutter package | `pingenie` |
| Android package | `com.siam.pingenie` |
| Platform target | Android |
| Minimum Android SDK | 23 |
| Developer credit | Developed by Siam Chowdhury |

---

## Core features

### PIN Genie authentication

Pin Genie does not show a normal fixed keypad. Each unlock step can randomize the digit groups, tile order, labels, colors, and shapes. This makes the unlock flow harder to observe from screen taps alone.

### Native app locking

The Flutter app stores the selected locked apps. The Android native AccessibilityService watches foreground app changes and opens the native Pin Genie lock screen before a protected app can be used.

### Biometric unlock

Biometric unlock is optional. PIN Genie remains the default unlock method, and the biometric option appears only when Android reports an enrolled biometric method.

### Security and recovery

The Settings screen includes a dedicated **Security** page for PIN reset, recovery methods, retry behavior, and unlock fallback options. Resetting the PIN requires the current PIN first.

Recovery codes are generated as one-time codes and are shown only when created. The app stores salted hashes of those codes, not readable code text. Custom security-question answers are also stored as salted hashes.

PIN retry timeout can be configured with a failed-attempt threshold and a custom timeout duration from seconds up to minutes. When the threshold is reached, PIN input is blocked only until the configured timeout expires.


### Intruder selfies

When Camera permission is granted, failed unlock attempts can store a front-camera selfie preview with the security event. Older log entries that were saved before selfie capture was fixed cannot be recovered.

### Fake crash mode

Fake crash mode shows a compact Android-style “isn’t responding” screen. A normal tap on **Wait** keeps the fake screen visible. Pressing and holding **Wait** opens the PIN Genie unlock screen.

### App disguise

The launcher icon can be disguised as one of the supported Google-style app icons:

- Original Pin Genie
- Google Meet
- Google Home
- Google Wallet
- Google Sheets
- Google Family Link
- Google Fi Wireless

The disguise system uses Android launcher aliases. After changing disguise, some launchers may need a few seconds, a home-screen refresh, or a launcher restart before the new icon appears.

---

## Android permissions and services

The Android patch script adds the native permissions and service declarations needed for true app locking.

```xml
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
<uses-permission android:name="android.permission.CAMERA" />
```

It also registers the AccessibilityService:

```xml
<service
    android:name=".AppLockAccessibilityService"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE" />
```

`QUERY_ALL_PACKAGES` is useful for internal or sideloaded app-lock builds that need to list installed apps. For Google Play distribution, review package-visibility policy requirements before publishing.

---

## How app locking works

1. Open Pin Genie.
2. Create the 4-digit PIN.
3. Open Android **Settings → Accessibility**.
4. Enable **PIN Genie App Lock**.
5. Return to Pin Genie.
6. Open the **Apps** tab.
7. Select the apps to protect.
8. Open a protected app from the launcher.
9. The native Pin Genie lock screen should appear before access.

Without Accessibility permission, Android does not allow a Flutter app to intercept other apps opened from the launcher. The app can still save settings, manage the lock list, and test its internal unlock flow, but true cross-app locking requires the native service.

---

## Local development

### Install dependencies

```bash
flutter pub get
```

### Generate Android files if missing

```bash
flutter create --platforms=android --project-name=pingenie --org=com.siam .
```

### Generate launcher icons

```bash
dart run flutter_launcher_icons
```

### Apply the native Android app-lock patch

```bash
python3 tool/patch_android_true_app_lock.py
```

Run this patch again after regenerating the Android folder.

### Run the app

```bash
flutter run
```

---

## Build a release APK

```bash
flutter create --platforms=android --project-name=pingenie --org=com.siam .
flutter pub get
dart run flutter_launcher_icons
python3 tool/patch_android_true_app_lock.py
flutter build apk --release
```

Release APK output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## GitHub Actions build

The workflow at `.github/workflows/flutter_android_build.yml` builds Android release APKs automatically.

It performs these steps:

1. Installs Java 17.
2. Installs stable Flutter.
3. Generates Android platform files if needed.
4. Runs `flutter pub get`.
5. Generates launcher icons.
6. Applies the native app-lock patch.
7. Runs analyzer and tests.
8. Builds three APK variants:
   - ARM64: `arm64-v8a`
   - ARM32: `armeabi-v7a`
   - Universal APK
9. Uploads all release APKs as one GitHub Actions artifact.

---

## Project structure

```text
lib/
  main.dart
  src/
    app.dart
    models/
    screens/
    state/
    theme/
    utils/
    widgets/

tool/
  patch_android_true_app_lock.py
  signing/

assets/
  app_icon/
    pin_genie_icon.png
    pin_genie_icon_foreground.png
    disguise/

docs/
  ANDROID_TRUE_APP_LOCK_PLAN.md

.github/workflows/
  flutter_android_build.yml
```

---

## Important notes

- Accessibility permission must be enabled manually by the user.
- Battery optimization and aggressive background-process restrictions may affect the native lock service on some Android skins.
- Launcher disguise depends on Android launcher alias behavior. Some launchers cache icons longer than others.
- Intruder selfie capture requires Camera permission.
- Existing intruder entries without image data cannot be converted into photos later.
- Play Store distribution may require policy review because app-lock behavior uses AccessibilityService and package visibility.

---

## Credits

Developed by **Siam Chowdhury**.
