// اتجاه القبلة: بوصلة حيّة تدير القرص مع هاتفك، وبدونها (جهاز بلا حسّاس) يبقى قرص ثابت إلى الشمال.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data_format.dart';
import 'data_repo.dart';
import 'data_settings.dart';
import 'prayer_qibla.dart';
import 'prayer_sky.dart';
import 'service_compass.dart';
import 'service_timezone.dart';
import 'theme_app.dart';

const Color _kAligned = Color(0xFF4CAF50);

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with WidgetsBindingObserver {
  StreamSubscription<CompassReading>? _sub;
  double? _heading; // null = لا بوصلة حيّة
  int _accuracy = 3;
  bool _aligned = false;
  bool _failed = false;

  SkySnapshot? _sky;
  SkyDay? _day;
  String _dayKey = '';
  Timer? _skyTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSky());
    _skyTimer = Timer.periodic(const Duration(seconds: 20), (_) => _updateSky());
  }

  // موضع الشمس والقمر يتحرك ببطء؛ تحديثه كل ٢٠ ثانية يكفي. بيانات اليوم (الشروق والغروب) مرة لكل يوم وموقع.
  void _updateSky() {
    final s = AppSettings.i;
    if (!s.hasLocation || !mounted) return;
    final place = s.nowAtPlace();
    final off = TzService.offsetAt(s.tzId, place.year, place.month, place.day) ??
        DateTime(place.year, place.month, place.day, 12).timeZoneOffset;
    final start = DateTime.utc(place.year, place.month, place.day).subtract(off);
    final key = '${s.lat!.toStringAsFixed(2)}|${s.lng!.toStringAsFixed(2)}|${start.millisecondsSinceEpoch}';
    if (key != _dayKey || _day == null) {
      _dayKey = key;
      _day = Sky.day(start, s.lat!, s.lng!);
    }
    final snap = Sky.at(DateTime.now().toUtc(), s.lat!, s.lng!, _day!);
    setState(() => _sky = snap);
  }

  @override
  void dispose() {
    _skyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused) {
      _stop(); // لا نستهلك البطارية والتطبيق في الخلفية
    }
  }

  double _bearing() => Qibla.bearing(AppSettings.i.lat!, AppSettings.i.lng!);

  void _start() {
    final s = AppSettings.i;
    if (!s.hasLocation) return;
    _stop();
    _sub = CompassService.stream(s.lat!, s.lng!).listen(
      _onReading,
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _heading = null;
            _failed = true;
          });
        }
      },
      cancelOnError: true,
    );
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
  }

  // فرق مُوقَّع بين زاويتين في المدى (-180, 180]
  static double _diff(double to, double from) => ((to - from + 540.0) % 360.0) - 180.0;

  void _onReading(CompassReading r) {
    final prev = _heading;
    final h = prev == null ? r.heading : (prev + 0.25 * _diff(r.heading, prev) + 360.0) % 360.0;
    final aligned = _diff(_bearing(), h).abs() < 3.0;
    if (aligned && !_aligned) HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() {
      _heading = h;
      _accuracy = r.accuracy;
      _aligned = aligned;
      _failed = false;
    });
  }

  String _t(DateTime? x) => x == null ? '—' : clockText(x, AppSettings.i.tzId);

  String _altText(double alt) => alt >= 0 ? 'فوق الأفق ${arDigits(alt.round())}°' : 'تحت الأفق';

  Widget _skyPanel() {
    final k = _sky;
    if (k == null) return const SizedBox.shrink();
    final sd = k.day.sun;
    final md = k.day.moon;
    final sun = (sd.rise == null && sd.set == null)
        ? (sd.upAtStart ? 'الشمس لا تغيب اليوم' : 'الشمس لا تشرق اليوم')
        : 'الشروق ${_t(sd.rise)}  •  الغروب ${_t(sd.set)}';
    final pct = arDigits((k.phase.illumination * 100).round());
    final moon = (md.rise == null && md.set == null)
        ? '${k.phase.name} $pct٪  •  لا شروق ولا غروب اليوم'
        : '${k.phase.name} $pct٪  •  شروق ${_t(md.rise)}  •  غروب ${_t(md.set)}';
    const st = TextStyle(color: AppColors.textLight, fontSize: 13, height: 1.5);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppDecor.glass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('☀️  $sun', style: st),
          Text('🌙  $moon', style: st),
          Text(
            'الآن: الشمس ${_altText(k.sun.altitude)}  •  القمر ${_altText(k.moon.altitude)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _guide(double bearing, double h) {
    final d = _diff(bearing, h);
    if (d.abs() < 3.0) return 'أنت متجه نحو القبلة ✓';
    return d > 0 ? 'استدر يمينًا ${arDigits(d.round())}°' : 'استدر يسارًا ${arDigits((-d).round())}°';
  }

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
          : _content(s),
    );
  }

  Widget _content(AppSettings s) {
    final bearing = _bearing();
    final km = Qibla.distanceKm(s.lat!, s.lng!).round();
    final h = _heading;
    final live = h != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (s.placeName.isNotEmpty)
            Text(s.placeName, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '${arDigits(bearing.round())}° من الشمال',
            style: const TextStyle(color: AppColors.gold, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          Text(
            'باتجاه ${Qibla.directionName(bearing)}',
            style: const TextStyle(color: AppColors.textLight, fontSize: 17),
          ),
          SizedBox(
            height: 40,
            child: Center(
              child: Text(
                h != null ? _guide(bearing, h) : '',
                style: TextStyle(
                  color: _aligned ? _kAligned : AppColors.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  final side = math.min(math.min(c.maxWidth, c.maxHeight), 340.0);
                  return SizedBox(
                    width: side,
                    height: side,
                    child: CustomPaint(
                      painter: _DialPainter(
                          bearing: bearing, heading: h ?? 0, aligned: _aligned, sky: _sky),
                    ),
                  );
                },
              ),
            ),
          ),
          if (live && _accuracy <= 1)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'البوصلة تحتاج معايرة: حرّك الهاتف في الهواء على شكل ٨ عدة مرات.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.gold, fontSize: 13),
              ),
            ),
          _skyPanel(),
          const SizedBox(height: 8),
          Text(
            'المسافة إلى مكة المكرمة: ${arDigits(km)} كم',
            style: const TextStyle(color: AppColors.textLight, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            live
                ? 'ضع الهاتف مسطّحًا بعيدًا عن المعادن والمغناطيس، وعندما يصير رمز الكعبة أعلى القرص تحت المثلث تكون متجهًا إلى القبلة. '
                    'القوس البرتقالي على الحافة مسار الشمس اليوم، والنقطتان شروقها وغروبها. '
                    'البوصلة مصحَّحة إلى الشمال الحقيقي، ومع ذلك تحقق من محراب مسجد قريب إن أمكن.'
                : (_failed
                    ? 'تعذّر تشغيل البوصلة في هذا الجهاز. وجّه أعلى هاتفك نحو الشمال (بوصلة الهاتف أو الخرائط) فيشير السهم إلى القبلة.'
                    : 'جارٍ تشغيل البوصلة... وإن لم تعمل فوجّه أعلى هاتفك نحو الشمال فيشير السهم إلى القبلة.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.bearing,
    required this.heading,
    required this.aligned,
    required this.sky,
  });

  final double bearing;
  final double heading;
  final bool aligned;
  final SkySnapshot? sky;

  // نكتب النص منتصبًا دائمًا رغم دوران القرص
  void _label(Canvas canvas, String text, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.rtl,
    )..layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(heading * math.pi / 180.0);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
    tp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 12;
    final accent = aligned ? _kAligned : AppColors.gold;

    canvas.drawCircle(c, r, Paint()..color = AppColors.cardBg);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = aligned ? _kAligned : AppColors.cardBorder,
    );

    // القرص يدور عكس اتجاه هاتفك
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-heading * math.pi / 180.0);
    canvas.translate(-c.dx, -c.dy);

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
    _label(canvas, 'شمال', c + Offset(0, -(r - 32)), 14, AppColors.gold);
    _label(canvas, 'شرق', c + Offset(r - 32, 0), 12, AppColors.textMuted);
    _label(canvas, 'جنوب', c + Offset(0, r - 32), 12, AppColors.textMuted);
    _label(canvas, 'غرب', c + Offset(-(r - 32), 0), 12, AppColors.textMuted);

    final a = bearing * math.pi / 180.0;
    final dir = Offset(math.sin(a), -math.cos(a));
    canvas.drawLine(
      c,
      c + dir * (r - 56),
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );
    _label(canvas, '🕋', c + dir * (r - 40), 32, accent);

    final k = sky;
    if (k != null) _drawSky(canvas, c, r, k);
    canvas.restore();

    canvas.drawCircle(c, 7, Paint()..color = accent);

    // مثلث ثابت: اتجاه أعلى هاتفك
    final tri = Path()
      ..moveTo(c.dx - 11, c.dy - r - 8)
      ..lineTo(c.dx + 11, c.dy - r - 8)
      ..lineTo(c.dx, c.dy - r + 12)
      ..close();
    canvas.drawPath(tri, Paint()..color = accent);
  }

  Offset _on(Offset c, double radius, double azimuth) {
    final a = azimuth * math.pi / 180.0;
    return c + Offset(math.sin(a), -math.cos(a)) * radius;
  }

  // يُرسم داخل القرص الدوّار: القوس والنقطتان والشمس والقمر تتحرك مع الاتجاهات الحقيقية
  void _drawSky(Canvas canvas, Offset c, double r, SkySnapshot k) {
    const sunColor = Color(0xFFFFB300);
    // مسار الشمس اليوم على الحافة
    final arcRect = Rect.fromCircle(center: c, radius: r - 3);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xB3FF9800);
    final path = k.day.sunPath;
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      if (a == null || b == null) continue;
      final sweep = ((b - a + 540.0) % 360.0) - 180.0;
      canvas.drawArc(arcRect, (a - 90.0) * math.pi / 180.0, sweep * math.pi / 180.0, false, arcPaint);
    }
    final sd = k.day.sun;
    if (sd.riseAz != null) {
      canvas.drawCircle(_on(c, r - 3, sd.riseAz!), 6, Paint()..color = const Color(0xFFFFE082));
    }
    if (sd.setAz != null) {
      canvas.drawCircle(_on(c, r - 3, sd.setAz!), 6, Paint()..color = const Color(0xFFE64A19));
    }

    // الشمس والقمر في اتجاههما الحالي؛ باهتان إن كانا تحت الأفق
    final sunPos = _on(c, r - 76, k.sun.azimuth);
    final moonPos = _on(c, math.max(r * 0.38, r - 104), k.moon.azimuth);
    final sunA = k.sun.altitude >= -0.83 ? 1.0 : 0.35;
    final moonA = k.moon.altitude >= -0.83 ? 1.0 : 0.35;

    canvas.drawCircle(sunPos, 11, Paint()..color = sunColor.withValues(alpha: sunA));
    final ray = Paint()
      ..strokeWidth = 2
      ..color = sunColor.withValues(alpha: sunA);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(sunPos + d * 14, sunPos + d * 19, ray);
    }

    // الجانب المضاء من القمر يواجه الشمس
    final v = sunPos - moonPos;
    _drawMoon(canvas, moonPos, 13, k.phase.illumination, math.atan2(v.dy, v.dx), moonA);
  }

  // قرص القمر: الجزء المضاء على الجهة +x ثم يُدار نحو الشمس. الحد الفاصل نصف قطع ناقص.
  void _drawMoon(Canvas canvas, Offset center, double radius, double k, double angle, double alpha) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final disc = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawCircle(Offset.zero, radius, Paint()..color = const Color(0xFF3B4A52).withValues(alpha: alpha));
    final lit = Paint()..color = const Color(0xFFF5F0D8).withValues(alpha: alpha);
    if (k > 0.97) {
      canvas.drawCircle(Offset.zero, radius, lit);
    } else if (k >= 0.03) {
      final rx = math.max(radius * (1 - 2 * k).abs(), 0.01);
      final term = Rect.fromLTRB(-rx, -radius, rx, radius);
      final p = Path()
        ..moveTo(0, -radius)
        ..arcTo(disc, -math.pi / 2, math.pi, false)
        ..arcTo(term, math.pi / 2, k < 0.5 ? -math.pi : math.pi, false)
        ..close();
      canvas.drawPath(p, lit);
    }
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.textMuted.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.bearing != bearing || old.heading != heading || old.aligned != aligned || old.sky != sky;
}
