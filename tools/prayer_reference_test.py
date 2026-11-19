#!/usr/bin/env python3
"""مرجع اختبار لحساب المواقيت: نسخة بايثون تطابق بنية lib/prayer_calc.dart دالةً بدالة،
تُقارَن بحساب فلكي مستقل (خوارزمية NOAA) للشروق والغروب والزوال.
الغرض: التحقق من صحة المنطق الفلكي قبل نقله، لا تحقيق مواقيت رسمية."""
import math

def sin(d): return math.sin(math.radians(d))
def cos(d): return math.cos(math.radians(d))
def tan(d): return math.tan(math.radians(d))
def asin(x): return math.degrees(math.asin(x))
def acos(x): return math.degrees(math.acos(x))
def atan2(y, x): return math.degrees(math.atan2(y, x))
def acot(x): return math.degrees(math.atan(1.0 / x))
def fix_angle(a): return a if math.isnan(a) else a - 360.0 * math.floor(a / 360.0)
def fix_hour(h): return h if math.isnan(h) else h - 24.0 * math.floor(h / 24.0)  # NaN يمرّ كما هو (في دارت floor على NaN يرمي استثناء)

def julian(y, m, d):
    if m <= 2: y -= 1; m += 12
    a = math.floor(y / 100.0); b = 2 - a + math.floor(a / 4.0)
    return math.floor(365.25 * (y + 4716)) + math.floor(30.6001 * (m + 1)) + d + b - 1524.5

def sun_position(jd):
    D = jd - 2451545.0
    g = fix_angle(357.529 + 0.98560028 * D)
    q = fix_angle(280.459 + 0.98564736 * D)
    L = fix_angle(q + 1.915 * sin(g) + 0.020 * sin(2 * g))
    e = 23.439 - 0.00000036 * D
    ra = fix_hour(atan2(cos(e) * sin(L), cos(L)) / 15.0)
    return asin(sin(e) * sin(L)), q / 15.0 - ra   # (declination, equation of time)

METHODS = {
    "mwl": (18.0, 17.0, None), "isna": (15.0, 15.0, None), "egypt": (19.5, 17.5, None),
    "makkah": (18.5, None, 90.0), "karachi": (18.0, 18.0, None),
    "tunisia": (18.0, 18.0, None), "algeria": (18.0, 17.0, None),
    "morocco": (19.0, 17.0, None), "turkey": (18.0, 17.0, None),
}

def compute(y, m, d, lat, lng, tz, method="mwl", asr_factor=1.0):
    fajr_a, isha_a, isha_min = METHODS[method]
    jd0 = julian(y, m, d) - lng / (15.0 * 24.0)

    def mid_day(t): return fix_hour(12.0 - sun_position(jd0 + t)[1])
    def angle_time(angle, t, ccw=False):
        decl = sun_position(jd0 + t)[0]; noon = mid_day(t)
        x = (-sin(angle) - sin(decl) * sin(lat)) / (cos(decl) * cos(lat))
        if x < -1 or x > 1: return float("nan")
        h = acos(x) / 15.0
        return noon + (-h if ccw else h)
    def asr_time(t):
        decl = sun_position(jd0 + t)[0]
        ang = -acot(asr_factor + tan(abs(lat - decl)))
        return angle_time(ang, t)

    t = {"fajr": 5 / 24, "sunrise": 6 / 24, "dhuhr": 12 / 24, "asr": 13 / 24, "sunset": 18 / 24, "isha": 18 / 24}
    r = {
        "fajr": angle_time(fajr_a, t["fajr"], True),
        "sunrise": angle_time(0.833, t["sunrise"], True),
        "dhuhr": mid_day(t["dhuhr"]),
        "asr": asr_time(t["asr"]),
        "sunset": angle_time(0.833, t["sunset"]),
    }
    r["isha"] = angle_time(isha_a, t["isha"]) if isha_a is not None else float("nan")
    # أطراف الشمال/الجنوب: نصف الليل
    night = fix_hour(r["sunrise"] - r["sunset"]) if not (math.isnan(r["sunrise"]) or math.isnan(r["sunset"])) else float("nan")
    def adjust(time, base, ccw):
        if math.isnan(night): return time
        portion = night / 2.0
        if math.isnan(time):
            return base - portion if ccw else base + portion
        diff = fix_hour(base - time) if ccw else fix_hour(time - base)
        if diff > portion:
            return base - portion if ccw else base + portion
        return time
    r["fajr"] = adjust(r["fajr"], r["sunrise"], True)
    if isha_a is not None: r["isha"] = adjust(r["isha"], r["sunset"], False)
    r["maghrib"] = r["sunset"]
    if isha_min is not None: r["isha"] = r["maghrib"] + isha_min / 60.0
    off = tz - lng / 15.0
    return {k: fix_hour(v + off) for k, v in r.items()}

def noaa_events(y, m, d, lat, lng, tz):
    jd = julian(y, m, d) + 0.5 - tz / 24.0        # منتصف النهار المحلي
    T = (jd - 2451545.0) / 36525.0
    L0 = fix_angle(280.46646 + T * (36000.76983 + T * 0.0003032))
    M = 357.52911 + T * (35999.05029 - 0.0001537 * T)
    ecc = 0.016708634 - T * (0.000042037 + 0.0000001267 * T)
    C = sin(M) * (1.914602 - T * (0.004817 + 0.000014 * T)) + sin(2 * M) * (0.019993 - 0.000101 * T) + sin(3 * M) * 0.000289
    app = L0 + C - 0.00569 - 0.00478 * sin(125.04 - 1934.136 * T)
    mo = 23 + (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60
    oc = mo + 0.00256 * cos(125.04 - 1934.136 * T)
    decl = asin(sin(oc) * sin(app))
    yy = tan(oc / 2) ** 2
    eq = 4 * math.degrees(yy * sin(2 * L0) - 2 * ecc * sin(M) + 4 * ecc * yy * sin(M) * cos(2 * L0)
                          - 0.5 * yy * yy * sin(4 * L0) - 1.25 * ecc * ecc * sin(2 * M))
    ha = acos(cos(90.833) / (cos(lat) * cos(decl)) - tan(lat) * tan(decl))
    noon = (720 - 4 * lng - eq + tz * 60) / 60.0
    return {"sunrise": noon - ha * 4 / 60.0, "dhuhr": noon, "sunset": noon + ha * 4 / 60.0}

def hm(h):
    if math.isnan(h): return "--:--"
    m = round(h * 60) % 1440
    return f"{m // 60:02d}:{m % 60:02d}"

if __name__ == "__main__":
    cases = [("مكة", 21.3891, 39.8579, 3, "makkah"), ("تونس", 36.8065, 10.1815, 1, "tunisia"),
             ("إسطنبول", 41.0082, 28.9784, 3, "turkey"), ("نيويورك", 40.7128, -74.0060, -5, "isna"),
             ("جاكرتا", -6.2088, 106.8456, 7, "mwl"), ("ستوكهولم", 59.3293, 18.0686, 1, "mwl")]
    dates = [(2026, 3, 20), (2026, 6, 21), (2026, 12, 21)]
    worst = 0.0
    for name, lat, lng, tz, meth in cases:
        for (y, m, d) in dates:
            tzz = tz + (1 if (name in ("تونس",) and False) else 0)
            r = compute(y, m, d, lat, lng, tzz, meth)
            n = noaa_events(y, m, d, lat, lng, tzz)
            diffs = {k: abs(((r[k] - n[k] + 12) % 24) - 12) * 60 for k in ("sunrise", "dhuhr", "sunset")}
            worst = max(worst, max(diffs.values()))
            print(f"{name:8s} {y}-{m:02d}-{d:02d} {meth:8s} فجر {hm(r['fajr'])} شروق {hm(r['sunrise'])} ظهر {hm(r['dhuhr'])} "
                  f"عصر {hm(r['asr'])} مغرب {hm(r['maghrib'])} عشاء {hm(r['isha'])} | أقصى فرق عن NOAA: {max(diffs.values()):.2f} د")
    print(f"\nأكبر فرق عن الحساب المستقل: {worst:.2f} دقيقة")
