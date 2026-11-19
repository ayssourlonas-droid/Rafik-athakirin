// حساب مواقيت الصلاة (خوارزمية praytimes.org الفلكية).
// نسخة بايثون مطابقة لها في tools/prayer_reference_test.py قورنت بحساب مستقل (NOAA)
// فكان أكبر فرق في الشروق/الزوال/الغروب أقل من دقيقة. زوايا الفجر والعشاء تعتمد على الجهة
// المعتمدة في بلدك، فراجعها مع جهة رسمية قبل الاعتماد.
import 'dart:math' as math;

enum Prayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerInfo on Prayer {
  String get nameAr {
    switch (this) {
      case Prayer.fajr:
        return 'الفجر';
      case Prayer.sunrise:
        return 'الشروق';
      case Prayer.dhuhr:
        return 'الظهر';
      case Prayer.asr:
        return 'العصر';
      case Prayer.maghrib:
        return 'المغرب';
      case Prayer.isha:
        return 'العشاء';
    }
  }

  /// الصلوات المفروضة (بلا الشروق)
  bool get isObligatory => this != Prayer.sunrise;
}

class CalcMethod {
  const CalcMethod(this.id, this.nameAr, this.fajrAngle, this.ishaAngle, this.ishaMinutes);

  final String id;
  final String nameAr;
  final double fajrAngle;
  final double? ishaAngle; // null = العشاء بعد المغرب بدقائق ثابتة
  final double? ishaMinutes;
}

const List<CalcMethod> kMethods = [
  CalcMethod('mwl', 'رابطة العالم الإسلامي', 18.0, 17.0, null),
  CalcMethod('makkah', 'أم القرى (مكة المكرمة)', 18.5, null, 90.0),
  CalcMethod('egypt', 'الهيئة المصرية العامة للمساحة', 19.5, 17.5, null),
  CalcMethod('karachi', 'جامعة العلوم الإسلامية بكراتشي', 18.0, 18.0, null),
  CalcMethod('isna', 'أمريكا الشمالية (ISNA)', 15.0, 15.0, null),
  CalcMethod('tunisia', 'تونس', 18.0, 18.0, null),
  CalcMethod('algeria', 'الجزائر', 18.0, 17.0, null),
  CalcMethod('morocco', 'المغرب', 19.0, 17.0, null),
  CalcMethod('turkey', 'تركيا (الديانة)', 18.0, 17.0, null),
];

CalcMethod methodById(String id) =>
    kMethods.firstWhere((m) => m.id == id, orElse: () => kMethods.first);

/// مواقيت يوم واحد. القيمة null تعني تعذّر الحساب (قرب القطبين).
class DayTimes {
  DayTimes(this.date, this._times);

  final DateTime date;
  final Map<Prayer, DateTime?> _times;

  DateTime? operator [](Prayer p) => _times[p];
}

class PrayerCalc {
  // ───────── أدوات رياضية (بالدرجات) ─────────
  static double _rad(double d) => d * math.pi / 180.0;
  static double _deg(double r) => r * 180.0 / math.pi;
  static double _sin(double d) => math.sin(_rad(d));
  static double _cos(double d) => math.cos(_rad(d));
  static double _tan(double d) => math.tan(_rad(d));
  static double _asin(double x) => _deg(math.asin(x));
  static double _acos(double x) => _deg(math.acos(x));
  static double _atan2(double y, double x) => _deg(math.atan2(y, x));
  static double _acot(double x) => _deg(math.atan(1.0 / x));

  // floor على NaN يرمي استثناء في دارت، لذلك نمرّر NaN كما هو.
  static double _fixAngle(double a) => a.isNaN ? a : a - 360.0 * (a / 360.0).floorToDouble();
  static double _fixHour(double h) => h.isNaN ? h : h - 24.0 * (h / 24.0).floorToDouble();

  static double _julian(int y, int m, int d) {
    var yy = y;
    var mm = m;
    if (mm <= 2) {
      yy -= 1;
      mm += 12;
    }
    final a = (yy / 100.0).floor();
    final b = 2 - a + (a / 4.0).floor();
    return (365.25 * (yy + 4716)).floor() +
        (30.6001 * (mm + 1)).floor() +
        d +
        b -
        1524.5;
  }

  /// (الميل الشمسي بالدرجات، معادلة الزمن بالساعات)
  static List<double> _sunPosition(double jd) {
    final dd = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * dd);
    final q = _fixAngle(280.459 + 0.98564736 * dd);
    final l = _fixAngle(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));
    final e = 23.439 - 0.00000036 * dd;
    final ra = _fixHour(_atan2(_cos(e) * _sin(l), _cos(l)) / 15.0);
    return [_asin(_sin(e) * _sin(l)), q / 15.0 - ra];
  }

  /// يحسب مواقيت يوم [date] (التاريخ المحلي) لموقع معيّن.
  static DayTimes compute({
    required DateTime date,
    required double lat,
    required double lng,
    required CalcMethod method,
    required bool hanafi,
  }) {
    // فرق التوقيت يؤخذ عند الظهر المحلي، فيشمل تغيّر التوقيت الصيفي في ساعات الفجر الأولى
    final offset = DateTime(date.year, date.month, date.day, 12).timeZoneOffset;
    final tz = offset.inMinutes / 60.0;
    final jd0 = _julian(date.year, date.month, date.day) - lng / (15.0 * 24.0);
    final asrFactor = hanafi ? 2.0 : 1.0;

    double midDay(double t) => _fixHour(12.0 - _sunPosition(jd0 + t)[1]);

    double angleTime(double angle, double t, {bool ccw = false}) {
      final decl = _sunPosition(jd0 + t)[0];
      final noon = midDay(t);
      final x = (-_sin(angle) - _sin(decl) * _sin(lat)) / (_cos(decl) * _cos(lat));
      if (x < -1.0 || x > 1.0) return double.nan;
      final h = _acos(x) / 15.0;
      return noon + (ccw ? -h : h);
    }

    double asrTime(double t) {
      final decl = _sunPosition(jd0 + t)[0];
      final ang = -_acot(asrFactor + _tan((lat - decl).abs()));
      return angleTime(ang, t);
    }

    var fajr = angleTime(method.fajrAngle, 5 / 24, ccw: true);
    final sunrise = angleTime(0.833, 6 / 24, ccw: true);
    final dhuhr = midDay(12 / 24);
    final asr = asrTime(13 / 24);
    final sunset = angleTime(0.833, 18 / 24);
    var isha = method.ishaAngle != null ? angleTime(method.ishaAngle!, 18 / 24) : double.nan;

    // خطوط العرض العالية: عند تعذّر الفجر/العشاء أو بُعدهما نستعمل نصف الليل
    final bothOk = !sunrise.isNaN && !sunset.isNaN;
    if (bothOk) {
      final night = _fixHour(sunrise - sunset);
      final portion = night / 2.0;
      if (fajr.isNaN || _fixHour(sunrise - fajr) > portion) {
        fajr = sunrise - portion;
      }
      if (method.ishaAngle != null && (isha.isNaN || _fixHour(isha - sunset) > portion)) {
        isha = sunset + portion;
      }
    }
    final maghrib = sunset;
    if (method.ishaMinutes != null && !maghrib.isNaN) {
      isha = maghrib + method.ishaMinutes! / 60.0;
    }

    final off = tz - lng / 15.0;
    final hours = <Prayer, double>{
      Prayer.fajr: fajr + off,
      Prayer.sunrise: sunrise + off,
      Prayer.dhuhr: dhuhr + off,
      Prayer.asr: asr + off,
      Prayer.maghrib: maghrib + off,
      Prayer.isha: isha + off,
    };

    // نبني اللحظة من منتصف الليل UTC ثم نطرح فرق التوقيت (آمن عند تغيّر التوقيت الصيفي)
    final base = DateTime.utc(date.year, date.month, date.day);
    final out = <Prayer, DateTime?>{};
    hours.forEach((p, h) {
      if (h.isNaN) {
        out[p] = null;
      } else {
        final minutes = (h * 60.0).round();
        out[p] = base
            .add(Duration(minutes: minutes))
            .subtract(offset)
            .toLocal();
      }
    });
    return DayTimes(date, out);
  }
}
