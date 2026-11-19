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

if errors:
    print("✗ فشل التعديل:", *errors, sep="\n  - ")
    sys.exit(1)
