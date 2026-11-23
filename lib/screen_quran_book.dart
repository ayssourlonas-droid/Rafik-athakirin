// «كتاب القرآن»: يفتح مباشرة على آخر صفحة قرأتَ فيها من المصحف، بصفحة تملأ الشاشة.
// الفهرس (قائمة السور والبحث) وعرض الآيات بالبطاقات من أيقونات الشريط العلوي.
import 'package:flutter/material.dart';

import 'data_bookmarks.dart';
import 'data_repo.dart';
import 'screen_quran_list.dart';
import 'screen_quran_reader.dart';
import 'theme_app.dart';
import 'view_mushaf_pages.dart';

class QuranBookScreen extends StatefulWidget {
  const QuranBookScreen({super.key});

  @override
  State<QuranBookScreen> createState() => _QuranBookScreenState();
}

class _QuranBookScreenState extends State<QuranBookScreen> {
  final Future<void> _pages = Repo.i.loadPages();
  late int _start;
  late int _current;
  int _epoch = 0; // يتغيّر عند القفز من الفهرس ليُبنى المصحف على الصفحة الجديدة

  @override
  void initState() {
    super.initState();
    final last = Bookmarks.i.lastPage;
    _start = (last >= 1 && last <= Repo.pageCount) ? last : 1;
    _current = _start;
  }

  void _onPage(int p) {
    _current = p; // دون setState: يُستدعى أثناء البناء
    Bookmarks.i.setLastPage(p);
  }

  Future<void> _openIndex() async {
    final page = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(builder: (_) => const QuranListScreen(pickPage: true)),
    );
    if (page == null || !mounted) return;
    setState(() {
      _start = page;
      _current = page;
      _epoch++;
    });
  }

  void _openAyahs() {
    MushafBlock? first;
    for (final blk in Repo.i.pageBlocks(_current)) {
      if (blk.ayahs.isNotEmpty) {
        first = blk;
        break;
      }
    }
    final b = first;
    if (b == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuranReaderScreen(surahNumber: b.surah, initialAyah: b.ayahs.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'القرآن الكريم',
      actions: [
        IconButton(
          tooltip: 'عرض الآيات',
          icon: const Icon(Icons.view_agenda_outlined, color: AppColors.gold),
          onPressed: _openAyahs,
        ),
        IconButton(
          tooltip: 'الفهرس والبحث',
          icon: const Icon(Icons.menu_book, color: AppColors.gold),
          onPressed: _openIndex,
        ),
      ],
      body: FutureBuilder<void>(
        future: _pages,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          return MushafPagesView(
            key: ValueKey('book$_epoch'),
            initialPage: _start,
            onPageChanged: _onPage,
          );
        },
      ),
    );
  }
}
