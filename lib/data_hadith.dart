// الأربعون النووية وتتمتها (٥٠ حديثًا): النص كما في الملف دون تعديل.
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class Hadith {
  const Hadith(this.number, this.title, this.narrator, this.text, this.source);
  final int number;
  final String title;
  final String narrator;
  final String text;
  final String source;
}

class HadithRepo {
  HadithRepo._();
  static final HadithRepo i = HadithRepo._();

  List<Hadith> items = const [];
  String sourceNote = '';
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/data/nawawi_hadiths.json');
    final m = json.decode(raw) as Map<String, dynamic>;
    sourceNote = m['source'] as String? ?? '';
    items = [
      for (final e in m['hadiths'] as List)
        Hadith(
          (e as Map<String, dynamic>)['number'] as int,
          e['title'] as String,
          e['narrator'] as String,
          e['text'] as String,
          e['source'] as String,
        ),
    ];
    _loaded = true;
  }
}
