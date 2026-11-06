#!/usr/bin/env python3
"""The Galactic Shop's art (2026-11-06; Data/Galactic): a card for every effect, title and skin, and the
grey copy of the explosions atlas a weapon effect is tinted from (Map/FxLayer.MONO_ATLAS).

  assets/embedded/galactic/<key>.png   a 3:2 card (the shop's card art, the Locker, the crate reveal)
  assets/embedded/fx/map_fx_mono.png   assets/map_fx/map_fx.png in grey (its brightness), same layout

Both are embedded by tools/assets/embed_images.py (run it after this). The items, their colours and the
skins' masks are read from src/shared/Data/Galactic.luau, so a new item there only needs this run again.

Usage: python3 tools/assets/make_galactic_art.py --font <a heavy .ttf, e.g. Montserrat Black>
"""
import argparse
import math
import os
import random
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "src", "shared", "Data", "Galactic.luau")
OUT = os.path.join(ROOT, "assets", "embedded", "galactic")
MAP_FX = os.path.join(ROOT, "assets", "map_fx", "map_fx.png")
MONO = os.path.join(ROOT, "assets", "embedded", "fx", "map_fx_mono.png")
W, H = 240, 160
PREVIEW_COLOR = (64, 132, 230)  # (UI/Locker.PREVIEW_COLOR: a skin shown on blue land)


def rgb(n):
    return ((n >> 16) & 255, (n >> 8) & 255, n & 255)


def items():
    """{kind, key, ...} for every entry of EFFECTS / TITLES / SKINS in Galactic.luau."""
    src = open(SRC, encoding="utf-8").read()
    out = []
    for table, kind in (("EFFECTS", "fx"), ("TITLES", "plate"), ("SKINS", "skin")):
        m = re.search(r"Galactic\.%s = \{(.*?)\n\}" % table, src, re.S)
        body = m.group(1)
        for e in re.finditer(r"\{\s*(key = .*?)\n?\t?\},?\n", body + "\n", re.S):
            text = e.group(1)
            it = {"kind": kind}
            for k, v in re.findall(r"(\w+) = (0x[0-9A-Fa-f]+|\"[^\"]*\"|true|false|\d+)", text):
                if v.startswith("0x"):
                    it[k] = int(v, 16)
                elif v.startswith('"'):
                    it[k] = v[1:-1]
                else:
                    it[k] = v
            mm = re.search(r"mask = \{([^}]*)", text)
            if mm:
                it["mask"] = re.findall(r"\"([^\"]*)\"", mm.group(1))
            out.append(it)
    return out


def space_bg(seed, tint=(0, 0, 0)):
    """Deep space: a dark gradient, a soft glow of `tint` and a few stars."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    top, bot = np.array([18, 20, 46], np.float32), np.array([6, 7, 18], np.float32)
    t = (yy / H)[..., None]
    img = top * (1 - t) + bot * t
    d = np.sqrt(((xx - W / 2) / W) ** 2 + ((yy - H / 2) / H) ** 2)
    glow = np.clip(1 - d * 2.2, 0, 1)[..., None] ** 2
    img = img + np.array(tint, np.float32) * glow * 0.35
    rnd = random.Random(seed)
    for _ in range(38):
        x, y = rnd.randrange(W), rnd.randrange(H)
        b = rnd.uniform(90, 230)
        img[y, x] = np.maximum(img[y, x], b)
    return img


def radial(cx, cy, r):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    return np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r


def fx_card(it, seed):
    c1, c2 = np.array(rgb(it["color"]), np.float32), np.array(rgb(it.get("color2", it["color"])), np.float32)
    img = space_bg(seed, c1)
    cx, cy = W * 0.5, H * 0.52
    d = radial(cx, cy, 52)
    # the fireball: color at the rim to color2 at the core, a white-hot centre
    ball = np.clip(1 - d, 0, 1)
    col = c1[None, None, :] * (1 - ball[..., None] ** 0.6) + c2[None, None, :] * (ball[..., None] ** 0.6)
    a = np.clip(ball * 1.6, 0, 1)[..., None] ** 0.8
    img = img * (1 - a) + col * a
    core = np.clip(1 - d * 3.2, 0, 1)[..., None] ** 1.5
    img = img * (1 - core) + 255 * core
    # the shockwave ring
    ring = np.exp(-((d - 1.18) / 0.06) ** 2)[..., None]
    img = img + c1 * ring * 0.9 + 255 * ring * 0.25
    # a wide glow
    halo = np.clip(1 - d / 2.0, 0, 1)[..., None] ** 2
    img = img + c1 * halo * 0.35
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    # rays and sparks
    over = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(over)
    rnd = random.Random(seed * 7 + 1)
    for i in range(14):
        ang = i / 14 * math.tau + rnd.uniform(-0.15, 0.15)
        r0, r1 = 26, rnd.uniform(58, 80)
        p0 = (cx + math.cos(ang) * r0, cy + math.sin(ang) * r0)
        p1 = (cx + math.cos(ang) * r1, cy + math.sin(ang) * r1)
        dr.line([p0, p1], fill=tuple(int(v) for v in c2) + (150,), width=2)
    for _ in range(30):
        ang, r = rnd.uniform(0, math.tau), rnd.uniform(34, 90)
        x, y = cx + math.cos(ang) * r * 1.3, cy + math.sin(ang) * r * 0.85
        s = rnd.uniform(1, 2.6)
        dr.ellipse([x - s, y - s, x + s, y + s], fill=tuple(int(v) for v in c1) + (230,))
    over = over.filter(ImageFilter.GaussianBlur(0.6))
    im.alpha_composite(over)
    if it.get("key") == "fx_blackhole":
        # a black hole: a dark core inside a bright accretion ring
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=255)
        m = m.filter(ImageFilter.GaussianBlur(3))
        black = Image.new("RGBA", (W, H), (4, 2, 10, 255))
        black.putalpha(m)
        im.alpha_composite(black)
    return im


def title_card(it, font_path, seed):
    c1, c2 = rgb(it["color"]), rgb(it.get("color2", it["color"]))
    glow = rgb(it.get("glow", 0))
    img = space_bg(seed, c2)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    text = it.get("text") or it["name"].upper()
    size = 54
    f = ImageFont.truetype(font_path, size)
    while f.getbbox(text)[2] - f.getbbox(text)[0] > W - 26 and size > 14:
        size -= 2
        f = ImageFont.truetype(font_path, size)
    l, t, r, b = f.getbbox(text)
    x, y = (W - (r - l)) / 2 - l, (H - (b - t)) / 2 - t
    stroke = max(2, size // 9)
    # the glow: the text's outline blurred in color2
    g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(g).text((x, y), text, font=f, fill=c2 + (255,), stroke_width=stroke + 4, stroke_fill=c2 + (255,))
    im.alpha_composite(g.filter(ImageFilter.GaussianBlur(9)))
    # the outline (glow colour), then the fill as a vertical gradient color -> color2
    o = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(o).text((x, y), text, font=f, fill=glow + (255,), stroke_width=stroke, stroke_fill=glow + (255,))
    im.alpha_composite(o)
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).text((x, y), text, font=f, fill=255)
    yy = np.mgrid[0:H, 0:W][0].astype(np.float32)
    tt = np.clip((yy - (y + t)) / max(1, (b - t)), 0, 1)[..., None]
    grad = np.array(c1, np.float32) * (1 - tt) + np.array(c2, np.float32) * tt
    fill = Image.fromarray(grad.astype(np.uint8), "RGB").convert("RGBA")
    fill.putalpha(m)
    im.alpha_composite(fill)
    # a little sparkle at a corner of the word
    sp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sp)
    sx, sy = x + r - 4, y + t - 2
    for a, ln in ((0, 9), (math.pi / 2, 9), (math.pi / 4, 4), (3 * math.pi / 4, 4)):
        ds.line([(sx - math.cos(a) * ln, sy - math.sin(a) * ln), (sx + math.cos(a) * ln, sy + math.sin(a) * ln)],
                fill=(255, 255, 255, 235), width=2)
    im.alpha_composite(sp)
    return im


def skin_card(it):
    """The skin's mask tiled over blue land ('#' in its accent), 4 px a tile, a darker border."""
    mask = it["mask"]
    acc = rgb(it.get("accent", 0xFFFFFF))
    px = 5 * (2 ** int(it.get("scale", 0) or 0))
    img = np.zeros((H, W, 3), np.float32)
    mh, mw = len(mask), len(mask[0])
    base = np.array(PREVIEW_COLOR, np.float32)
    for y in range(H):
        for x in range(W):
            tx, ty = x // px, y // px
            on = mask[ty % mh][tx % mw] == "#"
            img[y, x] = acc if on else base
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    v = np.clip(1 - (((xx - W / 2) / W) ** 2 + ((yy - H / 2) / H) ** 2) * 1.4, 0.55, 1)[..., None]
    img *= v
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W - 1, H - 1], outline=(20, 40, 90, 255), width=4)
    return im


def mono_atlas():
    src = Image.open(MAP_FX).convert("RGBA")
    a = np.asarray(src).astype(np.float32)
    v = np.max(a[..., :3], axis=2) / 255.0
    v = np.clip(v ** 0.8 * 1.08, 0, 1) * 255
    out = np.dstack([v, v, v, a[..., 3]]).astype(np.uint8)
    os.makedirs(os.path.dirname(MONO), exist_ok=True)
    Image.fromarray(out, "RGBA").save(MONO, optimize=True)
    print("wrote", os.path.relpath(MONO, ROOT))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--font", required=True)
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    mono_atlas()
    for i, it in enumerate(items()):
        if it["kind"] == "fx":
            im = fx_card(it, i + 1)
        elif it["kind"] == "plate":
            im = title_card(it, a.font, i + 1)
        else:
            im = skin_card(it)
        p = os.path.join(OUT, it["key"] + ".png")
        im.convert("RGB").save(p, optimize=True)
        print("wrote", os.path.relpath(p, ROOT))


if __name__ == "__main__":
    main()
