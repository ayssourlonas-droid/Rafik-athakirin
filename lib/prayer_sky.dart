// الشمس والقمر في السماء لأي مكان وزمان على الأرض: الارتفاع والسمت (الاتجاه) والشروق والغروب وطور القمر.
// معادلات مختصرة: الشمس دقتها نحو دقيقة في الشروق والغروب، والقمر نحو ٠٫٣° (اختُبرت على كسوف ٢٠٢٤
// وأطوار معروفة). الشروق والغروب بمسح الارتفاع كل ١٠ دقائق ثم تدقيقه، فتعمل حتى في القطبين.
import 'dart:math' as math;

class SkyPoint {
  const SkyPoint(this.altitude, this.azimuth);

  /// بالدرجات؛ سالب = تحت الأفق.
  final double altitude;

  /// 0..360 مع عقارب الساعة من الشمال الحقيقي.
  final double azimuth;
}

class MoonPhase {
  const MoonPhase(this.illumination, this.waxing);

  /// نسبة القرص المضاء 0..1
  final double illumination;
  final bool waxing;

  String get name {
    final k = illumination;
    if (k < 0.03) return 'محاق';
    if (k > 0.97) return 'بدر';
    if (k >= 0.45 && k <= 0.55) return waxing ? 'التربيع الأول' : 'التربيع الأخير';
    if (k < 0.45) return waxing ? 'هلال متزايد' : 'هلال متناقص';
    return waxing ? 'أحدب متزايد' : 'أحدب متناقص';
  }
}

class RiseSet {
  const RiseSet({this.rise, this.set, this.riseAz, this.setAz, required this.upAtStart});

  final DateTime? rise;
  final DateTime? set;
  final double? riseAz;
  final double? setAz;

  /// كان الجرم فوق الأفق في بداية النافذة (يفيد حين لا شروق ولا غروب: لا يغيب أو لا يشرق).
  final bool upAtStart;
}

/// بيانات اليوم (٢٤ ساعة من بداية يوم المكان): تُحسب مرة لكل يوم وموقع.
class SkyDay {
  const SkyDay(this.sun, this.moon, this.sunPath);

  final RiseSet sun;
  final RiseSet moon;

  /// سمت الشمس كل ١٠ دقائق؛ null حين تكون تحت الأفق.
  final List<double?> sunPath;
}

class SkySnapshot {
  const SkySnapshot(this.sun, this.moon, this.phase, this.day);

  final SkyPoint sun;
  final SkyPoint moon;
  final MoonPhase phase;
  final SkyDay day;
}

class _Eq {
  const _Eq(this.ra, this.dec, this.lon, this.parallax);
  final double ra; // درجات
  final double dec; // درجات
  final double lon; // خط الطول الكسوفي، درجات
  final double parallax; // اختلاف المنظر الأفقي (للقمر)، درجات
}

class Sky {
  static const double _h0 = -0.833; // الجرم المرئي كله يلامس الأفق (انكسار + نصف القطر)

  static double _rad(double d) => d * math.pi / 180.0;
  static double _deg(double r) => r * 180.0 / math.pi;
  static double _norm(double d) => ((d % 360.0) + 360.0) % 360.0;
  static double _jd(DateTime t) => t.toUtc().millisecondsSinceEpoch / 86400000.0 + 2440587.5;

  static _Eq _sunEq(double jd) {
    final d = jd - 2451545.0;
    final g = _rad(_norm(357.529 + 0.98560028 * d));
    final q = _norm(280.459 + 0.98564736 * d);
    final l = _norm(q + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g));
    final e = _rad(23.439 - 3.6e-7 * d);
    final ra = _norm(_deg(math.atan2(math.cos(e) * math.sin(_rad(l)), math.cos(_rad(l)))));
    final dec = _deg(math.asin(math.sin(e) * math.sin(_rad(l))));
    return _Eq(ra, dec, l, 0);
  }

  static _Eq _moonEq(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    double s(double a, double b) => math.sin(_rad(a + b * t));
    double c(double a, double b) => math.cos(_rad(a + b * t));
    final lamDeg = 218.32 +
        481267.881 * t +
        6.29 * s(135.0, 477198.87) -
        1.27 * s(259.3, -413335.36) +
        0.66 * s(235.7, 890534.22) +
        0.21 * s(269.9, 954397.74) -
        0.19 * s(357.5, 35999.05) -
        0.11 * s(186.5, 966404.03);
    final bet = 5.13 * s(93.3, 483202.02) +
        0.28 * s(228.2, 960400.89) -
        0.28 * s(318.3, 6003.15) -
        0.17 * s(217.6, -407332.21);
    final par = 0.9508 +
        0.0518 * c(135.0, 477198.87) +
        0.0095 * c(259.3, -413335.36) +
        0.0078 * c(235.7, 890534.22) +
        0.0028 * c(269.9, 954397.74);
    final lam = _rad(_norm(lamDeg));
    final b = _rad(bet);
    final l = math.cos(b) * math.cos(lam);
    final m = 0.9175 * math.cos(b) * math.sin(lam) - 0.3978 * math.sin(b);
    final n = 0.3978 * math.cos(b) * math.sin(lam) + 0.9175 * math.sin(b);
    return _Eq(_norm(_deg(math.atan2(m, l))), _deg(math.asin(n)), _norm(lamDeg), par);
  }

  static SkyPoint _altAz(_Eq eq, double jd, double lat, double lng) {
    final gmst = _norm(280.46061837 + 360.98564736629 * (jd - 2451545.0));
    final h = _rad(_norm(gmst + lng - eq.ra));
    final phi = _rad(lat);
    final d = _rad(eq.dec);
    final alt = math.asin(math.sin(phi) * math.sin(d) + math.cos(phi) * math.cos(d) * math.cos(h));
    final a = math.atan2(math.sin(h), math.cos(h) * math.sin(phi) - math.tan(d) * math.cos(phi));
    return SkyPoint(_deg(alt), _norm(_deg(a) + 180.0));
  }

  static SkyPoint sunAt(DateTime t, double lat, double lng) {
    final jd = _jd(t);
    return _altAz(_sunEq(jd), jd, lat, lng);
  }

  /// القمر بتصحيح اختلاف المنظر للارتفاع (يصل نحو ١°).
  static SkyPoint moonAt(DateTime t, double lat, double lng) {
    final jd = _jd(t);
    final eq = _moonEq(jd);
    final p = _altAz(eq, jd, lat, lng);
    return SkyPoint(p.altitude - eq.parallax * math.cos(_rad(p.altitude)), p.azimuth);
  }

  static MoonPhase phaseAt(DateTime t) {
    final jd = _jd(t);
    final s = _sunEq(jd);
    final m = _moonEq(jd);
    final cosPsi = math.sin(_rad(s.dec)) * math.sin(_rad(m.dec)) +
        math.cos(_rad(s.dec)) * math.cos(_rad(m.dec)) * math.cos(_rad(s.ra - m.ra));
    final psi = _deg(math.acos(cosPsi.clamp(-1.0, 1.0).toDouble()));
    final k = (1 - math.cos(_rad(psi))) / 2;
    return MoonPhase(k, _norm(m.lon - s.lon) < 180.0);
  }

  static RiseSet _riseSet(bool moon, DateTime startUtc, double lat, double lng) {
    SkyPoint at(DateTime t) => moon ? moonAt(t, lat, lng) : sunAt(t, lat, lng);
    double f(DateTime t) => at(t).altitude - _h0;
    DateTime? rise;
    DateTime? set;
    double? riseAz;
    double? setAz;
    var t = startUtc;
    var prev = f(t);
    final up0 = prev >= 0;
    for (var i = 0; i < 144; i++) {
      final t2 = t.add(const Duration(minutes: 10));
      final cur = f(t2);
      if ((prev < 0) != (cur < 0)) {
        var a = t;
        var b = t2;
        var fa = prev;
        for (var k = 0; k < 14; k++) {
          final mid = a.add(Duration(milliseconds: b.difference(a).inMilliseconds ~/ 2));
          final fm = f(mid);
          if ((fa < 0) == (fm < 0)) {
            a = mid;
            fa = fm;
          } else {
            b = mid;
          }
        }
        if (cur >= 0) {
          if (rise == null) {
            rise = b;
            riseAz = at(b).azimuth;
          }
        } else if (set == null) {
          set = b;
          setAz = at(b).azimuth;
        }
      }
      prev = cur;
      t = t2;
    }
    return RiseSet(rise: rise, set: set, riseAz: riseAz, setAz: setAz, upAtStart: up0);
  }

  /// [startUtc]: لحظة منتصف ليل المكان (بالتوقيت العالمي).
  static SkyDay day(DateTime startUtc, double lat, double lng) {
    final start = startUtc.toUtc();
    final path = <double?>[];
    for (var i = 0; i <= 144; i++) {
      final p = sunAt(start.add(Duration(minutes: 10 * i)), lat, lng);
      path.add(p.altitude >= _h0 ? p.azimuth : null);
    }
    return SkyDay(_riseSet(false, start, lat, lng), _riseSet(true, start, lat, lng), path);
  }

  static SkySnapshot at(DateTime t, double lat, double lng, SkyDay day) {
    return SkySnapshot(sunAt(t, lat, lng), moonAt(t, lat, lng), phaseAt(t), day);
  }
}
