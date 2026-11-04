// مصدر البيانات الوحيد: القرآن، التفسير، صفحات المصحف، والبحث.
// كل الملفات تُحمَّل من assets عند الحاجة فقط (التفسير سورة بسورة).
import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/services.dart' show rootBundle;

// ───────────────────── تطبيع النص العربي للبحث ─────────────────────
final RegExp _marksRe =
    RegExp('[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]');
final RegExp _longVowelsRe = RegExp('[اويى]');

/// المستوى الأول: إزالة التشكيل وعلامات التلاوة وتوحيد الهمزات والألف.
String normalizeArabic(String t) {
  var s = t.replaceAll(_marksRe, '');
  s = s
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ٱ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ء', '');
  return s.toLowerCase();
}

/// المستوى الثاني (هيكل الحروف): يتجاهل حروف المد، فيطابق الإملاء المعتاد
/// ("الصلاة") مع الرسم العثماني ("ٱلصَّلَوٰةَ").
String arabicSkeleton(String t) => normalizeArabic(t).replaceAll(_longVowelsRe, '');

/// أرقام عربية-هندية (٠١٢٣٤٥٦٧٨٩) لأرقام الآيات والصفحات.
String arDigits(int n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

// ───────────────────── النماذج ─────────────────────
class Surah {
  Surah({
    required this.n,
    required this.ar,
    required this.en,
    required this.type,
    required this.ayahs,
  });

  final int n;
  final String ar;
  final String en;
  final String type;
  final List<String> ayahs;

  int get ayahCount => ayahs.length;
  bool get hasBasmalaHeader => n != 1 && n != 9;
}

class AyahHit {
  AyahHit(this.surah, this.ayah, this.text);
  final int surah;
  final int ayah;
  final String text;
}

/// كتلة داخل صفحة المصحف: اسم سورة ('s') أو بسملة ('b') أو آيات ('a').
class MushafBlock {
  MushafBlock(this.type, this.surah, this.ayahs);
  final String type;
  final int surah;
  final List<int> ayahs;
}

class _Row {
  _Row(this.surah, this.ayah, this.text, this.n1, this.sk);
  final int surah;
  final int ayah;
  final String text;
  final String n1;
  final String sk;
}

// ───────────────────── المستودع ─────────────────────
class Repo {
  Repo._();
  static final Repo i = Repo._();

  static const String basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
  static const int pageCount = 604;

  List<Surah> surahs = const [];
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    final idxStr = await rootBundle.loadString('assets/data/surah_index.json');
    final quranStr = await rootBundle.loadString('assets/data/quran_uthmani.json');
    final idx = (json.decode(idxStr) as List).cast<Map<String, dynamic>>();
    final q = (json.decode(quranStr) as Map<String, dynamic>)['surahs'] as List;
    final out = <Surah>[];
    for (var i = 0; i < idx.length; i++) {
      final m = idx[i];
      final ayahs = (q[i] as Map<String, dynamic>)['ayahs'] as List;
      out.add(Surah(
        n: m['n'] as int,
        ar: m['ar'] as String,
        en: m['en'] as String,
        type: m['type'] as String,
        ayahs: ayahs.map((e) => e.toString()).toList(),
      ));
    }
    surahs = out;
    _ready = true;
  }

  Surah surah(int n) => surahs[n - 1];

  // ─────────── البحث ───────────
  List<_Row>? _rows;

  void _buildIndex() {
    if (_rows != null) return;
    final rows = <_Row>[];
    for (final s in surahs) {
      for (var a = 0; a < s.ayahs.length; a++) {
        final t = s.ayahs[a];
        final n1 = normalizeArabic(t);
        rows.add(_Row(s.n, a + 1, t, n1, n1.replaceAll(_longVowelsRe, '')));
      }
    }
    _rows = rows;
  }

  List<Surah> searchSurahs(String query) {
    final q = query.trim();
    if (q.isEmpty) return surahs;
    final nq = normalizeArabic(q);
    final lq = q.toLowerCase();
    final asNumber = int.tryParse(q);
    return surahs.where((s) {
      if (asNumber != null && s.n == asNumber) return true;
      return normalizeArabic(s.ar).contains(nq) || s.en.toLowerCase().contains(lq);
    }).toList();
  }

  /// بحث في نص الآيات: النتائج المطابقة حرفيًا أولًا، ثم المطابقة بهيكل الحروف.
  List<AyahHit> searchAyahs(String query, {int max = 40}) {
    final q = query.trim();
    if (q.length < 2) return const [];
    _buildIndex();
    final n1q = normalizeArabic(q);
    final skq = arabicSkeleton(q);
    final first = <AyahHit>[];
    final second = <AyahHit>[];
    for (final r in _rows!) {
      if (n1q.isNotEmpty && r.n1.contains(n1q)) {
        first.add(AyahHit(r.surah, r.ayah, r.text));
      } else if (skq.length >= 3 && r.sk.contains(skq)) {
        second.add(AyahHit(r.surah, r.ayah, r.text));
      }
      if (first.length >= max) break;
    }
    final all = [...first, ...second];
    return all.length > max ? all.sublist(0, max) : all;
  }

  // ─────────── التفسير الميسر ───────────
  int _tafsirSurah = -1;
  List<String> _tafsirCache = const [];

  Future<List<String>> loadSurahTafsir(int surah) async {
    if (_tafsirSurah == surah) return _tafsirCache;
    var list = <String>[];
    try {
      final data = await rootBundle.load('assets/data/tafsir_muyassar/$surah.json.gz');
      final bytes = gzip.decode(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      list = (json.decode(utf8.decode(bytes)) as List).map((e) => e.toString()).toList();
    } catch (_) {
      list = <String>[];
    }
    _tafsirSurah = surah;
    _tafsirCache = list;
    return list;
  }

  Future<String> tafsirOf(int surah, int ayah) async {
    final list = await loadSurahTafsir(surah);
    final idx = ayah - 1;
    if (idx < 0 || idx >= list.length) return '';
    return list[idx];
  }

  // ─────────── صفحات المصحف (604) ───────────
  List<List<MushafBlock>>? _pages;
  final Map<int, int> _ayahPage = {};
  final Map<int, int> _surahPage = {};

  Future<void> loadPages() async {
    if (_pages != null) return;
    final data = await rootBundle.load('assets/data/mushaf_pages.json.gz');
    final bytes = gzip.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    final raw = json.decode(utf8.decode(bytes)) as List;
    final pages = <List<MushafBlock>>[];
    for (var p = 0; p < raw.length; p++) {
      final blocks = <MushafBlock>[];
      for (final b in raw[p] as List) {
        final m = b as Map<String, dynamic>;
        final type = m['t'] as String;
        final s = (m['s'] as int?) ?? 0;
        final list = ((m['list'] as List?) ?? const []).map((e) => e as int).toList();
        blocks.add(MushafBlock(type, s, list));
        if (type == 's') {
          _surahPage.putIfAbsent(s, () => p + 1);
        } else if (type == 'a') {
          for (final a in list) {
            _ayahPage.putIfAbsent(s * 1000 + a, () => p + 1);
          }
        }
      }
      pages.add(blocks);
    }
    _pages = pages;
  }

  List<MushafBlock> pageBlocks(int page) {
    final p = _pages;
    if (p == null || page < 1 || page > p.length) return const [];
    return p[page - 1];
  }

  int pageOfAyah(int surah, int ayah) => _ayahPage[surah * 1000 + ayah] ?? pageOfSurah(surah);
  int pageOfSurah(int surah) => _surahPage[surah] ?? 1;
}
