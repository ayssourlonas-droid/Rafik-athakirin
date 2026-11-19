// اختيار الموقع: تلقائيًا (GPS) أو من قائمة مدن. يُستعمل من شاشة المواقيت والإعدادات.
import 'package:flutter/material.dart';

import 'data_settings.dart';
import 'service_location.dart';
import 'theme_app.dart';

Future<void> detectAndSaveLocation(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(const SnackBar(content: Text('جارٍ تحديد موقعك...')));
  final r = await LocationService.detect();
  messenger.hideCurrentSnackBar();
  if (r.isOk) {
    final la = r.lat!;
    final lo = r.lng!;
    AppSettings.i.setLocation(
      la,
      lo,
      'موقعك الحالي (${la.toStringAsFixed(2)}، ${lo.toStringAsFixed(2)})',
    );
    messenger.showSnackBar(const SnackBar(content: Text('تم تحديد الموقع ✓')));
  } else {
    messenger.showSnackBar(SnackBar(content: Text(r.error ?? 'تعذّر تحديد الموقع')));
  }
}

void showCityPicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bgMid,
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('اختر مدينتك',
                    style: TextStyle(color: AppColors.gold, fontSize: 18)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: kCities.length,
                  itemBuilder: (context, i) {
                    final c = kCities[i];
                    return ListTile(
                      title: Text(c.nameAr,
                          style: const TextStyle(color: AppColors.textLight, fontSize: 17)),
                      onTap: () {
                        AppSettings.i.setLocation(c.lat, c.lng, c.nameAr);
                        Navigator.of(ctx).pop();
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
}
