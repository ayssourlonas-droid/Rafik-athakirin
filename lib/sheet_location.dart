// الموقع: الأساس تلقائي (GPS). اختيار المدينة يدويًا لمدن الأقارب، وكبديل عند تعذّر الـ GPS.
import 'package:flutter/material.dart';

import 'data_repo.dart';
import 'data_settings.dart';
import 'service_location.dart';
import 'service_notifications.dart';
import 'theme_app.dart';

/// يطلب إذن الإشعارات والمنبّهات الدقيقة مرة واحدة فقط، بعد أول تحديد للموقع.
Future<void> askPermsOnce() => NotificationService.i.requestPermissionsOnce();

/// تحديد الموقع بالـ GPS (يعيد الوضع التلقائي).
Future<void> detectAndSaveLocation(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(const SnackBar(content: Text('جارٍ تحديد موقعك...')));
  final r = await LocationService.detect();
  messenger.hideCurrentSnackBar();
  if (r.isOk) {
    final la = r.lat!;
    final lo = r.lng!;
    AppSettings.i.setLocation(la, lo, LocationService.placeName(la, lo));
    messenger.showSnackBar(const SnackBar(content: Text('تم تحديد الموقع ✓')));
    await askPermsOnce();
  } else {
    messenger.showSnackBar(SnackBar(content: Text(r.error ?? 'تعذّر تحديد الموقع')));
  }
}

/// بديل عند تعذّر الـ GPS: مدينة يدوية تصير موقعك الأساسي.
void pickPrimaryCityManually(BuildContext context) {
  showCityPicker(
    context,
    title: 'اختر مدينتك (بديل عن الـ GPS)',
    onPick: (c) {
      AppSettings.i.setLocation(c.lat, c.lng, c.nameAr, tz: c.tzId, method: c.methodId, manual: true);
      askPermsOnce();
    },
  );
}

/// نافذة اختيار مدينة مع بحث.
void showCityPicker(
  BuildContext context, {
  required void Function(CityPreset) onPick,
  String title = 'اختر مدينة',
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bgMid,
    isScrollControlled: true,
    builder: (ctx) {
      var query = '';
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          final nq = normalizeArabic(query.trim());
          final list = [
            for (final c in kCities)
              if (nq.isEmpty || normalizeArabic(c.nameAr).contains(nq)) c,
          ];
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, controller) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(title, style: const TextStyle(color: AppColors.gold, fontSize: 18)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (v) => setSheet(() => query = v),
                      style: const TextStyle(color: AppColors.textLight, fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'ابحث عن مدينة',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        prefixIcon: Icon(Icons.search, color: AppColors.gold),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return ListTile(
                          title: Text(c.nameAr,
                              style: const TextStyle(color: AppColors.textLight, fontSize: 17)),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            onPick(c);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}
