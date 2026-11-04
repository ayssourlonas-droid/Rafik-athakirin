#version 460 core
#include <flutter/runtime_effect.glsl>

// التواء صفحة المصحف: التحويل عكسي — لكل بكسل نحسب أي نقطة من الورقة تظهر عنده.
// الفضاء القانوني: الثنية تبدأ من الحافة اليمنى وتتحرك يسارًا؛ عند uDir > 0
// نعكس المحور فتبدأ الثنية من اليسار (الصفحة التالية في الكتاب العربي).

uniform vec2 uSize;
uniform float uProgress;   // 0 مسطّحة .. 1 انقلبت كاملة
uniform float uDir;        // +1 تالية، -1 سابقة
uniform float uRadius;     // نصف قطر الثنية (نسبة من العرض)
uniform vec3 uPaper;       // لون ظهر الورقة
uniform sampler2D uTexture;

out vec4 fragColor;

const float PI = 3.14159265;

float toU(float s) {
  if (uDir > 0.0) {
    return 1.0 - s;
  }
  return s;
}

vec4 pageAt(float s, float y) {
  return texture(uTexture, vec2(toU(s), y));
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float x = uv.x;
  if (uDir > 0.0) {
    x = 1.0 - uv.x;
  }
  float y = uv.y;
  float r = uRadius;
  // خط الثنية: من الحافة (1) إلى خارج الشاشة (-r) فيختفي الملفوف كله
  float c = 1.0 - uProgress * (1.0 + r);

  vec4 col = vec4(0.0);

  // ١) الجزء المسطّح (الوجه الأمامي)
  if (x <= c) {
    col = pageAt(x, y);
  }

  // ٢) ظهر الورقة المسطّح فوقه إن امتدت الورقة بعد نصف الأسطوانة
  float flatEnd = 2.0 * c + PI * r - 1.0;
  if (x <= c) {
    float s = 2.0 * c + PI * r - x;
    if (s <= 1.0) {
      vec4 t = pageAt(s, y);
      vec3 back = mix(uPaper * 0.94, t.rgb * 0.92, 0.14);
      col = vec4(back, 1.0);
    } else if (flatEnd < c && col.a > 0.0) {
      float d = flatEnd - x;
      if (d > 0.0 && d < 0.07) {
        col.rgb *= 1.0 - 0.30 * (1.0 - d / 0.07);
      }
    }
  }

  // ٣) قوس الأسطوانة
  if (x >= c && x <= c + r) {
    float k = clamp((x - c) / r, 0.0, 1.0);
    float th1 = asin(k);

    float s1 = c + r * th1;
    if (s1 >= 0.0 && s1 <= 1.0) {
      vec4 t = pageAt(s1, y);
      float shade = mix(1.0, 0.80, th1 / (PI * 0.5));
      col = vec4(t.rgb * shade, t.a);
    }

    float th2 = PI - th1;
    float s2 = c + r * th2;
    if (s2 >= 0.0 && s2 <= 1.0) {
      vec4 t = pageAt(s2, y);
      float lit = mix(0.78, 1.0, (th2 - PI * 0.5) / (PI * 0.5));
      vec3 back = mix(uPaper, t.rgb, 0.14) * lit * 0.95;
      col = vec4(back, 1.0);
    }
  }

  // ٤) ظل الثنية على ما تحتها حيث لا ورقة
  if (x > c + r) {
    float sh = (1.0 - smoothstep(c + r, c + r + 0.14, x)) * 0.38
        * (1.0 - smoothstep(0.85, 1.0, uProgress));
    col = vec4(0.0, 0.0, 0.0, sh);
  }

  // الألوان هنا مضروبة مسبقًا في الشفافية (premultiplied) كما يتوقع فلتر
  fragColor = col;
}
