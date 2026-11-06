#!/usr/bin/env python3
"""Thumbnail prototypes for Galaxy Takeover, built on make_thumbnail.py's pieces (the real Star System
map, faction territories, unit sprites, the title):

  invasion   a close-up of a rocketship fleet storming a planet, a missile strike, the alien mascot
             (Noto Emoji "alien", Apache 2.0) and the title stacked top-left
  growth     "1 PLANET -> THE WHOLE GALAXY": your first claim beside the galaxy in your colour

Usage: python3 tools/trailer/thumb_variants.py --font <Rubik Black .ttf> --noto <icons.json> --out-dir DIR
"""
import argparse
import io
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_thumbnail as mt  # noqa: E402

W, H = mt.W, mt.H
CYAN = (56, 225, 255)


def view(vx, vy, vw):
    mt.VX, mt.VY, mt.VW = vx, vy, vw
    mt.VH = vw * 9 / 16
    mt.S = W / vw


def emoji(noto_path, name, px):
    import cairosvg  # noqa: PLC0415

    data = json.load(open(noto_path))
    ic = data["icons"][name]
    w0, h0 = ic.get("width", data.get("width", 128)), ic.get("height", data.get("height", 128))
    svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">%s</svg>' % (
        w0, h0, px, px, ic["body"])
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode()))).convert("RGBA")


def green(im):
    """Noto's grey alien as a little green one: its grey skin mapped onto greens by brightness."""
    a = np.array(im).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    grey = (np.abs(r - g) < 18) & (np.abs(g - b) < 22) & (r > 90)
    lum = (r + g + b) / 3 / 255
    out = a.copy()
    out[..., 0] = np.where(grey, 40 + 110 * lum, r)
    out[..., 1] = np.where(grey, 150 + 105 * lum, g)
    out[..., 2] = np.where(grey, 40 + 60 * lum, b)
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))


def gradient_text(base, xy, text, font, anchor="la", stroke=14):
    """Gold-to-white Rubik with a dark outline and drop, as the title."""
    x, y = xy
    d = ImageDraw.Draw(base)
    d.text((x + 7, y + 10), text, font=font, anchor=anchor, fill=(10, 6, 40, 255), stroke_width=stroke,
           stroke_fill=(10, 6, 40, 255))
    d.text((x, y), text, font=font, anchor=anchor, fill=(255, 255, 255, 255), stroke_width=stroke,
           stroke_fill=(20, 12, 70, 255))
    mask = Image.new("L", base.size, 0)
    ImageDraw.Draw(mask).text((x, y), text, font=font, anchor=anchor, fill=255)
    box = mask.getbbox()
    t = np.clip((np.arange(H) - box[1]) / max(1, box[3] - box[1]), 0, 1)[:, None]
    top, mid, bot = np.array([255, 252, 230]), np.array([255, 214, 90]), np.array([255, 140, 30])
    col = np.where(t < 0.5, top + (mid - top) * (t / 0.5), mid + (bot - mid) * ((t - 0.5) / 0.5))
    g = np.zeros((H, W, 4), np.uint8)
    g[..., 0:3] = col[:, None, :].astype(np.uint8)
    g[..., 3] = np.array(mask)
    base.alpha_composite(Image.fromarray(g))
    return box


def glow_text(base, xy, text, font, anchor="la", color=CYAN, r=24):
    lay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).text(xy, text, font=font, anchor=anchor, fill=(*color, 255), stroke_width=r,
                             stroke_fill=(*color, 255))
    base.alpha_composite(lay.filter(ImageFilter.GaussianBlur(r)))


def pill(base, cx, cy, text, font, fill=(20, 12, 70, 235), edge=CYAN, ink=(140, 240, 255)):
    b = font.getbbox(text)
    w, h = b[2] - b[0] + 70, b[3] - b[1] + 36
    d = ImageDraw.Draw(base)
    d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], radius=h / 2, fill=fill, outline=edge,
                        width=4)
    d.text((cx, cy), text, font=font, anchor="mm", fill=ink)


def invasion(font_path, noto, out):
    final, planets = mt.map_data()
    img, land, _ = mt.terrain(final, planets)
    byname = {p["name"]: p for p in planets}
    # Vortera (ice) is the target: Zorgon holds it, our invasion lands on its rim
    mt.FACTIONS = [
        ("You", CYAN, "48.2K", [("Nebvara VII", [(-30, 0), (-10, 40), (-20, -40), (40, 20)], 0.95),
                                ("Vortera", [(-60, 50)], 0.42)]),
        ("Zorgon Empire", (255, 70, 90), "31.7K", [("Vortera", [(25, -15), (10, -40), (20, 30)], 0.9)]),
        ("Krell Hive", (255, 200, 40), "27.4K", [("Rhomir Major", [(0, 0), (30, 50)], 0.8)]),
    ]
    owner = mt.territories(final, land, planets)
    view(560, 260, 560)
    base = mt.upscale(mt.paint_territories(img, owner))
    mt.sun(base, planets)

    def c(n, dx=0, dy=0):
        p = byname[n]
        return (p["x"] + dx, p["y"] + dy)

    # the fleet: five rocketships from Nebvara VII to Vortera's rim, staggered
    for k, (dx, dy, t) in enumerate([(-10, -70, 0.72), (20, -60, 0.6), (40, -40, 0.48), (-30, -55, 0.36),
                                     (10, -75, 0.86)]):
        mt.rocket_run(base, c("Nebvara VII", dx, dy), c("Vortera", -70 + k * 6, 45 - k * 4), t, CYAN, 9,
                      trim=(255, 255, 255))
    # their missile hits the front
    ex, ey = mt.to_px(*c("Vortera", 5, 5))
    mt.missile(base, c("Rhomir Major", 30, 60), c("Vortera", 5, 5), 0.97, (255, 200, 40), 0.3)
    mt.explosion(base, ex, ey, 95)
    mt.vignette(base)
    # title, stacked top-left
    fb = ImageFont.truetype(font_path, 190)
    for i, word in enumerate(("GALAXY", "TAKEOVER")):
        glow_text(base, (70, 40 + i * 190), word, fb)
    for i, word in enumerate(("GALAXY", "TAKEOVER")):
        gradient_text(base, (70, 40 + i * 190), word, fb)
    # the alien mascot, bottom-right, leaning in
    al = green(emoji(noto, "alien", 520)).rotate(-12, resample=Image.BICUBIC, expand=True)
    gl = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(gl).ellipse([W - 600, H - 560, W - 40, H + 40], fill=(120, 255, 140, 120))
    base.alpha_composite(gl.filter(ImageFilter.GaussianBlur(60)))
    sh = Image.new("RGBA", al.size, (0, 0, 0, 0))
    sh.putalpha(al.getchannel("A").point(lambda v: v * 0.5))
    base.alpha_composite(sh, (W - al.width + 40 + 14, H - al.height + 70 + 18))
    base.alpha_composite(al, (W - al.width + 40, H - al.height + 70))
    pill(base, 520, H - 90, "INVADE  •  CONQUER  •  RULE", ImageFont.truetype(font_path, 50))
    base.convert("RGB").save(out)


def growth(font_path, noto, out):
    final, planets = mt.map_data()
    img, land, _ = mt.terrain(final, planets)
    byname = {p["name"]: p for p in planets}
    you = (255, 60, 200)
    # left: minute 1, a speck on Xanna
    xp = byname["Xanna"]
    mt.FACTIONS = [("You", you, "1.2K", [("Xanna", [(-5, -5)], 0.16)])]
    owner = mt.territories(final, land, planets)
    view(xp["x"] - 170, xp["y"] - 110, 340)
    left = mt.upscale(mt.paint_territories(img, owner))
    # right: the whole galaxy, nearly all ours, a few holdouts
    claims = [(p["name"], [(0, 0), (p["r"] * 0.5, 0), (-p["r"] * 0.5, 0), (0, p["r"] * 0.5), (0, -p["r"] * 0.5)],
               1.3) for p in planets if p["biome"] not in ("star",)]
    holdouts = {"Astkar", "Ultera II", "Zephros"}
    mt.FACTIONS = [("You", you, "4.8M", [cl for cl in claims if cl[0] not in holdouts]),
                   ("Zorgon", (255, 70, 90), "", [cl for cl in claims if cl[0] in holdouts])]
    owner2 = mt.territories(final, land, planets)
    view(0, 0, 2000)
    right = mt.upscale(mt.paint_territories(img, owner2))
    mt.sun(right, planets)
    base = Image.new("RGBA", (W, H), (8, 10, 30, 255))
    half = W // 2
    lw = left.crop((W // 4, 0, W // 4 + half, H))
    rw = right.resize((int(W * 0.98), int(H * 0.98))).crop((int(W * 0.24), 0, int(W * 0.24) + half, H))
    base.alpha_composite(lw, (0, 0))
    base.alpha_composite(rw, (half, 0))
    # a dark band behind the title and the labels
    band = np.zeros((H, W, 4), np.uint8)
    k = np.clip(1 - np.arange(H) / 300.0, 0, 1) ** 1.5
    band[..., 3] = (k * 210)[:, None].astype(np.uint8)
    band[..., 0:3] = (6, 6, 24)
    base.alpha_composite(Image.fromarray(band))
    # the split: a bright diagonal seam
    seam = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(seam).line([(half, 250), (half, H)], fill=(255, 255, 255, 255), width=10)
    base.alpha_composite(seam)
    # "you" on the left
    d = ImageDraw.Draw(base)
    fyou = ImageFont.truetype(font_path, 64)
    view(xp["x"] - 170, xp["y"] - 110, 340)
    px, py = mt.to_px(xp["x"] - 5, xp["y"] - 5)
    px -= W // 4
    py -= 40
    mt.outlined(d, (px, py - 90), "YOU", fyou, (255, 255, 255), (0, 40, 60), 6)
    arrow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ad = ImageDraw.Draw(arrow)
    ad.line([(px, py - 55), (px, py - 18)], fill=(255, 255, 255, 255), width=10)
    ad.polygon([(px - 18, py - 30), (px + 18, py - 30), (px, py - 6)], fill=(255, 255, 255, 255))
    base.alpha_composite(arrow)
    # the big arrow across the seam
    ar = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    a2 = ImageDraw.Draw(ar)
    cy = H * 0.62
    a2.polygon([(half - 150, cy - 40), (half + 40, cy - 40), (half + 40, cy - 95), (half + 170, cy),
                (half + 40, cy + 95), (half + 40, cy + 40), (half - 150, cy + 40)], fill=(255, 214, 60, 255),
               outline=(20, 12, 70, 255), width=10)
    base.alpha_composite(ar.filter(ImageFilter.GaussianBlur(0.6)))
    fl = ImageFont.truetype(font_path, 64)
    pill(base, half / 2, H - 90, "1 PLANET", fl, ink=(255, 255, 255))
    pill(base, half + half / 2, H - 90, "THE WHOLE GALAXY", fl, fill=(10, 60, 80, 235), ink=(255, 255, 255))
    # title
    ft = ImageFont.truetype(font_path, 170)
    glow_text(base, (W / 2, 140), "GALAXY TAKEOVER", ft, anchor="mm")
    gradient_text(base, (W / 2, 140), "GALAXY TAKEOVER", ft, anchor="mm")
    # a small alien cheering beside the galaxy
    al = green(emoji(noto, "alien", 260)).rotate(10, resample=Image.BICUBIC, expand=True)
    base.alpha_composite(al, (W - al.width - 20, H - al.height - 150))
    base.convert("RGB").save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--font", required=True)
    ap.add_argument("--noto", required=True)
    ap.add_argument("--out-dir", required=True)
    a = ap.parse_args()
    os.makedirs(a.out_dir, exist_ok=True)
    invasion(a.font, a.noto, os.path.join(a.out_dir, "thumb_invasion.png"))
    growth(a.font, a.noto, os.path.join(a.out_dir, "thumb_growth.png"))
    print("wrote", a.out_dir)


if __name__ == "__main__":
    main()
