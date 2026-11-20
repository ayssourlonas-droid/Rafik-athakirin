#!/usr/bin/env python3
"""يعدّل مجلد android المُولَّد أثناء البناء (لا يُرفع إلى المستودع).

يضيف: الصلاحيات (إشعارات، منبّهات دقيقة، موقع، إقلاع)، مستقبلات الإشعارات المجدولة،
و"core library desugaring" الذي تشترطه حزمة الإشعارات، ويرفع minSdk إلى 24.
يطبع كل تعديل، ويفشل بوضوح إن لم يجد النمط المتوقع بدل أن يُبنى تطبيق ناقص بصمت."""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path("android")
errors = []

# ───────────── AndroidManifest.xml ─────────────
mf = ROOT / "app/src/main/AndroidManifest.xml"
s = mf.read_text(encoding="utf-8")
perms = [
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.VIBRATE",
    "android.permission.WAKE_LOCK",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
]
lines = "".join(f'    <uses-permission android:name="{p}" />\n' for p in perms if p not in s)
if "<application" not in s:
    errors.append("AndroidManifest: لم أجد وسم <application>")
else:
    s = s.replace("<application", lines + "    <application", 1) if lines else s
    receivers = ""
    if "ScheduledNotificationReceiver" not in s:
        receivers += '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
    if "ScheduledNotificationBootReceiver" not in s:
        receivers += (
            '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
            "            <intent-filter>\n"
            '                <action android:name="android.intent.action.BOOT_COMPLETED" />\n'
            '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />\n'
            '                <action android:name="android.intent.action.QUICKBOOT_POWERON" />\n'
            '                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />\n'
            "            </intent-filter>\n"
            "        </receiver>\n"
        )
    if receivers:
        if "</application>" not in s:
            errors.append("AndroidManifest: لم أجد </application>")
        else:
            s = s.replace("</application>", receivers + "    </application>", 1)
    mf.write_text(s, encoding="utf-8")
    print("✓ AndroidManifest: صلاحيات + مستقبلات الإشعارات")

# ───────────── build.gradle(.kts) ─────────────
kts = ROOT / "app/build.gradle.kts"
groovy = ROOT / "app/build.gradle"
if kts.exists():
    g = kts.read_text(encoding="utf-8")
    if "isCoreLibraryDesugaringEnabled" not in g:
        g, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
        if n == 0: errors.append("build.gradle.kts: لم أجد compileOptions")
    if "desugar_jdk_libs" not in g:
        dep = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")'
        if re.search(r"^dependencies\s*\{", g, re.M):
            g = re.sub(r"^(dependencies\s*\{)", r"\1\n    " + dep, g, count=1, flags=re.M)
        else:
            g += "\ndependencies {\n    " + dep + "\n}\n"
    g, n = re.subn(r"minSdk\s*=\s*[^\n]+", "minSdk = 24", g, count=1)
    if n == 0: errors.append("build.gradle.kts: لم أجد minSdk")
    kts.write_text(g, encoding="utf-8")
    print("✓ build.gradle.kts: desugaring + minSdk 24")
elif groovy.exists():
    g = groovy.read_text(encoding="utf-8")
    if "coreLibraryDesugaringEnabled" not in g:
        g, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        coreLibraryDesugaringEnabled true", g, count=1)
        if n == 0: errors.append("build.gradle: لم أجد compileOptions")
    if "desugar_jdk_libs" not in g:
        dep = "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'"
        if re.search(r"^dependencies\s*\{", g, re.M):
            g = re.sub(r"^(dependencies\s*\{)", r"\1\n    " + dep, g, count=1, flags=re.M)
        else:
            g += "\ndependencies {\n    " + dep + "\n}\n"
    g, n = re.subn(r"minSdkVersion\s+[^\n]+", "minSdkVersion 24", g, count=1)
    if n == 0: errors.append("build.gradle: لم أجد minSdkVersion")
    groovy.write_text(g, encoding="utf-8")
    print("✓ build.gradle: desugaring + minSdk 24")
else:
    errors.append("لم أجد app/build.gradle(.kts)")

# ───────────── معاينة الأذان من res/raw (نسخة واحدة من ملفات الصوت) ─────────────
KOTLIN = """package __PKG__

import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var player: MediaPlayer? = null

    private fun stopPlayer() {
        player?.let {
            try { it.stop() } catch (_: Exception) {}
            it.release()
        }
        player = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rafiq/adhan_preview")
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val name = call.argument<String>("name")
                    val resId = if (name == null) 0 else resources.getIdentifier(name, "raw", packageName)
                    if (resId == 0) {
                        result.error("missing", "raw resource not found: " + name, null)
                    } else {
                        stopPlayer()
                        val mp = MediaPlayer.create(this, resId)
                        if (mp == null) {
                            result.error("create", "MediaPlayer.create failed", null)
                        } else {
                            mp.setOnCompletionListener {
                                stopPlayer()
                                ch.invokeMethod("completed", null)
                            }
                            player = mp
                            mp.start()
                            result.success(null)
                        }
                    }
                }
                "stop" -> {
                    stopPlayer()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        stopPlayer()
        super.onDestroy()
    }
}
"""
acts = list((ROOT / "app/src/main").rglob("MainActivity.kt"))
if not acts:
    errors.append("لم أجد MainActivity.kt")
else:
    src = acts[0].read_text(encoding="utf-8")
    pm = re.search(r"^package\s+([\w.]+)", src, re.M)
    if not pm:
        errors.append("MainActivity.kt: لم أجد سطر package")
    else:
        acts[0].write_text(KOTLIN.replace("__PKG__", pm.group(1)), encoding="utf-8")
        print("✓ MainActivity: قناة معاينة الأذان من res/raw")

# يمنع مقلّص الموارد من حذف أصوات الأذان (تُستدعى بالاسم النصي لا بمرجع مباشر)
raw = ROOT / "app/src/main/res/raw"
raw.mkdir(parents=True, exist_ok=True)
(raw / "keep.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@raw/adhan_*" />\n',
    encoding="utf-8",
)
print("✓ res/raw/keep.xml")

if errors:
    print("✗ فشل التعديل:", *errors, sep="\n  - ")
    sys.exit(1)
