// إعدادات المواقيت والأذان (تُحفظ على الجهاز).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_calc.dart';

/// وضع الأذان لكل صلاة: كامل، مختصر (أول مقطع)، أو إشعار صامت فقط.
enum AdhanMode { full, short, silent }

extension AdhanModeInfo on AdhanMode {
  String get nameAr {
    switch (this) {
      case AdhanMode.full:
        return 'أذان كامل';
      case AdhanMode.short:
        return 'أذان مختصر';
      case AdhanMode.silent:
        return 'إشعار صامت';
    }
  }
}

class AdhanVoice {
  const AdhanVoice(this.id, this.nameAr);
  final String id; // يطابق أسماء الملفات: adhan_<id>_full / adhan_<id>_short
  final String nameAr;
}

const List<AdhanVoice> kAdhanVoices = [
  AdhanVoice('a1', 'الأذان الأول'),
  AdhanVoice('a9', 'الأذان الثاني'),
];

class CityPreset {
  const CityPreset(this.nameAr, this.lat, this.lng);
  final String nameAr;
  final double lat;
  final double lng;
}

const List<CityPreset> kCities = [
  CityPreset('تونس', 36.8065, 10.1815),
  CityPreset('صفاقس', 34.7406, 10.7603),
  CityPreset('سوسة', 35.8256, 10.6369),
  CityPreset('الجزائر', 36.7538, 3.0588),
  CityPreset('الدار البيضاء', 33.5731, -7.5898),
  CityPreset('القاهرة', 30.0444, 31.2357),
  CityPreset('مكة المكرمة', 21.3891, 39.8579),
  CityPreset('المدينة المنورة', 24.4709, 39.6122),
  CityPreset('جدة', 21.4858, 39.1925),
  CityPreset('الرياض', 24.7136, 46.6753),
  CityPreset('دبي', 25.2048, 55.2708),
  CityPreset('الدوحة', 25.2854, 51.5310),
  CityPreset('الكويت', 29.3759, 47.9774),
  CityPreset('عمّان', 31.9454, 35.9284),
  CityPreset('بغداد', 33.3152, 44.3661),
  CityPreset('إسطنبول', 41.0082, 28.9784),
  CityPreset('باريس', 48.8566, 2.3522),
  CityPreset('لندن', 51.5074, -0.1278),
  CityPreset('نيويورك', 40.7128, -74.0060),
];

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings i = AppSettings._();

  SharedPreferences? _prefs;

  double? lat;
  double? lng;
  String placeName = '';
  String methodId = 'mwl';
  bool hanafi = false;
  String voiceId = 'a1';
  bool countdownEnabled = true;
  final Map<String, AdhanMode> _modes = {};

  bool get hasLocation => lat != null && lng != null;
  CalcMethod get method => methodById(methodId);

  /// الافتراضي لكل صلاة: أذان كامل.
  AdhanMode modeOf(Prayer p) => _modes[p.name] ?? AdhanMode.full;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    lat = p.getDouble('lat');
    lng = p.getDouble('lng');
    placeName = p.getString('place') ?? '';
    methodId = p.getString('method') ?? 'mwl';
    hanafi = p.getBool('hanafi') ?? false;
    voiceId = p.getString('voice') ?? 'a1';
    countdownEnabled = p.getBool('countdown') ?? true;
    final raw = p.getString('modes');
    if (raw != null) {
      try {
        (json.decode(raw) as Map<String, dynamic>).forEach((k, v) {
          final idx = v as int;
          if (idx >= 0 && idx < AdhanMode.values.length) _modes[k] = AdhanMode.values[idx];
        });
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    if (lat != null) await p.setDouble('lat', lat!);
    if (lng != null) await p.setDouble('lng', lng!);
    await p.setString('place', placeName);
    await p.setString('method', methodId);
    await p.setBool('hanafi', hanafi);
    await p.setString('voice', voiceId);
    await p.setBool('countdown', countdownEnabled);
    await p.setString('modes', json.encode({for (final e in _modes.entries) e.key: e.value.index}));
  }

  void _commit() {
    _save();
    notifyListeners();
  }

  void setLocation(double la, double lo, String name) {
    lat = la;
    lng = lo;
    placeName = name;
    _commit();
  }

  void setMethod(String id) {
    methodId = id;
    _commit();
  }

  void setHanafi(bool v) {
    hanafi = v;
    _commit();
  }

  void setVoice(String id) {
    voiceId = id;
    _commit();
  }

  void setCountdown(bool v) {
    countdownEnabled = v;
    _commit();
  }

  void setMode(Prayer p, AdhanMode m) {
    _modes[p.name] = m;
    _commit();
  }
}
