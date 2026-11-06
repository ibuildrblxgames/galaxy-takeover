#!/usr/bin/env python3
"""Galaxy Takeover's experience thumbnails, made like RoWorld's (tools/trailer/thumbnails.py): a real gameplay
frame with the HUD cropped away, scaled to 1920 x 1080, and the wordmark in white with a dark outline and a
soft shadow in a top corner. No drawn art, no faces, no emoji: the game itself is the picture (the owner,
2026-11-05: "not too childish ... a little maturity, similar to RoWorld's, keeping our space theme").

Frames come from the trailer's Studio recordings (tools/trailer/edit_galaxy.py), extracted with ffmpeg:
  mirv.png   late game at 110.4 s (docked Studio, 1920 x 1012): the cluster missile barrage
  o72.png    open at 72 s (full screen, 1920 x 1080): our faction pushing into a neighbour on Xanna
  t61.8.png  trade at 61.8 s (full screen): the empire beside the sun, hyperlanes and fleets all round

Usage: python3 tools/trailer/thumbs_galaxy.py --src <frames dir> --font <Montserrat Black .ttf> --out <dir>
"""
import argparse
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

W, H = 1920, 1080

# (name, frame, crop x0 y0 x1 y1 in the frame's pixels, wordmark corner, cursor boxes to paint out).
# Each crop is 16:9 and clear of the HUD, measured on the frames: full-screen sessions have the top bars to
# y 176 and the bottom bar from y 896; the docked late session has its top bars (and the shadow of the
# universe-control panel) to y 220, the event feed from x 300 / y 690 and the bottom bar from y 850. The
# strike starts at x 446 so the wordmark clears the "Fenric Pride" label.
SHOTS = [
    ("mirv_strike", "mirv.png", (446, 222, 1278, 690), "right", []),
    ("invasion_front", "o72.png", (440, 178, 1546, 800), "left", []),
    ("galaxy_empire", "t61.8.png", (150, 178, 1414, 889), "right", [(380, 660, 520, 780)]),
]


def paint_out_cursor(im, boxes):
    """The mouse pointer was filmed too: inpaint its near-white pixels inside each box."""
    if not boxes:
        return im
    arr = np.array(im.convert("RGB"))
    mask = np.zeros(arr.shape[:2], np.uint8)
    for x0, y0, x1, y1 in boxes:
        sub = arr[y0:y1, x0:x1]
        # (the pointer is white with a black rim: take the white and grow it over the rim)
        white = cv2.dilate((sub.min(axis=2) > 200).astype(np.uint8), np.ones((5, 5), np.uint8))
        mask[y0:y1, x0:x1] = white * 255
    out = cv2.inpaint(arr, mask, 4, cv2.INPAINT_TELEA)
    return Image.fromarray(out)


def crop(im, box):
    out = im.crop(box).resize((W, H), Image.LANCZOS)
    # a light finish after the upscale: a touch of sharpening and contrast, and a soft vignette so the eye
    # lands on the middle (the colours stay the game's own)
    out = out.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    out = ImageEnhance.Contrast(out).enhance(1.06)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    v = 1 - 0.32 * np.clip((r - 0.55) / 0.85, 0, 1) ** 1.6
    arr = np.asarray(out).astype(np.float32) * v[..., None]
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8))


def wordmark(im, corner, font_path, lines=("GALAXY", "TAKEOVER"), px=138):
    """RoWorld's wordmark (white, a 14 px dark outline, a blurred shadow), on two lines: our name is twice
    as long as ROWORLD, and one line at their size would cover most of the picture."""
    f = ImageFont.truetype(font_path, px)
    gap = int(px * 0.06)
    boxes = [f.getbbox(t) for t in lines]
    tw = max(b[2] - b[0] for b in boxes)
    th = sum(b[3] - b[1] for b in boxes) + gap * (len(lines) - 1)
    pad = 40
    layer = Image.new("RGBA", (tw + pad * 2, th + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    y = pad
    for t, (l, top, r, b) in zip(lines, boxes):
        x = pad - l if corner == "left" else pad + tw - (r - l) - l
        d.text((x, y - top), t, font=f, fill=(255, 255, 255, 255), stroke_width=14, stroke_fill=(16, 22, 40, 255))
        y += b - top + gap
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    shadow.putalpha(layer.getchannel("A").point(lambda v: v * 150 // 255))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))
    base = im.convert("RGBA")
    x, y = (34 - pad + 14 if corner == "left" else W - layer.width - 34 + pad - 14), 22 - pad + 14
    base.alpha_composite(shadow, (x + 6, y + 10))
    base.alpha_composite(layer, (x, y))
    return base.convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--font", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for name, frame, box, corner, cursors in SHOTS:
        im = paint_out_cursor(Image.open(os.path.join(a.src, frame)).convert("RGB"), cursors)
        out = wordmark(crop(im, box), corner, a.font)
        p = os.path.join(a.out, f"GalaxyTakeover_thumb_{name}.jpg")
        out.save(p, quality=92)
        print(name, "->", p)


if __name__ == "__main__":
    main()
