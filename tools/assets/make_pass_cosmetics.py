#!/usr/bin/env python3
"""Space Pass cosmetics (Galaxy Takeover): fleet skins, insignia and territory skins.

Writes
  assets/embedded/ships/<id>.png          trim atlas over the unit sprites (same cells as
                                          assets/map_sprites/units_one.png): drawn untinted on top
                                          of the owner-coloured sprite, so ships keep their owner's
                                          colour and wear the skin's trim
  assets/embedded/ships/<id>_preview.png  a rocketship, a battlecruiser and a missile in a sample colour
  assets/embedded/insignia/atlas.png      the insignia (shown by your name like a flag), 96 x 64 each
  src/shared/Data/PassCosmetics.luau      GENERATED: ids, names, skin masks, insignia rects

Insignia art: Noto Emoji (Google, Apache License 2.0) from the npm package @iconify-json/noto.

Usage: python3 tools/assets/make_pass_cosmetics.py --noto <path to @iconify-json/noto/icons.json>
then   python3 tools/assets/embed_images.py
"""
import argparse
import io
import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UNITS = os.path.join(ROOT, "assets", "map_sprites", "units_one.png")
EMB = os.path.join(ROOT, "assets", "embedded")
LUA = os.path.join(ROOT, "src", "shared", "Data", "PassCosmetics.luau")

CELL = 13

# ---------------------------------------------------------------------------------------------------
# Fleet skins: (id, name, trim colour, accent colour). The trim replaces the sprite's outer rim, the
# accent its inner details (windows, engines, warhead bands).
# ---------------------------------------------------------------------------------------------------
SHIPS = [
    ("ship_neon", "Neon Fleet", 0x38E1FF, 0xFFFFFF),
    ("ship_biotech", "Biotech Fleet", 0x6CFF3A, 0x0E5A1E),
    ("ship_royal", "Royal Armada", 0xA25BFF, 0xFFD34D),
    ("ship_stealth", "Void Stalkers", 0x0C0C16, 0xFF2E4D),
    ("ship_golden", "Golden Armada", 0xFFC32E, 0xFFF6C8),
]
PREVIEW_FILL = (76, 123, 224)  # a sample owner colour for the Locker / pass cards

# ---------------------------------------------------------------------------------------------------
# Insignia: (id, name, Noto emoji, gradient top, gradient bottom, border)
# ---------------------------------------------------------------------------------------------------
INSIGNIA = [
    ("ins_alien", "Little Green", "alien", (40, 160, 90), (10, 60, 40), (140, 255, 170)),
    ("ins_comet", "Comet Chaser", "comet", (40, 90, 200), (14, 22, 70), (130, 200, 255)),
    ("ins_saucer", "Saucer Squad", "flying-saucer", (120, 70, 220), (34, 16, 80), (200, 160, 255)),
    ("ins_planet", "Ringed World", "ringed-planet", (230, 120, 50), (90, 30, 30), (255, 200, 120)),
    ("ins_rocket", "Rocket Ace", "rocket", (220, 50, 80), (40, 20, 90), (255, 150, 170)),
    ("ins_raider", "Pixel Raider", "alien-monster", (160, 60, 200), (30, 10, 60), (240, 150, 255)),
    ("ins_galaxy", "Milky Way", "milky-way", (30, 40, 110), (5, 5, 25), (150, 170, 255)),
    ("ins_crown", "Galactic Crown", "crown", (250, 190, 50), (150, 70, 10), (255, 240, 170)),
]
IW, IH = 96, 64

# ---------------------------------------------------------------------------------------------------
# Territory skins (several colours; '.' shows the owner's own fill)
# ---------------------------------------------------------------------------------------------------
KEYS = "123456789abcdefghijklmnopqrstuvwxyz"


def rows_of(grid):
    return ["".join("." if v == 0 else KEYS[v - 1] for v in row) for row in grid]


def skin_nebula():
    n = 32
    y, x = np.mgrid[0:n, 0:n] / n * 2 * math.pi
    rnd = random.Random(3)
    v = np.zeros((n, n))
    for kx, ky, a in [(1, 0, 1.0), (0, 1, 1.0), (1, 1, 0.7), (2, -1, 0.5), (3, 2, 0.3), (-2, 3, 0.3)]:
        v += a * np.sin(kx * x + ky * y + rnd.uniform(0, 6.28))
    v = (v - v.min()) / (v.max() - v.min())
    g = np.zeros((n, n), int)
    g[v > 0.42] = 1
    g[v > 0.55] = 2
    g[v > 0.68] = 3
    g[v > 0.82] = 4
    # a few bright stars in the gaps
    for _ in range(9):
        sx, sy = rnd.randrange(n), rnd.randrange(n)
        if g[sy, sx] == 0:
            g[sy, sx] = 5
    return {
        "id": "skin_nebula", "name": "Nebula Drift", "scale": 0, "alpha": 150,
        "colors": [0x4B2390, 0x8A3AB8, 0x3D5BD6, 0xE58BE0, 0xFFFFFF], "mask": rows_of(g),
    }


def skin_hyperspace():
    n = 32
    g = np.zeros((n, n), int)
    rnd = random.Random(11)
    for _ in range(16):
        y = rnd.randrange(n)
        x0 = rnd.randrange(n)
        ln = rnd.randrange(5, 14)
        col = rnd.choice([1, 1, 2])
        for i in range(ln):
            g[y, (x0 + i) % n] = col
        g[y, (x0 + ln) % n] = 3  # the bright head
    return {
        "id": "skin_hyperspace", "name": "Hyperspace", "scale": 0, "alpha": 185,
        "colors": [0x7FD8FF, 0xC9B8FF, 0xFFFFFF], "mask": rows_of(g),
    }


def skin_hive():
    w, h = 24, 14  # a hex lattice that tiles: centres every 12 across, rows 7 apart, odd rows shifted 6
    g = np.zeros((h, w), int)
    centres = []
    for j in range(-1, 3):
        for i in range(-1, 3):
            centres.append((12 * i + (6 if j % 2 else 0), 7 * j))
    for yy in range(h):
        for xx in range(w):
            d = sorted(math.hypot(xx + 0.5 - cx, (yy + 0.5 - cy) * 1.0) for cx, cy in centres)
            if d[1] - d[0] < 1.3:
                g[yy, xx] = 1
            elif d[0] < 1.6:
                g[yy, xx] = 2
    return {
        "id": "skin_hive", "name": "Alien Hive", "scale": 0, "alpha": 175,
        "colors": [0x5CFF7A, 0xD7FF5A], "mask": rows_of(g),
    }


def skin_circuit():
    n = 32
    g = np.zeros((n, n), int)
    rnd = random.Random(5)
    for _ in range(10):
        x, y = rnd.randrange(n), rnd.randrange(n)
        col = rnd.choice([1, 1, 2])
        horiz = rnd.random() < 0.5
        for _seg in range(3):
            ln = rnd.randrange(3, 9)
            for _ in range(ln):
                g[y % n, x % n] = col
                if horiz:
                    x += 1
                else:
                    y += 1
            horiz = not horiz
        # a node at the end of the trace
        for dy in (0, 1):
            for dx in (0, 1):
                g[(y + dy) % n, (x + dx) % n] = 3
    return {
        "id": "skin_circuit", "name": "Circuit Core", "scale": 0, "alpha": 175,
        "colors": [0x38E1FF, 0x1B8FA8, 0xFFFFFF], "mask": rows_of(g),
    }


def skin_supernova():
    n = 32
    g = np.zeros((n, n), int)
    c = n / 2 - 0.5
    for yy in range(n):
        for xx in range(n):
            dx, dy = xx - c, yy - c
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            if r < 2.6:
                g[yy, xx] = 1
            elif r < 4.2:
                g[yy, xx] = 2
            elif 7.0 <= r < 8.2:
                g[yy, xx] = 2
            elif 11.0 <= r < 12.0:
                g[yy, xx] = 3
            elif 14.6 <= r < 15.4:
                g[yy, xx] = 4
            elif r < 15 and abs(((a / (2 * math.pi) * 8) % 1) - 0.5) > 0.47:
                g[yy, xx] = 3  # eight rays
    return {
        "id": "skin_supernova", "name": "Supernova", "scale": 0, "alpha": 205,
        "colors": [0xFFF8E0, 0xFFD34D, 0xFF8A2B, 0xE0303A], "mask": rows_of(g),
    }


SKINS = [skin_nebula, skin_hyperspace, skin_hive, skin_circuit, skin_supernova]


# ---------------------------------------------------------------------------------------------------

def rgb(c):
    return ((c >> 16) & 255, (c >> 8) & 255, c & 255)


def make_ships():
    src = np.array(Image.open(UNITS).convert("RGBA"))
    h, w = src.shape[:2]
    alpha = src[:, :, 3] > 0
    rim = alpha & (src[:, :, 0] < 250)
    out_dir = os.path.join(EMB, "ships")
    os.makedirs(out_dir, exist_ok=True)
    # outer rim: a rim pixel with transparency (or its cell's edge) beside it
    outer = np.zeros_like(rim)
    for yy in range(h):
        for xx in range(w):
            if not rim[yy, xx]:
                continue
            cx = xx // CELL
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = xx + dx, yy + dy
                if ny < 0 or ny >= h or nx < cx * CELL or nx >= (cx + 1) * CELL or not alpha[ny, nx]:
                    outer[yy, xx] = True
                    break
    inner = rim & ~outer
    for sid, _name, trim, accent in SHIPS:
        img = np.zeros((h, w, 4), np.uint8)
        img[outer] = (*rgb(trim), 255)
        img[inner] = (*rgb(accent), 255)
        Image.fromarray(img).save(os.path.join(out_dir, sid + ".png"))
        # preview: rocketship (0), battlecruiser (2), missile (3) over the sample colour
        pad = 1
        pv = np.zeros((CELL + 2 * pad, 3 * CELL + 4 * pad, 4), np.uint8)
        for k, cell in enumerate((0, 2, 3)):
            ox = pad + k * (CELL + pad)
            for yy in range(CELL):
                for xx in range(CELL):
                    sx = cell * CELL + xx
                    if not alpha[yy, sx]:
                        continue
                    if img[yy, sx, 3] > 0:
                        pv[pad + yy, ox + xx] = img[yy, sx]
                    else:
                        pv[pad + yy, ox + xx] = (*PREVIEW_FILL, 255)
        Image.fromarray(pv).resize((pv.shape[1] * 4, pv.shape[0] * 4), Image.NEAREST).save(
            os.path.join(out_dir, sid + "_preview.png"))


def make_insignia(noto_path):
    import cairosvg

    data = json.load(open(noto_path))
    icons, W0, H0 = data["icons"], data.get("width", 128), data.get("height", 128)
    atlas = Image.new("RGBA", (IW * len(INSIGNIA), IH), (0, 0, 0, 0))
    rects = []
    S = 4  # supersample
    for i, (iid, name, emoji, top, bottom, border) in enumerate(INSIGNIA):
        big = Image.new("RGBA", (IW * S, IH * S), (0, 0, 0, 0))
        grad = Image.new("RGBA", (IW * S, IH * S))
        gd = ImageDraw.Draw(grad)
        for yy in range(IH * S):
            t = yy / (IH * S - 1)
            col = tuple(int(top[k] * (1 - t) + bottom[k] * t) for k in range(3))
            gd.line([(0, yy), (IW * S, yy)], fill=col + (255,))
        m = Image.new("L", (IW * S, IH * S), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, IW * S - 1, IH * S - 1], radius=12 * S, fill=255)
        big.paste(grad, (0, 0), m)
        d = ImageDraw.Draw(big)
        rnd = random.Random(i + 1)
        for _ in range(14):
            sx, sy = rnd.randrange(8 * S, (IW - 8) * S), rnd.randrange(6 * S, (IH - 6) * S)
            rr = rnd.choice([1, 1, 2]) * S // 2 + 1
            d.ellipse([sx - rr, sy - rr, sx + rr, sy + rr], fill=(255, 255, 255, rnd.randrange(70, 170)))
        d.rounded_rectangle([S, S, IW * S - 1 - S, IH * S - 1 - S], radius=11 * S, outline=border + (255,), width=3 * S)
        ic = icons[emoji]
        svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">%s</svg>' % (
            ic.get("width", W0), ic.get("height", H0), 50 * S, 50 * S, ic["body"])
        em = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode()))).convert("RGBA")
        # a soft dark shadow under the emoji
        sh = Image.new("RGBA", em.size, (0, 0, 0, 0))
        sh.putalpha(em.getchannel("A").point(lambda a: a * 0.45))
        big.alpha_composite(sh, ((IW * S - em.width) // 2 + 2 * S, (IH * S - em.height) // 2 + 3 * S))
        big.alpha_composite(em, ((IW * S - em.width) // 2, (IH * S - em.height) // 2))
        small = big.resize((IW, IH), Image.LANCZOS)
        atlas.alpha_composite(small, (i * IW, 0))
        rects.append((iid, name, i * IW, 0, IW, IH))
    os.makedirs(os.path.join(EMB, "insignia"), exist_ok=True)
    atlas.save(os.path.join(EMB, "insignia", "atlas.png"))
    return rects


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_lua(skins, rects):
    L = []
    L.append("--!strict")
    L.append("-- GENERATED by tools/assets/make_pass_cosmetics.py — do not edit by hand.")
    L.append("-- The Space Pass cosmetics (Data/BattlePass rewards; Data/Cosmetics resolves them by id):")
    L.append("--   skins     territory skins in several colours (a mask as Cosmetics.exclusive_skins)")
    L.append("--   ships     fleet skins: an embedded trim atlas drawn over the owner-coloured unit sprites")
    L.append("--   insignia  shown by your name like a flag; a rect in the embedded insignia atlas")
    L.append("-- Insignia art: Noto Emoji (Google, Apache License 2.0).")
    L.append("return {")
    L.append('\tinsignia_atlas = "insignia/atlas",')
    L.append("\tskins = {")
    for s in skins:
        cols = ", ".join("0x%06X" % c for c in s["colors"])
        L.append("\t\t{")
        L.append(f'\t\t\tid = {lua_str(s["id"])},')
        L.append(f'\t\t\tname = {lua_str(s["name"])},')
        L.append(f'\t\t\tscale = {s["scale"]},')
        L.append(f'\t\t\talpha = {s["alpha"]},')
        L.append(f"\t\t\tcolors = {{ {cols} }},")
        L.append("\t\t\tmask = {")
        for r in s["mask"]:
            L.append(f"\t\t\t\t{lua_str(r)},")
        L.append("\t\t\t},")
        L.append("\t\t},")
    L.append("\t},")
    L.append("\tships = {")
    for sid, name, trim, accent in SHIPS:
        L.append(f'\t\t{{ id = {lua_str(sid)}, name = {lua_str(name)}, image = "ships/{sid}", '
                 f'preview = "ships/{sid}_preview", trim = 0x{trim:06X}, accent = 0x{accent:06X} }},')
    L.append("\t},")
    L.append("\tinsignia = {")
    for iid, name, x, y, w, h in rects:
        L.append(f"\t\t{{ id = {lua_str(iid)}, name = {lua_str(name)}, x = {x}, y = {y}, w = {w}, h = {h} }},")
    L.append("\t},")
    L.append("}")
    open(LUA, "w").write("\n".join(L) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--noto", required=True, help="path to @iconify-json/noto/icons.json")
    a = ap.parse_args()
    make_ships()
    rects = make_insignia(a.noto)
    write_lua([f() for f in SKINS], rects)
    print("wrote", LUA)


if __name__ == "__main__":
    main()
