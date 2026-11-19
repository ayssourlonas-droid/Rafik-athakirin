// تحديد الموقع عبر GPS (يحتاج إذن الموقع). عند الفشل نُرجع سببًا مفهومًا بدل استثناء.
import 'package:geolocator/geolocator.dart';

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
  static Future<LocationOutcome> detect() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return LocationOutcome.fail('خدمة الموقع مغلقة في الهاتف. فعّلها ثم أعد المحاولة.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
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
}
