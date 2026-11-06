#!/usr/bin/env python3
"""Galaxy Takeover' experience thumbnail (1920 x 1080), drawn from the game's own data: the Star System map
(tools/maps/make_space_maps.py, seed 11, in the game's space palette), faction territories over its
planets, the unit sprites (assets/map_sprites/units_one.png) on rocketship invasions and a missile
strike, the faction name tags as NameLayer draws them, and the title.

Usage: python3 tools/trailer/make_thumbnail.py --font <Rubik Black .ttf> [--title "GALAXY TAKEOVER"]
                                               [--out build/thumbnail.png]
"""
import argparse
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "maps"))
import make_maps  # noqa: E402
import make_space_maps as msm  # noqa: E402

W, H = 1920, 1080
# the map window (tiles) shown, 16:9
VX, VY, VW = 330, 120, 1340
VH = VW * 9 / 16
S = W / VW  # px per tile
CELL = 13

# factions: (name, rgb, aliens, [(planet, seed points relative to the planet centre, reach x radius)])
# (each inner planet split between two factions, so their fronts show)
FACTIONS = [
    ("You", (56, 225, 255), "48.2K", [("Nebvara VII", [(-30, 0), (-10, 40), (-20, -40)], 0.7),
                                       ("Vortera", [(-60, 40)], 0.45)]),
    ("Zorgon Empire", (255, 70, 90), "31.7K", [("Vortera", [(25, -15), (10, -40)], 0.62),
                                                ("Nebvara VII", [(55, -45)], 0.38)]),
    ("Krell Hive", (255, 200, 40), "27.4K", [("Ulvara", [(20, -10), (10, 30)], 0.66)]),
    ("Draxis Legion", (120, 230, 90), "19.9K", [("Xanna", [(-15, 25), (20, 10)], 0.6)]),
    ("Vortan Collective", (190, 110, 255), "36.0K", [("Xanvex IV", [(60, 60), (90, -20), (20, 110)], 0.62)]),
    ("Nebulon Dominion", (255, 130, 40), "22.1K", [("Erizon II", [(-30, 60), (20, 90)], 0.62),
                                                   ("Rhomir Major", [(40, 60)], 0.55)]),
    ("Lumina Concord", (255, 110, 200), "", [("Ulvara", [(-45, 40)], 0.4), ("Xanna", [(45, -40)], 0.4)]),
]


def map_data():
    tiles, _land, planets = msm.system(11)
    h, w = tiles.shape
    final = np.frombuffer(make_maps.postprocess(bytes(tiles.ravel()), w, h), np.uint8).reshape(h, w)
    return final, planets


def terrain(final, planets):
    """The map in the game's palette (msm.preview_png's colours), one pixel a tile, no labels."""
    h, w = final.shape
    img = np.zeros((h, w, 3), np.float32)
    land = final >= 128
    mag = final & 31
    shore = (final & msm.SHORE) != 0
    img[:] = (8, 10, 30)
    rng = np.random.default_rng(1)
    r = rng.random((h, w))
    img[(r < 0.0035) & ~land] = (110, 118, 166)  # faint stars, as MapSurface
    img[(r > 0.997) & ~land] = (40, 44, 82)
    bidx = msm.biome_index(planets, h, w)
    for bi, name in enumerate(msm.BIOMES):
        if name == "star":
            continue
        cols = msm.PREVIEW_BIOME[name]
        sel = land & (bidx == bi)
        img[sel & (mag < 10)] = cols[0]
        img[sel & (mag >= 10) & (mag < 20)] = cols[1]
        img[sel & (mag >= 20) & (mag < 31)] = cols[2]
        img[sel & shore & (mag < 31)] = tuple(min(255, c + 50) for c in cols[0])
    return img, land, bidx


def territories(final, land, planets):
    """owner index per tile (0 = nobody): each faction's seed points on its planets, a noisy Voronoi."""
    h, w = final.shape
    owner = np.zeros((h, w), np.int16)
    byname = {p["name"]: p for p in planets}
    rng = np.random.default_rng(5)
    noise = msm.fbm(rng, h, w, 14, 3) * 26
    for fi, (_n, _c, _a, claims) in enumerate(FACTIONS):
        for pname, seeds, frac in claims:
            p = byname[pname]
            r = p["r"] + 2
            y0, y1 = int(p["y"] - r), int(p["y"] + r) + 1
            x0, x1 = int(p["x"] - r), int(p["x"] + r) + 1
            yy, xx = np.mgrid[y0:y1, x0:x1]
            best = np.full(yy.shape, 1e9)
            for sx, sy in seeds:
                d = np.hypot(xx - (p["x"] + sx), yy - (p["y"] + sy))
                best = np.minimum(best, d)
            reach = p["r"] * frac + noise[y0:y1, x0:x1]
            sel = (best < reach) & land[y0:y1, x0:x1] & (owner[y0:y1, x0:x1] == 0)
            owner[y0:y1, x0:x1][sel] = fi + 1
    return owner


def paint_territories(img, owner):
    out = img.copy()
    h, w = owner.shape
    border = np.zeros_like(owner, bool)
    o = owner
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        sh = np.roll(np.roll(o, dy, 0), dx, 1)
        border |= (o > 0) & (sh != o)
    for fi, (_n, c, _a, _cl) in enumerate(FACTIONS):
        m = owner == fi + 1
        c = np.array(c, np.float32)
        out[m] = out[m] * 0.42 + c * 0.58
        out[m & border] = c * 0.55
    return out


def upscale(img):
    """The visible window at S px a tile, nearest (the game draws tiles as crisp pixels)."""
    crop = img[int(VY):int(VY + VH) + 1, int(VX):int(VX + VW) + 1]
    im = Image.fromarray(np.clip(crop, 0, 255).astype(np.uint8))
    big = im.resize((int(im.width * S), int(im.height * S)), Image.NEAREST)
    return big.crop((0, 0, W, H)).convert("RGBA")


def to_px(x, y):
    return (x - VX) * S, (y - VY) * S


def sun(base, planets):
    sp = planets[0]
    cx, cy = to_px(sp["x"], sp["y"])
    r = sp["r"] * S
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    for k in range(40, 0, -1):
        rr = r * (1 + k * 0.05)
        a = int(6 + (40 - k) * 1.4)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(255, 130, 40, min(255, a)))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(40)))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(90)))
    yy, xx = np.mgrid[0:H, 0:W]
    dd = np.hypot(xx - cx, yy - cy) / r
    cor = np.zeros((H, W, 4), np.uint8)
    k = np.clip(1 - (dd - 1) / 1.6, 0, 1) ** 2.2
    cor[..., 0] = 255
    cor[..., 1] = (120 + 80 * k).astype(np.uint8)
    cor[..., 2] = (30 + 40 * k).astype(np.uint8)
    cor[..., 3] = np.where(dd > 1, k * 190, 0).astype(np.uint8)
    base.alpha_composite(Image.fromarray(cor))
    m = dd <= 1
    arr = np.zeros((H, W, 4), np.uint8)
    arr[..., 0] = 255
    arr[..., 1] = np.clip(250 - 110 * dd, 0, 255)
    arr[..., 2] = np.clip(205 - 190 * dd, 0, 255)
    arr[..., 3] = np.where(m, 255, 0)
    disc = Image.fromarray(arr)
    base.alpha_composite(disc)


def sprite(cell, color, scale, angle=0.0, trim=None):
    src = Image.open(os.path.join(ROOT, "assets", "map_sprites", "units_one.png")).convert("RGBA")
    a = np.array(src.crop((cell * CELL, 0, cell * CELL + CELL, CELL)))
    out = np.zeros_like(a)
    fill = (a[..., 3] > 0) & (a[..., 0] > 250)
    rim = (a[..., 3] > 0) & (a[..., 0] <= 250)
    out[fill] = (*color, 255)
    out[rim] = (*(trim or tuple(int(c * 0.45) for c in color)), 255)
    im = Image.fromarray(out).resize((CELL * scale, CELL * scale), Image.NEAREST)
    if angle:
        im = im.rotate(angle, resample=Image.NEAREST, expand=True)
    return im


def paste_center(base, im, x, y):
    base.alpha_composite(im, (int(x - im.width / 2), int(y - im.height / 2)))


def rocket_run(base, a, b, t, color, scale=6, trim=None):
    """A rocketship part way (t) from map point a to b, its dotted trail behind it."""
    ax, ay = to_px(*a)
    bx, by = to_px(*b)
    d = ImageDraw.Draw(base)
    n = 26
    for i in range(int(n * t)):
        k = i / n
        x, y = ax + (bx - ax) * k, ay + (by - ay) * k
        rr = 3.2
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(*color, 150))
    x, y = ax + (bx - ax) * t, ay + (by - ay) * t
    ang = -math.degrees(math.atan2(by - ay, bx - ax)) - 90
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([x - 40, y - 40, x + 40, y + 40], fill=(*color, 70))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(14)))
    paste_center(base, sprite(0, color, scale, ang, trim), x, y)


def missile(base, a, b, t, color, height=0.35):
    """A missile on its arc (a quadratic curve bowed up), with a fading exhaust trail."""
    ax, ay = to_px(*a)
    bx, by = to_px(*b)
    mx, my = (ax + bx) / 2, (ay + by) / 2 - math.hypot(bx - ax, by - ay) * height

    def at(k):
        return ((1 - k) ** 2 * ax + 2 * (1 - k) * k * mx + k * k * bx, (1 - k) ** 2 * ay + 2 * (1 - k) * k * my + k * k * by)

    trail = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(trail)
    steps = 60
    for i in range(int(steps * t)):
        k = i / steps
        x, y = at(k)
        f = i / max(1, steps * t)
        rr = 3 + 8 * f
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(255, 210, 160, int(50 + 170 * f)))
    base.alpha_composite(trail.filter(ImageFilter.GaussianBlur(2)))
    x, y = at(t)
    x2, y2 = at(min(1, t + 0.01))
    ang = -math.degrees(math.atan2(y2 - y, x2 - x)) - 90
    hl = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([x - 34, y - 34, x + 34, y + 34], fill=(255, 200, 120, 110))
    base.alpha_composite(hl.filter(ImageFilter.GaussianBlur(12)))
    paste_center(base, sprite(3, color, 7, ang), x, y)


def explosion(base, x, y, r):
    lay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for rr, col in ((r * 2.1, (255, 60, 30, 70)), (r * 1.5, (255, 110, 30, 150)), (r * 1.05, (255, 180, 60, 220)),
                    (r * 0.65, (255, 235, 150, 255)), (r * 0.32, (255, 255, 240, 255))):
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=col)
    base.alpha_composite(lay.filter(ImageFilter.GaussianBlur(r * 0.18)))
    ring = Image.new("RGBA", base.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rr = r * 2.5
    rd.ellipse([x - rr, y - rr, x + rr, y + rr], outline=(255, 220, 160, 160), width=max(3, int(r * 0.08)))
    base.alpha_composite(ring.filter(ImageFilter.GaussianBlur(3)))
    rng = np.random.default_rng(3)
    sp = ImageDraw.Draw(base)
    for _ in range(26):
        a = rng.uniform(0, 2 * math.pi)
        d0, d1 = r * rng.uniform(0.9, 1.4), r * rng.uniform(1.6, 2.6)
        sp.line([x + math.cos(a) * d0, y + math.sin(a) * d0, x + math.cos(a) * d1, y + math.sin(a) * d1],
                fill=(255, 220, 140, 230), width=3)


def outlined(d, xy, text, font, fill, outline, w, anchor="mm"):
    d.text(xy, text, font=font, fill=fill, anchor=anchor, stroke_width=w, stroke_fill=outline)


def name_tags(base, owner, font_b, font_s):
    """A tag in the middle of each faction's land: name over aliens, white with a dark outline
    (NameLayer draws the name in the owner's colour outline)."""
    d = ImageDraw.Draw(base)
    for fi, (name, c, aliens, _cl) in enumerate(FACTIONS):
        if aliens == "":
            continue  # (no tag: a small claim beside a bigger faction's)
        from scipy import ndimage  # noqa: PLC0415
        lab, n = ndimage.label(owner == fi + 1)
        if n == 0:
            continue
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        ys, xs = np.nonzero(lab == int(np.argmax(sizes)) + 1)
        x, y = to_px(xs.mean(), ys.mean())
        if not (60 < x < W - 60 and 240 < y < H - 40):
            continue
        dark = tuple(int(v * 0.35) for v in c)
        outlined(d, (x, y - 14), name, font_b, (255, 255, 255), dark, 5)
        outlined(d, (x, y + 22), aliens, font_s, (255, 255, 255), dark, 4)


def title(base, text, font_path):
    # a dark band behind the title, fading down
    band = Image.new("RGBA", base.size, (0, 0, 0, 0))
    arr = np.zeros((H, W, 4), np.uint8)
    k = np.clip(1 - np.arange(H) / 330.0, 0, 1) ** 1.6
    arr[..., 3] = (k * 200)[:, None].astype(np.uint8)
    arr[..., 0:3] = (6, 6, 24)
    base.alpha_composite(Image.fromarray(arr))
    size = 190
    font = ImageFont.truetype(font_path, size)
    while font.getbbox(text)[2] > W - 160:
        size -= 6
        font = ImageFont.truetype(font_path, size)
    cx, cy = W / 2, 135
    # cyan glow
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).text((cx, cy), text, font=font, anchor="mm", fill=(56, 225, 255, 255), stroke_width=22,
                              stroke_fill=(56, 225, 255, 255))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(26)))
    # chunky dark outline + drop
    ImageDraw.Draw(base).text((cx + 8, cy + 12), text, font=font, anchor="mm", fill=(10, 6, 40, 255),
                              stroke_width=16, stroke_fill=(10, 6, 40, 255))
    ImageDraw.Draw(base).text((cx, cy), text, font=font, anchor="mm", fill=(255, 255, 255, 255), stroke_width=16,
                              stroke_fill=(20, 12, 70, 255))
    # gold-to-white gradient fill
    mask = Image.new("L", base.size, 0)
    ImageDraw.Draw(mask).text((cx, cy), text, font=font, anchor="mm", fill=255)
    box = mask.getbbox()
    grad = np.zeros((H, W, 4), np.uint8)
    t = np.clip((np.arange(H) - box[1]) / max(1, box[3] - box[1]), 0, 1)[:, None]  # (H, 1)
    top, mid, bot = np.array([255, 252, 230]), np.array([255, 214, 90]), np.array([255, 140, 30])
    col = np.where(t < 0.5, top + (mid - top) * (t / 0.5), mid + (bot - mid) * ((t - 0.5) / 0.5))  # (H, 3)
    grad[..., 0:3] = col[:, None, :].astype(np.uint8)
    grad[..., 3] = np.array(mask)
    base.alpha_composite(Image.fromarray(grad))
    # shine on the upper half of the letters
    shine = np.zeros((H, W, 4), np.uint8)
    shine[..., 0:3] = 255
    upper = (np.arange(H) < box[1] + (box[3] - box[1]) * 0.42)[:, None]
    shine[..., 3] = (np.array(mask) * upper * 0.28).astype(np.uint8)
    base.alpha_composite(Image.fromarray(shine))
    # subtitle ribbon
    sub = "CONQUER THE UNIVERSE"
    sf = ImageFont.truetype(font_path, 46)
    sb = sf.getbbox(sub)
    sw = sb[2] - sb[0] + 80
    sy = box[3] + 44
    rib = Image.new("RGBA", base.size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rib)
    rd.rounded_rectangle([cx - sw / 2, sy - 34, cx + sw / 2, sy + 34], radius=34, fill=(20, 12, 70, 235),
                         outline=(56, 225, 255, 255), width=4)
    base.alpha_composite(rib)
    ImageDraw.Draw(base).text((cx, sy), sub, font=sf, anchor="mm", fill=(140, 240, 255, 255))


def vignette(base):
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2))
    a = (np.clip(d - 0.75, 0, 1) * 170).astype(np.uint8)
    arr = np.zeros((H, W, 4), np.uint8)
    arr[..., 3] = a
    base.alpha_composite(Image.fromarray(arr))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--font", required=True)
    ap.add_argument("--title", default="GALAXY TAKEOVER")
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "thumbnail.png"))
    a = ap.parse_args()
    final, planets = map_data()
    img, land, _bidx = terrain(final, planets)
    owner = territories(final, land, planets)
    base = upscale(paint_territories(img, owner))
    sun(base, planets)
    byname = {p["name"]: p for p in planets}

    def c(n, dx=0, dy=0):
        p = byname[n]
        return (p["x"] + dx, p["y"] + dy)

    you, zorg, krell, drax = (FACTIONS[i][1] for i in range(4))
    # invasions in flight
    rocket_run(base, c("Nebvara VII", 30, -60), c("Vortera", -60, 30), 0.62, you, 6, trim=(255, 255, 255))
    rocket_run(base, c("Nebvara VII", 60, 40), c("Xanna", -60, -20), 0.48, you, 6, trim=(255, 255, 255))
    rocket_run(base, c("Ulvara", -50, 50), c("Xanna", 55, -30), 0.55, krell, 5)
    rocket_run(base, c("Vortera", 70, 10), c("Ulvara", -55, -40), 0.4, zorg, 5)
    # a battlecruiser on patrol
    paste_center(base, sprite(2, drax, 6, 20), *to_px(*c("Xanna", -125, 40)))
    # the missile strike: one landing on Vortera, one on its way to Ulvara
    vx, vy = to_px(*c("Vortera", 15, -10))
    missile(base, c("Xanvex IV", 70, 40), c("Vortera", 15, -10), 0.97, (190, 110, 255), 0.45)
    explosion(base, vx, vy, 62)
    missile(base, c("Nebvara VII", 0, -40), c("Ulvara", 0, -20), 0.58, you, 0.3)
    fb = ImageFont.truetype(a.font, 34)
    fs = ImageFont.truetype(a.font, 30)
    name_tags(base, owner, fb, fs)
    vignette(base)
    title(base, a.title, a.font)
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    base.convert("RGB").save(a.out)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
