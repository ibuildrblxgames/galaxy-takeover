#!/usr/bin/env python3
"""Galaxy Takeover's experience icon (512 x 512), in the thumbnails' style (tools/trailer/thumbs_galaxy.py):
a real gameplay frame, the cluster-missile barrage on a planet, cropped square, and the wordmark in white
with a dark outline on two lines at the bottom over a dark fade (Roblox shows icons at ~150 px, so the
name fills the width). Roblox rounds the corners itself: the image is square and full-bleed.

Usage: python3 tools/trailer/make_icon.py --frame mirv2.png --crop 318,222,738,642 --font <Montserrat Black>
         --out icon.png
"""
import argparse

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

S = 1024  # drawn at 2x, saved at 512


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frame", required=True)
    ap.add_argument("--crop", required=True, help="x0,y0,x1,y1 (square) in the frame")
    ap.add_argument("--font", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--shift", type=int, default=0, help="move the picture up (px at 1024) under the text")
    a = ap.parse_args()
    box = tuple(int(v) for v in a.crop.split(","))
    im = Image.open(a.frame).convert("RGB").crop(box).resize((S, S), Image.LANCZOS)
    im = im.filter(ImageFilter.UnsharpMask(radius=3, percent=70, threshold=2))
    im = ImageEnhance.Contrast(im).enhance(1.08)
    im = ImageEnhance.Color(im).enhance(1.1)
    if a.shift:
        im = im.crop((0, a.shift, S, S)).resize((S, S), Image.LANCZOS)
    arr = np.asarray(im).astype(np.float32)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    # vignette, and a dark fade under the name
    r = np.sqrt(((xx - S / 2) / (S / 2)) ** 2 + ((yy - S * 0.42) / (S / 2)) ** 2)
    v = 1 - 0.35 * np.clip((r - 0.6) / 0.8, 0, 1)
    fade = np.clip((yy - S * 0.50) / (S * 0.30), 0, 1) ** 1.3
    arr = arr * v[..., None]
    arr = arr * (1 - 0.82 * fade[..., None]) + np.array([6, 9, 22]) * (0.82 * fade[..., None])
    base = Image.fromarray(arr.clip(0, 255).astype(np.uint8)).convert("RGBA")

    lines = ("GALAXY", "TAKEOVER")
    width = S - 2 * 54
    px = 300
    while True:
        f = ImageFont.truetype(a.font, px)
        if max(f.getbbox(t)[2] - f.getbbox(t)[0] for t in lines) <= width:
            break
        px -= 4
    f_big = ImageFont.truetype(a.font, px)
    # GALAXY a little smaller than TAKEOVER: the action word leads
    f_top = ImageFont.truetype(a.font, int(px * 0.86))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    stroke = 22
    y = S - 54
    for t, f in ((lines[1], f_big), (lines[0], f_top)):
        l, top, rr, b = f.getbbox(t)
        x = (S - (rr - l)) // 2 - l
        y -= b - top
        d.text((x, y - top), t, font=f, fill=(255, 255, 255, 255), stroke_width=stroke, stroke_fill=(16, 22, 40, 255))
        y -= 12
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow.putalpha(layer.getchannel("A").point(lambda v: v * 160 // 255))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    base.alpha_composite(shadow, (8, 14))
    base.alpha_composite(layer)
    base.convert("RGB").resize((512, 512), Image.LANCZOS).save(a.out, optimize=True)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
