// إعدادات المواقيت والأذان: الموقع، طريقة الحساب، صوت الأذان ووضعه لكل صلاة، العدّاد، الصلاحيات.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'data_settings.dart';
import 'prayer_calc.dart';
import 'service_notifications.dart';
import 'sheet_location.dart';
import 'theme_app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _doneSub;
  String? _playing; // اسم الملف الجاري تشغيله
  bool _notifOk = false;
  bool _exactOk = false;

  @override
  void initState() {
    super.initState();
    AppSettings.i.addListener(_onChanged);
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
    _loadPermissions();
  }

  @override
  void dispose() {
    AppSettings.i.removeListener(_onChanged);
    _doneSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPermissions() async {
    final n = await NotificationService.i.notificationsEnabled();
    final e = await NotificationService.i.canScheduleExact();
    if (mounted) {
      setState(() {
        _notifOk = n;
        _exactOk = e;
      });
    }
  }

  Future<void> _togglePreview(String voice, AdhanMode mode) async {
    final file = 'adhan_${voice}_${mode.name}.mp3';
    if (_playing == file) {
      await _player.stop();
      if (mounted) setState(() => _playing = null);
      return;
    }
    await _player.stop();
    await _player.play(AssetSource('audio/$file'));
    if (mounted) setState(() => _playing = file);
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: AppDecor.glass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.gold, fontSize: 17)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _voiceTile(AdhanVoice v) {
    final s = AppSettings.i;
    final selected = s.voiceId == v.id;
    Widget preview(AdhanMode m, String label) {
      final file = 'adhan_${v.id}_${m.name}.mp3';
      final on = _playing == file;
      return TextButton.icon(
        onPressed: () => _togglePreview(v.id, m),
        icon: Icon(on ? Icons.stop_circle_outlined : Icons.play_circle_outline, size: 20),
        label: Text(on ? 'إيقاف' : label),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? AppColors.gold : AppColors.cardBorder),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            onTap: () => s.setVoice(v.id),
            leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: AppColors.gold,
            ),
            title: Text(v.nameAr, style: const TextStyle(color: AppColors.textLight, fontSize: 16)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              preview(AdhanMode.short, 'معاينة المختصر'),
              preview(AdhanMode.full, 'معاينة الكامل'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.i;
    return AppScaffold(
      title: 'إعدادات الصلاة والأذان',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('الموقع', [
            Text(
              s.hasLocation ? (s.placeName.isEmpty ? 'موقع محفوظ' : s.placeName) : 'لم يُحدَّد بعد',
              style: const TextStyle(color: AppColors.textLight, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => detectAndSaveLocation(context),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('تلقائيًا (GPS)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgDeep,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => showCityPicker(context),
                  icon: const Icon(Icons.location_city, size: 18),
                  label: const Text('اختيار مدينة'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold),
                ),
              ],
            ),
          ]),
          _section('طريقة الحساب', [
            DropdownButton<String>(
              isExpanded: true,
              value: s.methodId,
              dropdownColor: AppColors.bgMid,
              style: const TextStyle(color: AppColors.textLight, fontSize: 16),
              items: [
                for (final m in kMethods) DropdownMenuItem<String>(value: m.id, child: Text(m.nameAr)),
              ],
              onChanged: (v) {
                if (v != null) s.setMethod(v);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.gold,
              title: const Text('العصر بالمذهب الحنفي (ظل مثلين)',
                  style: TextStyle(color: AppColors.textLight, fontSize: 15)),
              value: s.hanafi,
              onChanged: s.setHanafi,
            ),
            const Text(
              'الزوايا مأخوذة من المراجع الشائعة؛ تأكد من الجهة الرسمية في بلدك.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ]),
          _section('صوت الأذان', [
            for (final v in kAdhanVoices) _voiceTile(v),
          ]),
          _section('وضع الأذان لكل صلاة', [
            for (final p in Prayer.values.where((p) => p.isObligatory))
              Row(
                children: [
                  Text(p.nameAr, style: const TextStyle(color: AppColors.textLight, fontSize: 16)),
                  const Spacer(),
                  DropdownButton<AdhanMode>(
                    value: s.modeOf(p),
                    dropdownColor: AppColors.bgMid,
                    style: const TextStyle(color: AppColors.textLight, fontSize: 15),
                    items: [
                      for (final m in AdhanMode.values)
                        DropdownMenuItem<AdhanMode>(value: m, child: Text(m.nameAr)),
                    ],
                    onChanged: (m) {
                      if (m != null) s.setMode(p, m);
                    },
                  ),
                ],
              ),
          ]),
          _section('الشريط الهادئ', [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.gold,
              title: const Text('إشعار صغير بالوقت المتبقي للصلاة القادمة',
                  style: TextStyle(color: AppColors.textLight, fontSize: 15)),
              value: s.countdownEnabled,
              onChanged: s.setCountdown,
            ),
          ]),
          _section('الصلاحيات والتجربة', [
            _status('الإشعارات', _notifOk),
            _status('المنبّهات الدقيقة (لتوقيت الأذان بالثانية)', _exactOk),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () async {
                    await NotificationService.i.requestPermissions();
                    await _loadPermissions();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.bgDeep,
                  ),
                  child: const Text('السماح بالإشعارات والمنبّهات'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await NotificationService.i.requestPermissions();
                    final mode = s.modeOf(Prayer.dhuhr);
                    final msg = await NotificationService.i.scheduleTest(s, mode);
                    messenger.showSnackBar(SnackBar(content: Text(msg)));
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold),
                  child: const Text('جرّب الأذان بعد ١٠ ثوانٍ'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              NotificationService.i.lastReport?.summary ?? 'لم تُجدوَل الإشعارات بعد',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            const Text(
              'بعض الهواتف (شاومي، هواوي، أوبو...) توقف التطبيقات في الخلفية. إن لم يصلك الأذان، '
              'عطّل توفير البطارية لهذا التطبيق وفعّل التشغيل التلقائي من إعدادات الهاتف.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _status(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.error_outline,
              color: ok ? AppColors.quoteGreen : AppColors.bookmarkRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.textLight, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
