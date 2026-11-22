// مؤثرات صوتية قصيرة للمسبحة عبر SoundPool الأصلي (الملفات في res/raw).
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException, PlatformException;

class Sfx {
  static const MethodChannel _ch = MethodChannel('rafiq/sfx');

  static Future<void> load(List<String> names) async {
    try {
      await _ch.invokeMethod<void>('load', {'names': names});
    } on PlatformException {
      // لا شيء
    } on MissingPluginException {
      // لا شيء
    }
  }

  static void play(String name) {
    _ch.invokeMethod<void>('play', {'name': name}).catchError((_) {});
  }
}
