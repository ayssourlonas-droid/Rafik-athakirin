// اتجاه القبلة: زاوية من الشمال الحقيقي وسهم على قرص. بلا بوصلة حيّة بعد (تحتاج حسّاسات الهاتف).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data_repo.dart';
import 'data_settings.dart';
import 'prayer_qibla.dart';
import 'theme_app.dart';

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.i;
    return AppScaffold(
      title: 'اتجاه القبلة',
      body: !s.hasLocation
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'حدّد موقعك أولًا من شاشة أوقات الصلاة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textLight, fontSize: 18),
                ),
              ),
            )
          : _content(s.lat!, s.lng!, s.placeName),
    );
  }

  Widget _content(double lat, double lng, String place) {
    final bearing = Qibla.bearing(lat, lng);
    final km = Qibla.distanceKm(lat, lng).round();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (place.isNotEmpty)
            Text(place, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '${arDigits(bearing.round())}° من الشمال',
            style: const TextStyle(color: AppColors.gold, fontSize: 40, fontWeight: FontWeight.bold),
          ),
          Text(
            'باتجاه ${Qibla.directionName(bearing)}',
            style: const TextStyle(color: AppColors.textLight, fontSize: 18),
          ),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  final side = math.min(math.min(c.maxWidth, c.maxHeight), 320.0);
                  return SizedBox(
                    width: side,
                    height: side,
                    child: CustomPaint(painter: _DialPainter(bearing)),
                  );
                },
              ),
            ),
          ),
          Text(
            'المسافة إلى مكة المكرمة: ${arDigits(km)} كم',
            style: const TextStyle(color: AppColors.textLight, fontSize: 15),
          ),
          const SizedBox(height: 10),
          const Text(
            'وجّه أعلى هاتفك نحو الشمال (بوصلة الهاتف أو الخرائط) فيشير السهم إلى القبلة. '
            'الزاوية بالنسبة للشمال الحقيقي، وبوصلة الهاتف مغناطيسية فقد تختلف قليلًا. '
            'تحقق من محراب مسجد قريب إن أمكن.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.bearing);

  final double bearing;

  void _label(Canvas canvas, String text, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = AppColors.cardBg);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.cardBorder,
    );
    // تدريجات كل ٣٠ درجة
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final d = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(
        c + d * (r - (i % 3 == 0 ? 14 : 8)),
        c + d * r,
        Paint()
          ..strokeWidth = i % 3 == 0 ? 2.5 : 1.2
          ..color = AppColors.cardBorder,
      );
    }
    _label(canvas, 'شمال', c + Offset(0, -(r - 30)), 14, AppColors.gold);
    _label(canvas, 'شرق', c + Offset(r - 30, 0), 12, AppColors.textMuted);
    _label(canvas, 'جنوب', c + Offset(0, r - 30), 12, AppColors.textMuted);
    _label(canvas, 'غرب', c + Offset(-(r - 30), 0), 12, AppColors.textMuted);

    // سهم القبلة
    final a = bearing * math.pi / 180.0;
    final dir = Offset(math.sin(a), -math.cos(a));
    final tip = c + dir * (r - 52);
    canvas.drawLine(
      c,
      tip,
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold,
    );
    canvas.drawCircle(c, 7, Paint()..color = AppColors.gold);
    _label(canvas, '🕋', c + dir * (r - 36), 30, AppColors.gold);
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.bearing != bearing;
}
