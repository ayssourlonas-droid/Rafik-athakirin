// تنسيق الوقت بتوقيت مكان معيّن وبالأرقام التي اختارها المستخدم.
import 'data_repo.dart';
import 'service_timezone.dart';

String twoDigits(int n) => n < 10 ? '${arDigits(0)}${arDigits(n)}' : arDigits(n);

/// الساعة بنظام 12 ساعة بتوقيت [tzId] (فارغ = ساعة الهاتف).
String clockText(DateTime t, String tzId) {
  final w = TzService.wall(t, tzId);
  final h = w.hour % 12 == 0 ? 12 : w.hour % 12;
  final suffix = w.hour < 12 ? 'ص' : 'م';
  return '${arDigits(h)}:${twoDigits(w.minute)} $suffix';
}
