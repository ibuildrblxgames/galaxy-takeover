#!/usr/bin/env python3
"""Galaxy Takeover' 10-second trailer, cut from a Studio screen recording (Windows Game Bar: the whole Studio
window) of a real match. Each shot is the game viewport cropped out of the window and scaled to
1920 x 1080; a small caption says what the gameplay is; the logo card closes it (Roblox's video rules:
real footage, a logo overlay, sparse text describing gameplay, no claims; Creator Hub > Configurations >
Places > Videos: mp4, <= 60 s, <= 1920x1080, 16:9).

Usage: python3 tools/trailer/edit_space.py --src clip.mp4 --font <Rubik Black .ttf> --out trailer.mp4
         [--crop x,y,w,h] (the viewport in the recording's pixels)
"""
import argparse
import os
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H, FPS = 1920, 1080, 30
ENC = ["-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-pix_fmt", "yuv420p", "-r", str(FPS)]

# (source: "early" or "late" recording, start s in it, length s on screen, speed, caption): the build-up
# first (owner, 2026-11-05: "the first 5 seconds should be the build up: claiming your first bit of land,
# creating a colony, building troops, then invading"), sped up, then the late-game missile barrage
SHOTS = [
    ("early", 29.0, 2.0, 5.0, "CLAIM YOUR FIRST LAND"),
    ("early", 74.2, 1.5, 2.0, "BUILD COLONIES"),
    ("early", 95.0, 1.5, 4.0, "INVADE OTHER PLANETS"),
    ("late", 108.6, 2.6, 1.0, "WIPE OUT RIVAL FACTIONS"),
]
LOGO_S = 2.4
FADE_S = 0.25


def text_png(path, text, font_path, size, pad=26):
    """A caption pill: white Rubik on a dark glass pill with a cyan edge, transparent elsewhere."""
    f = ImageFont.truetype(font_path, size)
    b = f.getbbox(text)
    tw, th = b[2] - b[0], b[3] - b[1]
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = W / 2, H - 215  # (above the hotbar)
    d.rounded_rectangle([cx - tw / 2 - pad, cy - th / 2 - pad * 0.7, cx + tw / 2 + pad, cy + th / 2 + pad * 0.7],
                        radius=int(th), fill=(14, 10, 40, 215), outline=(56, 225, 255, 255), width=4)
    d.text((cx, cy), text, font=f, anchor="mm", fill=(255, 255, 255, 255))
    im.save(path)


def logo_png(path, font_path, bg_frame, title):
    """The closing card: the last shot's frame blurred and darkened, the title as on the thumbnail."""
    base = Image.open(bg_frame).convert("RGBA").resize((W, H)).filter(ImageFilter.GaussianBlur(14))
    dark = Image.new("RGBA", (W, H), (6, 6, 24, 150))
    base.alpha_composite(dark)
    size = 200
    font = ImageFont.truetype(font_path, size)
    while font.getbbox(title)[2] > W - 200:
        size -= 6
        font = ImageFont.truetype(font_path, size)
    cx, cy = W / 2, H / 2 - 40
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).text((cx, cy), title, font=font, anchor="mm", fill=(56, 225, 255, 255), stroke_width=22,
                              stroke_fill=(56, 225, 255, 255))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(26)))
    d = ImageDraw.Draw(base)
    d.text((cx + 8, cy + 12), title, font=font, anchor="mm", fill=(10, 6, 40, 255), stroke_width=16,
           stroke_fill=(10, 6, 40, 255))
    d.text((cx, cy), title, font=font, anchor="mm", fill=(255, 255, 255, 255), stroke_width=16,
           stroke_fill=(20, 12, 70, 255))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).text((cx, cy), title, font=font, anchor="mm", fill=255)
    box = mask.getbbox()
    t = np.clip((np.arange(H) - box[1]) / max(1, box[3] - box[1]), 0, 1)[:, None]
    top, mid, bot = np.array([255, 252, 230]), np.array([255, 214, 90]), np.array([255, 140, 30])
    col = np.where(t < 0.5, top + (mid - top) * (t / 0.5), mid + (bot - mid) * ((t - 0.5) / 0.5))
    grad = np.zeros((H, W, 4), np.uint8)
    grad[..., 0:3] = col[:, None, :].astype(np.uint8)
    grad[..., 3] = np.array(mask)
    base.alpha_composite(Image.fromarray(grad))
    sf = ImageFont.truetype(font_path, 52)
    sub = "CONQUER THE UNIVERSE"
    sb = sf.getbbox(sub)
    sw = sb[2] - sb[0] + 90
    sy = box[3] + 70
    d.rounded_rectangle([cx - sw / 2, sy - 38, cx + sw / 2, sy + 38], radius=38, fill=(20, 12, 70, 235),
                        outline=(56, 225, 255, 255), width=4)
    d.text((cx, sy), sub, font=sf, anchor="mm", fill=(140, 240, 255, 255))
    base.convert("RGB").save(path, quality=95)


def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--early", required=True, help="the early-game recording")
    ap.add_argument("--late", required=True, help="the late-game recording")
    ap.add_argument("--font", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--crop", required=True, help="x,y,w,h of the game viewport in the recording")
    ap.add_argument("--title", default="GALAXY TAKEOVER")
    a = ap.parse_args()
    def fit(x, y, w, h):
        # 16:9 inside the rect, centred
        if w * 9 > h * 16:
            nw = h * 16 // 9
            return x + (w - nw) // 2, y, nw, h
        nh = w * 9 // 16
        return x, y + (h - nh) // 2, w, nh

    base_crop = fit(*(int(v) for v in a.crop.split(",")))
    tmp = tempfile.mkdtemp()
    parts = []
    srcs = {"early": a.early, "late": a.late}
    for i, shot in enumerate(SHOTS):
        key, ss, dur, speed, cap = shot[:5]
        src = srcs[key]
        x, y, w, h = fit(*shot[5]) if len(shot) > 5 else base_crop
        cap_png = os.path.join(tmp, f"cap{i}.png")
        text_png(cap_png, cap, a.font, 54)
        out = os.path.join(tmp, f"shot{i}.part.mp4")
        vf = (f"[0:v]setpts=PTS/{speed},crop={w}:{h}:{x}:{y},scale={W}:{H}:flags=lanczos,setsar=1,fps={FPS},"
              f"trim=duration={dur}[v];"
              f"[1:v]format=rgba,fade=in:st=0.15:d=0.25:alpha=1[c];[v][c]overlay=0:0,"
              f"fade=in:st=0:d={FADE_S if i == 0 else 0.12},fade=out:st={dur - 0.12}:d=0.12[o]")
        run(["ffmpeg", "-y", "-ss", str(ss), "-t", str(dur * speed + 0.5), "-i", src, "-loop", "1", "-t", str(dur),
             "-i", cap_png,
             "-filter_complex", vf, "-map", "[o]", "-an", *ENC, out])
        os.rename(out, out.replace(".part", ""))
        parts.append(out.replace(".part", ""))
    # the logo card over the last shot's last frame
    last = os.path.join(tmp, "last.png")
    key, ss, dur, speed = SHOTS[-1][:4]
    x, y, w, h = fit(*SHOTS[-1][5]) if len(SHOTS[-1]) > 5 else base_crop
    run(["ffmpeg", "-y", "-ss", str(ss + dur * speed - 0.1), "-i", srcs[key], "-frames:v", "1", "-vf",
         f"crop={w}:{h}:{x}:{y},scale={W}:{H}", last])
    card = os.path.join(tmp, "card.jpg")
    logo_png(card, a.font, last, a.title)
    out = os.path.join(tmp, "logo.part.mp4")
    run(["ffmpeg", "-y", "-framerate", str(FPS), "-i", card, "-vf",
         f"format=yuv420p,loop=-1:1,trim=duration={LOGO_S},fade=in:st=0:d=0.3,fade=out:st={LOGO_S - 0.3}:d=0.3",
         *ENC, out])
    os.rename(out, out.replace(".part", ""))
    parts.append(out.replace(".part", ""))
    lst = os.path.join(tmp, "list.txt")
    with open(lst, "w") as f:
        for p in parts:
            f.write(f"file '{p}'\n")
    final_tmp = a.out + ".part.mp4"
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", "-movflags", "+faststart", final_tmp])
    os.rename(final_tmp, a.out)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
