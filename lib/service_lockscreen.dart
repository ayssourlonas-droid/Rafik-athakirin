// جسر إلى كود أندرويد الخاص بشاشة الأذان فوق القفل (MainActivity).
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException, PlatformException;

class LockScreenService {
  static const MethodChannel _ch = MethodChannel('rafiq/lock');

  static Future<T?> _call<T>(String method) async {
    try {
      return await _ch.invokeMethod<T>(method);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// هل يسمح النظام للتطبيق بفتح شاشة بملء الشاشة فوق القفل؟ (أندرويد 14+ قد يمنعها)
  static Future<bool> fsiAllowed() async => (await _call<bool>('fsiAllowed')) ?? true;

  /// يفتح صفحة إذن «الإشعارات بملء الشاشة» لهذا التطبيق. false إن لم تتوفر في هذا الإصدار.
  static Future<bool> openFsiSettings() async => (await _call<bool>('fsiSettings')) ?? false;

  /// يرفع أعلام «فوق القفل» فقط (يرجع القفل إلى وضعه).
  static Future<void> release() => _call<void>('release');

  /// يرفع الأعلام ويُرجع التطبيق إلى الخلفية (يعود القفل أو الشاشة السابقة).
  static Future<void> finish() => _call<void>('finish');

  /// يطلب من المستخدم فتح القفل ثم يرفع الأعلام.
  static Future<void> unlock() => _call<void>('unlock');
}
