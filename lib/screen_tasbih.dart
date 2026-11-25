// المسبحة: اضغط في أي مكان من المنطقة الوسطى للعدّ.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data_format.dart';
import 'data_repo.dart';
import 'data_settings.dart';
import 'data_tasbih.dart';
import 'service_sfx.dart';
import 'theme_app.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  final Tasbih _t = Tasbih.i;
  bool _pressed = false;
  String? _flash;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    Sfx.load(const ['tasbih_tick', 'tasbih_done']);
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _showFlash(String msg) {
    _flashTimer?.cancel();
    setState(() => _flash = msg);
    _flashTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  void _tap() {
    final ev = _t.tap();
    if (_t.sound) Sfx.play(ev == TasbihEvent.tick ? 'tasbih_tick' : 'tasbih_done');
    if (_t.vibrate) {
      if (ev == TasbihEvent.tick) {
        HapticFeedback.selectionClick();
      } else if (ev == TasbihEvent.allDone) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
    if (ev == TasbihEvent.roundDone) {
      _showFlash('اكتملت الدورة ${arDigits(_t.rounds)} ✓');
    } else if (ev == TasbihEvent.stepDone) {
      _showFlash('التالي: ${_t.active.text}');
    } else if (ev == TasbihEvent.allDone) {
      _showFlash('تقبّل الله منك 🤲');
    }
  }

  int? _parseInt(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in s.trim().split('')) {
      final i = ar.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    return int.tryParse(b.toString());
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text('تصفير العدّاد؟', style: TextStyle(color: AppColors.gold)),
        content: Text(
          _t.isSequence
              ? 'سيعود التسبيح بعد الصلاة إلى البداية.'
              : 'سيُصفَّر عدّ «${_t.active.short}» ودوراته، ويبقى المجموع الكلي.',
          style: const TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تصفير')),
        ],
      ),
    );
    if (ok == true) _t.reset();
  }

  Future<void> _askTarget() async {
    final controller = TextEditingController(text: _t.target > 0 ? '${_t.target}' : '');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text('الهدف', style: TextStyle(color: AppColors.gold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final n in const [33, 99, 100, 1000, 0])
                  ActionChip(
                    label: Text(n == 0 ? 'مفتوح' : arDigits(n)),
                    onPressed: () => Navigator.pop(ctx, n),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textLight, fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'أو اكتب رقمًا (٠ = مفتوح)',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
              onSubmitted: (s) => Navigator.pop(ctx, _parseInt(s)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _parseInt(controller.text)),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (v != null) _t.setTarget(v);
  }

  Widget _chip(String id, String label, {bool custom = false}) {
    final selected = _t.currentId == id;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onLongPress: custom ? () => _confirmDelete(id) : null,
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          backgroundColor: Colors.transparent,
          selectedColor: AppColors.gold,
          labelStyle: TextStyle(color: selected ? AppColors.bgDeep : AppColors.textLight),
          side: const BorderSide(color: AppColors.cardBorder),
          onSelected: (_) => _t.select(id),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final name = _t.all.firstWhere((d) => d.id == id, orElse: () => kDhikrs.first).short;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text('حذف الذكر؟', style: TextStyle(color: AppColors.gold)),
        content: Text('سيُحذف «$name» وعدّه ومجموعه.',
            style: const TextStyle(color: AppColors.textLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) _t.removeCustom(id);
  }

  Future<void> _addCustom() async {
    if (_t.all.length - kDhikrs.length >= Tasbih.maxCustoms) {
      _showFlash('بلغت الحد الأقصى (${arDigits(Tasbih.maxCustoms)} أذكار مخصصة)');
      return;
    }
    final text = TextEditingController();
    final target = TextEditingController(text: '33');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text('ذكر جديد', style: TextStyle(color: AppColors.gold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: text,
              maxLength: 60,
              style: const TextStyle(color: AppColors.textLight, fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'نص الذكر',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextField(
              controller: target,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textLight, fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'الهدف (٠ = مفتوح)',
                labelStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
        ],
      ),
    );
    if (ok == true) {
      final good = _t.addCustom(text.text, _parseInt(target.text) ?? 0);
      if (!good) _showFlash('اكتب نص الذكر (حتى ٦٠ حرفًا)');
    }
  }

  String _fmtTime(int minutes) {
    final h24 = minutes ~/ 60;
    final m = minutes % 60;
    final h = h24 % 12 == 0 ? 12 : h24 % 12;
    return '${arDigits(h)}:${twoDigits(m)} ${h24 < 12 ? 'ص' : 'م'}';
  }

  void _showReminders() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgMid,
      isScrollControlled: true,
      builder: (ctx) => ListenableBuilder(
        listenable: AppSettings.i,
        builder: (ctx, _) {
          final s = AppSettings.i;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تذكيرات المسبحة',
                    style: TextStyle(color: AppColors.gold, fontSize: 18)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.gold,
                  title: const Text('تسبيح ما بعد الصلاة',
                      style: TextStyle(color: AppColors.textLight)),
                  subtitle: Text(
                    'إشعار بعد كل صلاة بـ${arDigits(s.tasbihDelayMin)} دقيقة',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  value: s.tasbihAfterPrayer,
                  onChanged: s.setTasbihAfterPrayer,
                ),
                if (s.tasbihAfterPrayer)
                  Row(
                    children: [
                      const Text('بعد الصلاة بـ', style: TextStyle(color: AppColors.textMuted)),
                      IconButton(
                        onPressed: () => s.setTasbihDelay(s.tasbihDelayMin - 5),
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.gold),
                      ),
                      Text('${arDigits(s.tasbihDelayMin)} د',
                          style: const TextStyle(color: AppColors.textLight, fontSize: 16)),
                      IconButton(
                        onPressed: () => s.setTasbihDelay(s.tasbihDelayMin + 5),
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.gold),
                      ),
                    ],
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.gold,
                  title: const Text('تذكير يومي',
                      style: TextStyle(color: AppColors.textLight)),
                  subtitle: Text('الساعة ${_fmtTime(s.tasbihDailyMinutes)}',
                      style: const TextStyle(color: AppColors.textMuted)),
                  value: s.tasbihDaily,
                  onChanged: s.setTasbihDaily,
                ),
                if (s.tasbihDaily)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay(
                            hour: s.tasbihDailyMinutes ~/ 60, minute: s.tasbihDailyMinutes % 60),
                      );
                      if (t != null) s.setTasbihDailyTime(t.hour * 60 + t.minute);
                    },
                    icon: const Icon(Icons.schedule, size: 18),
                    label: const Text('تغيير الوقت'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'تحتاج التذكيرات إذن الإشعارات وتحديد موقعك. الضغط على الإشعار يفتح التطبيق.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: AppDecor.glass(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
                color: AppColors.textLight, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _counter(int count, int target) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // الصفر بالأرقام العربية (٠) يظهر نقطة تشبه خللًا في الرسم، فنكتب تلميحًا بدله
        count == 0
            ? const Text(
                'اضغط للعدّ',
                style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    height: 1.6),
              )
            : Text(
                arDigits(count),
                style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 76,
                    fontWeight: FontWeight.bold,
                    height: 1.1),
              ),
        Text(
          target > 0 ? 'من ${arDigits(target)}' : 'عدّ مفتوح',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
        ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final d = _t.active;
    final target = _t.target;
    final count = _t.count;
    final btn = OutlinedButton.styleFrom(
      foregroundColor: AppColors.gold,
      side: const BorderSide(color: AppColors.cardBorder),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(Tasbih.afterPrayerId, 'بعد الصلاة (${arDigits(33)}·${arDigits(33)}·${arDigits(34)})'),
                for (final k in _t.all) _chip(k.id, k.short, custom: _t.isCustom(k.id)),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ActionChip(
                    label: const Text('＋ ذكر جديد'),
                    backgroundColor: Colors.transparent,
                    labelStyle: const TextStyle(color: AppColors.gold),
                    side: const BorderSide(color: AppColors.gold),
                    onPressed: _addCustom,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_t.isSequence)
            Text(
              'المرحلة ${arDigits(_t.seqIndex + 1)} من ${arDigits(_t.seqLength)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          Text(
            d.text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gold, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: 28,
            child: Center(
              child: Text(_flash ?? '',
                  style: const TextStyle(color: AppColors.goldSoft, fontSize: 15)),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                setState(() => _pressed = true);
                _tap();
              },
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: Center(
                child: AnimatedScale(
                  scale: _pressed ? 0.965 : 1.0,
                  duration: const Duration(milliseconds: 90),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final side = math.min(math.min(c.maxWidth, c.maxHeight), 340.0);
                      return SizedBox(
                        width: side,
                        height: side,
                        child: CustomPaint(
                          painter: _BeadsPainter(count: count, target: target),
                          child: Center(child: _counter(count, target)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _stat('الدورات', arDigits(_t.rounds))),
              const SizedBox(width: 8),
              Expanded(child: _stat('كل الأذكار اليوم', arDigits(_t.today))),
              const SizedBox(width: 8),
              Expanded(child: _stat('إجمالي الذكر', arDigits(_t.total))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: count > 0 ? _t.undo : null,
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('تراجع'),
                  style: btn,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _confirmReset,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('تصفير'),
                  style: btn,
                ),
              ),
              if (!_t.isSequence) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _askTarget,
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('الهدف'),
                    style: btn,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'المسبحة',
      actions: [
        IconButton(
          tooltip: 'التذكيرات',
          icon: const Icon(Icons.notifications_active_outlined, color: AppColors.gold),
          onPressed: _showReminders,
        ),
        ListenableBuilder(
          listenable: _t,
          builder: (context, _) => IconButton(
            tooltip: _t.sound ? 'إيقاف الصوت' : 'تشغيل الصوت',
            icon: Icon(_t.sound ? Icons.volume_up : Icons.volume_off,
                color: _t.sound ? AppColors.gold : AppColors.textMuted),
            onPressed: _t.toggleSound,
          ),
        ),
        ListenableBuilder(
          listenable: _t,
          builder: (context, _) => IconButton(
            tooltip: _t.vibrate ? 'إيقاف الاهتزاز' : 'تشغيل الاهتزاز',
            icon: Icon(Icons.vibration, color: _t.vibrate ? AppColors.gold : AppColors.textMuted),
            onPressed: _t.toggleVibrate,
          ),
        ),
      ],
      body: ListenableBuilder(listenable: _t, builder: (context, _) => _content(context)),
    );
  }
}

/// حبّات حول الدائرة (للأهداف حتى ٤٠)، وقوس تقدّم للأهداف الأكبر.
class _BeadsPainter extends CustomPainter {
  _BeadsPainter({required this.count, required this.target});

  final int count;
  final int target;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 16;
    canvas.drawCircle(c, r + 12, Paint()..color = AppColors.cardBg);
    canvas.drawCircle(
      c,
      r + 12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.cardBorder,
    );
    if (target > 0 && target <= 40) {
      for (var i = 0; i < target; i++) {
        final a = -math.pi / 2 + 2 * math.pi * i / target;
        final p = c + Offset(math.cos(a), math.sin(a)) * r;
        final on = i < count;
        canvas.drawCircle(
          p,
          on ? 7.5 : 6.0,
          Paint()..color = on ? AppColors.gold : AppColors.cardBorder,
        );
      }
    } else {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = AppColors.cardBorder,
      );
      if (target > 0) {
        final sweep = 2 * math.pi * (count / target).clamp(0.0, 1.0).toDouble();
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10
            ..strokeCap = StrokeCap.round
            ..color = AppColors.gold,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BeadsPainter old) => old.count != count || old.target != target;
}
