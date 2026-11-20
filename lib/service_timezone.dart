// المناطق الزمنية: فرق التوقيت لمدينة بعينها (يشمل التوقيت الصيفي) وتحويل اللحظة إلى ساعة تلك المدينة.
// المعرّف فارغ = ساعة الهاتف نفسها (حالة الـ GPS).
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class TzService {
  static bool _ready = false;

  static void ensureInit() {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      _ready = true;
    } catch (_) {}
  }

  static tz.Location? _loc(String id) {
    if (id.isEmpty) return null;
    ensureInit();
    try {
      return tz.getLocation(id);
    } catch (_) {
      return null;
    }
  }

  /// فرق التوقيت عند ظهر اليوم المحدد في تلك المنطقة؛ null = استعمل ساعة الهاتف.
  static Duration? offsetAt(String id, int y, int m, int d) {
    final l = _loc(id);
    if (l == null) return null;
    return tz.TZDateTime(l, y, m, d, 12).timeZoneOffset;
  }

  /// "الآن" بساعة المدينة (للتاريخ واليوم).
  static DateTime nowAt(String id) {
    final l = _loc(id);
    return l == null ? DateTime.now() : tz.TZDateTime.now(l);
  }

  /// يحوّل لحظة إلى ساعة المدينة (حقول hour/minute/day صحيحة بتوقيتها).
  static DateTime wall(DateTime t, String id) {
    final l = _loc(id);
    return l == null ? t.toLocal() : tz.TZDateTime.from(t, l);
  }
}
