// شاشة الأذان: تظهر فوق القفل حين يحين الوقت (وعند الضغط على إشعار الأذان).
import 'package:flutter/material.dart';

import 'data_format.dart';
import 'data_settings.dart';
import 'service_lockscreen.dart';
import 'service_notifications.dart';
import 'theme_app.dart';

class AdhanScreen extends StatefulWidget {
  const AdhanScreen({super.key, required this.alert});

  final AdhanAlert alert;

  @override
  State<AdhanScreen> createState() => _AdhanScreenState();
}

class _AdhanScreenState extends State<AdhanScreen> {
  @override
  void dispose() {
    LockScreenService.release(); // لا يبقى التطبيق ظاهرًا فوق القفل بعد إغلاق الشاشة
    super.dispose();
  }

  Future<void> _stop() async {
    await NotificationService.i.stopAdhan(widget.alert.id);
    await LockScreenService.finish();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openApp() async {
    await LockScreenService.unlock();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final s = AppSettings.i;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Text('🕌', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              Text(
                a.isTest ? 'تجربة الأذان' : 'حان وقت صلاة ${a.prayerName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.gold, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                clockText(a.time, s.tzId),
                style: const TextStyle(
                    color: AppColors.textLight, fontSize: 56, fontWeight: FontWeight.bold),
              ),
              if (s.placeName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  s.placeName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
              ],
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.volume_off),
                  label: const Text('إيقاف الأذان', style: TextStyle(fontSize: 20)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgDeep,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _openApp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  child: const Text('فتح التطبيق', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
