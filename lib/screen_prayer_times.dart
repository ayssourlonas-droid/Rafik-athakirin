// أوقات الصلاة: مواقيت اليوم، والصلاة القادمة بعدّاد تنازلي حيّ.
import 'dart:async';

import 'package:flutter/material.dart';

import 'data_repo.dart';
import 'data_settings.dart';
import 'prayer_calc.dart';
import 'screen_settings.dart';
import 'sheet_location.dart';
import 'theme_app.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    AppSettings.i.addListener(_refresh);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    AppSettings.i.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() => _now = DateTime.now());
  }

  static const List<String> _weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  String _two(int n) => n < 10 ? '٠${arDigits(n)}' : arDigits(n);

  String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final suffix = t.hour < 12 ? 'ص' : 'م';
    return '${arDigits(h)}:${_two(t.minute)} $suffix';
  }

  String _countdown(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    return '${_two(h)}:${_two(m)}:${_two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.i;
    return AppScaffold(
      title: 'أوقات الصلاة',
      actions: [
        IconButton(
          tooltip: 'الإعدادات',
          icon: const Icon(Icons.settings, color: AppColors.gold),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
      body: s.hasLocation ? _content(s) : _noLocation(context),
    );
  }

  Widget _noLocation(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📍', style: TextStyle(fontSize: 46)),
            const SizedBox(height: 12),
            const Text(
              'حدّد موقعك لنحسب لك مواقيت الصلاة',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, fontSize: 18),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => detectAndSaveLocation(context),
              icon: const Icon(Icons.my_location),
              label: const Text('تحديد موقعي تلقائيًا'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgDeep,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => showCityPicker(context),
              icon: const Icon(Icons.location_city),
              label: const Text('اختيار مدينة'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AppSettings s) {
    DayTimes day(int offset) => PrayerCalc.compute(
          date: DateTime(_now.year, _now.month, _now.day + offset, 12),
          lat: s.lat!,
          lng: s.lng!,
          method: s.method,
          hanafi: s.hanafi,
        );
    final today = day(0);
    final tomorrow = day(1);

    // الصلاة القادمة (المفروضة فقط)
    Prayer? nextPrayer;
    DateTime? nextTime;
    for (final p in Prayer.values) {
      final t = today[p];
      if (p.isObligatory && t != null && t.isAfter(_now)) {
        nextPrayer = p;
        nextTime = t;
        break;
      }
    }
    if (nextPrayer == null && tomorrow[Prayer.fajr] != null) {
      nextPrayer = Prayer.fajr;
      nextTime = tomorrow[Prayer.fajr];
    }

    final weekday = _weekdays[_now.weekday - 1];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppDecor.glass(),
          child: Row(
            children: [
              const Icon(Icons.place, color: AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.placeName.isEmpty ? 'موقعك' : s.placeName,
                  style: const TextStyle(color: AppColors.textLight, fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () => showCityPicker(context),
                child: const Text('تغيير'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            '$weekday • ${arDigits(_now.day)}/${arDigits(_now.month)}/${arDigits(_now.year)}   —   ${s.method.nameAr}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        if (nextPrayer != null && nextTime != null)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: AppDecor.glass(glow: true),
            child: Column(
              children: [
                Text('الصلاة القادمة: ${nextPrayer.nameAr}',
                    style: const TextStyle(color: AppColors.gold, fontSize: 20)),
                const SizedBox(height: 10),
                Text(
                  _countdown(nextTime.difference(_now)),
                  style: const TextStyle(
                    color: AppColors.goldSoft,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_clock(nextTime),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
              ],
            ),
          ),
        for (final p in Prayer.values)
          _row(p, today[p], isNext: p == nextPrayer && today[p] == nextTime),
        const SizedBox(height: 12),
        const Text(
          'زوايا الفجر والعشاء حسب الجهة المختارة؛ راجع الجهة الرسمية في بلدك قبل الاعتماد.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _row(Prayer p, DateTime? t, {required bool isNext}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppDecor.glass(glow: isNext).copyWith(
        border: Border.all(color: isNext ? AppColors.gold : AppColors.cardBorder, width: isNext ? 1.6 : 1),
      ),
      child: Row(
        children: [
          Text(p.nameAr,
              style: TextStyle(
                color: p == Prayer.sunrise ? AppColors.textMuted : AppColors.textLight,
                fontSize: 19,
              )),
          const Spacer(),
          Text(t == null ? '--' : _clock(t),
              style: TextStyle(
                color: isNext ? AppColors.goldSoft : AppColors.textLight,
                fontSize: 19,
                fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
    );
  }
}
