// ورد القرآن: صفحات اليوم وتقدّم الختمة والسلسلة اليومية، تُحفظ على الجهاز.
// الصفحة تُحتسب مقروءة إذا بقيتَ عليها [dwellSeconds] ثوانٍ في المصحف (لا يُحتسب التقليب السريع).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Wird extends ChangeNotifier {
  Wird._();
  static final Wird i = Wird._();

  static const int totalPages = 604;
  static const int dwellSeconds = 8;
  static const String _key = 'wird_state';

  SharedPreferences? _prefs;
  int goal = 2; // صفحات يوميًا
  int khatmas = 0; // ختمات مكتملة
  String lastGoalDay = ''; // آخر يوم أتممتَ فيه الورد
  int _streakAtLast = 0; // طول السلسلة عند آخر يوم أتممتَ فيه
  String? khatmaStart; // بداية الختمة الحالية
  String _dayKey = '';
  final Set<int> _today = {};
  final Set<int> _khatma = {};
  Timer? _timer;

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _todayStr() => _fmt(DateTime.now());
  static String _yesterdayStr() {
    final n = DateTime.now();
    return _fmt(DateTime(n.year, n.month, n.day - 1));
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) return;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      goal = ((m['goal'] as int?) ?? 2).clamp(1, 60).toInt();
      khatmas = (m['khatmas'] as int?) ?? 0;
      lastGoalDay = m['lastGoalDay'] as String? ?? '';
      _streakAtLast = (m['streak'] as int?) ?? 0;
      khatmaStart = m['start'] as String?;
      _dayKey = m['dayKey'] as String? ?? '';
      for (final p in (m['today'] as List? ?? const [])) {
        if (p is int && p >= 1 && p <= totalPages) _today.add(p);
      }
      for (final p in (m['khatma'] as List? ?? const [])) {
        if (p is int && p >= 1 && p <= totalPages) _khatma.add(p);
      }
    } catch (_) {
      // بيانات تالفة: نبدأ من جديد دون انهيار
    }
  }

  void _save() {
    _prefs?.setString(
      _key,
      json.encode({
        'goal': goal,
        'khatmas': khatmas,
        'lastGoalDay': lastGoalDay,
        'streak': _streakAtLast,
        'start': khatmaStart,
        'dayKey': _dayKey,
        'today': _today.toList()..sort(),
        'khatma': _khatma.toList()..sort(),
      }),
    );
  }

  void _roll() {
    final t = _todayStr();
    if (t != _dayKey) {
      _dayKey = t;
      _today.clear();
    }
  }

  // ───────── القراءة ─────────
  int get todayCount {
    _roll();
    return _today.length;
  }

  int get khatmaCount => _khatma.length;
  double get khatmaProgress => _khatma.length / totalPages;
  bool get goalReached => todayCount >= goal;

  /// طول السلسلة الحالية بالأيام (صفر إن انقطعت).
  int get streak {
    if (lastGoalDay == _todayStr() || lastGoalDay == _yesterdayStr()) return _streakAtLast;
    return 0;
  }

  /// أيام إتمام الختمة بهذا الورد (null إن لم يبقَ شيء).
  int? get daysToFinish {
    final remaining = totalPages - _khatma.length;
    return remaining <= 0 ? null : (remaining / goal).ceil();
  }

  /// أُدخلت صفحة في المصحف؛ تُحتسب بعد البقاء عليها بضع ثوانٍ.
  void visit(int page) {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: dwellSeconds), () => _commit(page));
  }

  /// غادر المستخدم المصحف قبل مرور المدة: لا تُحتسب الصفحة.
  void leave() {
    _timer?.cancel();
    _timer = null;
  }

  void _commit(int page) {
    if (page < 1 || page > totalPages) return;
    _roll();
    final newToday = _today.add(page);
    final newKhatma = _khatma.add(page);
    if (!newToday && !newKhatma) return;
    khatmaStart ??= _todayStr();
    if (newToday && _today.length >= goal && lastGoalDay != _todayStr()) {
      _streakAtLast = (lastGoalDay == _yesterdayStr()) ? _streakAtLast + 1 : 1;
      lastGoalDay = _todayStr();
    }
    if (_khatma.length >= totalPages) {
      khatmas++;
      _khatma.clear();
      khatmaStart = null;
    }
    _save();
    notifyListeners();
  }

  // ───────── الإعدادات ─────────
  void setGoal(int g) {
    goal = g.clamp(1, 60).toInt();
    _save();
    notifyListeners();
  }

  void newKhatma() {
    _khatma.clear();
    khatmaStart = null;
    _save();
    notifyListeners();
  }
}
