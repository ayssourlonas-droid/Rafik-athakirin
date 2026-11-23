// الإشعارات: أذان كل صلاة (بصوت من res/raw) + شريط هادئ بالوقت المتبقي للصلاة القادمة.
// - الأذان: قناة لكل (صوت × وضع) لأن صوت قناة أندرويد لا يتغير بعد إنشائها.
// - العدّاد: إشعار ثابت صامت يعدّه النظام تنازليًا بلا تشغيل التطبيق، ويختفي وحده
//   عند حلول الصلاة (timeoutAfter) ويحلّ محله إشعار الصلاة التي بعدها.
// - الجدولة بنافذة متحركة لعشرة أيام تُجدَّد كلما فُتح التطبيق أو تغيّرت الإعدادات.
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'data_format.dart';
import 'data_repo.dart';
import 'data_settings.dart';
import 'prayer_calc.dart';
import 'service_timezone.dart';

class ScheduleReport {
  const ScheduleReport(this.scheduled, this.exact, this.error);

  final int scheduled;
  final bool exact;
  final String? error;

  String get summary {
    if (error != null) return error!;
    final kind = exact ? 'بتوقيت دقيق' : 'بتوقيت تقريبي (فعّل المنبّهات الدقيقة)';
    return 'جُدولت $scheduled إشعارًا $kind';
  }
}

class _Event {
  _Event(this.time, this.prayer);
  final DateTime time;
  final Prayer prayer;
}

/// تنبيه أذان وصل من إشعار (لفتح شاشة الأذان). الصيغة: adhan|<رقم الإشعار>|<اسم الصلاة>|<وقتها بالميلي ثانية>
class AdhanAlert {
  const AdhanAlert(this.id, this.prayerName, this.time);
  final int id;
  final String prayerName;
  final DateTime time;

  static const String testName = 'تجربة';
  bool get isTest => prayerName == testName;

  static String payloadOf(int id, String prayerName, DateTime time) =>
      'adhan|$id|$prayerName|${time.millisecondsSinceEpoch}';

  static AdhanAlert? parse(String? payload) {
    if (payload == null) return null;
    final p = payload.split('|');
    if (p.length < 4 || p[0] != 'adhan') return null;
    final id = int.tryParse(p[1]);
    final ms = int.tryParse(p[3]);
    if (id == null || ms == null) return null;
    return AdhanAlert(id, p[2], DateTime.fromMillisecondsSinceEpoch(ms));
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService i = NotificationService._();

  static const int _days = 10;

  /// يُضبط عند الضغط على إشعار أذان أو عند فتحه بملء الشاشة؛ يستمع إليه app_root ليفتح AdhanScreen.
  static final ValueNotifier<AdhanAlert?> adhanAlert = ValueNotifier<AdhanAlert?>(null);

  /// يزيد عند الضغط على تذكير المسبحة؛ يستمع إليه app_root ليفتح شاشة المسبحة.
  static final ValueNotifier<int> tasbihTap = ValueNotifier<int>(0);
  static const int _nowCountdownId = 1;
  static const MethodChannel _live = MethodChannel('rafiq/live'); // تحديث حي على أندرويد 16+
  static const int _testId = 9;
  static const int followDelayMin = 5; // بعد كم دقيقة من أذان مدينة القريب يصل الإشعار
  static const int _followBaseId = 3000; // + (رقم المدينة × 100) + ترتيب الإشعار
  static const List<Prayer> _prayers = [
    Prayer.fajr,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ];

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  ScheduleReport? lastReport;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready) return;
    try {
      TzService.ensureInit();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_adhan'),
        ),
        onDidReceiveNotificationResponse: (r) => _handlePayload(r.payload),
      );
      await _createChannels();
      _ready = true;
      // التطبيق فُتح من إشعار (أو بملء الشاشة) وهو مغلق تمامًا
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _handlePayload(launch!.notificationResponse?.payload);
      }
    } catch (_) {
      _ready = false;
    }
  }

  // اسم ملف الصوت في res/raw (يبقى كما هو)
  static String _soundName(String voice, AdhanMode mode) => 'adhan_${voice}_${mode.name}';
  // رقم القناة: صوت الأذان ببث المنبّه. القنوات القديمة (ببث الإشعارات) تُحذف عند التهيئة.
  static String _channelId(String voice, AdhanMode mode) => 'alarm_${_soundName(voice, mode)}';

  void _handlePayload(String? payload) {
    if (payload == 'tasbih') {
      tasbihTap.value++;
      return;
    }
    final a = AdhanAlert.parse(payload);
    if (a == null) return;
    // إشعار قديم ضغطتَ عليه بعد ساعات: لا نفتح شاشة الأذان
    final age = DateTime.now().difference(a.time);
    if (age > const Duration(minutes: 30)) return;
    adhanAlert.value = a;
  }

  /// يوقف الأذان بإلغاء إشعاره (وبإلغائه يتوقف صوته).
  Future<void> stopAdhan(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {
      // لا شيء
    }
  }

  Future<void> _createChannels() async {
    final a = _android;
    if (a == null) return;
    for (final v in kAdhanVoices) {
      for (final m in const [AdhanMode.full, AdhanMode.short]) {
        final id = _channelId(v.id, m);
        await a.deleteNotificationChannel(_soundName(v.id, m)); // القناة القديمة
        await a.createNotificationChannel(AndroidNotificationChannel(
          id,
          'الأذان — ${v.nameAr} (${m.nameAr})',
          description: 'تنبيه وقت الصلاة بصوت الأذان (ببث المنبّه)',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(_soundName(v.id, m)),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ));
      }
    }
    await a.createNotificationChannel(AndroidNotificationChannel(
      'prayer_silent',
      'تنبيه الصلاة (صامت)',
      description: 'إشعار وقت الصلاة دون صوت',
      importance: Importance.defaultImportance,
      playSound: false,
    ));
    await a.createNotificationChannel(AndroidNotificationChannel(
      'follow_prayers',
      'أذان مدن الأقارب (إشعار صامت)',
      description: 'إشعار صامت بعد أذان المدن التي تتابعها',
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
    ));
    await a.createNotificationChannel(AndroidNotificationChannel(
      'tasbih_reminders',
      'تذكيرات المسبحة',
      description: 'تذكير بتسبيح ما بعد الصلاة وتذكير يومي',
      importance: Importance.defaultImportance,
    ));
    await a.createNotificationChannel(AndroidNotificationChannel(
      'countdown',
      'الوقت المتبقي للصلاة القادمة',
      description: 'شريط هادئ يعدّ تنازليًا إلى الصلاة القادمة',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    ));
  }

  // ───────── الصلاحيات ─────────
  Future<bool> notificationsEnabled() async => (await _android?.areNotificationsEnabled()) ?? false;
  Future<bool> canScheduleExact() async => (await _android?.canScheduleExactNotifications()) ?? false;

  /// مرة واحدة فقط (بعد أول تحديد للموقع) كي لا تتكرر النوافذ.
  Future<void> requestPermissionsOnce() async {
    final s = AppSettings.i;
    if (s.permsAsked) return;
    s.markPermsAsked();
    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    final a = _android;
    if (a == null) return;
    await a.requestNotificationsPermission();
    await a.requestExactAlarmsPermission();
  }

  // ───────── تفاصيل الإشعارات ─────────
  NotificationDetails _adhanDetails(String voice, AdhanMode mode) {
    if (mode == AdhanMode.silent) {
      return const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_silent',
          'تنبيه الصلاة (صامت)',
          channelDescription: 'إشعار وقت الصلاة دون صوت',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
          autoCancel: true,
        ),
      );
    }
    final id = _channelId(voice, mode);
    final v = kAdhanVoices.firstWhere((e) => e.id == voice, orElse: () => kAdhanVoices.first);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        'الأذان — ${v.nameAr} (${mode.nameAr})',
        channelDescription: 'تنبيه وقت الصلاة بصوت الأذان',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_soundName(voice, mode)),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        autoCancel: true,
        category: AndroidNotificationCategory.alarm,
        // شاشة الأذان فوق القفل (تظهر والهاتف مقفل أو شاشته مطفأة فقط)
        fullScreenIntent: AppSettings.i.adhanLockScreen,
      ),
    );
  }

  NotificationDetails _reminderDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'tasbih_reminders',
        'تذكيرات المسبحة',
        channelDescription: 'تذكير بتسبيح ما بعد الصلاة وتذكير يومي',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        autoCancel: true,
      ),
    );
  }

  NotificationDetails _followDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'follow_prayers',
        'أذان مدن الأقارب (إشعار صامت)',
        channelDescription: 'إشعار صامت بعد أذان المدن التي تتابعها',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: false,
        autoCancel: true,
      ),
    );
  }

  NotificationDetails _countdownDetails(DateTime target, Duration visibleFor) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'countdown',
        'الوقت المتبقي للصلاة القادمة',
        channelDescription: 'شريط هادئ يعدّ تنازليًا إلى الصلاة القادمة',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        silent: true,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        when: target.millisecondsSinceEpoch,
        usesChronometer: true,
        chronometerCountDown: true,
        timeoutAfter: visibleFor.inMilliseconds,
      ),
    );
  }

  // ───────── التحديث الحي (أندرويد 16+) ─────────
  Future<bool> _liveSupported() async {
    try {
      return (await _live.invokeMethod<bool>('supported')) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _liveCancel() async {
    try {
      await _live.invokeMethod<void>('cancel');
    } on PlatformException {
      // لا شيء
    } on MissingPluginException {
      // لا شيء
    }
  }

  Future<void> _scheduleLive(List<_Event> events, DateTime now) async {
    final items = <Map<String, Object>>[];
    final nextIdx = events.indexWhere((e) => e.time.isAfter(now));
    if (nextIdx >= 0) {
      items.add({
        'at': 0,
        'target': events[nextIdx].time.millisecondsSinceEpoch,
        'name': events[nextIdx].prayer.nameAr,
      });
    }
    for (var k = 0; k + 1 < events.length; k++) {
      final e = events[k];
      final next = events[k + 1];
      if (!e.time.isAfter(now)) continue;
      items.add({
        'at': e.time.millisecondsSinceEpoch,
        'target': next.time.millisecondsSinceEpoch,
        'name': next.prayer.nameAr,
      });
    }
    try {
      await _live.invokeMethod<void>('schedule', {'items': items});
    } on PlatformException {
      // لا شيء
    } on MissingPluginException {
      // لا شيء
    }
  }

  // ───────── الجدولة ─────────
  List<_Event> _events(AppSettings s) {
    final now = s.nowAtPlace(); // تاريخ اليوم بتوقيت المكان المختار
    final out = <_Event>[];
    for (var d = 0; d <= _days; d++) {
      final day = DateTime(now.year, now.month, now.day + d, 12);
      final times = s.timesFor(day);
      for (final p in _prayers) {
        final t = times[p];
        if (t != null) out.add(_Event(t, p));
      }
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }

  Future<void> _zoned(
    int id,
    String title,
    String? body,
    DateTime at,
    NotificationDetails details,
    AndroidScheduleMode mode, {
    String? payload,
  }) async {
    final when = tz.TZDateTime.from(at, tz.UTC);
    try {
      await _plugin.zonedSchedule(id, title, body, when, details,
          androidScheduleMode: mode, payload: payload);
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        await _plugin.zonedSchedule(id, title, body, when, details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, payload: payload);
      } else {
        rethrow;
      }
    }
  }

  /// يعيد بناء كل الإشعارات المجدولة من الإعدادات الحالية.
  Future<ScheduleReport> reschedule(AppSettings s) async {
    if (!_ready) await init();
    if (!_ready) {
      return lastReport = const ScheduleReport(0, false, 'تعذّرت تهيئة الإشعارات');
    }
    if (!s.hasLocation) {
      return lastReport = const ScheduleReport(0, false, 'حدّد موقعك لتُجدوَل الإشعارات');
    }
    try {
      await _plugin.cancelAll();
      final events = _events(s);
      final now = DateTime.now();
      final exact = await canScheduleExact();
      final mode = exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      final place = s.placeName.isEmpty ? '' : ' • ${s.placeName}';
      var count = 0;

      // أندرويد 16+: العدّ التنازلي تحديث حي (شريحة/Now Bar)؛ غيره: الإشعار المضغوط من الإضافة
      final live = s.countdownEnabled && await _liveSupported();
      if (live) {
        await _scheduleLive(events, now);
      } else {
        await _liveCancel();
      }

      // الشريط الهادئ للصلاة القادمة يظهر فورًا
      final nextIdx = events.indexWhere((e) => e.time.isAfter(now));
      if (s.countdownEnabled && !live && nextIdx >= 0) {
        final e = events[nextIdx];
        await _plugin.show(
          _nowCountdownId,
          'الصلاة القادمة: ${e.prayer.nameAr}',
          null, // بلا سطر ثانٍ: إشعار مضغوط بسطر واحد
          _countdownDetails(e.time, e.time.difference(now)),
        );
        count++;
      }

      for (var k = 0; k < events.length; k++) {
        final e = events[k];
        if (!e.time.isAfter(now)) continue;
        await _zoned(
          1000 + k,
          'حان الآن وقت صلاة ${e.prayer.nameAr}',
          'حيّ على الصلاة$place',
          e.time,
          _adhanDetails(s.voiceId, s.modeOf(e.prayer)),
          mode,
          payload: AdhanAlert.payloadOf(1000 + k, e.prayer.nameAr, e.time),
        );
        count++;
        if (s.countdownEnabled && !live && k + 1 < events.length) {
          final next = events[k + 1];
          await _zoned(
            2000 + k,
            'الصلاة القادمة: ${next.prayer.nameAr}',
            null,
            e.time,
            _countdownDetails(next.time, next.time.difference(e.time)),
            mode,
          );
          count++;
        }
      }
      // مدن الأقارب: إشعار صامت بعد أذان كل مدينة بخمس دقائق (توقيت دقيق غير لازم)
      for (var ci = 0; ci < s.follows.length; ci++) {
        final f = s.follows[ci];
        final fnow = TzService.nowAt(f.tz);
        var k = 0;
        for (var d = 0; d <= _days; d++) {
          final times = s.followTimes(f, DateTime(fnow.year, fnow.month, fnow.day + d, 12));
          for (final p in _prayers) {
            final t = times[p];
            if (t == null) continue;
            final at = t.add(const Duration(minutes: followDelayMin));
            if (!at.isAfter(now)) continue;
            await _zoned(
              _followBaseId + ci * 100 + k,
              'أُذِّن لصلاة ${p.nameAr} في ${f.name}',
              'الساعة ${clockText(t, f.tz)} بتوقيتها • قبل ${arDigits(followDelayMin)} دقائق',
              at,
              _followDetails(),
              AndroidScheduleMode.inexactAllowWhileIdle,
            );
            count++;
            k++;
          }
        }
      }
      // تذكيرات المسبحة (إشعار هادئ بصوت الإشعارات الافتراضي)
      if (s.tasbihAfterPrayer) {
        var k = 0;
        for (final e in events) {
          final at = e.time.add(Duration(minutes: s.tasbihDelayMin));
          if (!at.isAfter(now)) continue;
          await _zoned(
            4000 + k,
            'تسبيح بعد صلاة ${e.prayer.nameAr}',
            'سبحان الله ${arDigits(33)} • الحمد لله ${arDigits(33)} • الله أكبر ${arDigits(34)}',
            at,
            _reminderDetails(),
            AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'tasbih',
          );
          count++;
          k++;
        }
      }
      if (s.tasbihDaily) {
        final base = DateTime.now();
        final h = s.tasbihDailyMinutes ~/ 60;
        final mi = s.tasbihDailyMinutes % 60;
        for (var d = 0; d <= _days; d++) {
          final at = DateTime(base.year, base.month, base.day + d, h, mi);
          if (!at.isAfter(now)) continue;
          await _zoned(
            4900 + d,
            'وقت المسبحة 📿',
            'ألا بذكر الله تطمئن القلوب',
            at,
            _reminderDetails(),
            AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'tasbih',
          );
          count++;
        }
      }
      return lastReport = ScheduleReport(count, exact, null);
    } catch (e) {
      return lastReport = ScheduleReport(0, false, 'تعذّرت الجدولة: $e');
    }
  }

  /// إشعار تجريبي بعد [seconds] ثانية بالصوت والوضع المختارين.
  Future<String> scheduleTest(AppSettings s, AdhanMode mode, {int seconds = 10}) async {
    if (!_ready) await init();
    if (!_ready) return 'تعذّرت تهيئة الإشعارات';
    try {
      final exact = await canScheduleExact();
      await _zoned(
        _testId,
        'تجربة الأذان',
        'هكذا سيصلك الأذان (${mode.nameAr})',
        DateTime.now().add(Duration(seconds: seconds)),
        _adhanDetails(s.voiceId, mode),
        exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: AdhanAlert.payloadOf(
            _testId, AdhanAlert.testName, DateTime.now().add(Duration(seconds: seconds))),
      );
      return exact
          ? 'سيصلك الإشعار خلال $seconds ثوانٍ. يمكنك قفل الشاشة الآن.'
          : 'جُدول الإشعار لكن بتوقيت تقريبي (قد يتأخر). فعّل المنبّهات الدقيقة من الإعدادات.';
    } catch (e) {
      return 'تعذّرت الجدولة: $e';
    }
  }
}
