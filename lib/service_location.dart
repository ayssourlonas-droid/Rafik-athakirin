// تحديد الموقع عبر GPS (يحتاج إذن الموقع). عند الفشل نُرجع سببًا مفهومًا بدل استثناء.
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import 'data_settings.dart';
import 'service_notifications.dart';

class LocationOutcome {
  LocationOutcome.ok(this.lat, this.lng)
      : error = null;
  LocationOutcome.fail(this.error)
      : lat = null,
        lng = null;

  final double? lat;
  final double? lng;
  final String? error;
  bool get isOk => error == null;
}

class LocationService {
  /// [ask] = false: لا نعرض نافذة طلب الإذن (للتحديث الصامت عند فتح التطبيق).
  static Future<LocationOutcome> detect({bool ask = true}) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return LocationOutcome.fail('خدمة الموقع مغلقة في الهاتف. فعّلها ثم أعد المحاولة.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        if (!ask) return LocationOutcome.fail('لم يُمنح إذن الموقع.');
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return LocationOutcome.fail('لم يُمنح إذن الموقع.');
      }
      if (perm == LocationPermission.deniedForever) {
        return LocationOutcome.fail('إذن الموقع مرفوض نهائيًا. فعّله من إعدادات التطبيق في الهاتف.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationOutcome.ok(pos.latitude, pos.longitude);
    } catch (e) {
      return LocationOutcome.fail('تعذّر تحديد الموقع تلقائيًا. اختر مدينتك يدويًا.');
    }
  }

  static DateTime? _lastAuto;

  static String placeName(double la, double lo) =>
      'موقعك الحالي (${la.toStringAsFixed(2)}، ${lo.toStringAsFixed(2)})';

  static double _km(double la1, double lo1, double la2, double lo2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180.0;
    final dLa = rad(la2 - la1);
    final dLo = rad(lo2 - lo1);
    final a = math.pow(math.sin(dLa / 2), 2) +
        math.cos(rad(la1)) * math.cos(rad(la2)) * math.pow(math.sin(dLo / 2), 2);
    return 2 * r * math.asin(math.sqrt(a.toDouble()));
  }

  /// تحديد الموقع تلقائيًا عند فتح التطبيق (ما لم يكن الموقع يدويًا).
  /// لا يغيّر الموقع إلا إذا ابتعد المستخدم أكثر من 15 كم، وبحدّ أدنى عشر دقائق بين محاولتين.
  static Future<void> autoRefresh() async {
    final s = AppSettings.i;
    if (s.manualPrimary) return;
    final now = DateTime.now();
    if (_lastAuto != null && now.difference(_lastAuto!) < const Duration(minutes: 10)) return;
    _lastAuto = now;
    final ask = !s.gpsAsked;
    if (ask) s.markGpsAsked();
    final r = await detect(ask: ask);
    if (!r.isOk) return;
    final first = !s.hasLocation;
    if (!first && _km(s.lat!, s.lng!, r.lat!, r.lng!) < 15) return;
    s.setLocation(r.lat!, r.lng!, placeName(r.lat!, r.lng!));
    if (first) await NotificationService.i.requestPermissionsOnce();
  }
}
