// الهوية البصرية المركزية — كل الألوان والأنماط من مكان واحد (منقولة من app_theme.gd).
import 'package:flutter/material.dart';

class AppColors {
  static const Color bgDeep = Color(0xFF061910);
  static const Color bgMid = Color(0xFF0A2D1A);
  static const Color bgLight = Color(0xFF123C25);

  static const Color gold = Color(0xFFD4A943);
  static const Color goldSoft = Color(0xFFF2D166);
  static const Color goldGlow = Color(0x59E6BF59);

  static const Color cardBg = Color(0x8C0F3D26);
  static const Color cardBorder = Color(0x59D4A943);

  static const Color textLight = Color(0xFFFAF2D9);
  static const Color textMuted = Color(0xB3BFD9C7);

  // ورقة المصحف
  static const Color paper = Color(0xFFF5EDD6);
  static const Color paperEdge = Color(0xFFE0D1A8);
  static const Color ink = Color(0xFF1F1A14);
  static const Color inkGold = Color(0xFF8C611A);

  // العلامات المرجعية
  static const Color bookmarkRed = Color(0xFFD94040);
  static const Color bookmarkBlue = Color(0xFF4080E6);

  // اقتباس قرآني داخل التفسير
  static const Color quoteGreen = Color(0xFF7FD99A);
}

class AppText {
  /// خط المصحف العثماني الرسمي (مجمع الملك فهد)
  static const String quranFont = 'UthmanicHafs';
}

class AppDecor {
  static BoxDecoration glass({bool glow = false}) {
    return BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
      boxShadow: glow
          ? const [BoxShadow(color: AppColors.goldGlow, blurRadius: 12)]
          : null,
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.25,
          colors: [AppColors.bgLight, AppColors.bgMid, AppColors.bgDeep],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: Text(title), actions: actions),
      body: AppBackground(child: SafeArea(top: false, child: body)),
    );
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bgDeep,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: Brightness.dark,
    ).copyWith(primary: AppColors.gold, surface: AppColors.bgMid),
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgDeep,
      foregroundColor: AppColors.gold,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.gold,
      ),
    ),
  );
}
