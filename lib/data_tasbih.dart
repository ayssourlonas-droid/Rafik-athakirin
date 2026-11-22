// المسبحة: الذكر الحالي والعدّ والدورات والمجاميع، تُحفظ على الجهاز.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dhikr {
  const Dhikr(this.id, this.text, this.short, this.target);
  final String id;
  final String text; // النص الكامل
  final String short; // اسم مختصر للشريحة
  final int target; // 0 = عدّ مفتوح
}

const List<Dhikr> kDhikrs = [
  Dhikr('subhan', 'سبحان الله', 'سبحان الله', 33),
  Dhikr('hamd', 'الحمد لله', 'الحمد لله', 33),
  Dhikr('akbar', 'الله أكبر', 'الله أكبر', 34),
  Dhikr('tahlil', 'لا إله إلا الله', 'لا إله إلا الله', 100),
  Dhikr('istighfar', 'أستغفر الله', 'أستغفر الله', 100),
  Dhikr('salawat', 'اللهم صلِّ وسلِّم على نبينا محمد', 'الصلاة على النبي', 100),
  Dhikr('subhan_hamd', 'سبحان الله وبحمده', 'سبحان الله وبحمده', 100),
  Dhikr('hawqala', 'لا حول ولا قوة إلا بالله', 'الحوقلة', 100),
  Dhikr('tabarak', 'تبارك الله', 'تبارك الله', 100),
  Dhikr('free', 'تسبيح حر', 'عدّ حر', 0),
];

enum TasbihEvent { tick, roundDone, stepDone, allDone }

class Tasbih extends ChangeNotifier {
  Tasbih._();
  static final Tasbih i = Tasbih._();

  static const String afterPrayerId = 'after_prayer';
  static const List<String> _seq = ['subhan', 'hamd', 'akbar']; // ٣٣ ثم ٣٣ ثم ٣٤
  static const List<int> _seqTargets = [33, 33, 34];
  static const String _prefKey = 'tasbih_state';

  SharedPreferences? _prefs;
  String currentId = 'subhan';
  int seqIndex = 0;
  bool vibrate = true;
  bool sound = true;
  static const int maxCustoms = 12;
  final List<Dhikr> _customs = [];
  final Map<String, int> _count = {};
  final Map<String, int> _rounds = {};
  final Map<String, int> _total = {};
  final Map<String, int> _target = {};
  String _todayKey = '';
  int _today = 0;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_prefKey);
    if (raw == null) return;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      final rawCustoms = m['customs'];
      if (rawCustoms is List) {
        for (final c in rawCustoms) {
          if (c is Map && c['id'] is String && c['t'] is String && _customs.length < maxCustoms) {
            final tg = c['n'] is int ? c['n'] as int : 0;
            _customs.add(_makeCustom(c['id'] as String, c['t'] as String, tg));
          }
        }
      }
      final cur = m['cur'] as String? ?? 'subhan';
      currentId = (cur == afterPrayerId || all.any((d) => d.id == cur)) ? cur : 'subhan';
      seqIndex = ((m['seq'] as int?) ?? 0).clamp(0, _seq.length - 1).toInt();
      vibrate = m['vib'] as bool? ?? true;
      sound = m['snd'] as bool? ?? true;
      _fill(_count, m['count']);
      _fill(_rounds, m['rounds']);
      _fill(_total, m['total']);
      _fill(_target, m['target']);
      _todayKey = m['dayKey'] as String? ?? '';
      _today = (m['today'] as int?) ?? 0;
    } catch (_) {
      // بيانات تالفة: نبدأ من جديد دون انهيار
    }
  }

  static void _fill(Map<String, int> out, dynamic v) {
    if (v is Map) {
      v.forEach((k, x) {
        if (x is int) out[k.toString()] = x;
      });
    }
  }

  void _save() {
    _prefs?.setString(
      _prefKey,
      json.encode({
        'cur': currentId,
        'seq': seqIndex,
        'vib': vibrate,
        'snd': sound,
        'customs': [
          for (final d in _customs) {'id': d.id, 't': d.text, 'n': d.target},
        ],
        'count': _count,
        'rounds': _rounds,
        'total': _total,
        'target': _target,
        'dayKey': _todayKey,
        'today': _today,
      }),
    );
  }

  void _rollDay() {
    final n = DateTime.now();
    final k = '${n.year}-${n.month}-${n.day}';
    if (k != _todayKey) {
      _todayKey = k;
      _today = 0;
    }
  }

  // ───────── الحالة الحالية ─────────
  bool get isSequence => currentId == afterPrayerId;
  int get seqLength => _seq.length;
  String get _stateKey => isSequence ? 'seq' : currentId;

  List<Dhikr> get all => [...kDhikrs, ..._customs];
  bool isCustom(String id) => _customs.any((d) => d.id == id);

  Dhikr _byId(String id) => all.firstWhere((d) => d.id == id, orElse: () => kDhikrs.first);

  static Dhikr _makeCustom(String id, String text, int target) {
    final short = text.length > 18 ? '${text.substring(0, 17)}…' : text;
    return Dhikr(id, text, short, target < 0 ? 0 : target);
  }

  /// يضيف ذكرًا بنصك ويختاره. false إن كان النص فارغًا أو طويلًا أو بلغت الحد الأقصى.
  bool addCustom(String text, int target) {
    final t = text.trim();
    if (t.isEmpty || t.length > 60 || _customs.length >= maxCustoms) return false;
    final id = 'c${DateTime.now().millisecondsSinceEpoch}';
    _customs.add(_makeCustom(id, t, target));
    currentId = id;
    _save();
    notifyListeners();
    return true;
  }

  void removeCustom(String id) {
    _customs.removeWhere((d) => d.id == id);
    _count.remove(id);
    _rounds.remove(id);
    _total.remove(id);
    _target.remove(id);
    if (currentId == id) currentId = 'subhan';
    _save();
    notifyListeners();
  }

  Dhikr get active => _byId(isSequence ? _seq[seqIndex] : currentId);
  int get target => isSequence ? _seqTargets[seqIndex] : (_target[currentId] ?? active.target);
  int get count => _count[_stateKey] ?? 0;
  int get rounds => _rounds[_stateKey] ?? 0;
  int get total => _total[active.id] ?? 0;
  int get today {
    _rollDay();
    return _today;
  }

  // ───────── الأفعال ─────────
  void select(String id) {
    if (id == currentId) return;
    currentId = id;
    _save();
    notifyListeners();
  }

  TasbihEvent tap() {
    _rollDay();
    final key = _stateKey;
    final d = active;
    var c = (_count[key] ?? 0) + 1;
    _total[d.id] = (_total[d.id] ?? 0) + 1;
    _today++;
    var event = TasbihEvent.tick;
    final t = target;
    if (t > 0 && c >= t) {
      c = 0;
      if (isSequence) {
        if (seqIndex < _seq.length - 1) {
          seqIndex++;
          event = TasbihEvent.stepDone;
        } else {
          seqIndex = 0;
          _rounds[key] = (_rounds[key] ?? 0) + 1;
          event = TasbihEvent.allDone;
        }
      } else {
        _rounds[key] = (_rounds[key] ?? 0) + 1;
        event = TasbihEvent.roundDone;
      }
    }
    _count[key] = c;
    _save();
    notifyListeners();
    return event;
  }

  void undo() {
    final c = count;
    if (c <= 0) return;
    final id = active.id;
    _count[_stateKey] = c - 1;
    _total[id] = ((_total[id] ?? 1) - 1).clamp(0, 1 << 31).toInt();
    _rollDay();
    if (_today > 0) _today--;
    _save();
    notifyListeners();
  }

  void reset() {
    _count[_stateKey] = 0;
    _rounds[_stateKey] = 0;
    if (isSequence) seqIndex = 0;
    _save();
    notifyListeners();
  }

  void setTarget(int t) {
    if (isSequence) return;
    final v = t < 0 ? 0 : t;
    _target[currentId] = v;
    if (v > 0 && count >= v) _count[currentId] = 0;
    _save();
    notifyListeners();
  }

  void toggleSound() {
    sound = !sound;
    _save();
    notifyListeners();
  }

  void toggleVibrate() {
    vibrate = !vibrate;
    _save();
    notifyListeners();
  }
}
