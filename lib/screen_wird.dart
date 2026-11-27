// ورد القرآن: هدف يومي بالصفحات، وتقدّم الختمة، وسلسلة الأيام، وتذكير يومي.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data_format.dart';
import 'data_repo.dart';
import 'data_settings.dart';
import 'data_wird.dart';
import 'screen_quran_book.dart';
import 'theme_app.dart';

class WirdScreen extends StatelessWidget {
  const WirdScreen({super.key});

  String _fmtTime(int minutes) {
    final h24 = minutes ~/ 60;
    final m = minutes % 60;
    final h = h24 % 12 == 0 ? 12 : h24 % 12;
    return '${arDigits(h)}:${twoDigits(m)} ${h24 < 12 ? 'ص' : 'م'}';
  }

  Future<void> _confirmNewKhatma(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text('بدء ختمة جديدة؟', style: TextStyle(color: AppColors.gold)),
        content: const Text(
          'سيُصفَّر تقدّم الختمة الحالية. عدد الختمات المكتملة وسلسلة الأيام يبقيان.',
          style: TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ابدأ')),
        ],
      ),
    );
    if (ok == true) Wird.i.newKhatma();
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: AppDecor.glass(),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppColors.textLight, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'ورد القرآن',
      body: ListenableBuilder(
        listenable: Listenable.merge([Wird.i, AppSettings.i]),
        builder: (context, _) => _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final w = Wird.i;
    final s = AppSettings.i;
    final today = w.todayCount;
    final days = w.daysToFinish;
    final pct = (w.khatmaProgress * 100).floor();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: AppDecor.glass(glow: w.goalReached),
          child: Column(
            children: [
              SizedBox(
                width: 190,
                height: 190,
                child: CustomPaint(
                  painter: _RingPainter(today / w.goal),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(arDigits(today),
                            style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 54,
                                fontWeight: FontWeight.bold,
                                height: 1.1)),
                        Text('من ${arDigits(w.goal)} صفحة',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                w.goalReached
                    ? 'أتممتَ وردك اليوم ✓ تقبّل الله منك'
                    : 'بقي ${arDigits(w.goal - today)} صفحة لإتمام وردك اليوم',
                style: TextStyle(
                  color: w.goalReached ? AppColors.goldSoft : AppColors.textLight,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: AppDecor.glass(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('وردك اليومي',
                      style: TextStyle(color: AppColors.textLight, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => w.setGoal(w.goal - 1),
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.gold),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text('${arDigits(w.goal)} ص',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textLight, fontSize: 16)),
                  ),
                  IconButton(
                    onPressed: () => w.setGoal(w.goal + 1),
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.gold),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in const [1, 2, 5, 10, 20])
                    ChoiceChip(
                      label: Text(n == 20 ? 'جزء (${arDigits(n)})' : arDigits(n)),
                      selected: w.goal == n,
                      showCheckmark: false,
                      backgroundColor: Colors.transparent,
                      selectedColor: AppColors.gold,
                      labelStyle: TextStyle(
                          color: w.goal == n ? AppColors.bgDeep : AppColors.textLight),
                      side: const BorderSide(color: AppColors.cardBorder),
                      onSelected: (_) => w.setGoal(n),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppDecor.glass(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ختمتك الحالية: ${arDigits(w.khatmaCount)} من ${arDigits(Wird.totalPages)} صفحة (${arDigits(pct)}٪)',
                style: const TextStyle(color: AppColors.textLight, fontSize: 15),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: w.khatmaProgress,
                  minHeight: 10,
                  backgroundColor: AppColors.cardBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
              if (days != null) ...[
                const SizedBox(height: 8),
                Text(
                  'بهذا الورد تُتمّ الختمة بعد نحو ${arDigits(days)} يومًا إن واظبتَ',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _stat('ختمات مكتملة', arDigits(w.khatmas)),
            const SizedBox(width: 8),
            _stat('أيام متتالية', arDigits(w.streak)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const QuranBookScreen())),
            icon: const Icon(Icons.menu_book),
            label: const Text('تابع القراءة', style: TextStyle(fontSize: 18)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bgDeep,
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _confirmNewKhatma(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.gold,
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          child: const Text('بدء ختمة جديدة'),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.gold,
          title: const Text('تذكير يومي بالورد', style: TextStyle(color: AppColors.textLight)),
          subtitle: Text(
            'الساعة ${_fmtTime(s.wirdReminderMinutes)} — يحتاج إذن الإشعارات وتحديد موقعك',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          value: s.wirdReminder,
          onChanged: s.setWirdReminder,
        ),
        if (s.wirdReminder)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                      hour: s.wirdReminderMinutes ~/ 60, minute: s.wirdReminderMinutes % 60),
                );
                if (t != null) s.setWirdReminderTime(t.hour * 60 + t.minute);
              },
              icon: const Icon(Icons.schedule, size: 18),
              label: const Text('تغيير الوقت'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.cardBorder),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          'تُحتسب الصفحة مقروءة إذا بقيتَ عليها ${arDigits(Wird.dwellSeconds)} ثوانٍ في المصحف، فلا يُعدّ التقليب السريع. '
          'الذي تقرؤه من «عرض الآيات» لا يُحتسب هنا، بل من صفحات المصحف.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.6),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = AppColors.cardBorder,
    );
    final p = progress.clamp(0.0, 1.0).toDouble();
    if (p > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * p,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..color = p >= 1.0 ? const Color(0xFF4CAF50) : AppColors.gold,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
