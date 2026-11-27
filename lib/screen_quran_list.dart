// قائمة السور + البحث في أسماء السور ونص الآيات.
import 'dart:async';

import 'package:flutter/material.dart';

import 'data_repo.dart';
import 'screen_quran_reader.dart';
import 'theme_app.dart';

class QuranListScreen extends StatefulWidget {
  const QuranListScreen({super.key, this.pickPage = false});

  /// true: عند اختيار سورة أو آية تُرجَع صفحتها في المصحف إلى الشاشة السابقة.
  final bool pickPage;

  @override
  State<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends State<QuranListScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<Surah> _surahs = Repo.i.surahs;
  List<AyahHit> _hits = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _query = text.trim();
        _surahs = Repo.i.searchSurahs(_query);
        _hits = Repo.i.searchAyahs(_query);
      });
    });
  }

  Future<void> _openSurah(int n, {int? ayah}) async {
    if (widget.pickPage) {
      await Repo.i.loadPages();
      if (!mounted) return;
      Navigator.of(context).pop(Repo.i.pageOfAyah(n, ayah ?? 1));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuranReaderScreen(surahNumber: n, initialAyah: ayah),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noResults = _query.isNotEmpty && _surahs.isEmpty && _hits.isEmpty;
    return AppScaffold(
      title: widget.pickPage ? 'فهرس السور' : 'القرآن الكريم',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              style: const TextStyle(color: AppColors.textLight, fontSize: 17),
              decoration: InputDecoration(
                hintText: 'ابحث عن سورة أو نص آية...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (final s in _surahs) _SurahTile(surah: s, onTap: () => _openSurah(s.n)),
                if (_hits.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                    child: Text(
                      'نتائج من نص الآيات (${_hits.length})',
                      style: const TextStyle(color: AppColors.gold, fontSize: 15),
                    ),
                  ),
                  for (final h in _hits)
                    _HitTile(hit: h, onTap: () => _openSurah(h.surah, ayah: h.ayah)),
                ],
                if (noResults)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('لا نتائج مطابقة',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.surah, required this.onTap});
  final Surah surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        customBorder: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(26)),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppDecor.glass(),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold),
                ),
                child: Text('${surah.n}',
                    style: const TextStyle(color: AppColors.gold, fontSize: 14)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(surah.ar,
                        style: const TextStyle(color: AppColors.textLight, fontSize: 20)),
                    const SizedBox(height: 2),
                    Text('${surah.type} • ${surah.ayahCount} آية',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              Text(surah.en,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onTap});
  final AyahHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = Repo.i.surah(hit.surah).ar;
    final text = hit.text.length > 90 ? '${hit.text.substring(0, 90)} ...' : hit.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        customBorder: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(26)),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: AppDecor.glass(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('سورة $name — آية ${hit.ayah}',
                  style: const TextStyle(color: AppColors.gold, fontSize: 15)),
              const SizedBox(height: 6),
              Text(
                text,
                style: const TextStyle(
                  fontFamily: AppText.quranFont,
                  color: AppColors.textLight,
                  fontSize: 20,
                  height: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
