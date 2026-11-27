// الشاشة الرئيسية: شبكة الأقسام (القرآن فعّال، والباقي قادم تباعًا).
import 'package:flutter/material.dart';

import 'screen_asma.dart';
import 'screen_hadith.dart';
import 'screen_prayer_times.dart';
import 'screen_qibla.dart';
import 'screen_quran_book.dart';
import 'screen_settings.dart';
import 'screen_tasbih.dart';
import 'screen_wird.dart';
import 'view_home_header.dart';
import 'theme_app.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // صور الواجهة في assets/images بصيغة WebP: a1a الإعدادات، a1b القبلة، a1c المسبحة، a1d القرآن
  static const List<_Tile> _tiles = [
    _Tile('📖', 'القرآن الكريم', true, asset: 'assets/images/a1d.webp'),
    _Tile('📜', 'الأحاديث', true, icon: Icons.auto_stories),
    _Tile('🤲', 'الوضوء والصلاة', false, icon: Icons.water_drop),
    _Tile('💚', 'الأذكار', false, icon: Icons.favorite),
    _Tile('📿', 'المسبحة', true, asset: 'assets/images/a1c.webp'),
    _Tile('🕌', 'أوقات الصلاة', true, icon: Icons.mosque),
    _Tile('📜', 'قصص السيرة', false, icon: Icons.history_edu),
    _Tile('🧭', 'اتجاه القبلة', true, asset: 'assets/images/a1b.webp'),
    _Tile('📗', 'ورد القرآن', true, icon: Icons.bookmark_added),
    _Tile('✨', 'الأسماء الحسنى', true, icon: Icons.auto_awesome),
  ];

  void _open(BuildContext context, _Tile t) {
    if (t.enabled) {
      final Widget screen;
      switch (t.label) {
        case 'أوقات الصلاة':
          screen = const PrayerTimesScreen();
        case 'المسبحة':
          screen = const TasbihScreen();
        case 'الأحاديث':
          screen = const HadithListScreen();
        case 'اتجاه القبلة':
          screen = const QiblaScreen();
        case 'ورد القرآن':
          screen = const WirdScreen();
        case 'الأسماء الحسنى':
          screen = const AsmaScreen();
        default:
          screen = const QuranBookScreen();
      }
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
          iconSize: 38,
          padding: const EdgeInsets.all(6),
          icon: Image.asset('assets/images/a1a.webp', width: 34, height: 34),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: HomeHeader(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PrayerTimesScreen()),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                for (var i = 0; i < _tiles.length; i++)
                  _Reveal(
                    index: i,
                    child: _TileView(tile: _tiles[i], onTap: () => _open(context, _tiles[i])),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// دخول متدرّج: تظهر البطاقة وتصعد قليلًا بتأخير بحسب ترتيبها (مرة واحدة عند أول بناء).
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 22 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

class _Tile {
  const _Tile(this.emoji, this.label, this.enabled, {this.asset, this.icon});
  final String emoji;

  /// صورة بدل الرمز التعبيري (إن وُجدت).
  final String? asset;

  /// أيقونة ذهبية داخل مربع ناعم لما لا صورة له بعد.
  final IconData? icon;
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
      customBorder: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(30)),
      onTap: onTap,
      child: Ink(
        decoration: AppDecor.glass(glow: tile.enabled, radius: 30),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tile.asset != null)
                Image.asset(tile.asset!, width: 72, height: 72, filterQuality: FilterQuality.medium)
              else if (tile.icon != null)
                _TileArt(icon: tile.icon!, dim: !tile.enabled)
              else
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

/// مربع ناعم بتدرّج التيل وحافة مضيئة وأيقونة ذهبية، على نسق صور الواجهة، لما لا صورة له بعد.
class _TileArt extends StatelessWidget {
  const _TileArt({required this.icon, required this.dim});
  final IconData icon;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.55 : 1.0,
      child: Container(
        width: 72,
        height: 72,
        decoration: ShapeDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.tealRim, AppColors.bgMid],
          ),
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: AppColors.tealGlow.withValues(alpha: 0.6), width: 1.3),
          ),
          shadows: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 5)),
          ],
        ),
        child: Icon(
          icon,
          size: 38,
          color: AppColors.gold,
          shadows: const [Shadow(color: AppColors.goldGlow, blurRadius: 10)],
        ),
      ),
    );
  }
}
