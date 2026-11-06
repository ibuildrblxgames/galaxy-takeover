#!/usr/bin/env python3
"""Galaxy Takeover: RoWorld's flag and skin-preview sheets are private to RoWorld's Roblox group, so in our
experience they draw blank (the Locker's flags and crate skins, the flag shop). This re-renders each
sheet locally with the exact rects of its manifest and writes it under assets/embedded, where
tools/assets/embed_images.py packs it into the place (UI/EmbeddedImage draws it; no upload).

  assets/embedded/flags/<n>.png          Assets/Flags.luau atlases (country flags, Wikimedia Commons)
  assets/embedded/shopflags/<n>.png      Assets/ShopFlags.luau `atlases` (name tags, Locker)
  assets/embedded/shopflags_big/<n>.png  Assets/ShopFlags.luau `big` (the shop's cards)
  assets/embedded/skins/previews.png     Assets/SkinPreviews.luau (tools/assets/make_skin_previews.py)

Usage: python3 tools/assets/embed_flags.py && python3 tools/assets/embed_images.py
"""
import io
import os
import re
import sys

import cairosvg
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EMB = os.path.join(ROOT, "assets", "embedded")
FLAGS_LUA = os.path.join(ROOT, "src", "shared", "Assets", "Flags.luau")
SHOP_LUA = os.path.join(ROOT, "src", "shared", "Assets", "ShopFlags.luau")
FLAG_SVG = os.path.join(ROOT, "assets", "flags")
SHOP_ART = os.path.join(ROOT, "assets", "shop_flags", "art")
MAX = 1024  # EditableImage's largest side


def save(sheets, sub, colors=0):
    """`colors`: reduce to that many colours first (flat vector art looks the same and packs far
    smaller in the place: every embedded pixel ships to each player)."""
    os.makedirs(os.path.join(EMB, sub), exist_ok=True)
    for n, im in sheets.items():
        assert im.width <= MAX and im.height <= MAX, (sub, n, im.size)
        if colors:
            alpha = im.getchannel("A")
            im = im.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
            im = im.convert("RGBA")
            im.putalpha(alpha)
        im.save(os.path.join(EMB, sub, f"{n}.png"), optimize=True)


def sheet_for(sheets, n, w, h):
    im = sheets.get(n)
    if im is None or im.width < w or im.height < h:
        big = Image.new("RGBA", (max(w, im.width if im else 0), max(h, im.height if im else 0)), (0, 0, 0, 0))
        if im is not None:
            big.paste(im, (0, 0))
        sheets[n] = big
    return sheets[n]


def country_flags():
    src = open(FLAGS_LUA, encoding="utf-8").read()
    rx = re.compile(r'code = "([^"]+)".*?atlas = (\d+), x = (\d+), y = (\d+), w = (\d+), h = (\d+)')
    sheets = {}
    n = 0
    for m in rx.finditer(src):
        code, a, x, y, w, h = m.group(1), *map(int, m.groups()[1:])
        path = os.path.join(FLAG_SVG, code + ".svg")
        if not os.path.exists(path):
            continue
        png = cairosvg.svg2png(url=path, output_width=w * 3)
        im = Image.open(io.BytesIO(png)).convert("RGBA")
        box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        if box:
            im = im.crop(box)
        im = im.resize((w, h), Image.LANCZOS)
        sheet_for(sheets, a, x + w, y + h).alpha_composite(im, (x, y))
        n += 1
    save(sheets, "flags", 256)
    print(f"country flags: {n} in {len(sheets)} sheets")


def flag_at(path, w, h):
    # (as tools/assets/make_shop_flags.py: centre crop to 3:2, then down in two steps)
    im = Image.open(path).convert("RGB")
    W, H = im.size
    if W * 2 > H * 3:
        nw = H * 3 // 2
        im = im.crop(((W - nw) // 2, 0, (W - nw) // 2 + nw, H))
    elif W * 2 < H * 3:
        nh = W * 2 // 3
        im = im.crop((0, (H - nh) // 2, W, (H - nh) // 2 + nh))
    if im.width > w * 3:
        im = im.resize((w * 3, h * 3), Image.LANCZOS)
    return im.resize((w, h), Image.LANCZOS).convert("RGBA")


def shop_flags():
    src = open(SHOP_LUA, encoding="utf-8").read()
    rx = re.compile(r'key = "([^"]+)".*?atlas = (\d+), x = (\d+), y = (\d+), w = (\d+), h = (\d+), '
                    r'big_rect = \{ (\d+), (\d+), (\d+), (\d+), (\d+) \}')
    small, big = {}, {}
    n = 0
    for m in rx.finditer(src):
        key = m.group(1)
        a, x, y, w, h, b, bx, by, bw, bh = map(int, m.groups()[1:])
        path = os.path.join(SHOP_ART, key + ".png")
        if not os.path.exists(path):
            print("missing art:", key)
            continue
        sheet_for(small, a, x + w, y + h).alpha_composite(flag_at(path, w, h), (x, y))
        sheet_for(big, b, bx + bw, by + bh).alpha_composite(flag_at(path, bw, bh), (bx, by))
        n += 1
    save(small, "shopflags", 256)
    save(big, "shopflags_big", 256)
    print(f"shop flags: {n} in {len(small)} small and {len(big)} big sheets")


def skin_previews():
    import make_skin_previews as msp
    import preview_skins as ps

    skins = ps.skins()
    cell = msp.TILES * msp.SCALE
    rows = (len(skins) + msp.COLS - 1) // msp.COLS
    sheet = Image.new("RGBA", (msp.COLS * (cell + msp.GAP), rows * (cell + msp.GAP)), (0, 0, 0, 0))
    for i, s in enumerate(skins):
        sheet.alpha_composite(msp.render(s), ((i % msp.COLS) * (cell + msp.GAP), (i // msp.COLS) * (cell + msp.GAP)))
    save({"previews": sheet}, "skins")
    print(f"skin previews: {len(skins)}")


if __name__ == "__main__":
    country_flags()
    shop_flags()
    skin_previews()
