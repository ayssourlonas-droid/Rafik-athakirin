// إعدادات المواقيت والأذان: الموقع، طريقة الحساب، صوت الأذان ووضعه لكل صلاة، العدّاد، الصلاحيات.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data_repo.dart';
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
  // المعاينة تُشغَّل من ملفات res/raw نفسها التي يستعملها الإشعار (نسخة واحدة من الصوت)
  static const MethodChannel _preview = MethodChannel('rafiq/adhan_preview');
  String? _playing; // اسم المورد الجاري تشغيله (adhan_a1_full ...)
  bool _notifOk = false;
  bool _exactOk = false;

  @override
  void initState() {
    super.initState();
    AppSettings.i.addListener(_onChanged);
    _preview.setMethodCallHandler((call) async {
      if (call.method == 'completed' && mounted) setState(() => _playing = null);
    });
    _loadPermissions();
  }

  @override
  void dispose() {
    AppSettings.i.removeListener(_onChanged);
    _preview.setMethodCallHandler(null);
    _preview.invokeMethod<void>('stop').catchError((_) {});
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
    final file = 'adhan_${voice}_${mode.name}';
    try {
      if (_playing == file) {
        await _preview.invokeMethod<void>('stop');
        if (mounted) setState(() => _playing = null);
        return;
      }
      await _preview.invokeMethod<void>('play', {'name': file});
      if (mounted) setState(() => _playing = file);
    } on PlatformException {
      if (mounted) {
        setState(() => _playing = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذّر تشغيل المعاينة')));
      }
    }
  }

  String _signed(int v) {
    if (v == 0) return arDigits(0);
    return v > 0 ? '+${arDigits(v)}' : '-${arDigits(-v)}';
  }

  Widget _digitChip(String label, bool latin) {
    final selected = AppSettings.i.latinDigits == latin;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.gold,
      labelStyle: TextStyle(color: selected ? AppColors.bgDeep : AppColors.textLight),
      side: const BorderSide(color: AppColors.cardBorder),
      onSelected: (_) => AppSettings.i.setLatinDigits(latin),
    );
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
      final file = 'adhan_${v.id}_${m.name}';
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
          _section('موقعك (تلقائي بالـ GPS)', [
            Text(
              s.hasLocation ? (s.placeName.isEmpty ? 'موقع محفوظ' : s.placeName) : 'لم يُحدَّد بعد',
              style: const TextStyle(color: AppColors.textLight, fontSize: 16),
            ),
            if (s.manualPrimary)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'الموقع محدد يدويًا الآن؛ اضغط الزر ليعود التحديد تلقائيًا.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => detectAndSaveLocation(context),
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('تحديث موقعي (GPS)'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bgDeep,
              ),
            ),
          ]),
          _section('مدن الأقارب', [
            Text(
              'أضف مدنًا يقيم فيها أقاربك. بعد أذان كل مدينة بـ${arDigits(NotificationService.followDelayMin)} دقائق يصلك إشعار صامت دون صوت أذان.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            for (var i = 0; i < s.follows.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.follows[i].name,
                    style: const TextStyle(color: AppColors.textLight, fontSize: 16)),
                trailing: IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete_outline, color: AppColors.gold),
                  onPressed: () => s.removeFollow(i),
                ),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: s.follows.length >= AppSettings.maxFollows
                  ? null
                  : () => showCityPicker(
                        context,
                        title: 'أضف مدينة قريبك',
                        onPick: s.addFollow,
                      ),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: Text(s.follows.length >= AppSettings.maxFollows
                  ? 'بلغت الحد الأقصى (${arDigits(AppSettings.maxFollows)} مدن)'
                  : 'إضافة مدينة'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.gold),
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
              'اختر الطريقة المعتمدة في بلدك. وإن اختلف الوقت دقيقة أو دقيقتين عن جدول مسجدك فاضبطه من «ضبط الدقائق».',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ]),
          _section('ضبط الدقائق', [
            for (final p in Prayer.values.where((p) => p.isObligatory))
              Row(
                children: [
                  Text(p.nameAr, style: const TextStyle(color: AppColors.textLight, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => s.setAdjust(p, s.adjustOf(p) - 1),
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.gold),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      _signed(s.adjustOf(p)),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textLight, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: () => s.setAdjust(p, s.adjustOf(p) + 1),
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.gold),
                  ),
                ],
              ),
            const Text(
              'دقائق تُضاف إلى وقت الصلاة (أو تُطرح) في العرض والأذان معًا.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ]),
          _section('شكل الأرقام', [
            Wrap(
              spacing: 8,
              children: [
                _digitChip('عربية ٠١٢٣٤٥٦٧٨٩', false),
                _digitChip('لاتينية 0123456789', true),
              ],
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
