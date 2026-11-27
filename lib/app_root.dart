// جذر التطبيق: يحمّل البيانات ثم يعرض الشاشة الرئيسية.
import 'dart:async';

import 'package:flutter/material.dart';

import 'data_bookmarks.dart';
import 'data_repo.dart';
import 'data_settings.dart';
import 'data_prayerlog.dart';
import 'data_tasbih.dart';
import 'data_wird.dart';
import 'screen_adhan.dart';
import 'screen_home.dart';
import 'screen_quran_book.dart';
import 'screen_tasbih.dart';
import 'service_location.dart';
import 'service_notifications.dart';
import 'theme_app.dart';

class RafiqApp extends StatefulWidget {
  const RafiqApp({super.key});

  @override
  State<RafiqApp> createState() => _RafiqAppState();
}

class _RafiqAppState extends State<RafiqApp> with WidgetsBindingObserver {
  late final Future<void> _boot = _load();
  Timer? _debounce;

  Future<void> _load() async {
    await Repo.i.init();
    await Bookmarks.i.init();
    await Tasbih.i.init();
    await Wird.i.init();
    await PrayerLog.i.init();
    await AppSettings.i.init();
    await NotificationService.i.init();
    AppSettings.i.addListener(_scheduleSoon);
    _scheduleSoon();
    LocationService.autoRefresh(); // الموقع تلقائي (GPS)؛ لا ننتظره كي لا نؤخر الإقلاع
  }

  // أي تغيير في الإعدادات (أو عودة التطبيق للواجهة) يجدّد جدولة الإشعارات
  void _scheduleSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), () {
      NotificationService.i.reschedule(AppSettings.i);
    });
  }

  final GlobalKey<NavigatorState> _nav = GlobalKey<NavigatorState>();
  bool _adhanOpen = false;

  void _onTasbih() {
    _openTasbih(0);
  }

  void _onWird() {
    _openWird(0);
  }

  void _openWird(int attempt) {
    final nav = _nav.currentState;
    if (nav == null) {
      if (attempt < 20) {
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _openWird(attempt + 1);
        });
      }
      return;
    }
    nav.push(MaterialPageRoute<void>(builder: (_) => const QuranBookScreen()));
  }

  void _openTasbih(int attempt) {
    final nav = _nav.currentState;
    if (nav == null) {
      if (attempt < 20) {
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _openTasbih(attempt + 1);
        });
      }
      return;
    }
    nav.push(MaterialPageRoute<void>(builder: (_) => const TasbihScreen()));
  }

  void _onAdhan() {
    final a = NotificationService.adhanAlert.value;
    if (a == null) return;
    NotificationService.adhanAlert.value = null;
    _openAdhan(a, 0);
  }

  // قد يصل التنبيه قبل أن يجهز الملاح (فتح من إشعار والتطبيق مغلق)، فنعيد المحاولة قليلًا
  void _openAdhan(AdhanAlert a, int attempt) {
    if (_adhanOpen) return;
    final nav = _nav.currentState;
    if (nav == null) {
      if (attempt < 20) {
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _openAdhan(a, attempt + 1);
        });
      }
      return;
    }
    _adhanOpen = true;
    nav
        .push(MaterialPageRoute<void>(builder: (_) => AdhanScreen(alert: a)))
        .whenComplete(() => _adhanOpen = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.adhanAlert.addListener(_onAdhan);
    NotificationService.tasbihTap.addListener(_onTasbih);
    NotificationService.wirdTap.addListener(_onWird);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleSoon();
      LocationService.autoRefresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.adhanAlert.removeListener(_onAdhan);
    NotificationService.tasbihTap.removeListener(_onTasbih);
    NotificationService.wirdTap.removeListener(_onWird);
    AppSettings.i.removeListener(_scheduleSoon);
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _nav,
      debugShowCheckedModeBanner: false,
      title: 'رفيق الذاكرين',
      theme: buildAppTheme(),
      // التطبيق كله من اليمين إلى اليسار
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: FutureBuilder<void>(
        future: _boot,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _Splash();
          }
          if (snap.hasError) {
            return _BootError(error: snap.error.toString());
          }
          return const HomeScreen();
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );
  }
}

class _BootError extends StatelessWidget {
  const _BootError({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'تعذّر تحميل البيانات:\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textLight, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
