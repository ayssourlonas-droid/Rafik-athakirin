// وضع البطاقات: كل آية بطاقة مستقلة، فيها زر التفسير وعلامتان مرجعيتان (حمراء/زرقاء).
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'data_bookmarks.dart';
import 'data_repo.dart';
import 'sheet_tafsir.dart';
import 'theme_app.dart';

class AyahCardsView extends StatelessWidget {
  const AyahCardsView({super.key, required this.surah, this.initialAyah});

  final Surah surah;
  final int? initialAyah;

  @override
  Widget build(BuildContext context) {
    final header = surah.hasBasmalaHeader ? 1 : 0;
    final total = header + surah.ayahCount;
    var start = 0;
    if (initialAyah != null) {
      start = initialAyah! - 1 + header;
      if (start < 0) start = 0;
      if (start > total - 1) start = total - 1;
    }
    return ScrollablePositionedList.builder(
      itemCount: total,
      initialScrollIndex: start,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemBuilder: (context, i) {
        if (header == 1 && i == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                Repo.basmala,
                style: TextStyle(
                  fontFamily: AppText.quranFont,
                  fontSize: 28,
                  height: 1.8,
                  color: AppColors.gold,
                ),
              ),
            ),
          );
        }
        final a = i - header + 1;
        return _AyahCard(surah: surah.n, number: a, text: surah.ayahs[a - 1]);
      },
    );
  }
}

class _AyahCard extends StatelessWidget {
  const _AyahCard({required this.surah, required this.number, required this.text});

  final int surah;
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      decoration: AppDecor.glass(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 6),
            child: Text(
              '﴿${arDigits(number)}﴾',
              style: const TextStyle(color: AppColors.gold, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontFamily: AppText.quranFont,
                fontSize: 26,
                height: 2.0,
                color: AppColors.textLight,
              ),
            ),
          ),
          Column(
            children: [
              IconButton(
                tooltip: 'التفسير',
                onPressed: () => showTafsirSheet(context, surah, number),
                icon: const Text('📖', style: TextStyle(fontSize: 22)),
              ),
              ListenableBuilder(
                listenable: Bookmarks.i,
                builder: (context, _) {
                  final c = Bookmarks.i.colorOf(surah, number);
                  return Column(
                    children: [
                      _Dot(
                        color: AppColors.bookmarkRed,
                        active: c == Bookmarks.red,
                        onTap: () => Bookmarks.i.toggle(surah, number, Bookmarks.red),
                      ),
                      const SizedBox(height: 4),
                      _Dot(
                        color: AppColors.bookmarkBlue,
                        active: c == Bookmarks.blue,
                        onTap: () => Bookmarks.i.toggle(surah, number, Bookmarks.blue),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.active, required this.onTap});

  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : color.withAlpha(26),
            border: active ? null : Border.all(color: color.withAlpha(140)),
          ),
        ),
      ),
    );
  }
}
