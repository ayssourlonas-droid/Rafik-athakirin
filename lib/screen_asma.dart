// الأسماء الحسنى: مجموعات مرتبة بقرب المعاني، مع بحث وشرح.
import 'package:flutter/material.dart';

import 'data_asma.dart';
import 'data_repo.dart';
import 'theme_app.dart';

class AsmaScreen extends StatefulWidget {
  const AsmaScreen({super.key});

  @override
  State<AsmaScreen> createState() => _AsmaScreenState();
}

class _AsmaScreenState extends State<AsmaScreen> {
  final Future<void> _load = AsmaRepo.i.load();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الأسماء الحسنى',
      body: FutureBuilder<void>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return Center(
              child: Text('تعذّر تحميل الأسماء:\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textLight)),
            );
          }
          final repo = AsmaRepo.i;
          final nq = normalizeArabic(_q.trim());
          final list = [
            for (final g in repo.groups)
              if (nq.isEmpty || normalizeArabic('${g.names.join(' ')} ${g.explanation}').contains(nq)) g,
          ];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  style: const TextStyle(color: AppColors.textLight, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'ابحث في الأسماء وشرحها',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    prefixIcon: Icon(Icons.search, color: AppColors.gold),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: Text('لا نتائج', style: TextStyle(color: AppColors.textMuted))),
                      ),
                    for (final g in list)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: AppDecor.glass(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              children: [
                                for (final n in g.names)
                                  Text(n,
                                      style: const TextStyle(
                                          color: AppColors.gold,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              g.explanation,
                              textAlign: TextAlign.justify,
                              style: const TextStyle(
                                  color: AppColors.textLight, fontSize: 16, height: 1.9),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(repo.note,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.7)),
                    const SizedBox(height: 6),
                    Text(repo.source,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.6)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
