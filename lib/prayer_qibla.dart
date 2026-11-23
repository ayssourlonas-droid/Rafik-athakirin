// اتجاه القبلة: الاتجاه الأولي على دائرة عظمى من موقعك إلى الكعبة، بالدرجات من الشمال الحقيقي.
import 'dart:math' as math;

class Qibla {
  static const double kaabaLat = 21.422487;
  static const double kaabaLng = 39.826206;

  static double _rad(double d) => d * math.pi / 180.0;

  /// 0..360 مع عقارب الساعة من الشمال الحقيقي (لا المغناطيسي).
  static double bearing(double lat, double lng) {
    final p1 = _rad(lat);
    final p2 = _rad(kaabaLat);
    final dl = _rad(kaabaLng - lng);
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
    final deg = math.atan2(y, x) * 180.0 / math.pi;
    return (deg + 360.0) % 360.0;
  }

  static double distanceKm(double lat, double lng) {
    const r = 6371.0;
    final a = _rad(lat);
    final b = _rad(kaabaLat);
    final dLa = b - a;
    final dLo = _rad(kaabaLng - lng);
    final h = math.pow(math.sin(dLa / 2), 2) +
        math.cos(a) * math.cos(b) * math.pow(math.sin(dLo / 2), 2);
    return 2 * r * math.asin(math.sqrt(h.toDouble()));
  }

  static String directionName(double deg) {
    const names = [
      'الشمال',
      'الشمال الشرقي',
      'الشرق',
      'الجنوب الشرقي',
      'الجنوب',
      'الجنوب الغربي',
      'الغرب',
      'الشمال الغربي',
    ];
    return names[((deg + 22.5) % 360 ~/ 45).toInt()];
  }
}
