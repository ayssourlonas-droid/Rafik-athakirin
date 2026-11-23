// العلامات المرجعية (حمراء/زرقاء) — علامة واحدة لكل آية، تُحفظ على الجهاز.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Bookmarks extends ChangeNotifier {
  Bookmarks._();
  static final Bookmarks i = Bookmarks._();

  static const String _prefKey = 'quran_bookmarks';
  static const String _lastPageKey = 'quran_last_page';
  static const String red = 'red';
  static const String blue = 'blue';

  final Map<String, String> _marks = {};

  /// آخر صفحة مصحف قُرئت (0 = لم تُقرأ صفحة بعد).
  int lastPage = 0;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    lastPage = _prefs!.getInt(_lastPageKey) ?? 0;
    final raw = _prefs!.getString(_prefKey);
    if (raw == null) return;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      decoded.forEach((k, v) => _marks[k] = v.toString());
    } catch (_) {
      // بيانات تالفة: نبدأ من جديد دون انهيار
    }
  }

  void setLastPage(int page) {
    if (page == lastPage) return;
    lastPage = page;
    _prefs?.setInt(_lastPageKey, page);
  }

  /// "red" أو "blue" أو null (بلا علامة)
  String? colorOf(int surah, int ayah) => _marks['$surah:$ayah'];

  /// الضغط على نفس اللون يزيل العلامة، ولون آخر يستبدلها.
  void toggle(int surah, int ayah, String color) {
    final key = '$surah:$ayah';
    if (_marks[key] == color) {
      _marks.remove(key);
    } else {
      _marks[key] = color;
    }
    _prefs?.setString(_prefKey, json.encode(_marks));
    notifyListeners();
  }
}
