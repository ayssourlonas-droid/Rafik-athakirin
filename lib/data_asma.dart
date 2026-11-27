// الأسماء الحسنى: ٢٥ مجموعة بشرحها كما في الملف (دار الدرر السنية) دون تعديل.
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class AsmaGroup {
  const AsmaGroup(this.id, this.names, this.explanation);
  final int id;
  final List<String> names;
  final String explanation;
}

class AsmaRepo {
  AsmaRepo._();
  static final AsmaRepo i = AsmaRepo._();

  List<AsmaGroup> groups = const [];
  String source = '';
  String note = '';
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/data/asma_husna.json');
    final m = json.decode(raw) as Map<String, dynamic>;
    source = m['source'] as String? ?? '';
    note = m['note'] as String? ?? '';
    groups = [
      for (final e in m['groups'] as List)
        AsmaGroup(
          (e as Map<String, dynamic>)['id'] as int,
          [for (final n in e['names'] as List) n.toString()],
          e['explanation'] as String,
        ),
    ];
    _loaded = true;
  }
}
