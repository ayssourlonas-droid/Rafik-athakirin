// المصحف الحقيقي: 604 صفحة رسمية (حدود الصفحات من بيانات مجمع الملك فهد/QUL)،
// بتقليب يمين/يسار والتواء الورقة. الالتواء يلتقط الصفحة كصورة مؤقتة ثم يحذفها.
//
// اتجاه القراءة العربي: السحب نحو اليمين = الصفحة التالية، نحو اليسار = السابقة.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'data_repo.dart';
import 'fx_page_curl.dart';
import 'theme_app.dart';

class MushafPagesView extends StatefulWidget {
  const MushafPagesView({super.key, required this.initialPage, this.onPageChanged});

  final int initialPage;

  /// يُستدعى عند فتح صفحة (لحفظ آخر صفحة). لا تستدعِ setState في الأب منه.
  final ValueChanged<int>? onPageChanged;

  @override
  State<MushafPagesView> createState() => _MushafPagesViewState();
}

class _MushafPagesViewState extends State<MushafPagesView>
    with SingleTickerProviderStateMixin {
  static const double _curlTravel = 0.8; // مسافة السحب (نسبة من العرض) لقلب الصفحة كاملة
  static const double _commit = 0.3; // تقدّم أكثر منه يُكمل التقليب عند ترك الإصبع

  final GlobalKey _captureKey = GlobalKey();
  late final AnimationController _anim;
  late int _page;

  ui.FragmentShader? _shader; // null = الالتواء غير متاح (تقليب بسيط)
  ui.Image? _snap;
  bool _capturing = false;
  bool _curling = false;
  bool _busy = false;
  bool _goingNext = true;
  bool _releasePending = false;
  int _dest = 1;
  double _progress = 0;
  double _accum = 0;
  double _origin = 0;
  double _width = 360;
  String _warmKey = '';

  @override
  void initState() {
    super.initState();
    _page = math.max(1, math.min(Repo.pageCount, widget.initialPage));
    widget.onPageChanged?.call(_page);
    _anim = AnimationController(vsync: this);
    loadCurlShader().then((s) {
      if (mounted) _shader = s;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _snap?.dispose();
    super.dispose();
  }

  // ───────── منطق الصفحات ─────────
  bool _canTurn(bool next) => next ? _page < Repo.pageCount : _page > 1;

  void _goTo(int p) {
    setState(() => _page = math.max(1, math.min(Repo.pageCount, p)));
    widget.onPageChanged?.call(_page);
  }

  double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  // ───────── التقاط لقطة الصفحة الحالية ─────────
  Future<ui.Image?> _captureImage() async {
    try {
      final ro = _captureKey.currentContext?.findRenderObject();
      if (ro is! RenderRepaintBoundary) return null;
      final dpr = MediaQuery.of(context).devicePixelRatio;
      return await ro.toImage(pixelRatio: dpr);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _startCurl(bool next, {required bool fromDrag}) async {
    _capturing = true;
    final img = await _captureImage();
    _capturing = false;
    if (!mounted) {
      img?.dispose();
      return false;
    }
    if (img == null) {
      _shader = null; // نوقف الالتواء ونرجع للتقليب البسيط
      return false;
    }
    final sign = next ? 1.0 : -1.0;
    final pending = _releasePending;
    setState(() {
      _snap = img;
      _curling = true;
      _goingNext = next;
      _dest = _page + (next ? 1 : -1);
      _origin = (fromDrag && !pending) ? _accum * sign : 0;
      _progress = pending ? _clamp01((_accum * sign) / (_width * _curlTravel)) : 0;
    });
    if (pending) {
      _releasePending = false;
      _finishDrag(0);
    }
    return true;
  }

  Future<void> _animateTo(double target) async {
    _busy = true;
    final from = _progress;
    final ms = (140 + 380 * (target - from).abs()).round();
    _anim.duration = Duration(milliseconds: ms);
    final tween = Tween<double>(begin: from, end: target)
        .chain(CurveTween(curve: Curves.easeOutCubic));
    void tick() {
      if (mounted) setState(() => _progress = tween.evaluate(_anim));
    }

    _anim.addListener(tick);
    await _anim.forward(from: 0);
    _anim.removeListener(tick);
  }

  void _endCurl(bool commit) {
    if (!mounted) return;
    setState(() {
      if (commit) _page = _dest;
      _curling = false;
      _progress = 0;
      _snap?.dispose();
      _snap = null;
      _busy = false;
    });
    if (commit) widget.onPageChanged?.call(_page);
  }

  Future<void> _finishDrag(double velocity) async {
    final sign = _goingNext ? 1.0 : -1.0;
    final flick = (velocity * sign) > 800;
    final commit = _progress >= _commit || (flick && _progress > 0.05);
    await _animateTo(commit ? 1.0 : 0.0);
    _endCurl(commit);
  }

  // ───────── الأزرار ─────────
  Future<void> _turnByButton(bool next) async {
    if (_busy || _capturing || _curling) return;
    if (!_canTurn(next)) return;
    if (_shader == null) {
      _goTo(_page + (next ? 1 : -1));
      return;
    }
    final ok = await _startCurl(next, fromDrag: false);
    if (!ok) {
      if (mounted) _goTo(_page + (next ? 1 : -1));
      return;
    }
    await _animateTo(1.0);
    _endCurl(true);
  }

  Future<void> _jumpDialog() async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgMid,
        title: const Text('الانتقال إلى صفحة', style: TextStyle(color: AppColors.gold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: AppColors.textLight),
          decoration: InputDecoration(hintText: '1 - ${Repo.pageCount}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value >= 1 && value <= Repo.pageCount && mounted) _goTo(value);
  }

  // ───────── السحب ─────────
  void _onStart(DragStartDetails d) {
    if (_busy) return;
    _accum = 0;
    _releasePending = false;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_busy) return;
    _accum += d.delta.dx;
    if (_curling) {
      final sign = _goingNext ? 1.0 : -1.0;
      final p = ((_accum * sign) - _origin) / (_width * _curlTravel);
      setState(() => _progress = _clamp01(p));
      return;
    }
    if (_capturing || _shader == null) return;
    if (_accum.abs() > 14) {
      final next = _accum > 0;
      if (_canTurn(next)) _startCurl(next, fromDrag: true);
    }
  }

  void _onEnd(DragEndDetails d) {
    if (_busy) return;
    if (_capturing) {
      _releasePending = true;
      return;
    }
    if (_curling) {
      _finishDrag(d.primaryVelocity ?? 0);
      return;
    }
    // لا التواء (الشيدر غير متاح): تقليب بسيط إن كانت المسافة كافية
    if (_shader == null && _accum.abs() > 60) {
      final next = _accum > 0;
      if (_canTurn(next)) _goTo(_page + (next ? 1 : -1));
    }
  }

  /// يحسب مسبقًا مقاس خط الصفحتين المجاورتين كي لا يتأخر التقليب.
  void _prewarmNeighbors(double w, double h) {
    final key = '$_page|${w.round()}|${h.round()}';
    if (key == _warmKey) return;
    _warmKey = key;
    final page = _page;
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || page != _page) return;
      if (page < Repo.pageCount) MushafPaperPage.prewarm(page + 1, w, h);
      if (page > 1) MushafPaperPage.prewarm(page - 1, w, h);
    });
  }

  // ───────── الواجهة ─────────
  Widget _navBar() {
    final canPrev = _page > 1;
    final canNext = _page < Repo.pageCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'الصفحة السابقة',
            onPressed: canPrev ? () => _turnByButton(false) : null,
            icon: Icon(Icons.chevron_right,
                size: 32, color: canPrev ? AppColors.gold : AppColors.textMuted),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _jumpDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'صفحة ${arDigits(_page)} من ${arDigits(Repo.pageCount)}',
                style: const TextStyle(color: AppColors.gold, fontSize: 16),
              ),
            ),
          ),
          IconButton(
            tooltip: 'الصفحة التالية',
            onPressed: canNext ? () => _turnByButton(true) : null,
            icon: Icon(Icons.chevron_left,
                size: 32, color: canNext ? AppColors.gold : AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _navBar(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                _width = constraints.maxWidth;
                _prewarmNeighbors(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: _onStart,
                  onHorizontalDragUpdate: _onUpdate,
                  onHorizontalDragEnd: _onEnd,
                  onHorizontalDragCancel: () => _onEnd(DragEndDetails()),
                  child: Stack(
                    children: [
                      // الصفحة الحالية (تُلتقط منها اللقطة)
                      Positioned.fill(
                        child: RepaintBoundary(
                          key: _captureKey,
                          child: MushafPaperPage(key: ValueKey('p$_page'), page: _page),
                        ),
                      ),
                      // الصفحة الوجهة تحت الالتواء لتنكشف تدريجيًا
                      if (_curling)
                        Positioned.fill(
                          child: MushafPaperPage(key: ValueKey('d$_dest'), page: _dest),
                        ),
                      // اللقطة المؤقتة مع الشيدر
                      if (_curling && _snap != null && _shader != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: CurlPainter(
                                shader: _shader!,
                                image: _snap!,
                                progress: _progress,
                                dir: _goingNext ? 1.0 : -1.0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// ورقة المصحف: ورق كريمي، وخط عثماني بحبر داكن.
/// الصفحة كلها تملأ المساحة المتاحة بلا تمرير: يُحسب أكبر مقاس خط يتّسع فيه محتوى الصفحة
/// بعرضها وارتفاعها (بحث ثنائي بقياس النص فعليًا)، ويُخزَّن الناتج لكل صفحة ومقاس.
/// حدود الصفحة من البيانات الرسمية؛ التفاف السطر عادي وليس مطابقًا حرفيًا لكل سطر مطبوع.
class MushafPaperPage extends StatelessWidget {
  const MushafPaperPage({super.key, required this.page});

  final int page;

  static const double _baseSize = 26;
  static const double _minScale = 0.4;
  static const double _maxScale = 1.15;
  static const EdgeInsets _pad = EdgeInsets.fromLTRB(14, 10, 14, 10);
  static const double _frame = 4; // إطار الورقة: 2 + 2
  static final Map<String, double> _fitCache = <String, double>{};

  // الأنماط مشتركة بين القياس والعرض كي يتطابقا؛ letterSpacing صفر يمنع تأثير الثيم في العرض.
  static TextStyle _ayahStyle(double k) => TextStyle(
        fontFamily: AppText.quranFont,
        fontSize: _baseSize * k,
        height: 2.0,
        letterSpacing: 0,
        color: AppColors.ink,
      );
  static TextStyle _numStyle(double k) => TextStyle(color: AppColors.inkGold, fontSize: 22 * k);
  static TextStyle _headStyle(double k) => TextStyle(
        fontFamily: AppText.quranFont,
        color: AppColors.inkGold,
        fontSize: 22 * k,
        height: 1.5,
        letterSpacing: 0,
        fontWeight: FontWeight.bold,
      );
  static TextStyle _basmalaStyle(double k) => TextStyle(
        fontFamily: AppText.quranFont,
        fontSize: 26 * k,
        height: 1.8,
        letterSpacing: 0,
        color: AppColors.inkGold,
      );

  static String _headText(MushafBlock b) => '﴾ سورة ${Repo.i.surah(b.surah).ar} ﴿';

  static TextSpan _ayahSpan(MushafBlock b, double k) {
    final s = Repo.i.surah(b.surah);
    final spans = <InlineSpan>[];
    for (final a in b.ayahs) {
      if (a < 1 || a > s.ayahCount) continue;
      spans.add(TextSpan(text: '${s.ayahs[a - 1]} '));
      spans.add(TextSpan(text: '﴿${arDigits(a)}﴾ ', style: _numStyle(k)));
    }
    return TextSpan(children: spans, style: _ayahStyle(k));
  }

  // ───────── القياس ─────────
  static double _textH(InlineSpan span, double width, {bool justify = false}) {
    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.rtl,
      textAlign: justify ? TextAlign.justify : TextAlign.center,
      textScaler: TextScaler.noScaling,
    )..layout(minWidth: justify ? width : 0, maxWidth: width);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  static double _blockHeight(MushafBlock b, double k, double w) {
    switch (b.type) {
      case 's':
        // هامش 6k×2 + حشو 6k×2 + إطار 2
        return 24 * k + 2 + _textH(TextSpan(text: _headText(b), style: _headStyle(k)), w - 2);
      case 'b':
        return 8 * k + _textH(TextSpan(text: Repo.basmala, style: _basmalaStyle(k)), w);
      default:
        return _textH(_ayahSpan(b, k), w, justify: true);
    }
  }

  static double _fit(int page, double w, double h) {
    final key = '$page|${w.round()}|${h.round()}';
    final hit = _fitCache[key];
    if (hit != null) return hit;
    final blocks = Repo.i.pageBlocks(page);
    double total(double k) {
      var t = 0.0;
      for (final b in blocks) {
        t += _blockHeight(b, k, w);
      }
      return t;
    }

    final limit = h * 0.985; // هامش أمان صغير
    double k;
    if (total(_maxScale) <= limit) {
      k = _maxScale;
    } else if (total(_minScale) > limit) {
      k = _minScale;
    } else {
      var lo = _minScale;
      var hi = _maxScale;
      for (var i = 0; i < 12; i++) {
        final mid = (lo + hi) / 2;
        if (total(mid) <= limit) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      k = lo;
    }
    if (_fitCache.length > 40) _fitCache.clear();
    _fitCache[key] = k;
    return k;
  }

  /// حساب مسبق لصفحة بمقاس الورقة الخارجي (عرض × ارتفاع).
  static void prewarm(int page, double outerW, double outerH) {
    if (outerW <= 0 || outerH <= 0) return;
    _fit(page, outerW - _frame - _pad.horizontal, outerH - _frame - _pad.vertical);
  }

  // ───────── العرض ─────────
  Widget _block(MushafBlock b, double k) {
    switch (b.type) {
      case 's':
        return Container(
          margin: EdgeInsets.symmetric(vertical: 6 * k),
          padding: EdgeInsets.symmetric(vertical: 6 * k),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.inkGold),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_headText(b), textAlign: TextAlign.center, style: _headStyle(k)),
        );
      case 'b':
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4 * k),
          child: Center(
            child: Text(Repo.basmala, textAlign: TextAlign.center, style: _basmalaStyle(k)),
          ),
        );
      default:
        return Text.rich(
          _ayahSpan(b, k),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = Repo.i.pageBlocks(page);
    // الصفحة تُقاس بلا تكبير خط النظام (المقاس يُحسب لتملأ الشاشة)
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.paperEdge, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth - _pad.horizontal;
              final h = c.maxHeight - _pad.vertical;
              final k = _fit(page, w, h);
              return Padding(
                padding: _pad,
                // احتياط: إن زاد الارتفاع الفعلي قليلًا عن القياس يُصغَّر المحتوى بدل أن يفيض
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: w,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final b in blocks) _block(b, k)],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
