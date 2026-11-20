#!/usr/bin/env python3
"""يولّد أيقونة أندرويد (قديمة + تكيّفية) من tools/icons/app_icon_source.png إلى tools/icons/res/.
التشغيل (يحتاج Pillow):  python3 tools/make_icons.py
الـ workflow ينسخ tools/icons/res إلى android/app/src/main/res أثناء البناء."""
import pathlib
from PIL import Image, ImageDraw, ImageFilter

HERE = pathlib.Path(__file__).parent / "icons"
SRC = Image.open(HERE / "app_icon_source.png").convert("RGBA")
OUT = HERE / "res"
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FOREGROUND = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
SCALE = 0.60  # حجم الرسم داخل الطبقة الأمامية (المنطقة الآمنة للأقنعة الدائرية)


def border_color(im):
    w, h = im.size
    band = max(2, w // 40)
    px = []
    for x in range(0, w, 7):
        for y in list(range(0, band)) + list(range(h - band, h)):
            px.append(im.getpixel((x, y))[:3])
    for y in range(0, h, 7):
        for x in list(range(0, band)) + list(range(w - band, w)):
            px.append(im.getpixel((x, y))[:3])
    return tuple(sum(c[i] for c in px) // len(px) for i in range(3))


BG = border_color(SRC)
BG_HEX = "#%02X%02X%02X" % BG


def foreground(size):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * SCALE)
    art = SRC.resize((inner, inner), Image.LANCZOS)
    # حواف متلاشية كي لا يظهر فرق بين لون الصورة والخلفية
    feather = max(2, int(inner * 0.025))  # أقل من بُعد الإطار الذهبي عن الحافة (~5%)
    mask = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(mask).rectangle([feather, feather, inner - feather, inner - feather], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(feather / 2))
    art.putalpha(mask)
    canvas.paste(art, ((size - inner) // 2, (size - inner) // 2), art)
    return canvas


for d, px in LEGACY.items():
    p = OUT / f"mipmap-{d}"
    p.mkdir(parents=True, exist_ok=True)
    SRC.convert("RGB").resize((px, px), Image.LANCZOS).save(p / "ic_launcher.png", optimize=True)
for d, px in FOREGROUND.items():
    p = OUT / f"mipmap-{d}"
    p.mkdir(parents=True, exist_ok=True)
    foreground(px).save(p / "ic_launcher_foreground.png", optimize=True)

(OUT / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
(OUT / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    "</adaptive-icon>\n", encoding="utf-8")
(OUT / "values").mkdir(parents=True, exist_ok=True)
(OUT / "values/ic_launcher_background.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    f'    <color name="ic_launcher_background">{BG_HEX}</color>\n</resources>\n', encoding="utf-8")
print("خلفية الأيقونة التكيّفية:", BG_HEX)
