// التقويم الهجري الجدولي (خوارزمية الكويت). تقريبي: قد يختلف يومًا عن الرؤية أو عن أم القرى،
// ولذلك في الإعدادات ضبط بالأيام (±٢). التاريخ الميلادي يُؤخذ بتاريخ المكان المختار.
import 'data_repo.dart';

const List<String> kHijriMonths = [
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

class HijriDate {
  const HijriDate(this.year, this.month, this.day);
  final int year;
  final int month; // 1..12
  final int day;

  String get monthName => kHijriMonths[(month - 1).clamp(0, 11).toInt()];
}

class Hijri {
  static HijriDate fromGregorian(int y, int m, int d, {int offsetDays = 0}) {
    final base = DateTime.utc(y, m, d).add(Duration(days: offsetDays));
    return _convert(base.year, base.month, base.day);
  }

  static String format(HijriDate h) => '${arDigits(h.day)} ${h.monthName} ${arDigits(h.year)} هـ';

  static int _t(num x) => x.truncate();

  static HijriDate _convert(int y, int m, int d) {
    final a = _t((m - 14) / 12);
    final jd = _t(1461 * (y + 4800 + a) / 4) +
        _t(367 * (m - 2 - 12 * a) / 12) -
        _t(3 * _t((y + 4900 + a) / 100) / 4) +
        d -
        32075;
    var l = jd - 1948440 + 10632;
    final n = _t((l - 1) / 10631);
    l = l - 10631 * n + 354;
    final j = _t((10985 - l) / 5316) * _t(50 * l / 17719) + _t(l / 5670) * _t(43 * l / 15238);
    l = l - _t((30 - j) / 15) * _t(17719 * j / 50) - _t(j / 16) * _t(15238 * j / 43) + 29;
    final mo = _t(24 * l / 709);
    final dd = l - _t(709 * mo / 24);
    final yy = 30 * n + j - 30;
    return HijriDate(yy, mo, dd);
  }
}
