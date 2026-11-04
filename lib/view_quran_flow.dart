// وضع "الصفحة" المتصلة: نص السورة كاملًا متدفقًا، ورقم كل آية ملاصق للنص.
import 'package:flutter/material.dart';

import 'data_repo.dart';
import 'theme_app.dart';

class AyahFlowView extends StatelessWidget {
  const AyahFlowView({super.key, required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    for (var i = 0; i < surah.ayahs.length; i++) {
      spans.add(TextSpan(text: '${surah.ayahs[i]} '));
      spans.add(TextSpan(
        text: '﴿${arDigits(i + 1)}﴾ ',
        style: const TextStyle(color: AppColors.gold, fontSize: 22),
      ));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          if (surah.hasBasmalaHeader)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                Repo.basmala,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppText.quranFont,
                  fontSize: 28,
                  height: 1.8,
                  color: AppColors.gold,
                ),
              ),
            ),
          Text.rich(
            TextSpan(children: spans),
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: AppText.quranFont,
              fontSize: 28,
              height: 2.1,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
