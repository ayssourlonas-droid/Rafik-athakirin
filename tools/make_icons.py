#!/usr/bin/env python3
"""يولّد أيقونات أندرويد (قديمة + تكيّفية + إشعار) من tools/icons/app_icon_source.png.
كل الناتج في مجلد واحد tools/icons، واسم الملف = مجلد الهدف في أندرويد + "__" + اسمه
(مثل mipmap-hdpi__ic_launcher.png)، وينسخها tools/patch_android.py إلى res أثناء البناء.
التشغيل (يحتاج Pillow وnumpy):  python3 tools/make_icons.py"""
import pathlib
from PIL import Image, ImageDraw, ImageFilter

HERE = pathlib.Path(__file__).parent / "icons"
SRC = Image.open(HERE / "app_icon_source.png").convert("RGBA")


def out_path(folder, name):
    return HERE / f"{folder}__{name}"


for old in HERE.glob("*__*"):  # مسح الناتج القديم قبل التوليد
    old.unlink()
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
    SRC.convert("RGB").resize((px, px), Image.LANCZOS).save(out_path(f"mipmap-{d}", "ic_launcher.png"), optimize=True)
for d, px in FOREGROUND.items():
    foreground(px).save(out_path(f"mipmap-{d}", "ic_launcher_foreground.png"), optimize=True)

out_path("mipmap-anydpi-v26", "ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@color/ic_launcher_background"/>\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
    "</adaptive-icon>\n", encoding="utf-8")
out_path("values", "ic_launcher_background.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
    f'    <color name="ic_launcher_background">{BG_HEX}</color>\n</resources>\n', encoding="utf-8")
print("خلفية الأيقونة التكيّفية:", BG_HEX)


# ───────── أيقونة الإشعار الصغيرة (أبيض على شفاف، هلال فوق كتاب) ─────────
def stat_icon():
    import collections
    import numpy as np
    rgb = np.array(SRC.convert("RGB")).astype(int)
    mask = rgb[:, :, 0] > 55  # الذهب والنحاس؛ خلفية التيل قيمة الأحمر فيها ≈ 1

    def comp(seed, box):
        x0, y0, x1, y1 = box
        seen = np.zeros_like(mask)
        q = collections.deque([seed])
        seen[seed] = True
        while q:
            y, x = q.popleft()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if y0 <= ny < y1 and x0 <= nx < x1 and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        return seen

    # إحداثيات مضبوطة على الصورة الحالية (1254×1254): الهلال ثم الكتاب
    sil = comp((480, 420), (300, 230, 950, 770)) | comp((900, 640), (215, 765, 1040, 1072))
    img = Image.fromarray((sil * 255).astype("uint8"))
    img = img.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.MinFilter(9)).filter(ImageFilter.GaussianBlur(3))
    ys, xs = np.where(np.array(img) > 20)
    crop = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = max(crop.size)
    sq = Image.new("L", (side, side), 0)
    sq.paste(crop, ((side - crop.size[0]) // 2, (side - crop.size[1]) // 2))
    for d, px in {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}.items():
        inner = round(px * 0.88)
        white = Image.new("RGBA", (inner, inner), (255, 255, 255, 255))
        white.putalpha(sq.resize((inner, inner), Image.LANCZOS))
        out = Image.new("RGBA", (px, px), (255, 255, 255, 0))
        out.paste(white, ((px - inner) // 2, (px - inner) // 2), white)
        out.save(out_path(f"drawable-{d}", "ic_stat_adhan.png"), optimize=True)
    print("✓ ic_stat_adhan (أيقونة الإشعار)")


try:
    stat_icon()
except ImportError:
    print("تخطّيت أيقونة الإشعار: ثبّت numpy (pip install numpy)")
