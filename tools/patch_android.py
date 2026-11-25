#!/usr/bin/env python3
"""يعدّل مجلد android المُولَّد أثناء البناء (لا يُرفع إلى المستودع).

يضيف: الصلاحيات (إشعارات، منبّهات دقيقة، موقع، إقلاع)، مستقبلات الإشعارات المجدولة،
و"core library desugaring" الذي تشترطه حزمة الإشعارات، ويرفع minSdk إلى 24.
يطبع كل تعديل، ويفشل بوضوح إن لم يجد النمط المتوقع بدل أن يُبنى تطبيق ناقص بصمت."""
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path("android")
errors = []

# ───────────── AndroidManifest.xml ─────────────
mf = ROOT / "app/src/main/AndroidManifest.xml"
s = mf.read_text(encoding="utf-8")
perms = [
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.USE_FULL_SCREEN_INTENT",  # شاشة الأذان فوق القفل
    "android.permission.POST_PROMOTED_NOTIFICATIONS",  # أندرويد 16: التحديثات الحية (شريحة شريط الحالة / Now Bar)
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
    if "LiveCountdownReceiver" not in s:
        receivers += (
            '        <receiver android:exported="false" android:name=".LiveCountdownReceiver">\n'
            "            <intent-filter>\n"
            '                <action android:name="android.intent.action.BOOT_COMPLETED" />\n'
            '                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />\n'
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

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.Surface
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var player: MediaPlayer? = null
    private var pool: SoundPool? = null
    private val sfxIds = HashMap<String, Int>()
    private val sfxReady: MutableSet<Int> = java.util.concurrent.ConcurrentHashMap.newKeySet()

    private fun ensurePool(): SoundPool {
        pool?.let { return it }
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val sp = SoundPool.Builder().setMaxStreams(4).setAudioAttributes(attrs).build()
        sp.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) sfxReady.add(sampleId)
        }
        pool = sp
        return sp
    }

    private var lockMode = false

    // بوصلة القبلة: اتجاه أعلى الهاتف من الشمال الحقيقي (مع تصحيح الانحراف المغناطيسي للموقع)
    private var compassListener: SensorEventListener? = null
    private var compassAccuracy = 3

    private fun startCompass(sink: EventChannel.EventSink, lat: Double, lng: Double) {
        stopCompass()
        val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (sensor == null) {
            sink.error("no_sensor", "لا يوجد حسّاس اتجاه في هذا الجهاز", null)
            return
        }
        val declination = try {
            GeomagneticField(lat.toFloat(), lng.toFloat(), 0f, System.currentTimeMillis()).declination
        } catch (e: Throwable) {
            0f
        }
        val rm = FloatArray(9)
        val adj = FloatArray(9)
        val ori = FloatArray(3)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                SensorManager.getRotationMatrixFromVector(rm, event.values)
                var ax = SensorManager.AXIS_X
                var ay = SensorManager.AXIS_Y
                val rotation = windowManager.defaultDisplay.rotation
                if (rotation == Surface.ROTATION_90) {
                    ax = SensorManager.AXIS_Y
                    ay = SensorManager.AXIS_MINUS_X
                } else if (rotation == Surface.ROTATION_180) {
                    ax = SensorManager.AXIS_MINUS_X
                    ay = SensorManager.AXIS_MINUS_Y
                } else if (rotation == Surface.ROTATION_270) {
                    ax = SensorManager.AXIS_MINUS_Y
                    ay = SensorManager.AXIS_X
                }
                SensorManager.remapCoordinateSystem(rm, ax, ay, adj)
                SensorManager.getOrientation(adj, ori)
                var az = Math.toDegrees(ori[0].toDouble()) + declination
                az = (az % 360.0 + 360.0) % 360.0
                sink.success(mapOf("h" to az, "a" to compassAccuracy))
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
                compassAccuracy = accuracy
            }
        }
        compassListener = listener
        sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)
    }

    private fun stopCompass() {
        val l = compassListener ?: return
        val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sm.unregisterListener(l)
        compassListener = null
    }

    // عند فتح التطبيق من إشعار الأذان (بملء الشاشة أو بالضغط) يُسمح له بالظهور فوق القفل وإضاءة الشاشة،
    // وتُرفع هذه الأعلام فور إغلاق شاشة الأذان أو مغادرتها كي لا يبقى التطبيق ظاهرًا فوق القفل.
    private fun applyLockFlags(i: Intent?) {
        val payload = i?.getStringExtra("payload") ?: return
        if (!payload.startsWith("adhan|")) return
        lockMode = true
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun clearLockFlags() {
        if (!lockMode) return
        lockMode = false
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(false)
            setTurnScreenOn(false)
        } else {
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        applyLockFlags(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        applyLockFlags(intent)
        super.onNewIntent(intent)
    }

    override fun onStop() {
        clearLockFlags()
        super.onStop()
    }

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

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "rafiq/compass").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events == null) return
                    val m = arguments as? Map<*, *>
                    val lat = (m?.get("lat") as? Number)?.toDouble() ?: 0.0
                    val lng = (m?.get("lng") as? Number)?.toDouble() ?: 0.0
                    startCompass(events, lat, lng)
                }

                override fun onCancel(arguments: Any?) {
                    stopCompass()
                }
            }
        )

        // شاشة الأذان فوق القفل
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rafiq/lock").setMethodCallHandler { call, result ->
            when (call.method) {
                "release" -> {
                    clearLockFlags()
                    result.success(null)
                }
                "finish" -> {
                    clearLockFlags()
                    moveTaskToBack(true)
                    result.success(null)
                }
                "unlock" -> {
                    val km = getSystemService(KeyguardManager::class.java)
                    if (Build.VERSION.SDK_INT >= 26 && km != null && km.isKeyguardLocked) {
                        km.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                            override fun onDismissSucceeded() {
                                clearLockFlags()
                            }
                        })
                    } else {
                        clearLockFlags()
                    }
                    result.success(null)
                }
                "fsiAllowed" -> {
                    var ok = true
                    if (Build.VERSION.SDK_INT >= 34) {
                        try {
                            val nm = getSystemService(NotificationManager::class.java)
                            ok = NotificationManager::class.java.getMethod("canUseFullScreenIntent").invoke(nm) as Boolean
                        } catch (e: Throwable) {
                            ok = true
                        }
                    }
                    result.success(ok)
                }
                "fsiSettings" -> {
                    var opened = false
                    if (Build.VERSION.SDK_INT >= 34) {
                        try {
                            startActivity(
                                Intent("android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT", Uri.parse("package:" + packageName))
                            )
                            opened = true
                        } catch (e: Throwable) {
                            opened = false
                        }
                    }
                    result.success(opened)
                }
                else -> result.notImplemented()
            }
        }

        // مؤثرات المسبحة (نقرة الحبّة وجرس الاكتمال): SoundPool لزمن استجابة قصير
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rafiq/sfx").setMethodCallHandler { call, result ->
            when (call.method) {
                "load" -> {
                    val names = call.argument<List<String>>("names") ?: emptyList()
                    val sp = ensurePool()
                    for (n in names) {
                        if (sfxIds.containsKey(n)) continue
                        val resId = resources.getIdentifier(n, "raw", packageName)
                        if (resId != 0) sfxIds[n] = sp.load(this, resId, 1)
                    }
                    result.success(null)
                }
                "play" -> {
                    val name = call.argument<String>("name") ?: ""
                    val id = sfxIds[name]
                    if (id != null && sfxReady.contains(id)) {
                        pool?.play(id, 1f, 1f, 1, 0, 1f)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // العدّ التنازلي كتحديث حي (أندرويد 16 فما فوق)؛ ما دونه يبقى الإشعار المضغوط من فلتر
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rafiq/live").setMethodCallHandler { call, result ->
            when (call.method) {
                "supported" -> result.success(LiveCountdown.supported(applicationContext))
                "schedule" -> {
                    val items = call.argument<List<Map<String, Any>>>("items") ?: emptyList()
                    LiveCountdown.schedule(applicationContext, items)
                    result.success(null)
                }
                "cancel" -> {
                    LiveCountdown.cancelAll(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        stopPlayer()
        stopCompass()
        pool?.release()
        pool = null
        super.onDestroy()
    }
}
"""
LIVE_KOTLIN = """package __PKG__

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

// عدّ تنازلي للصلاة القادمة كإشعار "تحديث حي" على أندرويد 16 فما فوق.
// دوال API 36 تُستدعى بالانعكاس كي لا يتوقف البناء إن كان compileSdk أقدم.
object LiveCountdown {
    const val ACTION = "__PKG__.LIVE_COUNTDOWN"
    private const val CHANNEL = "live_countdown"
    private const val NOTIF_ID = 777001
    private const val REQ_BASE = 5000
    private const val PREFS = "live_countdown"

    fun supported(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < 36) return false
        return try {
            val nm = ctx.getSystemService(NotificationManager::class.java)
            NotificationManager::class.java.getMethod("canPostPromotedNotifications").invoke(nm) as Boolean
        } catch (e: Throwable) {
            false
        }
    }

    private fun pending(ctx: Context, index: Int, target: Long, name: String, existingOnly: Boolean): PendingIntent? {
        val intent = Intent(ctx, LiveCountdownReceiver::class.java)
            .setAction(ACTION)
            .putExtra("target", target)
            .putExtra("name", name)
        val mode = if (existingOnly) PendingIntent.FLAG_NO_CREATE else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getBroadcast(ctx, REQ_BASE + index, intent, mode or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun cancelAlarms(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        val count = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt("count", 0)
        for (i in 0 until count) {
            val pi = pending(ctx, i, 0L, "", true)
            if (pi != null) {
                am.cancel(pi)
                pi.cancel()
            }
        }
    }

    fun cancelAll(ctx: Context) {
        cancelAlarms(ctx)
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        ctx.getSystemService(NotificationManager::class.java).cancel(NOTIF_ID)
    }

    // items: [{at, target, name}] — at = متى يظهر الإشعار (0 = الآن)، target = لحظة الصلاة القادمة
    fun schedule(ctx: Context, items: List<Map<String, Any>>) {
        cancelAlarms(ctx)
        val arr = JSONArray()
        for (m in items) {
            arr.put(
                JSONObject()
                    .put("at", (m["at"] as Number).toLong())
                    .put("target", (m["target"] as Number).toLong())
                    .put("name", m["name"] as String)
            )
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("items", arr.toString())
            .putInt("count", arr.length())
            .apply()
        arm(ctx, arr)
    }

    // بعد إعادة تشغيل الهاتف أو تحديث التطبيق تضيع المنبّهات، فنعيد ضبطها مما حُفظ
    fun rearm(ctx: Context) {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("items", null) ?: return
        arm(ctx, JSONArray(raw))
    }

    private fun arm(ctx: Context, arr: JSONArray) {
        val now = System.currentTimeMillis()
        val am = ctx.getSystemService(AlarmManager::class.java)
        var current: JSONObject? = null
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val at = o.getLong("at")
            val target = o.getLong("target")
            if (target <= now) continue
            if (at <= now) {
                current = o
                continue
            }
            val pi = pending(ctx, i, target, o.getString("name"), false) ?: continue
            try {
                if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                } else {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                }
            } catch (e: SecurityException) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            }
        }
        if (current != null) {
            post(ctx, current.getLong("target"), current.getString("name"))
        } else {
            ctx.getSystemService(NotificationManager::class.java).cancel(NOTIF_ID)
        }
    }

    fun post(ctx: Context, target: Long, name: String) {
        if (Build.VERSION.SDK_INT < 26) return
        val now = System.currentTimeMillis()
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (target <= now) {
            nm.cancel(NOTIF_ID)
            return
        }
        val channel = NotificationChannel(CHANNEL, "الوقت المتبقي للصلاة القادمة", NotificationManager.IMPORTANCE_LOW)
        channel.setSound(null, null)
        channel.enableVibration(false)
        nm.createNotificationChannel(channel)
        val icon = ctx.resources.getIdentifier("ic_stat_adhan", "drawable", ctx.packageName)
        val builder = Notification.Builder(ctx, CHANNEL)
            .setSmallIcon(if (icon != 0) icon else android.R.drawable.ic_dialog_info)
            .setContentTitle("الصلاة القادمة: " + name)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setWhen(target)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setTimeoutAfter(target - now + 60000L)
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        if (launch != null) {
            builder.setContentIntent(
                PendingIntent.getActivity(ctx, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            )
        }
        try {
            Notification.Builder::class.java
                .getMethod("setRequestPromotedOngoing", Boolean::class.javaPrimitiveType)
                .invoke(builder, true)
        } catch (e: Throwable) {
            // أندرويد أقدم أو الدالة غير متاحة: يبقى إشعارًا مضغوطًا عاديًا
        }
        nm.notify(NOTIF_ID, builder.build())
    }
}

class LiveCountdownReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == LiveCountdown.ACTION) {
            LiveCountdown.post(context, intent.getLongExtra("target", 0L), intent.getStringExtra("name") ?: "")
        } else {
            LiveCountdown.rearm(context)
        }
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
        (acts[0].parent / "LiveCountdown.kt").write_text(LIVE_KOTLIN.replace("__PKG__", pm.group(1)), encoding="utf-8")
        print("✓ MainActivity: قناة معاينة الأذان من res/raw + LiveCountdown.kt (تحديث حي)")

# يمنع مقلّص الموارد من حذف أصوات الأذان (تُستدعى بالاسم النصي لا بمرجع مباشر)
raw = ROOT / "app/src/main/res/raw"
raw.mkdir(parents=True, exist_ok=True)
(raw / "keep.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@raw/adhan_*,@raw/tasbih_*" />\n',
    encoding="utf-8",
)
print("✓ res/raw/keep.xml")

# ───────────── الأيقونات والأصوات: من المستودع إلى res ─────────────
# tools/icons/<مجلد الهدف>__<الاسم>  ←  res/<مجلد الهدف>/<الاسم>
# assets/audio/adhan_*.mp3 و tasbih_*.wav  ←  res/raw  (أسماؤها حروف صغيرة وأرقام وشرطة سفلية فقط)
REPO = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / "app/src/main/res"
icons = sorted((REPO / "tools/icons").glob("*__*"))
for f in icons:
    folder, name = f.name.split("__", 1)
    (RES / folder).mkdir(parents=True, exist_ok=True)
    shutil.copy2(f, RES / folder / name)
if not icons:
    errors.append("لا أيقونات في tools/icons (شغّل tools/make_icons.py)")
else:
    print(f"✓ أيقونات: {len(icons)} ملفًا")
(RES / "raw").mkdir(parents=True, exist_ok=True)
audio = []
for pat in ("adhan_*.mp3", "tasbih_*.wav"):
    audio += sorted((REPO / "assets/audio").glob(pat))
for f in audio:
    shutil.copy2(f, RES / "raw" / f.name)
if not audio:
    errors.append("لا ملفات صوت في assets/audio")
else:
    print(f"✓ أصوات في res/raw: {len(audio)} ملفًا")

if errors:
    print("✗ فشل التعديل:", *errors, sep="\n  - ")
    sys.exit(1)
