// إعدادات المواقيت والأذان (تُحفظ على الجهاز).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_calc.dart';
import 'service_timezone.dart';

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
  const CityPreset(this.nameAr, this.lat, this.lng, this.tzId, this.methodId);
  final String nameAr;
  final double lat;
  final double lng;
  final String tzId; // معرّف IANA (يشمل التوقيت الصيفي)
  final String methodId; // طريقة الحساب المقترحة لهذه الجهة
}

/// مدينة يتابعها المستخدم (قريب في بلد بعيد): يصله إشعار صامت بعد أذانها.
class FollowCity {
  const FollowCity(this.name, this.lat, this.lng, this.tz, this.method);
  final String name;
  final double lat;
  final double lng;
  final String tz;
  final String method;

  Map<String, dynamic> toJson() =>
      {'n': name, 'la': lat, 'lo': lng, 'tz': tz, 'm': method};

  static FollowCity? fromJson(dynamic j) {
    try {
      final m = j as Map<String, dynamic>;
      return FollowCity(
        m['n'] as String,
        (m['la'] as num).toDouble(),
        (m['lo'] as num).toDouble(),
        m['tz'] as String,
        m['m'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

const List<CityPreset> kCities = [
  CityPreset('تونس', 36.8065, 10.1815, 'Africa/Tunis', 'tunisia'),
  CityPreset('صفاقس', 34.7406, 10.7603, 'Africa/Tunis', 'tunisia'),
  CityPreset('سوسة', 35.8256, 10.6369, 'Africa/Tunis', 'tunisia'),
  CityPreset('الجزائر', 36.7538, 3.0588, 'Africa/Algiers', 'algeria'),
  CityPreset('وهران', 35.6971, -0.6308, 'Africa/Algiers', 'algeria'),
  CityPreset('قسنطينة', 36.365, 6.6147, 'Africa/Algiers', 'algeria'),
  CityPreset('الدار البيضاء', 33.5731, -7.5898, 'Africa/Casablanca', 'morocco'),
  CityPreset('الرباط', 34.0209, -6.8416, 'Africa/Casablanca', 'morocco'),
  CityPreset('مراكش', 31.6295, -7.9811, 'Africa/Casablanca', 'morocco'),
  CityPreset('طرابلس (ليبيا)', 32.8872, 13.1913, 'Africa/Tripoli', 'mwl'),
  CityPreset('بنغازي', 32.1167, 20.0667, 'Africa/Tripoli', 'mwl'),
  CityPreset('القاهرة', 30.0444, 31.2357, 'Africa/Cairo', 'egypt'),
  CityPreset('الإسكندرية', 31.2001, 29.9187, 'Africa/Cairo', 'egypt'),
  CityPreset('الخرطوم', 15.5007, 32.5599, 'Africa/Khartoum', 'mwl'),
  CityPreset('نواكشوط', 18.0735, -15.9582, 'Africa/Nouakchott', 'mwl'),
  CityPreset('دكار', 14.7167, -17.4677, 'Africa/Dakar', 'mwl'),
  CityPreset('مكة المكرمة', 21.3891, 39.8579, 'Asia/Riyadh', 'makkah'),
  CityPreset('المدينة المنورة', 24.4709, 39.6122, 'Asia/Riyadh', 'makkah'),
  CityPreset('جدة', 21.4858, 39.1925, 'Asia/Riyadh', 'makkah'),
  CityPreset('الرياض', 24.7136, 46.6753, 'Asia/Riyadh', 'makkah'),
  CityPreset('دبي', 25.2048, 55.2708, 'Asia/Dubai', 'uae'),
  CityPreset('أبوظبي', 24.4539, 54.3773, 'Asia/Dubai', 'uae'),
  CityPreset('الدوحة', 25.2854, 51.531, 'Asia/Qatar', 'qatar'),
  CityPreset('الكويت', 29.3759, 47.9774, 'Asia/Kuwait', 'kuwait'),
  CityPreset('المنامة', 26.2285, 50.586, 'Asia/Bahrain', 'mwl'),
  CityPreset('مسقط', 23.588, 58.3829, 'Asia/Muscat', 'mwl'),
  CityPreset('صنعاء', 15.3694, 44.191, 'Asia/Aden', 'mwl'),
  CityPreset('عمّان', 31.9454, 35.9284, 'Asia/Amman', 'mwl'),
  CityPreset('القدس', 31.7683, 35.2137, 'Asia/Jerusalem', 'mwl'),
  CityPreset('دمشق', 33.5138, 36.2765, 'Asia/Damascus', 'mwl'),
  CityPreset('بيروت', 33.8938, 35.5018, 'Asia/Beirut', 'mwl'),
  CityPreset('بغداد', 33.3152, 44.3661, 'Asia/Baghdad', 'mwl'),
  CityPreset('إسطنبول', 41.0082, 28.9784, 'Europe/Istanbul', 'turkey'),
  CityPreset('أنقرة', 39.9334, 32.8597, 'Europe/Istanbul', 'turkey'),
  CityPreset('باريس', 48.8566, 2.3522, 'Europe/Paris', 'uoif'),
  CityPreset('مرسيليا', 43.2965, 5.3698, 'Europe/Paris', 'uoif'),
  CityPreset('ليون', 45.764, 4.8357, 'Europe/Paris', 'uoif'),
  CityPreset('لندن', 51.5074, -0.1278, 'Europe/London', 'mwl'),
  CityPreset('مدريد', 40.4168, -3.7038, 'Europe/Madrid', 'mwl'),
  CityPreset('برلين', 52.52, 13.405, 'Europe/Berlin', 'mwl'),
  CityPreset('روما', 41.9028, 12.4964, 'Europe/Rome', 'mwl'),
  CityPreset('بروكسل', 50.8503, 4.3517, 'Europe/Brussels', 'mwl'),
  CityPreset('أمستردام', 52.3676, 4.9041, 'Europe/Amsterdam', 'mwl'),
  CityPreset('ستوكهولم', 59.3293, 18.0686, 'Europe/Stockholm', 'mwl'),
  CityPreset('موسكو', 55.7558, 37.6173, 'Europe/Moscow', 'mwl'),
  CityPreset('نيويورك', 40.7128, -74.006, 'America/New_York', 'isna'),
  CityPreset('واشنطن', 38.9072, -77.0369, 'America/New_York', 'isna'),
  CityPreset('شيكاغو', 41.8781, -87.6298, 'America/Chicago', 'isna'),
  CityPreset('هيوستن', 29.7604, -95.3698, 'America/Chicago', 'isna'),
  CityPreset('لوس أنجلوس', 34.0522, -118.2437, 'America/Los_Angeles', 'isna'),
  CityPreset('تورنتو', 43.6532, -79.3832, 'America/Toronto', 'isna'),
  CityPreset('مونتريال', 45.5017, -73.5673, 'America/Toronto', 'isna'),
  CityPreset('ساو باولو', -23.5505, -46.6333, 'America/Sao_Paulo', 'mwl'),
  CityPreset('سيدني', -33.8688, 151.2093, 'Australia/Sydney', 'mwl'),
  CityPreset('ملبورن', -37.8136, 144.9631, 'Australia/Melbourne', 'mwl'),
  CityPreset('كراتشي', 24.8607, 67.0011, 'Asia/Karachi', 'karachi'),
  CityPreset('إسلام آباد', 33.6844, 73.0479, 'Asia/Karachi', 'karachi'),
  CityPreset('لاهور', 31.5497, 74.3436, 'Asia/Karachi', 'karachi'),
  CityPreset('دلهي', 28.6139, 77.209, 'Asia/Kolkata', 'karachi'),
  CityPreset('مومباي', 19.076, 72.8777, 'Asia/Kolkata', 'karachi'),
  CityPreset('دكا', 23.8103, 90.4125, 'Asia/Dhaka', 'karachi'),
  CityPreset('كابول', 34.5553, 69.2075, 'Asia/Kabul', 'karachi'),
  CityPreset('طشقند', 41.2995, 69.2401, 'Asia/Tashkent', 'mwl'),
  CityPreset('كوالالمبور', 3.139, 101.6869, 'Asia/Kuala_Lumpur', 'seasia'),
  CityPreset('جاكرتا', -6.2088, 106.8456, 'Asia/Jakarta', 'seasia'),
  CityPreset('سنغافورة', 1.3521, 103.8198, 'Asia/Singapore', 'seasia'),
  CityPreset('طوكيو', 35.6762, 139.6503, 'Asia/Tokyo', 'mwl'),
  CityPreset('بكين', 39.9042, 116.4074, 'Asia/Shanghai', 'mwl'),
  CityPreset('جوهانسبرغ', -26.2041, 28.0473, 'Africa/Johannesburg', 'mwl'),
  CityPreset('كيب تاون', -33.9249, 18.4241, 'Africa/Johannesburg', 'mwl'),
  CityPreset('لاغوس', 6.5244, 3.3792, 'Africa/Lagos', 'mwl'),
  CityPreset('نيروبي', -1.2921, 36.8219, 'Africa/Nairobi', 'mwl'),
  CityPreset('أديس أبابا', 9.03, 38.74, 'Africa/Addis_Ababa', 'mwl'),
  CityPreset('مقديشو', 2.0469, 45.3182, 'Africa/Mogadishu', 'mwl'),
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
  String tzId = ''; // منطقة المدينة المختارة؛ فارغ = ساعة الهاتف
  bool latinDigits = false; // false = أرقام عربية (٠١٢)، true = لاتينية (012)
  final Map<String, int> _adjust = {}; // دقائق الضبط لكل صلاة
  bool manualPrimary = false; // true = موقع يدوي (بديل عند تعذّر الـ GPS)
  bool gpsAsked = false; // هل طُلب إذن الموقع من قبل
  static const int maxFollows = 3;
  final List<FollowCity> follows = [];
  int hijriOffset = 0; // ضبط التقويم الهجري بالأيام (-2..2)
  bool adhanLockScreen = true; // شاشة الأذان فوق القفل
  bool tasbihAfterPrayer = false; // تذكير بتسبيح ما بعد الصلاة
  int tasbihDelayMin = 10; // بعد كم دقيقة من الصلاة
  bool tasbihDaily = false; // تذكير يومي
  int tasbihDailyMinutes = 20 * 60; // وقت التذكير اليومي (دقائق من منتصف الليل)
  bool permsAsked = false; // هل طُلبت صلاحيات الإشعارات والمنبّهات من قبل
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
    permsAsked = p.getBool('permsAsked') ?? false;
    hijriOffset = (p.getInt('hijriOff') ?? 0).clamp(-2, 2).toInt();
    adhanLockScreen = p.getBool('lockScreen') ?? true;
    tasbihAfterPrayer = p.getBool('tsAfter') ?? false;
    tasbihDelayMin = (p.getInt('tsDelay') ?? 10).clamp(0, 30).toInt();
    tasbihDaily = p.getBool('tsDaily') ?? false;
    tasbihDailyMinutes = (p.getInt('tsDailyAt') ?? 20 * 60).clamp(0, 1439).toInt();
    tzId = p.getString('tz') ?? '';
    manualPrimary = p.getBool('manual') ?? false;
    gpsAsked = p.getBool('gpsAsked') ?? false;
    final rawFollows = p.getString('follows');
    if (rawFollows != null) {
      try {
        for (final j in json.decode(rawFollows) as List) {
          final f = FollowCity.fromJson(j);
          if (f != null && follows.length < maxFollows) follows.add(f);
        }
      } catch (_) {}
    }
    latinDigits = p.getBool('latinDigits') ?? false;
    final rawAdj = p.getString('adjust');
    if (rawAdj != null) {
      try {
        (json.decode(rawAdj) as Map<String, dynamic>).forEach((k, v) {
          _adjust[k] = (v as int).clamp(-30, 30).toInt();
        });
      } catch (_) {}
    }
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
    await p.setBool('permsAsked', permsAsked);
    await p.setInt('hijriOff', hijriOffset);
    await p.setBool('lockScreen', adhanLockScreen);
    await p.setBool('tsAfter', tasbihAfterPrayer);
    await p.setInt('tsDelay', tasbihDelayMin);
    await p.setBool('tsDaily', tasbihDaily);
    await p.setInt('tsDailyAt', tasbihDailyMinutes);
    await p.setString('tz', tzId);
    await p.setBool('manual', manualPrimary);
    await p.setBool('gpsAsked', gpsAsked);
    await p.setString('follows', json.encode([for (final f in follows) f.toJson()]));
    await p.setBool('latinDigits', latinDigits);
    await p.setString('adjust', json.encode(_adjust));
    await p.setString('modes', json.encode({for (final e in _modes.entries) e.key: e.value.index}));
  }

  void _commit() {
    _save();
    notifyListeners();
  }

  /// [tz] معرّف منطقة المدينة (فارغ للـ GPS = ساعة الهاتف). [method] طريقة الحساب المقترحة إن وُجدت.
  void setLocation(double la, double lo, String name,
      {String tz = '', String? method, bool manual = false}) {
    manualPrimary = manual;
    lat = la;
    lng = lo;
    placeName = name;
    tzId = tz;
    if (method != null) methodId = method;
    _commit();
  }

  /// مواقيت يوم [day] (الساعة 12 ظهرًا بتاريخ المكان) مع المنطقة الزمنية وضبط الدقائق.
  DayTimes timesFor(DateTime day) => PrayerCalc.compute(
        date: day,
        lat: lat!,
        lng: lng!,
        method: method,
        hanafi: hanafi,
        zoneOffset: TzService.offsetAt(tzId, day.year, day.month, day.day),
        adjust: adjustMap,
      );

  void setHijriOffset(int days) {
    hijriOffset = days.clamp(-2, 2).toInt();
    _commit();
  }

  void setAdhanLockScreen(bool v) {
    adhanLockScreen = v;
    _commit();
  }

  void setTasbihAfterPrayer(bool v) {
    tasbihAfterPrayer = v;
    _commit();
  }

  void setTasbihDelay(int minutes) {
    tasbihDelayMin = minutes.clamp(0, 30).toInt();
    _commit();
  }

  void setTasbihDaily(bool v) {
    tasbihDaily = v;
    _commit();
  }

  void setTasbihDailyTime(int minutes) {
    tasbihDailyMinutes = minutes.clamp(0, 1439).toInt();
    _commit();
  }

  void markGpsAsked() {
    gpsAsked = true;
    _commit();
  }

  bool addFollow(CityPreset c) {
    if (follows.length >= maxFollows) return false;
    if (follows.any((f) => f.name == c.nameAr)) return false;
    follows.add(FollowCity(c.nameAr, c.lat, c.lng, c.tzId, c.methodId));
    _commit();
    return true;
  }

  void removeFollow(int index) {
    if (index < 0 || index >= follows.length) return;
    follows.removeAt(index);
    _commit();
  }

  /// مواقيت مدينة قريب (بطريقتها المقترحة، دون ضبط دقائق).
  DayTimes followTimes(FollowCity f, DateTime day) => PrayerCalc.compute(
        date: day,
        lat: f.lat,
        lng: f.lng,
        method: methodById(f.method),
        hanafi: false,
        zoneOffset: TzService.offsetAt(f.tz, day.year, day.month, day.day),
      );

  /// "الآن" بتوقيت المكان المختار.
  DateTime nowAtPlace() => TzService.nowAt(tzId);

  int adjustOf(Prayer p) => _adjust[p.name] ?? 0;

  Map<Prayer, int> get adjustMap {
    final m = <Prayer, int>{};
    for (final p in Prayer.values) {
      final v = _adjust[p.name];
      if (v != null && v != 0) m[p] = v;
    }
    return m;
  }

  void setAdjust(Prayer p, int minutes) {
    _adjust[p.name] = minutes.clamp(-30, 30).toInt();
    _commit();
  }

  void setLatinDigits(bool v) {
    latinDigits = v;
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

  void markPermsAsked() {
    permsAsked = true;
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
