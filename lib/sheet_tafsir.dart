// نافذة التفسير الميسر (مجمع الملك فهد) لآية واحدة. الاقتباس القرآني ﴿ ﴾ يُلوَّن وقت العرض فقط.
import 'package:flutter/material.dart';

import 'data_repo.dart';
import 'theme_app.dart';

void showTafsirSheet(BuildContext context, int surah, int ayah) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TafsirSheet(surah: surah, ayah: ayah),
  );
}

final RegExp _quoteRe = RegExp('﴿[^﴾]*﴾');

List<InlineSpan> _tafsirSpans(String text) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in _quoteRe.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    spans.add(TextSpan(
      text: m.group(0),
      style: const TextStyle(
        fontFamily: AppText.quranFont,
        color: AppColors.quoteGreen,
        fontSize: 22,
      ),
    ));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

class _TafsirSheet extends StatefulWidget {
  const _TafsirSheet({required this.surah, required this.ayah});

  final int surah;
  final int ayah;

  @override
  State<_TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<_TafsirSheet> {
  late final Future<String> _future = Repo.i.tafsirOf(widget.surah, widget.ayah);

  @override
  Widget build(BuildContext context) {
    final name = Repo.i.surah(widget.surah).ar;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgMid,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'التفسير الميسر — سورة $name • آية ${widget.ayah}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.gold, fontSize: 18),
                ),
              ),
              Expanded(
                child: FutureBuilder<String>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      );
                    }
                    final text = snap.data ?? '';
                    return ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      children: [
                        if (text.isEmpty)
                          const Center(
                            child: Text(
                              'التفسير غير متوفر لهذه الآية',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                            ),
                          )
                        else
                          Text.rich(
                            TextSpan(children: _tafsirSpans(text)),
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 19,
                              height: 1.9,
                            ),
                          ),
                        const SizedBox(height: 20),
                        const Text(
                          'المصدر: التفسير الميسر — مجمع الملك فهد لطباعة المصحف الشريف',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
