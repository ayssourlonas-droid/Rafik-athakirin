// الأحاديث: قائمة بحث ثم صفحة حديث يُقلَّب بينها بالسحب.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data_hadith.dart';
import 'data_repo.dart';
import 'theme_app.dart';

class HadithListScreen extends StatefulWidget {
  const HadithListScreen({super.key});

  @override
  State<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends State<HadithListScreen> {
  final Future<void> _load = HadithRepo.i.load();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الأحاديث',
      body: FutureBuilder<void>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return Center(
              child: Text('تعذّر تحميل الأحاديث:\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textLight)),
            );
          }
          final all = HadithRepo.i.items;
          final nq = normalizeArabic(_q.trim());
          final list = [
            for (var i = 0; i < all.length; i++)
              if (nq.isEmpty || normalizeArabic('${all[i].title} ${all[i].text}').contains(nq)) i,
          ];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  style: const TextStyle(color: AppColors.textLight, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'ابحث في عناوين الأحاديث ونصوصها',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    prefixIcon: Icon(Icons.search, color: AppColors.gold),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(
                        child: Text('لا نتائج', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, k) {
                          final idx = list[k];
                          final h = all[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.cardBg,
                              foregroundColor: AppColors.gold,
                              child: Text(arDigits(h.number)),
                            ),
                            title: Text(h.title,
                                style: const TextStyle(color: AppColors.textLight, fontSize: 17)),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => HadithScreen(initialIndex: idx)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final h = HadithRepo.i.items[_index];
    await Clipboard.setData(ClipboardData(text: '${h.title}\n${h.narrator}\n${h.text}\n\n${h.source}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ الحديث')));
  }

  @override
  Widget build(BuildContext context) {
    final items = HadithRepo.i.items;
    return AppScaffold(
      title: 'حديث رقم ${arDigits(items[_index].number)}',
      actions: [
        IconButton(
          tooltip: 'نسخ',
          icon: const Icon(Icons.copy, color: AppColors.gold),
          onPressed: _copy,
        ),
      ],
      body: PageView.builder(
        controller: _controller,
        itemCount: items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final h = items[i];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  h.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  h.narrator.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.7),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecor.glass(),
                  child: SelectableText(
                    h.text,
                    textAlign: TextAlign.justify,
                    style: const TextStyle(color: AppColors.textLight, fontSize: 22, height: 2.0),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  h.source,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.8),
                ),
                const SizedBox(height: 18),
                Text(
                  HadithRepo.i.sourceNote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.6),
                ),
                const SizedBox(height: 6),
                const Text(
                  'اسحب يمينًا ويسارًا للتنقل بين الأحاديث',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
