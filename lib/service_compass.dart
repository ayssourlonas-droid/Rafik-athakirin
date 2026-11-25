// بوصلة حيّة من حسّاس اتجاه الهاتف (كود أندرويد في MainActivity)، مصحَّحة إلى الشمال الحقيقي.
import 'package:flutter/services.dart' show EventChannel;

class CompassReading {
  const CompassReading(this.heading, this.accuracy);

  /// اتجاه أعلى الهاتف بالدرجات من الشمال الحقيقي مع عقارب الساعة (0..360).
  final double heading;

  /// دقة الحسّاس: 0 غير موثوق، 1 منخفضة، 2 متوسطة، 3 عالية.
  final int accuracy;
}

class CompassService {
  static const EventChannel _ch = EventChannel('rafiq/compass');

  /// موقعك لازم لحساب الانحراف المغناطيسي (الفرق بين الشمال المغناطيسي والحقيقي).
  static Stream<CompassReading> stream(double lat, double lng) {
    return _ch.receiveBroadcastStream(<String, double>{'lat': lat, 'lng': lng}).map((e) {
      final m = e as Map<Object?, Object?>;
      return CompassReading((m['h'] as num).toDouble(), (m['a'] as num).toInt());
    });
  }
}
