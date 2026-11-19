// الشاشة الرئيسية: شبكة الأقسام (القرآن فعّال، والباقي قادم تباعًا).
import 'package:flutter/material.dart';

import 'screen_prayer_times.dart';
import 'screen_quran_list.dart';
import 'screen_settings.dart';
import 'theme_app.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<_Tile> _tiles = [
    _Tile('📖', 'القرآن الكريم', true),
    _Tile('📜', 'الأحاديث', false),
    _Tile('🤲', 'الوضوء والصلاة', false),
    _Tile('💚', 'الأذكار', false),
    _Tile('📿', 'المسبحة', false),
    _Tile('🕌', 'أوقات الصلاة', true),
    _Tile('📜', 'قصص السيرة', false),
    _Tile('🧭', 'اتجاه القبلة', false),
  ];

  void _open(BuildContext context, _Tile t) {
    if (t.enabled) {
      final Widget screen =
          t.label == 'أوقات الصلاة' ? const PrayerTimesScreen() : const QuranListScreen();
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('قريباً إن شاء الله 🚧')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'رفيق الذاكرين',
      actions: [
        IconButton(
          tooltip: 'الإعدادات',
          icon: const Icon(Icons.settings, color: AppColors.gold),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'أهلاً وسهلاً',
              style: TextStyle(color: AppColors.gold, fontSize: 20),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.25,
                children: [
                  for (final t in _tiles) _TileView(tile: t, onTap: () => _open(context, t)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile {
  const _Tile(this.emoji, this.label, this.enabled);
  final String emoji;
  final String label;
  final bool enabled;
}

class _TileView extends StatelessWidget {
  const _TileView({required this.tile, required this.onTap});
  final _Tile tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Ink(
        decoration: AppDecor.glass(glow: tile.enabled),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tile.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 8),
              Text(
                tile.label,
                style: TextStyle(
                  fontSize: 18,
                  color: tile.enabled ? AppColors.textLight : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
