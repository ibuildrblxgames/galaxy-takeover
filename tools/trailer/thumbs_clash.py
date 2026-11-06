#!/usr/bin/env python3
"""Galaxy Takeover's thumbnail and icon in RoWorld's live style (the owner, 2026-11-05: "make me
thumbnails and icons similar to this", RoWorld's: a close, clean shot of two countries meeting, a
troop count on each and a curved arrow from each side pushing into the other, the name top left).

Source: a Studio play-session frame with the HUD hidden (every PlayerGui ScreenGui but RofrontMap
disabled from the command bar) and the camera on a planet where two factions meet (`film look`), taken
from a short Game Bar recording. The count labels and arrows are drawn here.

Usage: python3 tools/trailer/thumbs_clash.py --frame shot.png --font <Montserrat Black .ttf> --out <dir>
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

W, H = 1920, 1080
INK = (14, 18, 36)


def grade(im):
    im = ImageEnhance.Color(im).enhance(1.6)
    im = ImageEnhance.Contrast(im).enhance(1.08)
    return im.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))


def bezier(p0, p1, p2, n=80):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2 = (np.array(p, float) for p in (p0, p1, p2))
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t ** 2 * p2


def arrow(layer, p0, ctrl, p1, width, tint, scale=1.0):
    """A thick curved arrow, RoWorld's: the side's colour at the tail turning white at the head, a dark
    outline and a soft shadow. Drawn as one outline polygon at 2x (smooth edges)."""
    k = 2
    pts = bezier(p0, ctrl, p1, 120) * k
    w = width * k
    d_end = pts[-1] - pts[-4]
    d_end /= np.linalg.norm(d_end)
    head_len, head_w = w * 1.5, w * 1.15
    base = pts[-1] - d_end * head_len
    body = np.array([p for p in pts if np.dot(p - base, d_end) < 0] + [base])
    tang = np.gradient(body, axis=0)
    tang /= np.linalg.norm(tang, axis=1)[:, None]
    nrm = np.stack([-tang[:, 1], tang[:, 0]], axis=1)
    # the body tapers a little toward the tail
    half = (w / 2) * np.linspace(0.75, 1.0, len(body))[:, None]
    left, right = body + nrm * half, body - nrm * half
    n_end = np.array([-d_end[1], d_end[0]])
    tip = pts[-1]
    cap = [body[0] - tang[0] * (w / 2) * np.cos(a) * 0.9 + nrm[0] * half[0] * np.sin(a)
           for a in np.linspace(np.pi / 2, -np.pi / 2, 12)]
    poly = (list(map(tuple, left)) + [tuple(base + n_end * head_w), tuple(tip), tuple(base - n_end * head_w)]
            + list(map(tuple, right[::-1])) + list(map(tuple, cap[::-1])))
    size = (layer.size[0] * k, layer.size[1] * k)

    def shape(grow):
        m = Image.new("L", size, 0)
        ImageDraw.Draw(m).polygon(poly, fill=255)
        if grow > 0:
            m = m.filter(ImageFilter.MaxFilter(int(grow * 2 * k) | 1))
        return m.resize(layer.size, Image.LANCZOS)

    outline = shape(7 * scale)
    sh = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    sh.putalpha(outline.point(lambda v: v * 120 // 255))
    layer.alpha_composite(sh.filter(ImageFilter.GaussianBlur(12 * scale)), (int(8 * scale), int(12 * scale)))
    ink = Image.new("RGBA", layer.size, INK + (0,))
    ink.putalpha(outline)
    layer.alpha_composite(ink)
    fill_mask = shape(0)
    xs, ys = np.meshgrid(np.arange(layer.size[0]), np.arange(layer.size[1]))
    a, b = np.array(p0, float), np.array(p1, float)
    t = np.clip(((xs - a[0]) * (b - a)[0] + (ys - a[1]) * (b - a)[1]) / np.dot(b - a, b - a), 0, 1) ** 0.9
    col = np.array(tint, float)[None, None, :] * (1 - t[..., None]) + np.array([255, 255, 255.0]) * t[..., None]
    layer.alpha_composite(Image.fromarray(np.dstack([col.astype(np.uint8), np.array(fill_mask)]), "RGBA"))


def label(layer, font_path, text, centre, px):
    f = ImageFont.truetype(font_path, px)
    d = ImageDraw.Draw(layer)
    l, t, r, b = f.getbbox(text)
    x, y = centre[0] - (r - l) / 2 - l, centre[1] - (b - t) / 2 - t
    sh = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((x, y), text, font=f, fill=(0, 0, 0, 140), stroke_width=px // 7, stroke_fill=(0, 0, 0, 140))
    layer.alpha_composite(sh.filter(ImageFilter.GaussianBlur(px / 12)), (px // 18, px // 10))
    d.text((x, y), text, font=f, fill=(255, 255, 255, 255), stroke_width=px // 9, stroke_fill=INK + (255,))


def wordmark(layer, font_path, lines, xy, px, align="left"):
    f = ImageFont.truetype(font_path, px)
    text_layer = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(text_layer)
    y = xy[1]
    sh = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ds = ImageDraw.Draw(sh)
    boxes = [f.getbbox(t) for t in lines]
    wmax = max(b[2] - b[0] for b in boxes)
    for t, (l, top, r, b) in zip(lines, boxes):
        x = xy[0] - l if align == "left" else xy[0] + (wmax - (r - l)) / 2 - l
        ds.text((x, y - top), t, font=f, fill=(0, 0, 0, 150), stroke_width=px // 9, stroke_fill=(0, 0, 0, 150))
        d.text((x, y - top), t, font=f, fill=(255, 255, 255, 255), stroke_width=px // 10, stroke_fill=INK + (255,))
        y += (b - top) + px * 0.08
    layer.alpha_composite(sh.filter(ImageFilter.GaussianBlur(px / 14)), (px // 22, px // 13))
    layer.alpha_composite(text_layer)


def compose(frame, crop, size, font, spec):
    im = grade(frame.crop(crop).resize(size, Image.LANCZOS)).convert("RGBA")
    fx = Image.new("RGBA", size, (0, 0, 0, 0))
    for a in spec["arrows"]:
        arrow(fx, *a)
    for text, c, px in spec["labels"]:
        label(fx, font, text, c, px)
    im.alpha_composite(fx)
    wm = Image.new("RGBA", size, (0, 0, 0, 0))
    wordmark(wm, font, *spec["wordmark"])
    im.alpha_composite(wm)
    return im.convert("RGB")


PINK, TEAL = (236, 70, 190), (40, 190, 170)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frame", required=True)
    ap.add_argument("--font", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    frame = Image.open(a.frame).convert("RGB")
    # the viewport of the docked Studio recording, below Roblox's own menu buttons: 16:9
    thumb = compose(frame, (440, 214, 1730, 940), (W, H), a.font, {
        "arrows": [
            ((640, 720), (860, 520), (1085, 590), 62, PINK),   # pink pushes east
            ((1520, 520), (1350, 360), (1160, 450), 62, TEAL),  # teal pushes west
        ],
        "labels": [("84K", (600, 850), 120), ("126K", (1560, 660), 120)],
        "wordmark": (("GALAXY", "TAKEOVER"), (46, 34), 150),
    })
    p = os.path.join(a.out, "GalaxyTakeover_thumb_clash.jpg")
    thumb.save(p, quality=92)
    print("wrote", p)
    # the icon: the same clash, square
    icon = compose(frame, (600, 214, 1326, 940), (1024, 1024), a.font, {
        "arrows": [
            ((170, 560), (330, 400), (520, 450), 70, PINK),
            ((900, 400), (770, 270), (600, 330), 70, TEAL),
        ],
        "labels": [],
        "wordmark": (("GALAXY", "TAKEOVER"), (0, 0), 1),
    })
    # (the icon's name: two lines across the bottom, as the earlier icon)
    ic = icon.convert("RGBA")
    arr = np.asarray(ic).astype(np.float32)
    yy = np.mgrid[0:1024, 0:1024][0].astype(np.float32)
    fade = np.clip((yy - 560) / 300, 0, 1) ** 1.3
    arr[..., :3] = arr[..., :3] * (1 - 0.8 * fade[..., None]) + np.array(INK) * 0.8 * fade[..., None]
    ic = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")
    f_big = ImageFont.truetype(a.font, 200)
    while f_big.getbbox("TAKEOVER")[2] - f_big.getbbox("TAKEOVER")[0] > 1024 - 100:
        f_big = ImageFont.truetype(a.font, f_big.size - 4)
    f_top = ImageFont.truetype(a.font, int(f_big.size * 0.86))
    layer = Image.new("RGBA", ic.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    y = 1024 - 50
    for t, f in (("TAKEOVER", f_big), ("GALAXY", f_top)):
        l, top, r, b = f.getbbox(t)
        y -= b - top
        d.text(((1024 - (r - l)) / 2 - l, y - top), t, font=f, fill=(255, 255, 255, 255), stroke_width=22,
               stroke_fill=INK + (255,))
        y -= 12
    sh = Image.new("RGBA", ic.size, (0, 0, 0, 0))
    sh.putalpha(layer.getchannel("A").point(lambda v: v * 160 // 255))
    ic.alpha_composite(sh.filter(ImageFilter.GaussianBlur(16)), (8, 14))
    ic.alpha_composite(layer)
    p = os.path.join(a.out, "GalaxyTakeover_icon_clash.png")
    ic.convert("RGB").resize((512, 512), Image.LANCZOS).save(p, optimize=True)
    print("wrote", p)


if __name__ == "__main__":
    main()
