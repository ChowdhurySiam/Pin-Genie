#!/usr/bin/env python3
"""Patch a generated Flutter Android project with native app-lock support.

Run after `flutter create --platforms=android --project-name=pingenie --org=com.siam .`.
The Flutter UI stores PIN and locked package data in SharedPreferences. This patch adds
an Android AccessibilityService and a native PIN Genie Activity that read the same data.
"""
from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
MANIFEST = ANDROID / "app/src/main/AndroidManifest.xml"
TARGET_PACKAGE = "com.siam.pingenie"
APP_NAME = "Pin Genie"
PROJECT_NAME = "pingenie"



def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def detect_package() -> str:
    # Pin Genie uses a fixed Android application ID. This keeps generated
    # GitHub Actions builds and previously generated local android/ folders
    # on the same package name.
    return TARGET_PACKAGE


def patch_disguise_launcher_icons() -> None:
    """Install launcher icon resources used by activity-alias disguises.

    The generated Flutter launcher icon remains the default Pin Genie icon.
    Disguise aliases need their own mipmap assets; otherwise Android changes
    the label but keeps the Pin Genie icon, which makes the disguise appear
    broken on most launchers.
    """
    source_dir = ROOT / "assets/app_icon/disguise"
    icons = [
        "ic_launcher_google_home",
        "ic_launcher_google_sheets",
        "ic_launcher_google_wallet",
        "ic_launcher_google_meet",
        "ic_launcher_google_family_link",
        "ic_launcher_google_fi_wireless",
    ]
    densities = ["mipmap-mdpi", "mipmap-hdpi", "mipmap-xhdpi", "mipmap-xxhdpi", "mipmap-xxxhdpi"]
    for icon in icons:
        source = source_dir / f"{icon}.png"
        if not source.exists():
            raise SystemExit(f"Missing disguise launcher icon asset: {source}")
        for density in densities:
            target_dir = ANDROID / f"app/src/main/res/{density}"
            target_dir.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target_dir / f"{icon}.png")


def _launcher_alias_block() -> str:
    return """
        <activity-alias
            android:name=".OriginalLauncherAlias"
            android:enabled="true"
            android:exported="true"
            android:icon="@mipmap/ic_launcher"
            android:label="@string/launcher_name_original"
            android:targetActivity=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>

        <activity-alias
            android:name=".GoogleHomeAlias"
            android:enabled="false"
            android:exported="true"
            android:icon="@mipmap/ic_launcher_google_home"
            android:label="@string/launcher_name_google_home"
            android:targetActivity=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>

        <activity-alias
            android:name=".GoogleSheetsAlias"
            android:enabled="false"
            android:exported="true"
            android:icon="@mipmap/ic_launcher_google_sheets"
            android:label="@string/launcher_name_google_sheets"
            android:targetActivity=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>

        <activity-alias
            android:name=".GoogleWalletAlias"
            android:enabled="false"
            android:exported="true"
            android:icon="@mipmap/ic_launcher_google_wallet"
            android:label="@string/launcher_name_google_wallet"
            android:targetActivity=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>

        <activity-alias
            android:name=".GoogleMeetAlias"
            android:enabled="false"
            android:exported="true"
            android:icon="@mipmap/ic_launcher_google_meet"
            android:label="@string/launcher_name_google_meet"
            android:targetActivity=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>

        <activity-alias
            android:name=".GoogleFamilyLinkAlias"
            android:enabled="false"
            android:exported="true"
            android:icon="@mipmap/ic_launcher_google_family_link"
            android:label="@string/launcher_name_google_family_link"
            android:targetActivity=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>

        <activity-alias
            android:name=".GoogleFiWirelessAlias"
            android:enabled="false"
            android:exported="true"
            android:icon="@mipmap/ic_launcher_google_fi_wireless"
            android:label="@string/launcher_name_google_fi_wireless"
            android:targetActivity=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>
"""


def _strip_launcher_category_from_main_activity(text: str) -> str:
    activity_pattern = re.compile(
        r'(<activity\b(?=[^>]*android:name="\.MainActivity")[\s\S]*?</activity>)',
        flags=re.DOTALL,
    )

    def strip(match: re.Match[str]) -> str:
        block = match.group(1)
        return re.sub(
            r'\s*<category\s+android:name="android\.intent\.category\.LAUNCHER"\s*/>',
            '',
            block,
            flags=re.DOTALL,
        )

    return activity_pattern.sub(strip, text, count=1)


def _remove_existing_launcher_aliases(text: str) -> str:
    alias_names = (
        "OriginalLauncherAlias",
        "GoogleHomeAlias",
        "GoogleSheetsAlias",
        "GoogleWalletAlias",
        "GoogleMeetAlias",
        "GoogleFamilyLinkAlias",
        "GoogleFiWirelessAlias",
    )
    alias_pattern = re.compile(
        r'\n\s*<activity-alias\b(?=[^>]*android:name="\.(' + "|".join(alias_names) + r')")[\s\S]*?</activity-alias>',
        flags=re.DOTALL,
    )
    return alias_pattern.sub("", text)


def patch_manifest() -> None:
    text = read(MANIFEST)
    text = re.sub(r'android:label="[^"]*"', 'android:label="@string/app_name"', text, count=1)
    permissions = [
        '<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />',
        '<uses-permission android:name="android.permission.CAMERA" />',
        '<uses-permission android:name="android.permission.USE_BIOMETRIC" />',
        '<uses-permission android:name="android.permission.USE_FINGERPRINT" />',
    ]
    for permission in permissions:
        if permission not in text:
            text = text.replace("<application", f"    {permission}\n\n    <application", 1)

    if ".NativeLockActivity" not in text:
        entries = """
        <activity
            android:name=".NativeLockActivity"
            android:excludeFromRecents="true"
            android:exported="false"
            android:launchMode="singleTask"
            android:theme="@style/Theme.PinGenie.NativeLock" />

        <service
            android:name=".AppLockAccessibilityService"
            android:exported="true"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/app_lock_accessibility_service" />
        </service>
"""
        text = text.replace("    </application>", f"{entries}\n    </application>", 1)

    if ".PrivateNotificationService" not in text:
        notification_entry = """
        <service
            android:name=".PrivateNotificationService"
            android:exported="true"
            android:label="@string/app_name"
            android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
            <intent-filter>
                <action android:name="android.service.notification.NotificationListenerService" />
            </intent-filter>
        </service>
"""
        text = text.replace("    </application>", f"{notification_entry}\n    </application>", 1)

    if ".PinGenieQuickTileService" not in text:
        tile_entry = """
        <service
            android:name=".PinGenieQuickTileService"
            android:exported="true"
            android:icon="@mipmap/ic_launcher"
            android:label="Pin Genie"
            android:permission="android.permission.BIND_QUICK_SETTINGS_TILE">
            <intent-filter>
                <action android:name="android.service.quicksettings.action.QS_TILE" />
            </intent-filter>
        </service>
"""
        text = text.replace("    </application>", f"{tile_entry}\n    </application>", 1)

    # Only MainActivity should lose its direct LAUNCHER category. Older versions
    # removed the first LAUNCHER category globally, so rerunning the patch could
    # silently strip categories from the aliases and leave the app undisguisable.
    text = _strip_launcher_category_from_main_activity(text)
    text = _remove_existing_launcher_aliases(text)
    text = re.sub(r"\n\s*</application>", f"{_launcher_alias_block()}\n    </application>", text, count=1)

    write(MANIFEST, text)

def patch_strings() -> None:
    path = ANDROID / "app/src/main/res/values/strings.xml"
    if path.exists():
        text = read(path)
    else:
        text = "<resources>\n</resources>\n"
    strings = {
        "app_name": APP_NAME,
        "app_lock_accessibility_label": "PIN Genie App Lock",
        "app_lock_accessibility_summary": "Locks selected apps with PIN Genie.",
        "app_lock_accessibility_description": "PIN Genie App Lock watches which app is opened and shows a PIN screen before selected apps can be used.",
        "launcher_name_original": APP_NAME,
        "launcher_name_google_home": "Google Home",
        "launcher_name_google_sheets": "Google Sheets",
        "launcher_name_google_wallet": "Google Wallet",
        "launcher_name_google_meet": "Google Meet",
        "launcher_name_google_family_link": "Google Family Link",
        "launcher_name_google_fi_wireless": "Google Fi Wireless",
    }
    for name, value in strings.items():
        pattern = rf'<string\s+name="{re.escape(name)}">.*?</string>'
        replacement = f'<string name="{name}">{value}</string>'
        if re.search(pattern, text, flags=re.DOTALL):
            text = re.sub(pattern, replacement, text, count=1, flags=re.DOTALL)
        else:
            text = text.replace("</resources>", f'    {replacement}\n</resources>', 1)
    write(path, text)


def patch_styles() -> None:
    path = ANDROID / "app/src/main/res/values/styles.xml"
    if path.exists():
        text = read(path)
    else:
        text = "<resources>\n</resources>\n"
    if "Theme.PinGenie.NativeLock" not in text:
        style = """
    <style name="Theme.PinGenie.NativeLock" parent="android:style/Theme.Material.NoActionBar">
        <item name="android:windowNoTitle">true</item>
        <item name="android:windowActionBar">false</item>
        <item name="android:windowFullscreen">false</item>
        <item name="android:windowIsTranslucent">false</item>
        <item name="android:windowDisablePreview">true</item>
        <item name="android:colorAccent">#9EA8FF</item>
    </style>
"""
        text = text.replace("</resources>", f"{style}</resources>", 1)
    write(path, text)


def write_accessibility_config() -> None:
    write(
        ANDROID / "app/src/main/res/xml/app_lock_accessibility_service.xml",
        """<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged|typeWindowsChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:accessibilityFlags="flagReportViewIds|flagRetrieveInteractiveWindows"
    android:canRetrieveWindowContent="true"
    android:description="@string/app_lock_accessibility_description"
    android:notificationTimeout="30"
    android:summary="@string/app_lock_accessibility_summary" />
""",
    )

def patch_gradle_identity() -> None:
    gradle_paths = [
        ANDROID / "app/build.gradle",
        ANDROID / "app/build.gradle.kts",
    ]
    for path in gradle_paths:
        if not path.exists():
            continue
        text = read(path)
        if path.suffix == ".kts":
            text = re.sub(r'namespace\s*=\s*"[^"]+"', f'namespace = "{TARGET_PACKAGE}"', text)
            text = re.sub(r'applicationId\s*=\s*"[^"]+"', f'applicationId = "{TARGET_PACKAGE}"', text)
        else:
            text = re.sub(r'namespace\s*=\s*["\'][^"\']+["\']', f'namespace = "{TARGET_PACKAGE}"', text)
            text = re.sub(r'namespace\s+["\'][^"\']+["\']', f'namespace "{TARGET_PACKAGE}"', text)
            text = re.sub(r'applicationId\s*=\s*["\'][^"\']+["\']', f'applicationId = "{TARGET_PACKAGE}"', text)
            text = re.sub(r'applicationId\s+["\'][^"\']+["\']', f'applicationId "{TARGET_PACKAGE}"', text)
        write(path, text)



def patch_release_signing() -> None:
    """Use one stable release key so APK updates install over previous builds.

    Flutter's generated Android template signs release builds with the local debug key
    unless a release signing config is provided. GitHub runners create different debug
    keys, so updates can fail with a generic "App not installed" message. This project
    ships a fixed development release key for repeatable GitHub Actions APK updates.
    """
    key_source = ROOT / "tool/signing/pin_genie_update_key.jks"
    if not key_source.exists():
        raise SystemExit(
            "tool/signing/pin_genie_update_key.jks is missing. "
            "Keep this file committed, or configure your own release signing key. "
            "Without a stable signing key Android updates will fail."
        )

    key_target = ANDROID / "app/pin_genie_update_key.jks"
    key_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(key_source, key_target)

    write(
        ANDROID / "key.properties",
        """storePassword=pinGenieUpdateKey2026
keyPassword=pinGenieUpdateKey2026
keyAlias=pin_genie_update
storeFile=pin_genie_update_key.jks
""",
    )

    kts_path = ANDROID / "app/build.gradle.kts"
    groovy_path = ANDROID / "app/build.gradle"

    if kts_path.exists():
        text = read(kts_path)
        if "val pinGenieKeystoreProperties" not in text:
            text = """import java.io.FileInputStream
import java.util.Properties

val pinGenieKeystoreProperties = Properties()
val pinGenieKeystorePropertiesFile = rootProject.file("key.properties")
if (pinGenieKeystorePropertiesFile.exists()) {
    pinGenieKeystoreProperties.load(FileInputStream(pinGenieKeystorePropertiesFile))
}

""" + text

        signing_block = """
    signingConfigs {
        create("pinGenieRelease") {
            keyAlias = pinGenieKeystoreProperties["keyAlias"] as String
            keyPassword = pinGenieKeystoreProperties["keyPassword"] as String
            storeFile = file(pinGenieKeystoreProperties["storeFile"] as String)
            storePassword = pinGenieKeystoreProperties["storePassword"] as String
        }
    }

"""
        if "create(\"pinGenieRelease\")" not in text:
            text = text.replace("    buildTypes {", signing_block + "    buildTypes {", 1)
        text = re.sub(
            r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
            'signingConfig = signingConfigs.getByName("pinGenieRelease")',
            text,
        )
        text = re.sub(
            r'signingConfig\s*=\s*signingConfigs\.getByName\("release"\)',
            'signingConfig = signingConfigs.getByName("pinGenieRelease")',
            text,
        )
        if 'signingConfig = signingConfigs.getByName("pinGenieRelease")' not in text:
            text = text.replace(
                "        release {",
                "        release {\n            signingConfig = signingConfigs.getByName(\"pinGenieRelease\")",
                1,
            )
        write(kts_path, text)
        return

    if groovy_path.exists():
        text = read(groovy_path)
        if "pinGenieKeystoreProperties" not in text:
            text = """def pinGenieKeystoreProperties = new Properties()
def pinGenieKeystorePropertiesFile = rootProject.file('key.properties')
if (pinGenieKeystorePropertiesFile.exists()) {
    pinGenieKeystoreProperties.load(new FileInputStream(pinGenieKeystorePropertiesFile))
}

""" + text

        signing_block = """
    signingConfigs {
        pinGenieRelease {
            keyAlias pinGenieKeystoreProperties['keyAlias']
            keyPassword pinGenieKeystoreProperties['keyPassword']
            storeFile file(pinGenieKeystoreProperties['storeFile'])
            storePassword pinGenieKeystoreProperties['storePassword']
        }
    }

"""
        if "pinGenieRelease" not in text:
            text = text.replace("    buildTypes {", signing_block + "    buildTypes {", 1)
        text = re.sub(r'signingConfig\s+signingConfigs\.debug', 'signingConfig signingConfigs.pinGenieRelease', text)
        text = re.sub(r'signingConfig\s*=\s*signingConfigs\.debug', 'signingConfig signingConfigs.pinGenieRelease', text)
        if "signingConfig signingConfigs.pinGenieRelease" not in text:
            text = text.replace(
                "        release {",
                "        release {\n            signingConfig signingConfigs.pinGenieRelease",
                1,
            )
        write(groovy_path, text)


def kotlin_dir(package_name: str) -> Path:
    return ANDROID / "app/src/main/kotlin" / Path(*package_name.split("."))


def write_intruder_selfie_capture(package_name: str) -> None:
    write(
        kotlin_dir(package_name) / "IntruderSelfieCapture.kt",
        f"""package {package_name}

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.SurfaceTexture
import android.hardware.Camera
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.math.max

@Suppress("DEPRECATION")
object IntruderSelfieCapture {{
    private const val MAX_IMAGE_EDGE = 480
    private const val JPEG_QUALITY = 62
    private const val CAPTURE_TIMEOUT_MS = 3200L

    fun capture(context: Context, onResult: (String?) -> Unit) {{
        if (!hasCameraPermission(context)) {{
            deliver(onResult, null)
            return
        }}

        Thread {{
            var camera: Camera? = null
            var texture: SurfaceTexture? = null
            var base64: String? = null
            try {{
                val cameraId = frontCameraId() ?: firstCameraId() ?: throw IllegalStateException("No camera available")
                val info = Camera.CameraInfo().also {{ Camera.getCameraInfo(cameraId, it) }}
                camera = Camera.open(cameraId)
                camera.parameters = camera.parameters.apply {{
                    jpegQuality = JPEG_QUALITY
                    supportedPictureSizes
                        ?.filter {{ it.width > 0 && it.height > 0 }}
                        ?.minByOrNull {{ size ->
                            val edge = max(size.width, size.height)
                            kotlin.math.abs(edge - MAX_IMAGE_EDGE)
                        }}
                        ?.let {{ pictureSize -> setPictureSize(pictureSize.width, pictureSize.height) }}
                    supportedPreviewSizes
                        ?.filter {{ it.width > 0 && it.height > 0 }}
                        ?.minByOrNull {{ size ->
                            val edge = max(size.width, size.height)
                            kotlin.math.abs(edge - MAX_IMAGE_EDGE)
                        }}
                        ?.let {{ previewSize -> setPreviewSize(previewSize.width, previewSize.height) }}
                }}
                texture = SurfaceTexture(17)
                camera.setPreviewTexture(texture)
                camera.startPreview()
                Thread.sleep(420L)

                val latch = CountDownLatch(1)
                var jpegBytes: ByteArray? = null
                camera.takePicture(null, null, Camera.PictureCallback {{ data, _ ->
                    jpegBytes = data
                    latch.countDown()
                }})
                latch.await(CAPTURE_TIMEOUT_MS, TimeUnit.MILLISECONDS)
                base64 = jpegBytes?.let {{ encodeDisplayJpeg(it, info) }}
            }} catch (_: Exception) {{
                base64 = null
            }} finally {{
                try {{ camera?.stopPreview() }} catch (_: Exception) {{}}
                try {{ camera?.release() }} catch (_: Exception) {{}}
                try {{ texture?.release() }} catch (_: Exception) {{}}
            }}
            deliver(onResult, base64)
        }}.start()
    }}

    private fun hasCameraPermission(context: Context): Boolean {{
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            context.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }}

    private fun frontCameraId(): Int? {{
        val info = Camera.CameraInfo()
        for (id in 0 until Camera.getNumberOfCameras()) {{
            Camera.getCameraInfo(id, info)
            if (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT) return id
        }}
        return null
    }}

    private fun firstCameraId(): Int? = if (Camera.getNumberOfCameras() > 0) 0 else null

    private fun encodeDisplayJpeg(bytes: ByteArray, info: Camera.CameraInfo): String? {{
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val rotated = rotateAndScale(bitmap, info)
        val output = ByteArrayOutputStream()
        rotated.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, output)
        if (rotated !== bitmap) bitmap.recycle()
        rotated.recycle()
        return Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
    }}

    private fun rotateAndScale(bitmap: Bitmap, info: Camera.CameraInfo): Bitmap {{
        val matrix = Matrix()
        val rotation = if (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT) {{
            (360 - info.orientation) % 360
        }} else {{
            info.orientation
        }}
        if (rotation != 0) matrix.postRotate(rotation.toFloat())
        if (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT) matrix.postScale(-1f, 1f)

        val largestEdge = max(bitmap.width, bitmap.height)
        if (largestEdge > MAX_IMAGE_EDGE) {{
            val scale = MAX_IMAGE_EDGE.toFloat() / largestEdge.toFloat()
            matrix.postScale(scale, scale)
        }}

        return try {{
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        }} catch (_: Exception) {{
            bitmap
        }}
    }}

    private fun deliver(onResult: (String?) -> Unit, value: String?) {{
        Handler(Looper.getMainLooper()).post {{ onResult(value) }}
    }}
}}
""",
    )


def write_main_activity(package_name: str) -> None:
    write(
        kotlin_dir(package_name) / "MainActivity.kt",
        f"""package {package_name}

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {{
    private var pendingCameraPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler {{ call, result ->
            when (call.method) {{
                "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
                "openAccessibilitySettings" -> {{
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }}
                "openNotificationListenerSettings" -> {{
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(true)
                }}
                "hasCameraPermission" -> result.success(hasCameraPermission())
                "requestCameraPermission" -> requestCameraPermission(result)
                "captureIntruderSelfie" -> captureIntruderSelfie(result)
                "syncLockState" -> {{
                    syncLockState(call.arguments as? Map<*, *>)
                    result.success(true)
                }}
                "isBiometricAvailable" -> result.success(isBiometricAvailable())
                "getBiometricProfile" -> result.success(biometricProfile())
                "authenticateBiometric" -> authenticateBiometric(result)
                "applyAppDisguise" -> {{
                    val option = (call.arguments as? Map<*, *>)?.get("option") as? String ?: "original"
                    applyAppDisguise(option)
                    result.success(true)
                }}
                "getCurrentAppDisguise" -> result.success(currentAppDisguise())
                "readNativeSecurityEvents" -> result.success(readNativeSecurityEvents())
                "clearNativeSecurityEvents" -> {{
                    getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE).edit().remove(KEY_SECURITY_EVENTS).apply()
                    result.success(true)
                }}
                else -> result.notImplemented()
            }}
        }}
    }}

    private fun hasCameraPermission(): Boolean {{
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }}

    private fun requestCameraPermission(result: MethodChannel.Result) {{
        if (hasCameraPermission()) {{
            result.success(true)
            return
        }}
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {{
            result.success(true)
            return
        }}
        if (pendingCameraPermissionResult != null) {{
            result.error("camera_permission_active", "A camera permission request is already active.", null)
            return
        }}
        pendingCameraPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA_PERMISSION)
    }}

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {{
        if (requestCode == REQUEST_CAMERA_PERMISSION) {{
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingCameraPermissionResult?.success(granted)
            pendingCameraPermissionResult = null
            return
        }}
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }}

    private fun captureIntruderSelfie(result: MethodChannel.Result) {{
        if (!hasCameraPermission()) {{
            result.success("")
            return
        }}
        IntruderSelfieCapture.capture(this) {{ imageBase64 ->
            result.success(imageBase64 ?: "")
        }}
    }}

    private fun syncLockState(arguments: Map<*, *>?) {{
        val lockedPackages = (arguments?.get("lockedPackages") as? List<*>)
            ?.mapNotNull {{ it as? String }}
            ?.toSet()
            ?: emptySet()
        getSharedPreferences(LOCK_STATE_PREFS, MODE_PRIVATE)
            .edit()
            .clear()
            .putString(KEY_PIN_HASH, arguments?.get("pinHash") as? String ?: "")
            .putString(KEY_PIN_SALT, arguments?.get("pinSalt") as? String ?: "")
            .putInt(KEY_PIN_LENGTH, arguments?.get("pinLength") as? Int ?: 4)
            .putBoolean(KEY_SETUP_COMPLETE, arguments?.get("setupComplete") as? Boolean ?: false)
            .putBoolean(KEY_PROTECTION_ENABLED, arguments?.get("protectionEnabled") as? Boolean ?: true)
            .putInt(KEY_LOCK_DELAY_SECONDS, ((arguments?.get("lockDelaySeconds") as? Int) ?: 45).coerceIn(1, 60))
            .putString(KEY_RELOCK_TIMEOUT_MODE, arguments?.get("relockTimeoutMode") as? String ?: "immediately")
            .putBoolean(KEY_FAKE_CRASH_ENABLED, arguments?.get("fakeCrashEnabled") as? Boolean ?: false)
            .putBoolean(KEY_INTRUDER_LOG_ENABLED, arguments?.get("intruderLogEnabled") as? Boolean ?: true)
            .putBoolean(KEY_INTRUDER_SELFIE_ENABLED, arguments?.get("intruderSelfieEnabled") as? Boolean ?: false)
            .putBoolean(KEY_PRIVATE_NOTIFICATIONS, arguments?.get("privateNotificationEnabled") as? Boolean ?: false)
            .putBoolean(KEY_QUICK_TILE_ENABLED, arguments?.get("quickTileEnabled") as? Boolean ?: true)
            .putString(KEY_UNLOCK_METHOD, arguments?.get("unlockMethod") as? String ?: "fingerprintSwitch")
            .putString(KEY_LOCK_THEME, arguments?.get("lockTheme") as? String ?: "defaultBlue")
            .putString(KEY_TILE_STYLE, arguments?.get("tileStyle") as? String ?: "randomMaterial")
            .putInt(KEY_PIN_FAILURE_THRESHOLD, ((arguments?.get("pinFailureThreshold") as? Int) ?: 5).coerceIn(1, 10))
            .putInt(KEY_PIN_RETRY_TIMEOUT_SECONDS, ((arguments?.get("pinRetryTimeoutSeconds") as? Int) ?: 30).coerceIn(5, 3600))
            .putBoolean(KEY_RECOVERY_CODES_ENABLED, arguments?.get("recoveryCodesEnabled") as? Boolean ?: false)
            .putBoolean(KEY_SECURITY_QUESTION_ENABLED, arguments?.get("securityQuestionEnabled") as? Boolean ?: false)
            .putString(KEY_SECURITY_QUESTION, arguments?.get("securityQuestion") as? String ?: "")
            .putStringSet(KEY_LOCKED_PACKAGES, lockedPackages)
            .apply()
    }}

    private fun readNativeSecurityEvents(): List<Map<String, Any?>> {{
        val raw = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
            .getString(KEY_SECURITY_EVENTS, "[]") ?: "[]"
        val result = mutableListOf<Map<String, Any?>>()
        try {{
            val array = JSONArray(raw)
            for (index in 0 until array.length()) {{
                val item = array.optJSONObject(index) ?: continue
                result.add(
                    mapOf(
                        "time" to item.optString("time"),
                        "appLabel" to item.optString("appLabel", "Unknown app"),
                        "packageName" to item.optString("packageName", ""),
                        "method" to item.optString("method", "PIN Genie"),
                        "message" to item.optString("message", "Authentication event"),
                        "hasSelfie" to item.optBoolean("hasSelfie", false),
                        "selfieBase64" to item.optString("selfieBase64", "")
                    )
                )
            }}
        }} catch (_: Exception) {{
            return emptyList()
        }}
        return result
    }}

    private fun isAccessibilityEnabled(): Boolean {{
        val expected = ComponentName(
            this,
            AppLockAccessibilityService::class.java
        ).flattenToString()
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        for (service in splitter) {{
            if (service.equals(expected, ignoreCase = true)) return true
        }}
        return false
    }}

    @Suppress("DEPRECATION")
    private fun isBiometricAvailable(): Boolean {{
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val manager = getSystemService(BiometricManager::class.java) ?: return false
        return manager.canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
    }}

    private fun biometricProfile(): Map<String, Any> {{
        val available = isBiometricAvailable()
        val style = if (available) biometricStyle() else "none"
        val message = when (style) {{
            "face" -> "Face unlock is available on this device."
            "in_display_fingerprint" -> "In-display fingerprint unlock is available on this device."
            "side_fingerprint" -> "Side-mounted fingerprint unlock is available on this device."
            "rear_fingerprint" -> "Rear fingerprint unlock is available on this device."
            "generic_fingerprint" -> "Fingerprint or face unlock is available on this device."
            else -> "No enrolled fingerprint or face unlock was found on this device."
        }}
        return mapOf(
            "available" to available,
            "style" to style,
            "message" to message
        )
    }}

    private fun biometricStyle(): String {{
        val hasFace = packageManager.hasSystemFeature(PackageManager.FEATURE_FACE)
        val hasFingerprint = packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)
        if (hasFace && !hasFingerprint) return "face"
        if (!hasFingerprint && hasFace) return "face"
        if (!hasFingerprint) return "generic_fingerprint"
        return fingerprintPlacementStyle()
    }}

    private fun fingerprintPlacementStyle(): String {{
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val model = Build.MODEL.lowercase()
        val device = Build.DEVICE.lowercase()
        val fingerprint = Build.FINGERPRINT.lowercase()
        val haystack = "$manufacturer $brand $model $device $fingerprint"

        val inDisplayHints = listOf(
            "pixel 6", "pixel 7", "pixel 8", "pixel 9",
            "galaxy s20", "galaxy s21", "galaxy s22", "galaxy s23", "galaxy s24", "galaxy s25",
            "galaxy note10", "galaxy note20", "galaxy a5", "galaxy a7",
            "oneplus 6t", "oneplus 7", "oneplus 8", "oneplus 9", "oneplus 10", "oneplus 11", "oneplus 12",
            "find x", "reno", "vivo", "iqoo", "realme gt", "mi 9", "mi 10", "mi 11", "mi 12", "mi 13", "mi 14",
            "xiaomi 12", "xiaomi 13", "xiaomi 14", "xiaomi 15", "redmi note 13 pro+"
        )
        if (inDisplayHints.any {{ haystack.contains(it) }}) return "in_display_fingerprint"

        val sideHints = listOf(
            "fold", "flip", "z fold", "z flip", "surface duo",
            "poco", "redmi", "m200", "m201", "m210", "m211", "m212", "m220", "m221", "m230", "m231",
            "xperia", "moto g", "moto edge", "power", "nord n", "galaxy a0", "galaxy a1", "galaxy a2", "galaxy a3", "galaxy m", "galaxy f"
        )
        if (sideHints.any {{ haystack.contains(it) }}) return "side_fingerprint"

        val rearHints = listOf(
            "pixel 2", "pixel 3", "pixel 4a", "pixel 5", "nexus", "oneplus 5", "oneplus 5t", "oneplus 6",
            "mi a1", "mi a2", "redmi note 5", "redmi note 6", "redmi note 7", "redmi note 8"
        )
        if (rearHints.any {{ haystack.contains(it) }}) return "rear_fingerprint"

        return "generic_fingerprint"
    }}

    private fun currentAppDisguise(): String {{
        return getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
            .getString(KEY_APP_DISGUISE, "original") ?: "original"
    }}

    private fun applyAppDisguise(option: String) {{
        val aliases = linkedMapOf(
            "original" to "{package_name}.OriginalLauncherAlias",
            "googleHome" to "{package_name}.GoogleHomeAlias",
            "googleSheets" to "{package_name}.GoogleSheetsAlias",
            "googleWallet" to "{package_name}.GoogleWalletAlias",
            "googleMeet" to "{package_name}.GoogleMeetAlias",
            "googleFamilyLink" to "{package_name}.GoogleFamilyLinkAlias",
            "googleFiWireless" to "{package_name}.GoogleFiWirelessAlias",
        )
        val resolved = if (aliases.containsKey(option)) option else "original"
        val pm = packageManager
        val flags = PackageManager.DONT_KILL_APP or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {{
            PackageManager.SYNCHRONOUS
        }} else {{
            0
        }}

        fun setAliasState(className: String, state: Int) {{
            try {{
                val component = ComponentName(this, className)
                if (pm.getComponentEnabledSetting(component) != state) {{
                    pm.setComponentEnabledSetting(component, state, flags)
                }}
            }} catch (_: Exception) {{
                // The manifest patch installs these aliases. Ignore stale installs
                // that do not have every alias yet; the next APK update will fix it.
            }}
        }}

        // Enable the requested alias first so the launcher never has a moment
        // where every launcher entry is disabled.
        setAliasState(aliases.getValue(resolved), PackageManager.COMPONENT_ENABLED_STATE_ENABLED)
        for ((key, className) in aliases) {{
            if (key != resolved) {{
                setAliasState(className, PackageManager.COMPONENT_ENABLED_STATE_DISABLED)
            }}
        }}

        getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
            .edit()
            .putString(KEY_APP_DISGUISE, resolved)
            .apply()
    }}

    private fun authenticateBiometric(result: MethodChannel.Result) {{
        if (!isBiometricAvailable() || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {{
            result.success(false)
            return
        }}

        var completed = false
        fun complete(value: Boolean) {{
            if (!completed) {{
                completed = true
                result.success(value)
            }}
        }}

        val executor = mainExecutor
        val prompt = BiometricPrompt.Builder(this)
            .setTitle("Unlock Pin Genie")
            .setSubtitle("Use fingerprint or face unlock.")
            .setNegativeButton("Use PIN Genie", executor) {{ _, _ -> complete(false) }}
            .build()

        prompt.authenticate(
            CancellationSignal(),
            executor,
            object : BiometricPrompt.AuthenticationCallback() {{
                override fun onAuthenticationSucceeded(authenticationResult: BiometricPrompt.AuthenticationResult) {{
                    complete(true)
                }}

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {{
                    complete(false)
                }}

                override fun onAuthenticationFailed() {{
                    // Keep the prompt active. Android will request another scan.
                }}
            }}
        )
    }}

    private companion object {{
        const val CHANNEL = "pin_genie/native_app_lock"
        const val REQUEST_CAMERA_PERMISSION = 7401
        const val LOCK_STATE_PREFS = "PinGenieLockState"
        const val NATIVE_PREFS = "NativePinGeniePrefs"
        const val KEY_SECURITY_EVENTS = "security_events"
        const val KEY_PIN_HASH = "pin_hash"
        const val KEY_PIN_SALT = "pin_salt"
        const val KEY_PIN_LENGTH = "pin_length"
        const val KEY_SETUP_COMPLETE = "setup_complete"
        const val KEY_PROTECTION_ENABLED = "protection_enabled"
        const val KEY_LOCK_DELAY_SECONDS = "lock_delay_seconds"
        const val KEY_RELOCK_TIMEOUT_MODE = "relock_timeout_mode"
        const val KEY_FAKE_CRASH_ENABLED = "fake_crash_enabled"
        const val KEY_INTRUDER_LOG_ENABLED = "intruder_log_enabled"
        const val KEY_INTRUDER_SELFIE_ENABLED = "intruder_selfie_enabled"
        const val KEY_PRIVATE_NOTIFICATIONS = "private_notification_enabled"
        const val KEY_QUICK_TILE_ENABLED = "quick_tile_enabled"
        const val KEY_UNLOCK_METHOD = "unlock_method"
        const val KEY_LOCK_THEME = "lock_theme"
        const val KEY_TILE_STYLE = "tile_style"
        const val KEY_PIN_FAILURE_THRESHOLD = "pin_failure_threshold"
        const val KEY_PIN_RETRY_TIMEOUT_SECONDS = "pin_retry_timeout_seconds"
        const val KEY_RECOVERY_CODES_ENABLED = "recovery_codes_enabled"
        const val KEY_SECURITY_QUESTION_ENABLED = "security_question_enabled"
        const val KEY_SECURITY_QUESTION = "security_question"
        const val KEY_LOCKED_PACKAGES = "locked_packages"
        const val KEY_APP_DISGUISE = "app_disguise"
    }}
}}
""",
    )
    java_activity = ANDROID / "app/src/main/java" / Path(*package_name.split(".")) / "MainActivity.java"
    if java_activity.exists():
        java_activity.unlink()

def write_accessibility_service(package_name: str) -> None:
    write(
        kotlin_dir(package_name) / "AppLockAccessibilityService.kt",
        f"""package {package_name}

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.Locale

class AppLockAccessibilityService : AccessibilityService() {{
    private val monitorHandler = Handler(Looper.getMainLooper())
    private var lastForegroundPackage: String? = null
    private val foregroundMonitor = object : Runnable {{
        override fun run() {{
            try {{
                rootInActiveWindow?.packageName?.toString()?.let {{ activePackage ->
                    handleObservedPackage(activePackage)
                }}
            }} catch (_: Exception) {{
                // Root-window polling is a compatibility fallback for older Android/OEM builds.
            }} finally {{
                monitorHandler.postDelayed(this, 700L)
            }}
        }}
    }}

    private val screenReceiver = object : BroadcastReceiver() {{
        override fun onReceive(context: Context?, intent: Intent?) {{
            if (intent?.action == Intent.ACTION_SCREEN_OFF) {{
                clearTemporaryUnlocks()
            }}
        }}
    }}

    override fun onServiceConnected() {{
        super.onServiceConnected()
        clearStaleImmediateUnlocksOnStart()
        monitorHandler.removeCallbacks(foregroundMonitor)
        monitorHandler.post(foregroundMonitor)
        try {{
            registerReceiver(screenReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
        }} catch (_: Exception) {{
            // Some OEMs restrict dynamic screen receivers. The app still works
            // with immediate/custom modes when this receiver is unavailable.
        }}
    }}

    override fun onDestroy() {{
        monitorHandler.removeCallbacks(foregroundMonitor)
        try {{
            unregisterReceiver(screenReceiver)
        }} catch (_: Exception) {{
            // Receiver was not registered or was already removed.
        }}
        super.onDestroy()
    }}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {{
        val packageNameFromEvent = event?.packageName?.toString() ?: return
        val eventType = event.eventType
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) return
        handleObservedPackage(packageNameFromEvent)
    }}

    override fun onInterrupt() = Unit

    private fun handleObservedPackage(packageNameFromEvent: String) {{
        if (packageNameFromEvent == packageName) return

        updateForegroundTracking(packageNameFromEvent)

        if (packageNameFromEvent == "com.android.systemui") return

        // App info, uninstall, and clear-data screens are guarded separately so
        // clearing Pin Genie data or deleting any app cannot bypass the lock.
        if (isSensitiveAppManagementPackage(packageNameFromEvent) && isSensitiveAppManagementScreenVisible()) {{
            if (isTemporarilyUnlocked(SENSITIVE_APP_MANAGEMENT_GUARD_PACKAGE)) {{
                extendTemporaryUnlock(SENSITIVE_APP_MANAGEMENT_GUARD_PACKAGE)
            }} else {{
                startSensitiveAppManagementGuard()
                return
            }}
        }}

        // Installer/update/uninstall screens must not be bypassed completely.
        // They are protected with one PIN check first, then a temporary maintenance
        // window lets Android continue the exact update/delete flow without loops.
        if (isMaintenanceWindowActive() && (isInstallerOrUpdatePackage(packageNameFromEvent) || isSystemControlPackage(packageNameFromEvent))) {{
            extendMaintenanceWindow()
            return
        }}

        if (isInstallerOrUpdatePackage(packageNameFromEvent)) {{
            if (shouldProtectInstallerFlow()) {{
                startInstallerGuard()
            }} else {{
                grantMaintenanceWindow()
            }}
            return
        }}

        if (!shouldLock(packageNameFromEvent)) return
        if (isTemporarilyUnlocked(packageNameFromEvent)) {{
            extendTemporaryUnlock(packageNameFromEvent)
            return
        }}
        if (wasStartedRecently(packageNameFromEvent)) return

        val intent = Intent(this, NativeLockActivity::class.java).apply {{
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            putExtra(NativeLockActivity.EXTRA_TARGET_PACKAGE, packageNameFromEvent)
            putExtra(NativeLockActivity.EXTRA_TARGET_LABEL, appLabel(packageNameFromEvent))
        }}
        startActivity(intent)
    }}

    private fun updateForegroundTracking(currentPackage: String) {{
        val prefs = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
        val previous = lastForegroundPackage ?: prefs.getString(KEY_LAST_FOREGROUND_PACKAGE, null)
        if (previous != null && previous != currentPackage && previous != packageName) {{
            handlePackageLeftForeground(previous)
        }}
        lastForegroundPackage = currentPackage
        prefs.edit().putString(KEY_LAST_FOREGROUND_PACKAGE, currentPackage).apply()
    }}

    private fun handlePackageLeftForeground(previousPackage: String) {{
        if (!isLockedPackage(previousPackage)) return
        val prefs = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
        val editor = prefs.edit()
        when (relockTimeoutMode()) {{
            "immediately" -> editor.remove(unlockedKey(previousPackage))
            "afterScreenOff" -> Unit
            else -> editor.putLong(unlockedKey(previousPackage), System.currentTimeMillis() + lockDelayMs(previousPackage))
        }}
        editor.apply()
    }}

    private fun shouldProtectInstallerFlow(): Boolean {{
        val prefs = getSharedPreferences(LOCK_STATE_PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_SETUP_COMPLETE, false)) return false
        if (!prefs.getBoolean(KEY_PROTECTION_ENABLED, true)) return false
        return true
    }}

    private fun startInstallerGuard() {{
        val now = System.currentTimeMillis()
        val prefs = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
        val key = lastStartedKey(INSTALLER_GUARD_PACKAGE)
        if (now - prefs.getLong(key, 0L) < 1200L) return
        prefs.edit().putLong(key, now).apply()

        val intent = Intent(this, NativeLockActivity::class.java).apply {{
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            putExtra(NativeLockActivity.EXTRA_TARGET_PACKAGE, INSTALLER_GUARD_PACKAGE)
            putExtra(NativeLockActivity.EXTRA_TARGET_LABEL, "App install / uninstall protection")
        }}
        startActivity(intent)
    }}

    private fun startSensitiveAppManagementGuard() {{
        val now = System.currentTimeMillis()
        val prefs = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
        val key = lastStartedKey(SENSITIVE_APP_MANAGEMENT_GUARD_PACKAGE)
        if (now - prefs.getLong(key, 0L) < 1200L) return
        prefs.edit().putLong(key, now).apply()

        val intent = Intent(this, NativeLockActivity::class.java).apply {{
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            putExtra(NativeLockActivity.EXTRA_TARGET_PACKAGE, SENSITIVE_APP_MANAGEMENT_GUARD_PACKAGE)
            putExtra(NativeLockActivity.EXTRA_TARGET_LABEL, "App delete / clear data protection")
        }}
        startActivity(intent)
    }}

    private fun shouldLock(targetPackage: String): Boolean {{
        if (isInstallerOrUpdatePackage(targetPackage)) return false
        val prefs = getSharedPreferences(LOCK_STATE_PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_SETUP_COMPLETE, false)) return false
        if (!prefs.getBoolean(KEY_PROTECTION_ENABLED, true)) return false
        if (isSystemControlPackage(targetPackage)) return true
        val locked = prefs.getStringSet(KEY_LOCKED_PACKAGES, emptySet()) ?: emptySet()
        return locked.contains(targetPackage)
    }}

    private fun isTemporarilyUnlocked(targetPackage: String): Boolean {{
        val prefs = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
        return prefs.getLong(unlockedKey(targetPackage), 0L) > System.currentTimeMillis()
    }}

    private fun extendTemporaryUnlock(targetPackage: String) {{
        getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
            .edit()
            .putLong(unlockedKey(targetPackage), System.currentTimeMillis() + lockDelayMs(targetPackage))
            .apply()
    }}

    private fun isMaintenanceWindowActive(): Boolean {{
        return getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
            .getLong(KEY_MAINTENANCE_UNLOCKED_UNTIL, 0L) > System.currentTimeMillis()
    }}

    private fun grantMaintenanceWindow() {{
        getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
            .edit()
            .putLong(KEY_MAINTENANCE_UNLOCKED_UNTIL, System.currentTimeMillis() + MAINTENANCE_UNLOCK_MS)
            .apply()
    }}

    private fun extendMaintenanceWindow() {{
        getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
            .edit()
            .putLong(KEY_MAINTENANCE_UNLOCKED_UNTIL, System.currentTimeMillis() + MAINTENANCE_UNLOCK_MS)
            .apply()
    }}

    private fun clearTemporaryUnlocks() {{
        val prefs = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
        val editor = prefs.edit()
        for (key in prefs.all.keys) {{
            if (key.startsWith("unlocked_until_")) {{
                editor.remove(key)
            }}
        }}
        editor.apply()
    }}

    private fun relockTimeoutMode(): String {{
        return getSharedPreferences(LOCK_STATE_PREFS, MODE_PRIVATE)
            .getString(KEY_RELOCK_TIMEOUT_MODE, "immediately") ?: "immediately"
    }}

    private fun lockDelayMs(targetPackage: String? = null): Long {{
        return when (relockTimeoutMode()) {{
            "immediately" -> IMMEDIATE_UNLOCK_GRACE_MS
            "afterScreenOff" -> Long.MAX_VALUE / 4
            else -> {{
                val seconds = getSharedPreferences(LOCK_STATE_PREFS, MODE_PRIVATE)
                    .getInt(KEY_LOCK_DELAY_SECONDS, 45)
                    .coerceIn(1, 60)
                seconds * 1000L
            }}
        }}
    }}

    private fun wasStartedRecently(targetPackage: String): Boolean {{
        val now = System.currentTimeMillis()
        val prefs = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
        val key = lastStartedKey(targetPackage)
        val previous = prefs.getLong(key, 0L)
        if (now - previous < 1200L) return true
        prefs.edit().putLong(key, now).apply()
        return false
    }}

    private fun isInstallerOrUpdatePackage(packageName: String): Boolean = packageName in setOf(
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.samsung.android.packageinstaller",
        "com.sec.android.app.packageinstaller",
        "com.miui.packageinstaller",
        "com.coloros.packageinstaller",
        "com.oplus.packageinstaller",
        "com.vivo.packageinstaller",
        "com.huawei.appmarket",
        "com.hihonor.appmarket",
        "com.xiaomi.market",
        "com.heytap.market",
        "com.oppo.market",
        "com.vivo.appstore",
        "com.bbk.appstore",
        "com.sec.android.app.samsungapps",
        "com.google.android.permissioncontroller",
        "com.android.permissioncontroller"
    )

    private fun isSystemControlPackage(packageName: String): Boolean = packageName in setOf(
        "com.android.settings",
        "com.android.settings.intelligence",
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.samsung.android.packageinstaller",
        "com.sec.android.app.packageinstaller",
        "com.google.android.permissioncontroller",
        "com.android.permissioncontroller",
        "com.android.vending",
        "com.miui.securitycenter",
        "com.miui.packageinstaller",
        "com.coloros.safecenter",
        "com.oplus.safecenter",
        "com.vivo.permissionmanager",
        "com.iqoo.secure",
        "com.huawei.systemmanager",
        "com.hihonor.systemmanager",
        "com.sec.android.app.samsungapps",
        "com.huawei.appmarket",
        "com.hihonor.appmarket",
        "com.xiaomi.market",
        "com.heytap.market",
        "com.oppo.market",
        "com.vivo.appstore",
        "com.bbk.appstore",
        "com.transsion.phonemaster",
        "com.infinix.xmanager",
        "com.itel.security"
    )

    private fun isSensitiveAppManagementPackage(packageName: String): Boolean {{
        return isSystemControlPackage(packageName) || packageName in setOf(
            "com.google.android.gms",
            "com.google.android.gsf",
            "com.android.shell"
        )
    }}

    private fun isSensitiveAppManagementScreenVisible(): Boolean {{
        val root = rootInActiveWindow ?: return false
        val tokens = mutableListOf<String>()
        collectNodeText(root, tokens, 0)
        if (tokens.isEmpty()) return false
        val text = tokens.joinToString(" ").lowercase(Locale.US)
        val directSensitiveActions = listOf(
            "uninstall",
            "delete app",
            "remove app",
            "clear data",
            "clear storage",
            "erase data",
            "wipe data",
            "disable app",
            "force stop"
        )
        if (directSensitiveActions.any {{ text.contains(it) }}) return true

        val appInfoHints = listOf(
            "app info",
            "app details",
            "application info",
            "manage apps",
            "storage & cache",
            "storage usage",
            "used storage"
        )
        val destructiveHints = listOf("storage", "data", "cache", "permissions", "default")
        return appInfoHints.any {{ text.contains(it) }} && destructiveHints.any {{ text.contains(it) }}
    }}

    private fun collectNodeText(node: AccessibilityNodeInfo?, out: MutableList<String>, depth: Int) {{
        if (node == null || depth > 8 || out.size > 160) return
        node.text?.toString()?.trim()?.takeIf {{ it.isNotEmpty() }}?.let {{ out.add(it) }}
        node.contentDescription?.toString()?.trim()?.takeIf {{ it.isNotEmpty() }}?.let {{ out.add(it) }}
        node.viewIdResourceName?.trim()?.takeIf {{ it.isNotEmpty() }}?.let {{ out.add(it) }}
        for (index in 0 until node.childCount) {{
            collectNodeText(node.getChild(index), out, depth + 1)
        }}
    }}

    private fun isLockedPackage(targetPackage: String): Boolean {{
        val locked = getSharedPreferences(LOCK_STATE_PREFS, MODE_PRIVATE)
            .getStringSet(KEY_LOCKED_PACKAGES, emptySet()) ?: emptySet()
        return locked.contains(targetPackage)
    }}

    private fun clearStaleImmediateUnlocksOnStart() {{
        if (relockTimeoutMode() != "immediately") return
        val prefs = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
        val editor = prefs.edit()
        for (key in prefs.all.keys) {{
            if (key.startsWith("unlocked_until_")) editor.remove(key)
        }}
        editor.apply()
    }}

    private fun appLabel(targetPackage: String): String = try {{
        val appInfo = packageManager.getApplicationInfo(targetPackage, 0)
        packageManager.getApplicationLabel(appInfo).toString()
    }} catch (_: Exception) {{
        targetPackage
    }}

    private companion object {{
        const val LOCK_STATE_PREFS = "PinGenieLockState"
        const val NATIVE_PREFS = "NativePinGeniePrefs"
        const val KEY_SETUP_COMPLETE = "setup_complete"
        const val KEY_PROTECTION_ENABLED = "protection_enabled"
        const val KEY_LOCK_DELAY_SECONDS = "lock_delay_seconds"
        const val KEY_RELOCK_TIMEOUT_MODE = "relock_timeout_mode"
        const val KEY_LOCKED_PACKAGES = "locked_packages"
        const val KEY_APP_DISGUISE = "app_disguise"

        fun unlockedKey(packageName: String) = "unlocked_until_$packageName"
        fun lastStartedKey(packageName: String) = "last_started_$packageName"
        const val KEY_MAINTENANCE_UNLOCKED_UNTIL = "maintenance_unlocked_until"
        const val KEY_LAST_FOREGROUND_PACKAGE = "last_foreground_package"
        const val INSTALLER_GUARD_PACKAGE = "pin.genie.installer.guard"
        const val SENSITIVE_APP_MANAGEMENT_GUARD_PACKAGE = "pin.genie.app.management.guard"
        const val MAINTENANCE_UNLOCK_MS = 180_000L
        const val IMMEDIATE_UNLOCK_GRACE_MS = 1_200L
    }}
}}
""",
    )


def write_native_lock_activity(package_name: str) -> None:
    write(
        kotlin_dir(package_name) / "NativeLockActivity.kt",
        f"""package {package_name}

import android.app.Activity
import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.security.MessageDigest
import java.security.SecureRandom
import java.text.SimpleDateFormat
import java.util.Collections
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import org.json.JSONArray
import org.json.JSONObject

class NativeLockActivity : Activity() {{
    private data class TileShape(
        val topLeft: Float,
        val topRight: Float,
        val bottomLeft: Float,
        val bottomRight: Float
    )

    private data class GenieBucket(
        val digits: Set<String>,
        val display: String,
        val label: String,
        val arrow: String,
        val tone: Int,
        val shape: TileShape
    )

    private class BiometricVisualView(
        context: Context,
        private val styleName: String,
        private val foreground: Int,
        private val surface: Int,
        private val tertiary: Int
    ) : View(context) {{
        private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {{
            color = surface
            style = Paint.Style.FILL
        }}
        private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {{
            color = foreground
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }}
        private val solidPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {{
            color = foreground
            style = Paint.Style.FILL
        }}

        override fun onDraw(canvas: Canvas) {{
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            if (w <= 0f || h <= 0f) return

            // Match the Flutter Pin Genie biometric animation: a soft rounded
            // icon surface, a phone silhouette for fingerprint placements, and
            // one highlighted sensor area.
            val radius = minOf(w, h) * 0.31f
            fillPaint.color = surface
            canvas.drawRoundRect(RectF(0f, 0f, w, h), radius, radius, fillPaint)

            when (styleName) {{
                "face" -> drawFace(canvas, w, h)
                "in_display_fingerprint" -> drawInDisplayFingerprint(canvas, w, h)
                "side_fingerprint" -> drawSideFingerprint(canvas, w, h)
                "rear_fingerprint" -> drawRearFingerprint(canvas, w, h)
                else -> drawGenericBiometric(canvas, w, h)
            }}
        }}

        private fun alphaColor(color: Int, alpha: Float): Int {{
            return Color.argb((255f * alpha).toInt().coerceIn(0, 255), Color.red(color), Color.green(color), Color.blue(color))
        }}

        private fun drawFace(canvas: Canvas, w: Float, h: Float) {{
            strokePaint.color = alphaColor(foreground, 0.90f)
            strokePaint.strokeWidth = minOf(w, h) * 0.045f
            val face = RectF(w * 0.24f, h * 0.20f, w * 0.76f, h * 0.80f)
            canvas.drawRoundRect(face, w * 0.15f, h * 0.15f, strokePaint)
            solidPaint.color = foreground
            canvas.drawCircle(w * 0.40f, h * 0.44f, w * 0.033f, solidPaint)
            canvas.drawCircle(w * 0.60f, h * 0.44f, w * 0.033f, solidPaint)
            canvas.drawArc(RectF(w * 0.38f, h * 0.52f, w * 0.62f, h * 0.68f), 25f, 130f, false, strokePaint)
        }}

        private fun drawPhone(canvas: Canvas, w: Float, h: Float): RectF {{
            val phone = RectF(w * 0.30f, h * 0.14f, w * 0.70f, h * 0.86f)
            fillPaint.color = alphaColor(0xFFFFFFFF.toInt(), 0.12f)
            canvas.drawRoundRect(phone, w * 0.14f, w * 0.14f, fillPaint)
            strokePaint.color = alphaColor(foreground, 0.22f)
            strokePaint.strokeWidth = minOf(w, h) * 0.018f
            canvas.drawRoundRect(phone, w * 0.14f, w * 0.14f, strokePaint)
            return phone
        }}

        private fun drawInDisplayFingerprint(canvas: Canvas, w: Float, h: Float) {{
            drawPhone(canvas, w, h)
            val pulse = RectF(w * 0.36f, h * 0.56f, w * 0.64f, h * 0.84f)
            fillPaint.color = alphaColor(tertiary, 0.36f)
            canvas.drawOval(pulse, fillPaint)
            strokePaint.color = alphaColor(tertiary, 0.72f)
            strokePaint.strokeWidth = minOf(w, h) * 0.016f
            canvas.drawOval(pulse, strokePaint)
            drawFingerprint(canvas, w / 2f, h * 0.70f, minOf(w, h) * 0.105f, alphaColor(foreground, 0.92f))
        }}

        private fun drawSideFingerprint(canvas: Canvas, w: Float, h: Float) {{
            val phone = drawPhone(canvas, w, h)
            drawFingerprint(canvas, w / 2f, h * 0.52f, minOf(w, h) * 0.145f, alphaColor(foreground, 0.62f))
            val side = RectF(phone.right - w * 0.015f, h * 0.34f, phone.right + w * 0.055f, h * 0.66f)
            fillPaint.color = alphaColor(tertiary, 0.78f)
            canvas.drawRoundRect(side, w * 0.030f, w * 0.030f, fillPaint)
        }}

        private fun drawRearFingerprint(canvas: Canvas, w: Float, h: Float) {{
            drawPhone(canvas, w, h)
            val rear = RectF(w * 0.36f, h * 0.24f, w * 0.64f, h * 0.52f)
            fillPaint.color = alphaColor(tertiary, 0.34f)
            canvas.drawOval(rear, fillPaint)
            strokePaint.color = alphaColor(tertiary, 0.72f)
            strokePaint.strokeWidth = minOf(w, h) * 0.016f
            canvas.drawOval(rear, strokePaint)
            drawFingerprint(canvas, w / 2f, h * 0.38f, minOf(w, h) * 0.095f, alphaColor(foreground, 0.92f))
        }}

        private fun drawGenericBiometric(canvas: Canvas, w: Float, h: Float) {{
            strokePaint.color = alphaColor(foreground, 0.26f)
            strokePaint.strokeWidth = minOf(w, h) * 0.040f
            val face = RectF(w * 0.24f, h * 0.22f, w * 0.76f, h * 0.78f)
            canvas.drawRoundRect(face, w * 0.16f, h * 0.16f, strokePaint)
            drawFingerprint(canvas, w / 2f, h / 2f, minOf(w, h) * 0.24f, foreground)
        }}

        private fun drawFingerprint(canvas: Canvas, cx: Float, cy: Float, r: Float, color: Int) {{
            strokePaint.color = color
            strokePaint.strokeWidth = maxOf(2.2f, r * 0.12f)
            canvas.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), 206f, 128f, false, strokePaint)
            canvas.drawArc(RectF(cx - r * 0.78f, cy - r * 0.78f, cx + r * 0.78f, cy + r * 0.78f), 202f, 136f, false, strokePaint)
            canvas.drawArc(RectF(cx - r * 0.56f, cy - r * 0.56f, cx + r * 0.56f, cy + r * 0.56f), 194f, 152f, false, strokePaint)
            canvas.drawArc(RectF(cx - r * 0.34f, cy - r * 0.34f, cx + r * 0.34f, cy + r * 0.34f), 182f, 176f, false, strokePaint)
            canvas.drawLine(cx, cy - r * 0.18f, cx, cy + r * 0.64f, strokePaint)
            canvas.drawLine(cx - r * 0.27f, cy + r * 0.10f, cx - r * 0.27f, cy + r * 0.46f, strokePaint)
            canvas.drawLine(cx + r * 0.27f, cy + r * 0.10f, cx + r * 0.27f, cy + r * 0.42f, strokePaint)
        }}
    }}

    private class MethodSwitchIconView(
        context: Context,
        private val showPinIcon: Boolean,
        private val foreground: Int
    ) : View(context) {{
        private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {{
            color = foreground
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }}
        private val solidPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {{
            color = foreground
            style = Paint.Style.FILL
        }}

        override fun onDraw(canvas: Canvas) {{
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            if (showPinIcon) drawEnhancedEncryption(canvas, w, h) else drawFingerprint(canvas, w / 2f, h / 2f, minOf(w, h) * 0.40f)
        }}

        private fun drawEnhancedEncryption(canvas: Canvas, w: Float, h: Float) {{
            // Native approximation of Flutter's Icons.enhanced_encryption_rounded.
            strokePaint.strokeWidth = minOf(w, h) * 0.085f
            val shackle = RectF(w * 0.30f, h * 0.10f, w * 0.70f, h * 0.56f)
            canvas.drawArc(shackle, 205f, 130f, false, strokePaint)
            val body = RectF(w * 0.20f, h * 0.42f, w * 0.80f, h * 0.86f)
            canvas.drawRoundRect(body, w * 0.11f, w * 0.11f, solidPaint)

            // Cut a small plus-style detail from the body using the button's
            // dark container color so it reads like the Material icon.
            val cutPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {{
                color = Color.rgb(70, 75, 96)
                style = Paint.Style.STROKE
                strokeCap = Paint.Cap.ROUND
                strokeWidth = minOf(w, h) * 0.070f
            }}
            canvas.drawLine(w * 0.50f, h * 0.55f, w * 0.50f, h * 0.74f, cutPaint)
            canvas.drawLine(w * 0.40f, h * 0.645f, w * 0.60f, h * 0.645f, cutPaint)
        }}

        private fun drawFingerprint(canvas: Canvas, cx: Float, cy: Float, r: Float) {{
            // Native approximation of Flutter's Icons.fingerprint_rounded.
            strokePaint.strokeWidth = maxOf(2.2f, r * 0.12f)
            canvas.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), 206f, 128f, false, strokePaint)
            canvas.drawArc(RectF(cx - r * 0.78f, cy - r * 0.78f, cx + r * 0.78f, cy + r * 0.78f), 202f, 136f, false, strokePaint)
            canvas.drawArc(RectF(cx - r * 0.56f, cy - r * 0.56f, cx + r * 0.56f, cy + r * 0.56f), 194f, 152f, false, strokePaint)
            canvas.drawArc(RectF(cx - r * 0.34f, cy - r * 0.34f, cx + r * 0.34f, cy + r * 0.34f), 182f, 176f, false, strokePaint)
            canvas.drawLine(cx, cy - r * 0.18f, cx, cy + r * 0.66f, strokePaint)
            canvas.drawLine(cx - r * 0.27f, cy + r * 0.10f, cx - r * 0.27f, cy + r * 0.46f, strokePaint)
            canvas.drawLine(cx + r * 0.27f, cy + r * 0.10f, cx + r * 0.27f, cy + r * 0.42f, strokePaint)
        }}
    }}

    private val selectedBuckets = mutableListOf<Set<String>>()
    private val random = SecureRandom()
    private var targetPackage: String? = null
    private var targetLabel: String = "locked app"
    private var pinLength = 4
    private var biometricAvailable = false
    private var biometricStyle = "generic_fingerprint"
    private var biometricMode = false
    private var hiddenBiometricPromptStarted = false
    private var fakeCrashDismissed = false
    private lateinit var dotsRow: LinearLayout
    private lateinit var tilesGrid: GridLayout

    override fun onCreate(savedInstanceState: Bundle?) {{
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        targetPackage = intent.getStringExtra(EXTRA_TARGET_PACKAGE)
        targetLabel = resolveTargetLabel(intent.getStringExtra(EXTRA_TARGET_LABEL), targetPackage)
        pinLength = flutterPrefs().getInt(KEY_PIN_LENGTH, 4).coerceIn(4, 8)
        refreshBiometricProfile()
        buildContent()
    }}

    override fun onNewIntent(intent: Intent?) {{
        super.onNewIntent(intent)
        setIntent(intent)
        targetPackage = intent?.getStringExtra(EXTRA_TARGET_PACKAGE)
        targetLabel = resolveTargetLabel(intent?.getStringExtra(EXTRA_TARGET_LABEL), targetPackage)
        selectedBuckets.clear()
        biometricMode = false
        hiddenBiometricPromptStarted = false
        refreshBiometricProfile()
        buildContent()
    }}

    @Deprecated("Deprecated in Android SDK")
    override fun onBackPressed() {{
        sendUserHome()
    }}


    private fun resolveTargetLabel(providedLabel: String?, packageNameValue: String?): String {{
        val cleaned = providedLabel?.trim().orEmpty()
        if (cleaned.isNotBlank() && cleaned != "locked app" && !cleaned.contains(".")) return cleaned

        if (!packageNameValue.isNullOrBlank() && packageNameValue != INSTALLER_GUARD_PACKAGE) {{
            try {{
                val appInfo = packageManager.getApplicationInfo(packageNameValue, 0)
                val resolved = packageManager.getApplicationLabel(appInfo).toString().trim()
                if (resolved.isNotBlank()) return resolved
            }} catch (_: Exception) {{
                // Fall back below when Android does not expose the label.
            }}
        }}

        return when (packageNameValue) {{
            INSTALLER_GUARD_PACKAGE -> "Package installer"
            SENSITIVE_APP_MANAGEMENT_GUARD_PACKAGE -> "App management protection"
            else -> if (cleaned.isNotBlank()) cleaned else "App"
        }}
    }}

    private fun fakeCrashTitle(): String {{
        val name = resolveTargetLabel(targetLabel, targetPackage)
        val safeName = if (name.equals("locked app", ignoreCase = true)) "App" else name
        return "$safeName isn't responding"
    }}

    private fun unlockMethod(): String = flutterPrefs().getString(KEY_UNLOCK_METHOD, "fingerprintSwitch") ?: "fingerprintSwitch"

    private fun biometricSwitchModeEnabled(): Boolean = biometricAvailable && unlockMethod() == "fingerprintSwitch"

    private fun hiddenBiometricModeEnabled(): Boolean = biometricAvailable && unlockMethod() == "pinWithHiddenFingerprint"

    private fun refreshBiometricProfile() {{
        biometricAvailable = isBiometricAvailable()
        biometricStyle = if (biometricAvailable) biometricProfileStyle() else "none"
    }}

    private fun buildContent() {{
        val frame = FrameLayout(this).apply {{
            setBackgroundColor(themeBg())
        }}
        val root = ScrollView(this).apply {{
            setBackgroundColor(themeBg())
            isFillViewport = true
        }}
        val container = LinearLayout(this).apply {{
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(22), dp(32), dp(22), dp(96))
        }}
        root.addView(
            container,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        frame.addView(
            root,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        val showingFakeCrash = !fakeCrashDismissed && flutterPrefs().getBoolean(KEY_FAKE_CRASH_ENABLED, false)
        if (showingFakeCrash) {{
            buildFakeCrashContent(container)
        }} else if (biometricMode) {{
            buildBiometricContent(container)
        }} else {{
            buildPinContent(container)
        }}

        if (!showingFakeCrash && biometricSwitchModeEnabled()) addUnlockMethodButton(frame)
        setContentView(frame)

        if (!showingFakeCrash && hiddenBiometricModeEnabled() && !hiddenBiometricPromptStarted) {{
            hiddenBiometricPromptStarted = true
            window.decorView.postDelayed({{ authenticateBiometric() }}, 260L)
        }}
    }}


    private fun buildFakeCrashContent(container: LinearLayout) {{
        val nightMode = resources.configuration.uiMode and 0x30
        val dark = nightMode == 0x20
        val overlay = if (dark) Color.rgb(18, 18, 20) else Color.rgb(210, 210, 210)
        val surface = if (dark) Color.rgb(48, 49, 56) else Color.rgb(250, 250, 252)
        val primaryText = if (dark) Color.rgb(245, 245, 248) else Color.rgb(20, 20, 22)
        val secondaryText = if (dark) Color.rgb(225, 225, 230) else Color.rgb(48, 48, 52)
        val accent = if (dark) Color.rgb(204, 216, 255) else Color.rgb(112, 70, 28)

        container.gravity = Gravity.CENTER
        container.setBackgroundColor(overlay)
        container.setPadding(dp(28), dp(32), dp(28), dp(32))

        val card = LinearLayout(this).apply {{
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(22), dp(20), dp(22), dp(20))
            background = roundRect(surface, dp(24))
            elevation = dp(6).toFloat()
        }}
        val cardWidth = minOf(
            resources.displayMetrics.widthPixels - dp(56),
            dp(336)
        ).coerceAtLeast(dp(260))
        container.addView(
            card,
            LinearLayout.LayoutParams(
                cardWidth,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        card.addView(TextView(this).apply {{
            text = fakeCrashTitle()
            setTextColor(primaryText)
            textSize = 19f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.START
            includeFontPadding = false
            setPadding(0, 0, 0, dp(16))
            maxLines = 2
        }})

        fun actionRow(
            iconText: String,
            label: String,
            action: () -> Unit,
            longAction: (() -> Unit)? = null
        ): LinearLayout {{
            return LinearLayout(this).apply {{
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, dp(8), 0, dp(8))
                isClickable = true
                isFocusable = true
                setOnClickListener {{ action() }}
                val revealPinMenu = longAction
                if (revealPinMenu != null) {{
                    setOnLongClickListener {{
                        revealPinMenu.invoke()
                        true
                    }}
                }}
                addView(TextView(this@NativeLockActivity).apply {{
                    text = iconText
                    setTextColor(accent)
                    textSize = 24f
                    gravity = Gravity.CENTER
                    typeface = Typeface.DEFAULT_BOLD
                    includeFontPadding = false
                }}, LinearLayout.LayoutParams(dp(42), dp(40)).apply {{ rightMargin = dp(14) }})
                addView(TextView(this@NativeLockActivity).apply {{
                    text = label
                    setTextColor(secondaryText)
                    textSize = 18f
                    gravity = Gravity.CENTER_VERTICAL
                    includeFontPadding = false
                    maxLines = 1
                }}, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            }}
        }}

        card.addView(actionRow("×", "Close app", {{ sendUserHome() }}))
        card.addView(actionRow(
            "◷",
            "Wait",
            {{
                Toast.makeText(this, "Still waiting…", Toast.LENGTH_SHORT).show()
            }},
            {{
                fakeCrashDismissed = true
                buildContent()
            }}
        ))
    }}

    private fun buildPinContent(container: LinearLayout) {{
        val card = LinearLayout(this).apply {{
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(18), dp(20), dp(18), dp(18))
            background = roundRect(themeCard(), dp(28))
        }}
        container.addView(
            card,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {{ bottomMargin = dp(16) }}
        )

        card.addView(TextView(this).apply {{
            text = "Unlock protection"
            setTextColor(themeTitle())
            textSize = 24f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }})
        card.addView(TextView(this).apply {{
            text = "Tap the tile containing each hidden PIN digit. Tiles reshuffle after every tap."
            setTextColor(themeBody())
            textSize = 14f
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.08f)
            setPadding(0, dp(8), 0, dp(14))
        }})

        dotsRow = LinearLayout(this).apply {{
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }}
        card.addView(dotsRow)
        refreshDots()

        tilesGrid = GridLayout(this).apply {{
            columnCount = 2
            rowCount = 2
            alignmentMode = GridLayout.ALIGN_BOUNDS
            useDefaultMargins = false
        }}
        container.addView(tilesGrid)
        rebuildTiles()
    }}

    private fun buildBiometricContent(container: LinearLayout) {{
        val card = LinearLayout(this).apply {{
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(26), dp(30), dp(26), dp(28))
            background = roundRect(themeCard(), dp(38))
        }}
        container.addView(
            card,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        val icon = BiometricVisualView(this, biometricStyle, themeTitle(), tileColor(1), tileColor(2))
        card.addView(icon, LinearLayout.LayoutParams(dp(122), dp(122)).apply {{ bottomMargin = dp(22) }})
        startBiometricPulse(icon)

        card.addView(TextView(this).apply {{
            text = biometricVisualTitle()
            setTextColor(themeTitle())
            textSize = 27f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }})
        card.addView(TextView(this).apply {{
            text = biometricVisualDescription()
            setTextColor(themeBody())
            textSize = 16f
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.16f)
            setPadding(0, dp(12), 0, dp(22))
        }})

        val scanButton = LinearLayout(this).apply {{
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            background = roundRect(tileColor(2), dp(24))
            setPadding(dp(18), 0, dp(18), 0)
            isClickable = true
            isFocusable = true
            setOnClickListener {{ authenticateBiometric() }}
        }}
        scanButton.addView(
            MethodSwitchIconView(this, false, tileForeground(2)),
            LinearLayout.LayoutParams(dp(22), dp(22)).apply {{ rightMargin = dp(10) }}
        )
        scanButton.addView(TextView(this).apply {{
            text = biometricButtonText()
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setTextColor(tileForeground(2))
            includeFontPadding = false
        }})
        card.addView(scanButton, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(58)
        ))
    }}

    private fun addUnlockMethodButton(frame: FrameLayout) {{
        val button = FrameLayout(this).apply {{
            background = roundRect(tileColor(1), dp(18))
            isClickable = true
            isFocusable = true
            setOnClickListener {{
                animate().scaleX(0.92f).scaleY(0.92f).setDuration(90).withEndAction {{
                    animate().scaleX(1f).scaleY(1f).setDuration(140).start()
                    switchUnlockMethod()
                }}.start()
            }}
        }}
        button.addView(
            MethodSwitchIconView(this, biometricMode, tileForeground(1)),
            FrameLayout.LayoutParams(dp(27), dp(27), Gravity.CENTER)
        )
        frame.addView(
            button,
            FrameLayout.LayoutParams(dp(56), dp(56), Gravity.BOTTOM or Gravity.END).apply {{
                rightMargin = dp(22)
                bottomMargin = dp(34)
            }}
        )
    }}

    private fun switchUnlockMethod() {{
        selectedBuckets.clear()
        val shouldOpenBiometricPrompt = !biometricMode
        biometricMode = shouldOpenBiometricPrompt
        buildContent()
        if (shouldOpenBiometricPrompt) {{
            window.decorView.postDelayed({{ authenticateBiometric() }}, 220L)
        }}
    }}

    private fun refreshDots() {{
        if (!::dotsRow.isInitialized) return
        dotsRow.removeAllViews()
        repeat(pinLength) {{ index ->
            val dot = View(this).apply {{
                background = roundRect(
                    if (index < selectedBuckets.size) themeIconForeground() else themeDotEmpty(),
                    dp(99)
                )
            }}
            dotsRow.addView(
                dot,
                LinearLayout.LayoutParams(dp(12), dp(12)).apply {{
                    leftMargin = dp(5)
                    rightMargin = dp(5)
                }}
            )
        }}
    }}

    private fun rebuildTiles() {{
        tilesGrid.removeAllViews()
        val buckets = buildBuckets()
        val screenWidth = resources.displayMetrics.widthPixels
        val horizontalPagePadding = dp(22) * 2
        val gap = dp(12)
        // Each tile has left/right margins of gap / 2. A two-column row therefore
        // consumes 2 * side + 2 * gap. The previous calculation only removed one
        // gap, so the native lock screen could overflow and visually clip/shift the
        // right column. Keep the grid inside the same centered content width as the
        // Flutter PIN Genie screen.
        val maxTileSide = if (tileStyle() == "compact") dp(132) else dp(158)
        val side = ((screenWidth - horizontalPagePadding - (gap * 2)) / 2).coerceAtMost(maxTileSide)

        buckets.forEach {{ bucket ->
            val tile = LinearLayout(this).apply {{
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dp(12), dp(14), dp(12), dp(14))
                background = expressiveRoundRect(tileColor(bucket.tone), side, bucket.shape)
                isClickable = true
                isFocusable = true
                setOnClickListener {{
                    selectedBuckets.add(bucket.digits)
                    refreshDots()
                    if (selectedBuckets.size >= pinLength) verifyOrReject()
                    rebuildTiles()
                }}
            }}

            val iconWrap = FrameLayout(this)
            iconWrap.addView(TextView(this).apply {{
                text = bucket.arrow
                setTextColor(tileForeground(bucket.tone))
                textSize = 25f
                gravity = Gravity.CENTER
                typeface = Typeface.DEFAULT_BOLD
                includeFontPadding = false
            }}, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            ))
            tile.addView(iconWrap, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(28)
            ))

            val digitsWrap = FrameLayout(this)
            digitsWrap.addView(TextView(this).apply {{
                text = bucket.display
                setTextColor(tileForeground(bucket.tone))
                textSize = 23f
                gravity = Gravity.CENTER
                typeface = Typeface.DEFAULT_BOLD
                includeFontPadding = false
            }}, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            ))
            tile.addView(digitsWrap, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            ))

            val labelWrap = FrameLayout(this)
            labelWrap.addView(TextView(this).apply {{
                text = bucket.label
                setTextColor(withAlpha(tileForeground(bucket.tone), 188))
                textSize = 13f
                gravity = Gravity.CENTER
                typeface = Typeface.DEFAULT_BOLD
                includeFontPadding = false
            }}, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER
            ))
            tile.addView(labelWrap, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(24)
            ))

            tilesGrid.addView(
                tile,
                GridLayout.LayoutParams().apply {{
                    width = side
                    height = side
                    setMargins(gap / 2, gap / 2, gap / 2, gap / 2)
                }}
            )
        }}
    }}

    private fun buildBuckets(): List<GenieBucket> {{
        val digits = ('0'..'9').map {{ it.toString() }}.toMutableList()
        val bucketSizes = mutableListOf(3, 3, 2, 2)
        val directions = mutableListOf(
            "North" to "↑",
            "East" to "→",
            "South" to "↓",
            "West" to "←"
        )
        val tones = mutableListOf(0, 1, 2, 0)
        val shapes = shapesForStyle(tileStyle()).toMutableList()

        Collections.shuffle(digits, random)
        Collections.shuffle(bucketSizes, random)
        Collections.shuffle(directions, random)
        Collections.shuffle(tones, random)
        Collections.shuffle(shapes, random)

        var cursor = 0
        val entries = mutableListOf<GenieBucket>()
        bucketSizes.forEachIndexed {{ index, size ->
            val group = digits.subList(cursor, cursor + size).toMutableList()
            cursor += size
            Collections.shuffle(group, random)
            val direction = directions[index]
            entries.add(
                GenieBucket(
                    digits = group.toSet(),
                    display = group.joinToString("  "),
                    label = direction.first,
                    arrow = direction.second,
                    tone = tones[index],
                    shape = shapes[index]
                )
            )
        }}
        Collections.shuffle(entries, random)
        return entries
    }}

    private fun verifyOrReject() {{
        if (isRetryBlocked()) {{
            selectedBuckets.clear()
            refreshDots()
            Toast.makeText(this, "Try again in ${{retryRemainingSeconds()}}s", Toast.LENGTH_SHORT).show()
            return
        }}
        if (matchesSavedPin(selectedBuckets)) {{
            clearNativePinFailures()
            unlockAndOpenTarget("PIN Genie")
            return
        }}
        recordSecurityEvent("PIN Genie", "Wrong PIN Genie pattern", true)
        registerNativePinFailure()
        selectedBuckets.clear()
        refreshDots()
        if (isRetryBlocked()) {{
            Toast.makeText(this, "Too many attempts. Try again in ${{retryRemainingSeconds()}}s", Toast.LENGTH_SHORT).show()
        }} else {{
            Toast.makeText(this, "Wrong PIN", Toast.LENGTH_SHORT).show()
        }}
    }}

    private fun isRetryBlocked(): Boolean {{
        val until = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE).getLong(KEY_PIN_RETRY_BLOCKED_UNTIL, 0L)
        return until > System.currentTimeMillis()
    }}

    private fun retryRemainingSeconds(): Long {{
        val until = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE).getLong(KEY_PIN_RETRY_BLOCKED_UNTIL, 0L)
        val remaining = ((until - System.currentTimeMillis()) / 1000L).coerceAtLeast(1L)
        return remaining
    }}

    private fun registerNativePinFailure() {{
        val prefs = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
        val threshold = flutterPrefs().getInt(KEY_PIN_FAILURE_THRESHOLD, 5).coerceIn(1, 10)
        val timeoutMs = flutterPrefs().getInt(KEY_PIN_RETRY_TIMEOUT_SECONDS, 30).coerceIn(5, 3600) * 1000L
        val nextCount = prefs.getInt(KEY_FAILED_PIN_ATTEMPT_COUNT, 0) + 1
        val editor = prefs.edit()
        if (nextCount >= threshold) {{
            editor.putInt(KEY_FAILED_PIN_ATTEMPT_COUNT, 0)
            editor.putLong(KEY_PIN_RETRY_BLOCKED_UNTIL, System.currentTimeMillis() + timeoutMs)
        }} else {{
            editor.putInt(KEY_FAILED_PIN_ATTEMPT_COUNT, nextCount)
        }}
        editor.apply()
    }}

    private fun clearNativePinFailures() {{
        getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
            .edit()
            .putInt(KEY_FAILED_PIN_ATTEMPT_COUNT, 0)
            .remove(KEY_PIN_RETRY_BLOCKED_UNTIL)
            .apply()
    }}

    private fun matchesSavedPin(buckets: List<Set<String>>): Boolean {{
        val prefs = flutterPrefs()
        val salt = prefs.getString(KEY_PIN_SALT, null) ?: return false
        val expected = prefs.getString(KEY_PIN_HASH, null) ?: return false
        var matched = false

        fun visit(index: Int, current: String) {{
            if (matched) return
            if (index == buckets.size) {{
                matched = constantTimeEquals(sha256("$salt:$current"), expected)
                return
            }}
            for (digit in buckets[index]) {{
                visit(index + 1, current + digit)
                if (matched) return
            }}
        }}

        visit(0, "")
        return matched
    }}

    private fun unlockAndOpenTarget(method: String = "PIN Genie") {{
        val packageToOpen = targetPackage ?: run {{
            finishAndRemoveTask()
            return
        }}
        recordSecurityEvent(method, "Unlocked successfully", false)
        val now = System.currentTimeMillis()
        val isInstallerGuard = packageToOpen == INSTALLER_GUARD_PACKAGE
        val isSensitiveManagementGuard = packageToOpen == SENSITIVE_APP_MANAGEMENT_GUARD_PACKAGE
        val graceMs = if (isInstallerGuard || isSensitiveManagementGuard || isSystemControlPackage(packageToOpen)) {{
            maxOf(lockDelayMs(), SYSTEM_CONTROL_UNLOCK_MS)
        }} else {{
            lockDelayMs()
        }}
        val unlockEditor = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
            .edit()
            .putLong(unlockedKey(packageToOpen), now + graceMs)
            .putLong(lastStartedKey(packageToOpen), now)
        if (isInstallerGuard || isSensitiveManagementGuard || isSystemControlPackage(packageToOpen)) {{
            unlockEditor.putLong(KEY_MAINTENANCE_UNLOCKED_UNTIL, now + maxOf(graceMs, MAINTENANCE_UNLOCK_MS))
        }}
        unlockEditor.apply()

        // Installer/update/uninstall windows already exist behind this lock Activity.
        // Finishing the lock Activity after a valid PIN lets Android continue that exact
        // delete/update confirmation screen instead of restarting or bypassing it.
        finishAndRemoveTask()
    }}

    private fun isSystemControlPackage(packageName: String): Boolean = packageName in setOf(
        "com.android.settings",
        "com.android.settings.intelligence",
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.samsung.android.packageinstaller",
        "com.google.android.permissioncontroller",
        "com.android.permissioncontroller",
        "com.android.vending",
        "com.miui.securitycenter",
        "com.miui.packageinstaller",
        "com.coloros.safecenter",
        "com.oplus.safecenter",
        "com.vivo.permissionmanager",
        "com.iqoo.secure",
        "com.huawei.systemmanager",
        "com.hihonor.systemmanager",
        "com.sec.android.app.samsungapps",
        "com.huawei.appmarket",
        "com.hihonor.appmarket",
        "com.xiaomi.market",
        "com.heytap.market",
        "com.oppo.market",
        "com.vivo.appstore",
        "com.bbk.appstore",
        "com.transsion.phonemaster",
        "com.infinix.xmanager",
        "com.itel.security"
    )

    private fun sendUserHome() {{
        val home = Intent(Intent.ACTION_MAIN).apply {{
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }}
        startActivity(home)
        finishAndRemoveTask()
    }}

    @Suppress("DEPRECATION")
    private fun isBiometricAvailable(): Boolean {{
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val manager = getSystemService(BiometricManager::class.java) ?: return false
        return manager.canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
    }}

    private fun biometricProfileStyle(): String {{
        val hasFace = packageManager.hasSystemFeature(PackageManager.FEATURE_FACE)
        val hasFingerprint = packageManager.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)
        if (hasFace && !hasFingerprint) return "face"
        if (!hasFingerprint && hasFace) return "face"
        if (!hasFingerprint) return "generic_fingerprint"
        return fingerprintPlacementStyle()
    }}

    private fun fingerprintPlacementStyle(): String {{
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val model = Build.MODEL.lowercase()
        val device = Build.DEVICE.lowercase()
        val fingerprint = Build.FINGERPRINT.lowercase()
        val haystack = "$manufacturer $brand $model $device $fingerprint"

        val inDisplayHints = listOf(
            "pixel 6", "pixel 7", "pixel 8", "pixel 9",
            "galaxy s20", "galaxy s21", "galaxy s22", "galaxy s23", "galaxy s24", "galaxy s25",
            "galaxy note10", "galaxy note20", "galaxy a5", "galaxy a7",
            "oneplus 6t", "oneplus 7", "oneplus 8", "oneplus 9", "oneplus 10", "oneplus 11", "oneplus 12",
            "find x", "reno", "vivo", "iqoo", "realme gt", "mi 9", "mi 10", "mi 11", "mi 12", "mi 13", "mi 14",
            "xiaomi 12", "xiaomi 13", "xiaomi 14", "xiaomi 15", "redmi note 13 pro+"
        )
        if (inDisplayHints.any {{ haystack.contains(it) }}) return "in_display_fingerprint"

        val sideHints = listOf(
            "fold", "flip", "z fold", "z flip", "surface duo",
            "poco", "redmi", "m200", "m201", "m210", "m211", "m212", "m220", "m221", "m230", "m231",
            "xperia", "moto g", "moto edge", "power", "nord n", "galaxy a0", "galaxy a1", "galaxy a2", "galaxy a3", "galaxy m", "galaxy f"
        )
        if (sideHints.any {{ haystack.contains(it) }}) return "side_fingerprint"

        val rearHints = listOf(
            "pixel 2", "pixel 3", "pixel 4a", "pixel 5", "nexus", "oneplus 5", "oneplus 5t", "oneplus 6",
            "mi a1", "mi a2", "redmi note 5", "redmi note 6", "redmi note 7", "redmi note 8"
        )
        if (rearHints.any {{ haystack.contains(it) }}) return "rear_fingerprint"

        return "generic_fingerprint"
    }}

    private fun biometricVisualGlyph(): String = when (biometricStyle) {{
        "face" -> "◌"
        "in_display_fingerprint" -> "◎"
        "side_fingerprint" -> "▌"
        "rear_fingerprint" -> "●"
        else -> "◉"
    }}

    private fun biometricVisualTextSize(): Float = when (biometricStyle) {{
        "side_fingerprint" -> 70f
        else -> 58f
    }}

    private fun biometricVisualTitle(): String = when (biometricStyle) {{
        "face" -> "Face unlock"
        "in_display_fingerprint" -> "In-display fingerprint"
        "side_fingerprint" -> "Side fingerprint"
        "rear_fingerprint" -> "Rear fingerprint"
        else -> "Fingerprint or face unlock"
    }}

    private fun biometricVisualDescription(): String = when (biometricStyle) {{
        "face" -> "PIN Genie is still the default. Use face unlock only on devices with enrolled face authentication."
        "in_display_fingerprint" -> "PIN Genie is still the default. Place your finger on the in-display sensor when Android asks."
        "side_fingerprint" -> "PIN Genie is still the default. Touch the side-mounted sensor when Android asks."
        "rear_fingerprint" -> "PIN Genie is still the default. Touch the rear sensor when Android asks."
        else -> "PIN Genie is still the default. Use biometric unlock only when this device has enrolled fingerprint or face authentication."
    }}

    private fun biometricButtonText(): String = when (biometricStyle) {{
        "face" -> "Scan face"
        "in_display_fingerprint" -> "Scan in-display fingerprint"
        "side_fingerprint" -> "Scan side fingerprint"
        "rear_fingerprint" -> "Scan rear fingerprint"
        else -> "Scan fingerprint or face"
    }}

    private fun startBiometricPulse(view: View) {{
        if (!biometricMode || isFinishing) return
        view.animate()
            .scaleX(1.07f)
            .scaleY(1.07f)
            .alpha(0.86f)
            .setDuration(620)
            .withEndAction {{
                if (!biometricMode || isFinishing) return@withEndAction
                view.animate()
                    .scaleX(1f)
                    .scaleY(1f)
                    .alpha(1f)
                    .setDuration(620)
                    .withEndAction {{ startBiometricPulse(view) }}
                    .start()
            }}
            .start()
    }}

    private fun authenticateBiometric() {{
        if (!biometricAvailable || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {{
            biometricMode = false
            buildContent()
            return
        }}

        val executor = mainExecutor
        val prompt = BiometricPrompt.Builder(this)
            .setTitle("Unlock protection")
            .setSubtitle("${{biometricVisualTitle()}} for $targetLabel.")
            .setNegativeButton("Use PIN Genie", executor) {{ _, _ ->
                biometricMode = false
                buildContent()
            }}
            .build()

        prompt.authenticate(
            CancellationSignal(),
            executor,
            object : BiometricPrompt.AuthenticationCallback() {{
                override fun onAuthenticationSucceeded(authenticationResult: BiometricPrompt.AuthenticationResult) {{
                    unlockAndOpenTarget("Biometric")
                }}

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {{
                    if (!isFinishing) {{
                        biometricMode = false
                        buildContent()
                    }}
                }}

                override fun onAuthenticationFailed() {{
                    recordSecurityEvent("Biometric", "Biometric scan not recognized", true)
                    Toast.makeText(this@NativeLockActivity, "Fingerprint or face not recognized", Toast.LENGTH_SHORT).show()
                }}
            }}
        )
    }}

    private fun recordSecurityEvent(method: String, message: String, failed: Boolean) {{
        val state = flutterPrefs()
        if (failed && !state.getBoolean(KEY_INTRUDER_LOG_ENABLED, true)) return
        val shouldCaptureSelfie = failed &&
            state.getBoolean(KEY_INTRUDER_SELFIE_ENABLED, false) &&
            hasCameraPermission()

        if (shouldCaptureSelfie) {{
            IntruderSelfieCapture.capture(this) {{ imageBase64 ->
                saveSecurityEvent(method, message, failed, imageBase64.orEmpty())
            }}
        }} else {{
            saveSecurityEvent(method, message, failed, null)
        }}
    }}

    private fun saveSecurityEvent(method: String, message: String, failed: Boolean, selfieBase64: String?) {{
        val state = flutterPrefs()
        val prefs = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
        val raw = prefs.getString(KEY_SECURITY_EVENTS, "[]") ?: "[]"
        val array = try {{
            JSONArray(raw)
        }} catch (_: Exception) {{
            JSONArray()
        }}

        val timeFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {{
            timeZone = TimeZone.getTimeZone("UTC")
        }}
        val event = JSONObject().apply {{
            put("time", timeFormat.format(Date()))
            put("appLabel", targetLabel)
            put("packageName", targetPackage ?: "")
            put("method", method)
            put("message", message)
            put("hasSelfie", failed && state.getBoolean(KEY_INTRUDER_SELFIE_ENABLED, false))
            if (!selfieBase64.isNullOrBlank()) put("selfieBase64", selfieBase64)
        }}

        val next = JSONArray()
        next.put(event)
        val limit = minOf(array.length(), 99)
        for (index in 0 until limit) {{
            next.put(array.opt(index))
        }}
        prefs.edit().putString(KEY_SECURITY_EVENTS, next.toString()).apply()
    }}

    private fun hasCameraPermission(): Boolean {{
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    }}

    private fun flutterPrefs() = getSharedPreferences(LOCK_STATE_PREFS, MODE_PRIVATE)

    private fun lockDelayMs(): Long {{
        return when (flutterPrefs().getString(KEY_RELOCK_TIMEOUT_MODE, "immediately") ?: "immediately") {{
            "immediately" -> 1_200L
            "afterScreenOff" -> Long.MAX_VALUE / 4
            else -> {{
                val seconds = flutterPrefs().getInt(KEY_LOCK_DELAY_SECONDS, 45).coerceIn(1, 60)
                seconds * 1000L
            }}
        }}
    }}

    private fun sha256(value: String): String {{
        val bytes = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") {{ "%02x".format(it.toInt() and 0xff) }}
    }}

    private fun constantTimeEquals(a: String, b: String): Boolean {{
        if (a.length != b.length) return false
        var result = 0
        for (index in a.indices) {{
            result = result or (a[index].code xor b[index].code)
        }}
        return result == 0
    }}

    private fun lockTheme(): String = flutterPrefs().getString(KEY_LOCK_THEME, "defaultBlue") ?: "defaultBlue"

    private fun tileStyle(): String = flutterPrefs().getString(KEY_TILE_STYLE, "randomMaterial") ?: "randomMaterial"

    private fun themeBg(): Int = when (lockTheme()) {{
        "amoledBlack" -> Color.rgb(0, 0, 0)
        "purpleNeon" -> Color.rgb(16, 11, 29)
        "minimalLight" -> Color.rgb(248, 247, 252)
        "materialPastel" -> Color.rgb(244, 247, 255)
        "animeSoft" -> Color.rgb(22, 15, 31)
        else -> BG
    }}

    private fun themeCard(): Int = when (lockTheme()) {{
        "amoledBlack" -> Color.rgb(8, 10, 15)
        "purpleNeon" -> Color.rgb(63, 36, 108)
        "minimalLight" -> Color.rgb(236, 233, 255)
        "materialPastel" -> Color.rgb(220, 230, 255)
        "animeSoft" -> Color.rgb(77, 60, 120)
        else -> PRIMARY_CONTAINER
    }}

    private fun themeTitle(): Int = when (lockTheme()) {{
        "minimalLight", "materialPastel" -> Color.rgb(28, 27, 34)
        else -> ON_PRIMARY_CONTAINER
    }}

    private fun themeBody(): Int = when (lockTheme()) {{
        "minimalLight" -> Color.rgb(85, 82, 96)
        "materialPastel" -> Color.rgb(78, 88, 107)
        else -> SUBTLE
    }}

    private fun themeIconForeground(): Int = when (lockTheme()) {{
        "minimalLight", "materialPastel" -> Color.rgb(37, 32, 71)
        else -> ON_PRIMARY_CONTAINER
    }}

    private fun themeDotEmpty(): Int = when (lockTheme()) {{
        "minimalLight" -> Color.rgb(194, 192, 207)
        "materialPastel" -> Color.rgb(172, 183, 200)
        else -> DOT_EMPTY
    }}

    private fun themeTileColors(): List<Int> = when (lockTheme()) {{
        "amoledBlack" -> listOf(Color.rgb(21, 26, 41), Color.rgb(32, 36, 49), Color.rgb(42, 33, 48))
        "purpleNeon" -> listOf(Color.rgb(74, 43, 123), Color.rgb(49, 49, 94), Color.rgb(122, 53, 108))
        "minimalLight" -> listOf(Color.rgb(231, 227, 255), Color.rgb(236, 238, 247), Color.rgb(255, 216, 232))
        "materialPastel" -> listOf(Color.rgb(220, 230, 255), Color.rgb(217, 240, 229), Color.rgb(255, 217, 226))
        "animeSoft" -> listOf(Color.rgb(77, 60, 120), Color.rgb(68, 82, 115), Color.rgb(123, 66, 100))
        else -> listOf(PRIMARY_CONTAINER, SECONDARY_CONTAINER, TERTIARY_CONTAINER)
    }}

    private fun themeTileForegrounds(): List<Int> = when (lockTheme()) {{
        "minimalLight" -> listOf(Color.rgb(37, 32, 71), Color.rgb(46, 51, 70), Color.rgb(76, 35, 57))
        "materialPastel" -> listOf(Color.rgb(23, 32, 51), Color.rgb(22, 52, 38), Color.rgb(75, 37, 50))
        else -> listOf(Color.rgb(240, 241, 255), Color.rgb(231, 233, 248), Color.rgb(255, 216, 234))
    }}

    private fun tileColor(tone: Int): Int = themeTileColors()[tone % themeTileColors().size]

    private fun tileForeground(tone: Int): Int = themeTileForegrounds()[tone % themeTileForegrounds().size]

    private fun shapesForStyle(style: String): List<TileShape> = when (style) {{
        "roundedSquare" -> List(4) {{ TileShape(0.22f, 0.22f, 0.22f, 0.22f) }}
        "circle" -> List(4) {{ TileShape(0.50f, 0.50f, 0.50f, 0.50f) }}
        "compact" -> List(4) {{ TileShape(0.18f, 0.18f, 0.18f, 0.18f) }}
        else -> listOf(
            TileShape(0.30f, 0.44f, 0.42f, 0.30f),
            TileShape(0.46f, 0.28f, 0.32f, 0.44f),
            TileShape(0.34f, 0.42f, 0.28f, 0.48f),
            TileShape(0.42f, 0.34f, 0.46f, 0.28f)
        )
    }}

    private fun withAlpha(color: Int, alpha: Int): Int = Color.argb(
        alpha.coerceIn(0, 255),
        Color.red(color),
        Color.green(color),
        Color.blue(color)
    )

    private fun expressiveRoundRect(color: Int, side: Int, shape: TileShape): GradientDrawable = GradientDrawable().apply {{
        setColor(color)
        setCornerRadii(
            floatArrayOf(
                side * shape.topLeft,
                side * shape.topLeft,
                side * shape.topRight,
                side * shape.topRight,
                side * shape.bottomRight,
                side * shape.bottomRight,
                side * shape.bottomLeft,
                side * shape.bottomLeft
            )
        )
    }}

    private fun roundRect(color: Int, radius: Int): GradientDrawable = GradientDrawable().apply {{
        setColor(color)
        cornerRadius = radius.toFloat()
    }}

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    companion object {{
        const val EXTRA_TARGET_PACKAGE = "target_package"
        const val EXTRA_TARGET_LABEL = "target_label"
        private const val LOCK_STATE_PREFS = "PinGenieLockState"
        private const val NATIVE_PREFS = "NativePinGeniePrefs"
        private const val KEY_PIN_HASH = "pin_hash"
        private const val KEY_PIN_SALT = "pin_salt"
        private const val KEY_PIN_LENGTH = "pin_length"
        private const val KEY_LOCK_DELAY_SECONDS = "lock_delay_seconds"
        private const val KEY_RELOCK_TIMEOUT_MODE = "relock_timeout_mode"
        private const val KEY_FAKE_CRASH_ENABLED = "fake_crash_enabled"
        private const val KEY_INTRUDER_LOG_ENABLED = "intruder_log_enabled"
        private const val KEY_INTRUDER_SELFIE_ENABLED = "intruder_selfie_enabled"
        private const val KEY_SECURITY_EVENTS = "security_events"
        private const val KEY_UNLOCK_METHOD = "unlock_method"
        private const val KEY_LOCK_THEME = "lock_theme"
        private const val KEY_TILE_STYLE = "tile_style"
        private const val KEY_PIN_FAILURE_THRESHOLD = "pin_failure_threshold"
        private const val KEY_PIN_RETRY_TIMEOUT_SECONDS = "pin_retry_timeout_seconds"
        private const val KEY_FAILED_PIN_ATTEMPT_COUNT = "failed_pin_attempt_count"
        private const val KEY_PIN_RETRY_BLOCKED_UNTIL = "pin_retry_blocked_until"
        private val BG = Color.rgb(17, 20, 24)
        private val PRIMARY_CONTAINER = Color.rgb(62, 74, 134)
        private val SECONDARY_CONTAINER = Color.rgb(70, 75, 96)
        private val TERTIARY_CONTAINER = Color.rgb(105, 64, 91)
        private val ON_PRIMARY_CONTAINER = Color.rgb(240, 241, 255)
        private val TEXT = Color.rgb(240, 241, 255)
        private val SUBTLE = Color.rgb(201, 203, 224)
        private val DOT_EMPTY = Color.rgb(102, 106, 126)

        const val SYSTEM_CONTROL_UNLOCK_MS = 120_000L

        fun unlockedKey(packageName: String) = "unlocked_until_$packageName"
        fun lastStartedKey(packageName: String) = "last_started_$packageName"
        const val KEY_MAINTENANCE_UNLOCKED_UNTIL = "maintenance_unlocked_until"
        const val KEY_LAST_FOREGROUND_PACKAGE = "last_foreground_package"
        const val INSTALLER_GUARD_PACKAGE = "pin.genie.installer.guard"
        const val SENSITIVE_APP_MANAGEMENT_GUARD_PACKAGE = "pin.genie.app.management.guard"
        const val MAINTENANCE_UNLOCK_MS = 180_000L
        const val IMMEDIATE_UNLOCK_GRACE_MS = 1_200L
    }}
}}
""",
    )



def write_notification_service(package_name: str) -> None:
    write(
        kotlin_dir(package_name) / "PrivateNotificationService.kt",
        f"""package {package_name}

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class PrivateNotificationService : NotificationListenerService() {{
    override fun onNotificationPosted(sbn: StatusBarNotification?) {{
        val notification = sbn ?: return
        val prefs = getSharedPreferences(LOCK_STATE_PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_PRIVATE_NOTIFICATIONS, false)) return
        val locked = prefs.getStringSet(KEY_LOCKED_PACKAGES, emptySet()) ?: emptySet()
        if (!locked.contains(notification.packageName)) return
        cancelNotification(notification.key)
    }}

    private companion object {{
        const val LOCK_STATE_PREFS = "PinGenieLockState"
        const val KEY_LOCKED_PACKAGES = "locked_packages"
        const val KEY_APP_DISGUISE = "app_disguise"
        const val KEY_PRIVATE_NOTIFICATIONS = "private_notification_enabled"
    }}
}}
""",
    )


def write_quick_tile_service(package_name: str) -> None:
    write(
        kotlin_dir(package_name) / "PinGenieQuickTileService.kt",
        f"""package {package_name}

import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class PinGenieQuickTileService : TileService() {{
    override fun onStartListening() {{
        super.onStartListening()
        updateTile()
    }}

    override fun onClick() {{
        super.onClick()
        val prefs = getSharedPreferences(LOCK_STATE_PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_QUICK_TILE_ENABLED, true)) return
        val next = !prefs.getBoolean(KEY_PROTECTION_ENABLED, true)
        prefs.edit().putBoolean(KEY_PROTECTION_ENABLED, next).apply()
        updateTile()
    }}

    private fun updateTile() {{
        val tile = qsTile ?: return
        val prefs = getSharedPreferences(LOCK_STATE_PREFS, MODE_PRIVATE)
        val enabled = prefs.getBoolean(KEY_PROTECTION_ENABLED, true)
        tile.state = if (enabled) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = if (enabled) "Pin Genie On" else "Pin Genie Off"
        tile.updateTile()
    }}

    private companion object {{
        const val LOCK_STATE_PREFS = "PinGenieLockState"
        const val KEY_PROTECTION_ENABLED = "protection_enabled"
        const val KEY_QUICK_TILE_ENABLED = "quick_tile_enabled"
    }}
}}
""",
    )

def main() -> None:
    if not MANIFEST.exists():
        raise SystemExit("android project not found. Run flutter create --platforms=android first.")
    package_name = detect_package()
    patch_gradle_identity()
    patch_release_signing()
    patch_disguise_launcher_icons()
    patch_manifest()
    patch_strings()
    patch_styles()
    write_accessibility_config()
    write_intruder_selfie_capture(package_name)
    write_main_activity(package_name)
    write_accessibility_service(package_name)
    write_notification_service(package_name)
    write_quick_tile_service(package_name)
    write_native_lock_activity(package_name)
    print(f"Patched native Android app lock files for package {package_name}")


if __name__ == "__main__":
    main()
