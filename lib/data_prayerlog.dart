// سجل الصلوات المؤدّاة: يعلّمها المستخدم بنفسه من شاشة المواقيت، ويُحفظ على الجهاز (آخر ٩٠ يومًا).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_calc.dart';

class PrayerLog extends ChangeNotifier {
  PrayerLog._();
  static final PrayerLog i = PrayerLog._();

  static const String _key = 'prayer_log';
  static const int _keepDays = 90;
  static const Map<Prayer, int> _bit = {
    Prayer.fajr: 0,
    Prayer.dhuhr: 1,
    Prayer.asr: 2,
    Prayer.maghrib: 3,
    Prayer.isha: 4,
  };

  SharedPreferences? _prefs;
  final Map<String, int> _days = {};

  static String keyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) return;
    try {
      (json.decode(raw) as Map<String, dynamic>).forEach((k, v) {
        if (v is int) _days[k] = v & 31;
      });
    } catch (_) {
      // بيانات تالفة: نبدأ من جديد
    }
  }

  bool done(DateTime day, Prayer p) {
    final b = _bit[p];
    if (b == null) return false;
    return (((_days[keyOf(day)] ?? 0) >> b) & 1) == 1;
  }

  int countOn(DateTime day) {
    var m = _days[keyOf(day)] ?? 0;
    var c = 0;
    while (m != 0) {
      c += m & 1;
      m >>= 1;
    }
    return c;
  }

  void toggle(DateTime day, Prayer p) {
    final b = _bit[p];
    if (b == null) return;
    final k = keyOf(day);
    final next = (_days[k] ?? 0) ^ (1 << b);
    if (next == 0) {
      _days.remove(k);
    } else {
      _days[k] = next;
    }
    if (_days.length > _keepDays + 30) {
      final keys = _days.keys.toList()..sort();
      for (final old in keys.take(_days.length - _keepDays)) {
        _days.remove(old);
      }
    }
    _prefs?.setString(_key, json.encode(_days));
    notifyListeners();
  }
}
