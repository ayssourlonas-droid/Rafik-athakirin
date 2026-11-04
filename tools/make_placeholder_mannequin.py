#!/usr/bin/env python3
"""يولّد دمية بسيطة جدًا (GLB) لاختبار خط العمل قبل وصول النموذج الحقيقي.

- بلا وجه، أعضاؤها أشكال هندسية، ومفاصلها عقد glTF بأسماء واضحة (Hips, Spine, Chest,
  Neck, Head, UpperArm_L, LowerArm_L, Hand_L, UpperLeg_L, LowerLeg_L, Foot_L وما يقابلها _R).
- هذه ليست الدمية النهائية؛ تُستبدل بملف GLB حقيقي لاحقًا.
الاستعمال:  python3 make_placeholder_mannequin.py [مسار_الإخراج]
"""
import json
import math
import struct
import sys

import numpy as np

# ───────────── مولّدات الأشكال ─────────────
def box(w, h, d, center=(0, 0, 0)):
    cx, cy, cz = center
    x, y, z = w / 2, h / 2, d / 2
    faces = [  # (normal, 4 corners)
        ((0, 0, 1), [(-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]),
        ((0, 0, -1), [(x, -y, -z), (-x, -y, -z), (-x, y, -z), (x, y, -z)]),
        ((1, 0, 0), [(x, -y, z), (x, -y, -z), (x, y, -z), (x, y, z)]),
        ((-1, 0, 0), [(-x, -y, -z), (-x, -y, z), (-x, y, z), (-x, y, -z)]),
        ((0, 1, 0), [(-x, y, z), (x, y, z), (x, y, -z), (-x, y, -z)]),
        ((0, -1, 0), [(-x, -y, -z), (x, -y, -z), (x, -y, z), (-x, -y, z)]),
    ]
    P, N, I = [], [], []
    for n, quad in faces:
        base = len(P)
        for c in quad:
            P.append((c[0] + cx, c[1] + cy, c[2] + cz))
            N.append(n)
        I += [base, base + 1, base + 2, base, base + 2, base + 3]
    return np.array(P, np.float32), np.array(N, np.float32), np.array(I, np.uint16)


def sphere(r, center=(0, 0, 0), scale=(1, 1, 1), seg=20, rings=12):
    P, N, I = [], [], []
    for i in range(rings + 1):
        v = i / rings
        th = v * math.pi
        for j in range(seg + 1):
            u = j / seg
            ph = u * 2 * math.pi
            nx, ny, nz = math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)
            P.append((center[0] + r * scale[0] * nx, center[1] + r * scale[1] * ny, center[2] + r * scale[2] * nz))
            nn = np.array([nx / scale[0], ny / scale[1], nz / scale[2]])
            nn = nn / np.linalg.norm(nn)
            N.append(tuple(nn))
    for i in range(rings):
        for j in range(seg):
            a = i * (seg + 1) + j
            b = a + seg + 1
            I += [a, b, a + 1, a + 1, b, b + 1]
    return np.array(P, np.float32), np.array(N, np.float32), np.array(I, np.uint16)


def tube_down(r_top, r_bot, length, seg=20):
    """أسطوانة (مخروط مقطوع) تمتد من y=0 إلى y=-length."""
    P, N, I = [], [], []
    slope = (r_top - r_bot) / length
    for k, (y, r) in enumerate(((0.0, r_top), (-length, r_bot))):
        for j in range(seg + 1):
            ph = j / seg * 2 * math.pi
            c, s = math.cos(ph), math.sin(ph)
            P.append((r * c, y, r * s))
            n = np.array([c, slope, s])
            N.append(tuple(n / np.linalg.norm(n)))
    for j in range(seg):
        a, b = j, j + seg + 1
        I += [a, b, a + 1, a + 1, b, b + 1]
    return np.array(P, np.float32), np.array(N, np.float32), np.array(I, np.uint16)


def merge(*meshes):
    P, N, I, off = [], [], [], 0
    for p, n, i in meshes:
        P.append(p); N.append(n); I.append(i.astype(np.uint32) + off); off += len(p)
    idx = np.concatenate(I)
    assert idx.max() < 65535
    return np.concatenate(P), np.concatenate(N), idx.astype(np.uint16)


# ───────────── تعريف الهيكل ─────────────
def qz(deg):
    a = math.radians(deg) / 2
    return [0.0, 0.0, math.sin(a), math.cos(a)]


def limb_nodes(side, sx):
    """sx = +1 لليسار، -1 لليمين."""
    arm_deg = 18 * sx
    return [
        dict(name=f"UpperArm_{side}", t=(0.20 * sx, 0.25, 0), r=qz(arm_deg),
             mesh=merge(tube_down(0.048, 0.040, 0.28), sphere(0.052)), children=[
            dict(name=f"LowerArm_{side}", t=(0, -0.28, 0),
                 mesh=merge(tube_down(0.040, 0.032, 0.26), sphere(0.044)), children=[
                dict(name=f"Hand_{side}", t=(0, -0.26, 0),
                     mesh=merge(box(0.085, 0.11, 0.032, (0, -0.055, 0)), sphere(0.034)))])]),
    ]


def leg_nodes(side, sx):
    return dict(name=f"UpperLeg_{side}", t=(0.09 * sx, -0.07, 0),
                mesh=merge(tube_down(0.075, 0.058, 0.42), sphere(0.078)), children=[
        dict(name=f"LowerLeg_{side}", t=(0, -0.42, 0),
             mesh=merge(tube_down(0.058, 0.040, 0.42), sphere(0.060)), children=[
            dict(name=f"Foot_{side}", t=(0, -0.42, 0),
                 mesh=merge(box(0.09, 0.06, 0.25, (0, -0.03, 0.06)), sphere(0.042)))])])


def build_tree():
    chest_children = [
        dict(name="Neck", t=(0, 0.30, 0), mesh=tube_down(0.05, 0.05, 0.0001) if False else merge(sphere(0.052, (0, 0.04, 0), (1, 1.4, 1))),
             children=[dict(name="Head", t=(0, 0.08, 0), mesh=sphere(0.105, (0, 0.11, 0), (0.92, 1.1, 1.0)))]),
        *limb_nodes("L", +1), *limb_nodes("R", -1),
    ]
    return dict(name="Hips", t=(0, 0.95, 0), mesh=box(0.34, 0.17, 0.20), children=[
        dict(name="Spine", t=(0, 0.09, 0), mesh=box(0.31, 0.22, 0.19, (0, 0.11, 0)), children=[
            dict(name="Chest", t=(0, 0.22, 0), mesh=box(0.37, 0.30, 0.21, (0, 0.14, 0)), children=chest_children)]),
        leg_nodes("L", +1), leg_nodes("R", -1)])


# ───────────── كتابة GLB ─────────────
def write_glb(root, path):
    nodes, meshes, accessors, views = [], [], [], []
    blob = bytearray()

    def add_view(data, target):
        while len(blob) % 4: blob.append(0)
        views.append(dict(buffer=0, byteOffset=len(blob), byteLength=len(data), target=target))
        blob.extend(data)
        return len(views) - 1

    def add_node(d):
        idx = len(nodes)
        node = {"name": d["name"], "translation": [float(v) for v in d["t"]]}
        if "r" in d: node["rotation"] = d["r"]
        nodes.append(node)
        if d.get("mesh") is not None:
            P, N, I = d["mesh"]
            vp = add_view(P.tobytes(), 34962); vn = add_view(N.tobytes(), 34962); vi = add_view(I.tobytes(), 34963)
            a0 = len(accessors)
            accessors.append(dict(bufferView=vp, componentType=5126, count=len(P), type="VEC3",
                                  min=[float(x) for x in P.min(0)], max=[float(x) for x in P.max(0)]))
            accessors.append(dict(bufferView=vn, componentType=5126, count=len(N), type="VEC3"))
            accessors.append(dict(bufferView=vi, componentType=5123, count=len(I), type="SCALAR"))
            meshes.append(dict(name=d["name"] + "_mesh", primitives=[dict(
                attributes={"POSITION": a0, "NORMAL": a0 + 1}, indices=a0 + 2, material=0, mode=4)]))
            node["mesh"] = len(meshes) - 1
        kids = [add_node(c) for c in d.get("children", [])]
        if kids: node["children"] = kids
        return idx

    add_node(root)
    gltf = {
        "asset": {"version": "2.0", "generator": "make_placeholder_mannequin.py"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": nodes, "meshes": meshes,
        "materials": [{"name": "mannequin", "pbrMetallicRoughness": {
            "baseColorFactor": [0.80, 0.76, 0.68, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.8}}],
        "accessors": accessors, "bufferViews": views, "buffers": [{"byteLength": len(blob)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(blob) % 4: blob.append(0)
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON")); f.write(js)
        f.write(struct.pack("<I4s", len(blob), b"BIN\x00")); f.write(bytes(blob))
    return len(nodes), total


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "mannequin_placeholder.glb"
    n, size = write_glb(build_tree(), out)
    print(f"تم: {out} — {n} عقدة، {size} بايت")
