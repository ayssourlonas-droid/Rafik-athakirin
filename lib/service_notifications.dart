// الإشعارات: أذان كل صلاة (بصوت من res/raw) + شريط هادئ بالوقت المتبقي للصلاة القادمة.
// - الأذان: قناة لكل (صوت × وضع) لأن صوت قناة أندرويد لا يتغير بعد إنشائها.
// - العدّاد: إشعار ثابت صامت يعدّه النظام تنازليًا بلا تشغيل التطبيق، ويختفي وحده
//   عند حلول الصلاة (timeoutAfter) ويحلّ محله إشعار الصلاة التي بعدها.
// - الجدولة بنافذة متحركة لعشرة أيام تُجدَّد كلما فُتح التطبيق أو تغيّرت الإعدادات.
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'data_settings.dart';
import 'prayer_calc.dart';

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

class NotificationService {
  NotificationService._();
  static final NotificationService i = NotificationService._();

  static const int _days = 10;
  static const int _nowCountdownId = 1;
  static const int _testId = 9;
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
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _createChannels();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static String _channelId(String voice, AdhanMode mode) => 'adhan_${voice}_${mode.name}';

  Future<void> _createChannels() async {
    final a = _android;
    if (a == null) return;
    for (final v in kAdhanVoices) {
      for (final m in const [AdhanMode.full, AdhanMode.short]) {
        final id = _channelId(v.id, m);
        await a.createNotificationChannel(AndroidNotificationChannel(
          id,
          'الأذان — ${v.nameAr} (${m.nameAr})',
          description: 'تنبيه وقت الصلاة بصوت الأذان',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(id),
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
        sound: RawResourceAndroidNotificationSound(id),
        autoCancel: true,
        category: AndroidNotificationCategory.alarm,
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

  // ───────── الجدولة ─────────
  List<_Event> _events(AppSettings s) {
    final now = DateTime.now();
    final out = <_Event>[];
    for (var d = 0; d <= _days; d++) {
      final day = DateTime(now.year, now.month, now.day + d, 12);
      final times = PrayerCalc.compute(
        date: day,
        lat: s.lat!,
        lng: s.lng!,
        method: s.method,
        hanafi: s.hanafi,
      );
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
    String body,
    DateTime at,
    NotificationDetails details,
    AndroidScheduleMode mode,
  ) async {
    final when = tz.TZDateTime.from(at, tz.UTC);
    try {
      await _plugin.zonedSchedule(id, title, body, when, details, androidScheduleMode: mode);
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        await _plugin.zonedSchedule(id, title, body, when, details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
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

      // الشريط الهادئ للصلاة القادمة يظهر فورًا
      final nextIdx = events.indexWhere((e) => e.time.isAfter(now));
      if (s.countdownEnabled && nextIdx >= 0) {
        final e = events[nextIdx];
        await _plugin.show(
          _nowCountdownId,
          'الصلاة القادمة: ${e.prayer.nameAr}',
          'الوقت المتبقي$place',
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
        );
        count++;
        if (s.countdownEnabled && k + 1 < events.length) {
          final next = events[k + 1];
          await _zoned(
            2000 + k,
            'الصلاة القادمة: ${next.prayer.nameAr}',
            'الوقت المتبقي$place',
            e.time,
            _countdownDetails(next.time, next.time.difference(e.time)),
            mode,
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
      );
      return exact
          ? 'سيصلك الإشعار خلال $seconds ثوانٍ. يمكنك قفل الشاشة الآن.'
          : 'جُدول الإشعار لكن بتوقيت تقريبي (قد يتأخر). فعّل المنبّهات الدقيقة من الإعدادات.';
    } catch (e) {
      return 'تعذّرت الجدولة: $e';
    }
  }
}
