#!/usr/bin/env python3
"""يتحقق من سلامة نص القرآن في المشروع، ويُشغَّل تلقائيًا قبل كل بناء (build_apk.yml).

الفحوص:
 1) بصمة SHA-256 لكل ملف في assets/data وassets/fonts مطابقة لـ tools/quran_checksums.txt
    (أي تغيير ولو حرف واحد في بيانات القرآن أو تفسيره أو خطه يفشل البناء).
 2) البنية: 114 سورة و6236 آية، وعدد آيات كل سورة يطابق surah_index.json.
 3) البسملة: التطبيق يحذف البسملة من الآية الأولى (لأنها تُعرض عنوانًا مستقلًا). نتحقق أن المحذوف
    كلمات البسملة فقط، وأن البسملة + الباقي = النص الأصلي حرفًا بحرف، وأنها لا تحذف شيئًا من
    الفاتحة (آيتها الأولى هي البسملة) ولا من التوبة (لا بسملة فيها).

بعد تعديل مقصود في البيانات (استبدال ملف مثلًا): python3 tools/verify_quran.py --update
"""
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SUMS = ROOT / "tools/quran_checksums.txt"
GUARDED = ["assets/data", "assets/fonts"]

# شكل البسملة في البيانات (الفاتحة آية 1)، وشكل آخر فيه شدّة زائدة على الباء في سورتين (95 و97)
BASMALA = "\u0628\u0650\u0633\u0652\u0645\u0650 \u0671\u0644\u0644\u0651\u064e\u0647\u0650 \u0671\u0644\u0631\u0651\u064e\u062d\u0652\u0645\u064e\u0640\u0670\u0646\u0650 \u0671\u0644\u0631\u0651\u064e\u062d\u0650\u064a\u0645\u0650"
BASMALA_EXTRA_SHADDA = BASMALA[0] + "\u0651" + BASMALA[1:]
KNOWN_PREFIXES = {BASMALA, BASMALA_EXTRA_SHADDA}

MARKS = re.compile("[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]")
SUBS = [("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ٱ", "ا"), ("ى", "ي"), ("ة", "ه"), ("ؤ", "و"), ("ئ", "ي"), ("ء", "")]
TARGET = ["بسم", "الله", "الرحمن", "الرحيم"]


def normalize(t):  # نفس normalizeArabic في lib/data_repo.dart
    s = MARKS.sub("", t)
    for a, b in SUBS:
        s = s.replace(a, b)
    return s.lower()


def file_hashes():
    out = {}
    for sub in GUARDED:
        for p in sorted((ROOT / sub).rglob("*")):
            if p.is_file():
                out[p.relative_to(ROOT).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out


def main():
    current = file_hashes()
    if "--update" in sys.argv:
        SUMS.write_text("".join(f"{h}  {p}\n" for p, h in sorted(current.items())), encoding="utf-8")
        print(f"حُدّث {SUMS.name}: {len(current)} ملفًا")
        return 0

    errors, notes = [], []

    # 1) البصمات
    expected = {}
    for line in SUMS.read_text(encoding="utf-8").splitlines():
        if line.strip():
            h, p = line.split("  ", 1)
            expected[p] = h
    for p in sorted(set(expected) | set(current)):
        if p not in current:
            errors.append(f"ملف مفقود: {p}")
        elif p not in expected:
            errors.append(f"ملف جديد غير مسجَّل: {p}")
        elif current[p] != expected[p]:
            errors.append(f"تغيّر محتوى الملف: {p}")

    # 2) البنية
    data = json.loads((ROOT / "assets/data/quran_uthmani.json").read_text(encoding="utf-8"))["surahs"]
    index = json.loads((ROOT / "assets/data/surah_index.json").read_text(encoding="utf-8"))
    if len(data) != 114:
        errors.append(f"عدد السور {len(data)} بدل 114")
    total = sum(len(s["ayahs"]) for s in data)
    if total != 6236:
        errors.append(f"عدد الآيات {total} بدل 6236")
    for i, s in enumerate(data):
        if i < len(index) and len(s["ayahs"]) != index[i]["ayahs"]:
            errors.append(f"سورة {i + 1}: عدد الآيات {len(s['ayahs'])} لا يطابق الفهرس {index[i]['ayahs']}")

    # 3) البسملة
    if data and data[0]["ayahs"][0] != BASMALA:
        errors.append("الفاتحة آية 1 ليست البسملة بشكلها المرجعي")
    extra = []
    for i, s in enumerate(data):
        n = i + 1
        first = s["ayahs"][0]
        words = first.split(" ")
        has = len(words) > 4 and [normalize(w) for w in words[:4]] == TARGET
        if n in (1, 9):
            if has:
                errors.append(f"سورة {n}: لا يُفترض حذف بسملة منها")
            continue
        if not has:
            errors.append(f"سورة {n}: الآية الأولى لا تبدأ بالبسملة (لن يُحذف منها شيء)")
            continue
        prefix, rest = " ".join(words[:4]), " ".join(words[4:])
        if prefix + " " + rest != first:
            errors.append(f"سورة {n}: البسملة + الباقي لا يساويان النص الأصلي")
        if not rest.strip():
            errors.append(f"سورة {n}: لا يبقى نص بعد حذف البسملة")
        if prefix not in KNOWN_PREFIXES:
            errors.append(f"سورة {n}: المحذوف ليس شكلًا معروفًا للبسملة: {prefix!r}")
        if prefix == BASMALA_EXTRA_SHADDA:
            extra.append(n)
    if extra:
        notes.append(f"سور فيها شدّة زائدة على باء البسملة في ملف البيانات الأصلي (تُحذف مع البسملة): {extra}")

    for n in notes:
        print("ملاحظة:", n)
    if errors:
        print("✗ فشل التحقق من نص القرآن:")
        for e in errors:
            print("  -", e)
        return 1
    print(f"✓ نص القرآن سليم: {len(current)} ملفًا مطابقًا للبصمات، 114 سورة، {total} آية، والبسملة تُحذف بدقة من 112 سورة")
    return 0


if __name__ == "__main__":
    sys.exit(main())
