// رأس الرئيسية: الصلاة القادمة وعدّها التنازلي، وخلفية تتغير بحسب الوقت (فجر/نهار/عصر/غروب/ليل)،
// وقوس الشمس أو القمر (بطوره الفعلي ليلًا) يتحرك مع ساعة اليوم.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data_format.dart';
import 'data_hijri.dart';
import 'data_repo.dart';
import 'data_settings.dart';
import 'prayer_calc.dart';
import 'prayer_sky.dart';
import 'theme_app.dart';

enum _DayPhase { night, dawn, day, afternoon, dusk }

class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const List<Prayer> _fard = [
    Prayer.fajr,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ];

  static List<Color> _gradient(_DayPhase p) {
    switch (p) {
      case _DayPhase.night:
        return const [Color(0xFF001B1A), Color(0xFF012A33)];
      case _DayPhase.dawn:
        return const [Color(0xFF013537), Color(0xFFB36A4A)];
      case _DayPhase.day:
        return const [Color(0xFF025152), Color(0xFF1B9A98)];
      case _DayPhase.afternoon:
        return const [Color(0xFF025152), Color(0xFFC9954A)];
      case _DayPhase.dusk:
        return const [Color(0xFF013537), Color(0xFF6A3A4C)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.i;
    if (!s.hasLocation) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 110,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: AppDecor.glass(glow: true, radius: 30),
          child: const Text(
            'حدّد موقعك لتظهر الصلاة القادمة وعدّها التنازلي',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLight, fontSize: 17),
          ),
        ),
      );
    }

    final now = _now;
    final place = s.nowAtPlace();
    DayTimes day(int off) => s.timesFor(DateTime(place.year, place.month, place.day + off, 12));
    final yd = day(-1);
    final t0 = day(0);
    final t1 = day(1);

    Prayer? np;
    DateTime? nt;
    for (final t in [t0, t1]) {
      for (final p in _fard) {
        final x = t[p];
        if (x != null && x.isAfter(now)) {
          np = p;
          nt = x;
          break;
        }
      }
      if (np != null) break;
    }

    // طور اليوم
    final fajr = t0[Prayer.fajr];
    final sunrise = t0[Prayer.sunrise];
    final asr = t0[Prayer.asr];
    final maghrib = t0[Prayer.maghrib];
    final isha = t0[Prayer.isha];
    _DayPhase phase;
    if (fajr != null && sunrise != null && asr != null && maghrib != null && isha != null) {
      if (now.isBefore(fajr)) {
        phase = _DayPhase.night;
      } else if (now.isBefore(sunrise)) {
        phase = _DayPhase.dawn;
      } else if (now.isBefore(asr)) {
        phase = _DayPhase.day;
      } else if (now.isBefore(maghrib)) {
        phase = _DayPhase.afternoon;
      } else if (now.isBefore(isha)) {
        phase = _DayPhase.dusk;
      } else {
        phase = _DayPhase.night;
      }
    } else {
      phase = Sky.sunAt(now.toUtc(), s.lat!, s.lng!).altitude > 0 ? _DayPhase.day : _DayPhase.night;
    }

    // موضع الجرم على القوس: الشمس بين الشروق والغروب، والقمر بين الغروب والشروق التالي
    double? frac;
    var isSun = true;
    if (sunrise != null && maghrib != null) {
      if (!now.isBefore(sunrise) && now.isBefore(maghrib)) {
        frac = now.difference(sunrise).inSeconds / math.max(1, maghrib.difference(sunrise).inSeconds);
      } else {
        isSun = false;
        final before = now.isBefore(sunrise);
        final start = before ? yd[Prayer.maghrib] : maghrib;
        final end = before ? sunrise : t1[Prayer.sunrise];
        if (start != null && end != null && end.isAfter(start)) {
          frac = now.difference(start).inSeconds / math.max(1, end.difference(start).inSeconds);
        }
      }
    }
    final moon = Sky.phaseAt(now.toUtc());
    final stars = phase == _DayPhase.night ? 1.0 : (phase == _DayPhase.dusk || phase == _DayPhase.dawn ? 0.5 : 0.0);

    final hijri = Hijri.format(
        Hijri.fromGregorian(place.year, place.month, place.day, offsetDays: s.hijriOffset));

    String countdown = '--:--:--';
    if (nt != null) {
      final d = nt.difference(now);
      final h = d.inHours;
      final m = d.inMinutes % 60;
      final sec = d.inSeconds % 60;
      countdown = '${twoDigits(h)}:${twoDigits(m)}:${twoDigits(sec)}';
    }

    final shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(34),
      side: const BorderSide(color: AppColors.cardBorder),
    );
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 236,
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _gradient(phase),
          ),
          shape: shape,
          shadows: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 8)),
            BoxShadow(color: AppColors.goldGlow, blurRadius: 18),
          ],
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _SkyPainter(
                    fraction: frac,
                    isSun: isSun,
                    moonK: moon.illumination,
                    moonLitRight: moon.waxing == (s.lat! >= 0),
                    stars: stars,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hijri,
                            style: const TextStyle(color: AppColors.sand, fontSize: 13),
                          ),
                        ),
                        if (s.placeName.isNotEmpty)
                          Flexible(
                            child: Text(
                              s.placeName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.sand, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('الصلاة القادمة',
                        style: TextStyle(color: AppColors.textLight, fontSize: 14)),
                    Text(
                      np == null ? '—' : np.nameAr,
                      style: const TextStyle(
                          color: AppColors.goldSoft, fontSize: 34, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                    Text(
                      countdown,
                      style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          height: 1.2),
                    ),
                    if (nt != null)
                      Text(
                        'الساعة ${clockText(nt, s.tzId)}',
                        style: const TextStyle(color: AppColors.sand, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter({
    required this.fraction,
    required this.isSun,
    required this.moonK,
    required this.moonLitRight,
    required this.stars,
  });

  final double? fraction;
  final bool isSun;
  final double moonK;
  final bool moonLitRight;
  final double stars;

  @override
  void paint(Canvas canvas, Size size) {
    // نجوم ثابتة المواضع (مولّد بسيط)، تظهر ليلًا وعند الفجر والغروب
    if (stars > 0) {
      var seed = 7;
      double next() {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        return seed / 0x7fffffff;
      }

      for (var i = 0; i < 26; i++) {
        final x = next() * size.width;
        final y = next() * size.height * 0.62;
        final r = 0.6 + next() * 1.1;
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()..color = const Color(0xFFFAE6C0).withValues(alpha: (0.25 + next() * 0.5) * stars),
        );
      }
    }

    final cx = size.width / 2;
    final baseY = size.height - 22;
    final radius = math.min(size.width * 0.40, size.height * 0.34);
    final line = Paint()
      ..strokeWidth = 1
      ..color = const Color(0x40FAE6C0);
    canvas.drawLine(Offset(18, baseY), Offset(size.width - 18, baseY), line);

    // قوس منقّط لمسار الجرم
    final rect = Rect.fromCircle(center: Offset(cx, baseY), radius: radius);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0x55FAE6C0);
    for (var i = 0; i < 28; i++) {
      canvas.drawArc(rect, math.pi + i * math.pi / 28, math.pi / 70, false, dash);
    }

    final f = fraction;
    if (f == null) return;
    final a = math.pi * f.clamp(0.0, 1.0).toDouble();
    final p = Offset(cx - radius * math.cos(a), baseY - radius * math.sin(a));
    if (isSun) {
      canvas.drawCircle(p, 26, Paint()..color = const Color(0x40FFD27A));
      canvas.drawCircle(p, 13, Paint()..color = const Color(0xFFFFC857));
    } else {
      canvas.drawCircle(p, 24, Paint()..color = const Color(0x30FAE6C0));
      _moon(canvas, p, 12);
    }
  }

  void _moon(Canvas canvas, Offset center, double r) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (!moonLitRight) canvas.rotate(math.pi);
    final disc = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF3B4A52));
    final lit = Paint()..color = const Color(0xFFF5F0D8);
    if (moonK > 0.97) {
      canvas.drawCircle(Offset.zero, r, lit);
    } else if (moonK >= 0.03) {
      final rx = math.max(r * (1 - 2 * moonK).abs(), 0.01);
      final term = Rect.fromLTRB(-rx, -r, rx, r);
      final path = Path()
        ..moveTo(0, -r)
        ..arcTo(disc, -math.pi / 2, math.pi, false)
        ..arcTo(term, math.pi / 2, moonK < 0.5 ? -math.pi : math.pi, false)
        ..close();
      canvas.drawPath(path, lit);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.fraction != fraction ||
      old.isSun != isSun ||
      old.moonK != moonK ||
      old.moonLitRight != moonLitRight ||
      old.stars != stars;
}
