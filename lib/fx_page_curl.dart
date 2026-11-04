// التواء الصفحة: لقطة مؤقتة للصفحة تُرسم بشيدر يلفّها كأسطوانة ويكشف ما تحتها.
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// يحمّل الشيدر؛ يعيد null عند أي فشل (فيرجع المصحف للتقليب البسيط دون انهيار).
Future<ui.FragmentShader?> loadCurlShader() async {
  try {
    final program = await ui.FragmentProgram.fromAsset('assets/shaders/page_curl.frag');
    return program.fragmentShader();
  } catch (_) {
    return null;
  }
}

class CurlPainter extends CustomPainter {
  CurlPainter({
    required this.shader,
    required this.image,
    required this.progress,
    required this.dir,
  });

  final ui.FragmentShader shader;
  final ui.Image image;

  /// 0 = مسطّحة، 1 = انقلبت كاملة
  final double progress;

  /// +1 الصفحة التالية (تبدأ الثنية من اليسار)، -1 السابقة (من اليمين)
  final double dir;

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, progress);
    shader.setFloat(3, dir);
    shader.setFloat(4, 0.11); // نصف قطر الثنية
    shader.setFloat(5, 0.96); // لون ظهر الورقة (أحمر)
    shader.setFloat(6, 0.93); // أخضر
    shader.setFloat(7, 0.84); // أزرق
    shader.setImageSampler(0, image);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant CurlPainter old) =>
      old.progress != progress || old.image != image || old.dir != dir;
}
