#!/usr/bin/env python3
"""Galaxy Takeover's trailer, cut like RoWorld's (tools/trailer/edit.py, the experience's live video): the
same seven shots in the same lengths (62, 63, 50, 38, 50, 109, 61 frames at 30 fps: hard cuts, no intro),
the same caption plates sliding in top left at the same times, the same end card (the last frame held and
darkened, the wordmark), the same fade out. Footage: Studio play sessions recorded with Windows Game Bar
(real gameplay, HUD included), each shot cropped to the game viewport and scaled to 1920 x 1080.

Usage: python3 tools/trailer/edit_galaxy.py --font <Montserrat Black .ttf> --open O.mp4 --trade T.mp4
         --late L.mp4 --out galaxy_takeover_trailer.mp4
"""
import argparse
import os
import shutil
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FPS = 30
W, H = 1920, 1080
ACCENT = (56, 225, 255)  # RoWorld's plate bar is its amber; ours the game's cyan


def fit(x, y, w, h):
    """16:9 inside the rect, centred."""
    if w * 9 > h * 16:
        nw = h * 16 // 9
        return x + (w - nw) // 2, y, nw, h
    nh = w * 9 // 16
    return x, y + (h - nh) // 2, w, nh


VIEW_FULL = fit(3, 85, 1914, 925)  # the full-screen Studio sessions (open, trade)
VIEW_LATE = fit(286, 144, 1452, 798)  # the late-game session (docked Studio)
CLOSE = (760, 236, 1150, 647)  # the hyperlane close-up

# (clip, start s, frames, speed, crop) in RoWorld's order and lengths:
SEGMENTS = [
    ("open", 16.0, 62, 3.1, VIEW_FULL),  # a speck on Xanna growing into a faction (in-game 4x, sped up)
    ("open", 55.0, 63, 3.3, VIEW_FULL),  # the army sweeps through the neighbours: Vrark Nest wiped out
    ("trade", 36.0, 50, 2.0, VIEW_FULL),  # cargo freighters paid at the Starport (+6.6K, +10.0K)
    ("trade", 45.0, 38, 2.0, CLOSE),  # the hyperlanes close up: shuttles paid "+25.0K"
    ("late", 77.9, 50, 1.0, VIEW_LATE),  # an antimatter strike on Eidolon Host: 729K -> 589K
    ("late", 108.8, 109, 1.0, VIEW_LATE),  # the climax: the cluster missile barrage (owner's favourite)
    ("late", 112.43, 61, 1.0, VIEW_LATE),  # the galaxy after it
]
HOLD = 74  # the end card: the last frame held

CAPTIONS = [
    ("BUILD YOUR EMPIRE", 0.25, 1.9),
    ("INVADE YOUR NEIGHBORS", 2.3, 4.0),
    ("TRADE ACROSS THE GALAXY", 4.35, 5.75),
    ("WIPE OUT RIVAL FACTIONS", 7.2, 10.6),
    ("CONTROL 80% OF THE GALAXY TO WIN", 12.45, 14.35),
]


def font(path, px):
    return ImageFont.truetype(path, px)


def wordmark(font_path, text, px=170):
    """RoWorld's end-card wordmark: a warm gradient fill, a dark outline and a soft shadow."""
    f = font(font_path, px)
    l, t, r, b = f.getbbox(text)
    tw, th = r - l, b - t
    pad = 40
    w, h = tw + pad * 2, th + pad * 2
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((pad - l, pad - t), text, font=f, fill=255)
    stroke = Image.new("L", (w, h), 0)
    ImageDraw.Draw(stroke).text((pad - l, pad - t), text, font=f, fill=255, stroke_width=9, stroke_fill=255)
    grad = np.zeros((h, w, 3), np.float32)
    top, bot = np.array([255, 241, 206]), np.array([246, 170, 52])
    ys = np.linspace(0, 1, h)[:, None]
    grad[:] = (top + (bot - top) * ys)[:, None, :]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow = stroke.filter(ImageFilter.GaussianBlur(10))
    img.paste((10, 14, 26, 150), (6, 12), shadow)
    img.paste((44, 24, 6, 255), (0, 0), stroke)
    fill = Image.fromarray(grad.astype(np.uint8), "RGB").convert("RGBA")
    fill.putalpha(mask)
    img.alpha_composite(fill)
    return img


def caption_img(font_path, text):
    f = font(font_path, 60)
    l, t, r, b = f.getbbox(text)
    tw, th = r - l, b - t
    pad, bar = 28, 10
    w, h = tw + pad * 2 + bar + 22, th + pad * 2
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=14, fill=(10, 14, 26, 190))
    d.rectangle([pad - 6, pad - 2, pad - 6 + bar, h - pad + 2], fill=ACCENT + (255,))
    d.text((pad + bar + 16 - l, pad - t), text, font=f, fill=(255, 255, 255, 255))
    return img


def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def extract(src, start, frames, speed, crop, out_dir):
    """The segment's frames, at playback speed, cropped and scaled: out_dir/00000.jpg ..."""
    os.makedirs(out_dir, exist_ok=True)
    x, y, w, h = crop
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-ss", str(start), "-t", str(frames / FPS * speed + 0.5), "-i", src,
         "-vf", f"setpts=PTS/{speed},fps={FPS},crop={w}:{h}:{x}:{y},scale={W}:{H}:flags=lanczos",
         "-frames:v", str(frames), "-q:v", "2", os.path.join(out_dir, "%05d.jpg")], check=True)
    got = sorted(os.listdir(out_dir))
    while len(got) < frames:  # (a short source: hold its last frame)
        shutil.copy(os.path.join(out_dir, got[-1]), os.path.join(out_dir, "%05d.jpg" % (len(got) + 1)))
        got = sorted(os.listdir(out_dir))
    return [os.path.join(out_dir, g) for g in got[:frames]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--font", required=True)
    ap.add_argument("--open", required=True)
    ap.add_argument("--trade", required=True)
    ap.add_argument("--late", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--title", default="GALAXY TAKEOVER")
    a = ap.parse_args()
    srcs = {"open": a.open, "trade": a.trade, "late": a.late}
    tmp = tempfile.mkdtemp()
    frames = []
    for i, (clip, start, n, speed, crop) in enumerate(SEGMENTS):
        frames += extract(srcs[clip], start, n, speed, crop, os.path.join(tmp, f"s{i}"))
    end_start = len(frames)
    frames += [frames[-1]] * HOLD
    n = len(frames)
    print("frames:", n, "=", round(n / FPS, 2), "s")
    logo = wordmark(a.font, a.title)
    logo_small = logo.resize((int(logo.width * 0.82), int(logo.height * 0.82)), Image.LANCZOS)
    caps = {c[0]: caption_img(a.font, c[0]) for c in CAPTIONS}
    out_tmp = a.out + ".part.mp4"
    enc = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
         "-i", "-", "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-pix_fmt", "yuv420p",
         "-movflags", "+faststart", out_tmp], stdin=subprocess.PIPE)
    for fi, path in enumerate(frames):
        t = fi / FPS
        img = Image.open(path).convert("RGBA")
        for text, s0, s1 in CAPTIONS:
            if s0 - 0.1 <= t <= s1 + 0.1:
                ci = ease((t - s0) / 0.2) * (1 - ease((t - (s1 - 0.25)) / 0.25))
                if ci <= 0:
                    continue
                arr = np.asarray(caps[text]).copy()
                arr[..., 3] = (arr[..., 3] * ci).astype(np.uint8)
                x = 96 - int(40 * (1 - ease((t - s0) / 0.2)))
                img.alpha_composite(Image.fromarray(arr, "RGBA"), (x, 118))
        if fi >= end_start - 6:
            k = ease((fi - (end_start - 6)) / 14)
            img.alpha_composite(Image.new("RGBA", (W, H), (6, 10, 20, int(150 * k))))
            arr = np.asarray(logo_small).copy()
            arr[..., 3] = (arr[..., 3] * k).astype(np.uint8)
            img.alpha_composite(Image.fromarray(arr, "RGBA"),
                                ((W - logo_small.width) // 2, (H - logo_small.height) // 2 - 10))
        tail = n - fi
        if tail <= 8:
            img = Image.blend(Image.new("RGBA", (W, H), (0, 0, 0, 255)), img, tail / 8)
        enc.stdin.write(img.convert("RGB").tobytes())
    enc.stdin.close()
    if enc.wait() != 0:
        raise SystemExit("ffmpeg failed")
    os.rename(out_tmp, a.out)
    shutil.rmtree(tmp, ignore_errors=True)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
