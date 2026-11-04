// شاشة قراءة السورة بثلاثة أوضاع: بطاقات، صفحة متصلة، ومصحف حقيقي (604 صفحة).
import 'package:flutter/material.dart';

import 'data_repo.dart';
import 'theme_app.dart';
import 'view_mushaf_pages.dart';
import 'view_quran_cards.dart';
import 'view_quran_flow.dart';

class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key, required this.surahNumber, this.initialAyah});

  final int surahNumber;
  final int? initialAyah;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  int _mode = 0; // 0 بطاقات، 1 صفحة متصلة، 2 مصحف حقيقي
  final Future<void> _pages = Repo.i.loadPages();

  Widget _body(Surah s) {
    switch (_mode) {
      case 1:
        return AyahFlowView(key: ValueKey('f${s.n}'), surah: s);
      case 2:
        return FutureBuilder<void>(
          future: _pages,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            return MushafPagesView(
              initialPage: Repo.i.pageOfAyah(s.n, widget.initialAyah ?? 1),
            );
          },
        );
      default:
        return AyahCardsView(
          key: ValueKey('c${s.n}'),
          surah: s,
          initialAyah: widget.initialAyah,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Repo.i.surah(widget.surahNumber);
    return AppScaffold(
      title: 'سورة ${s.ar}',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<int>(value: 0, label: Text('بطاقات')),
                ButtonSegment<int>(value: 1, label: Text('صفحة')),
                ButtonSegment<int>(value: 2, label: Text('المصحف')),
              ],
              selected: {_mode},
              onSelectionChanged: (v) => setState(() => _mode = v.first),
              style: SegmentedButton.styleFrom(
                foregroundColor: AppColors.textLight,
                selectedForegroundColor: AppColors.bgDeep,
                selectedBackgroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.cardBorder),
              ),
            ),
          ),
          Expanded(child: _body(s)),
        ],
      ),
    );
  }
}
