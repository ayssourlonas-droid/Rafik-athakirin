// الهوية البصرية المركزية — كل الألوان والأنماط من مكان واحد (منقولة من app_theme.gd).
import 'package:flutter/material.dart';

class AppColors {
  // اللوحة مستخلصة من صور الواجهة: تيل عميق، وذهب دافئ، وكريمي
  static const Color bgDeep = Color(0xFF001B1A);
  static const Color bgMid = Color(0xFF012223);
  static const Color bgLight = Color(0xFF013537);
  static const Color tealRim = Color(0xFF025152); // حافة التيل في الأيقونات
  static const Color tealGlow = Color(0xFF1B9A98); // توهج التيل

  static const Color gold = Color(0xFFD9AE5C);
  static const Color goldSoft = Color(0xFFF2D08A);
  static const Color goldGlow = Color(0x59D9AE5C);
  static const Color sand = Color(0xFFD7C49B);

  static const Color cardBg = Color(0x99013537);
  static const Color cardBorder = Color(0x59D9AE5C);

  static const Color textLight = Color(0xFFFAE6C0);
  static const Color textMuted = Color(0xB39FB8B4);

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
  /// بطاقة بحواف مستمرة ناعمة (squircle) كأيقونات الواجهة: تدرّج تيل خفيف، وحد ذهبي رفيع، وظل عميق.
  static ShapeDecoration glass({
    bool glow = false,
    double radius = 26,
    Color? borderColor,
    double borderWidth = 1,
  }) {
    return ShapeDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xB3025152), Color(0xB3012A2C)],
      ),
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor ?? AppColors.cardBorder, width: borderWidth),
      ),
      shadows: [
        const BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 6)),
        if (glow) const BoxShadow(color: AppColors.goldGlow, blurRadius: 16),
      ],
    );
  }
}

/// زخرفة نجمية هندسية خافتة جدًا (مربعان متداخلان بزاوية ٤٥°) تُرسم مرة واحدة بالكود.
class _StarPatternPainter extends CustomPainter {
  const _StarPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 92.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x16D9AE5C);
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / (cell * 0.5)).ceil() + 1;
    const a = cell * 0.27; // نصف ضلع المربع
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cx = c * cell + (r.isOdd ? cell / 2 : 0);
        final cy = r * cell * 0.5;
        final sq = Path()
          ..moveTo(cx - a, cy - a)
          ..lineTo(cx + a, cy - a)
          ..lineTo(cx + a, cy + a)
          ..lineTo(cx - a, cy + a)
          ..close();
        canvas.drawPath(sq, paint);
        final d = a * 1.4142;
        final dm = Path()
          ..moveTo(cx, cy - d)
          ..lineTo(cx + d, cy)
          ..lineTo(cx, cy + d)
          ..lineTo(cx - d, cy)
          ..close();
        canvas.drawPath(dm, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StarPatternPainter old) => false;
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          const IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: _StarPatternPainter())),
          ),
          child,
        ],
      ),
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
      shape: Border(bottom: BorderSide(color: AppColors.cardBorder)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
