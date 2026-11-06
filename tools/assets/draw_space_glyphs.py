#!/usr/bin/env python3
"""Galaxy Takeover glyph sheets: white silhouettes on magenta, drawn in code (no image model), in the
layout tools/assets/make_map_sprites.py keys into the map plates' glyphs and the interface masks.

  assets/map_sprites/src/glyph_sheet.png       3 x 3, Defs.S_* order: Colony (dome habitat),
      Starport (ring station), Fabricator (gear), Shield Generator (hex shield), Laser Turret,
      Missile Silo (kept), Plasma Cannon, Hangar Bay (starfighter), Mass Driver (kept)
  assets/map_sprites/src/unit_glyph_sheet.png  5 x 1, UI_UNITS order: Battlecruiser, Photon Missile,
      Antimatter Missile, Cluster Missile (kept), Alien Rocketship

Cells marked "kept" are copied from the sheet as it is (RoWorld's art that already fits space).

Usage: python3 tools/assets/draw_space_glyphs.py [--preview out.png]
"""
import math
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "map_sprites", "src")
MAGENTA = (255, 0, 255)
WHITE = (255, 255, 255)
SS = 4  # supersampling


class Pen:
    """Draws in a cell's unit square [0, 1]^2 at SS x resolution."""

    def __init__(self, size):
        self.size = size
        self.im = Image.new("RGB", (size * SS, size * SS), MAGENTA)
        self.d = ImageDraw.Draw(self.im)

    def p(self, x, y):
        return (x * self.size * SS, y * self.size * SS)

    def poly(self, pts, fill=WHITE):
        self.d.polygon([self.p(x, y) for x, y in pts], fill=fill)

    def rect(self, x0, y0, x1, y1, fill=WHITE, r=0.0):
        a, b = self.p(x0, y0), self.p(x1, y1)
        self.d.rounded_rectangle([a, b], radius=r * self.size * SS, fill=fill)

    def ellipse(self, cx, cy, rx, ry, fill=WHITE):
        self.d.ellipse([self.p(cx - rx, cy - ry), self.p(cx + rx, cy + ry)], fill=fill)

    def circle(self, cx, cy, r, fill=WHITE):
        self.ellipse(cx, cy, r, r, fill)

    def ring(self, cx, cy, rx, ry, w, fill=WHITE):
        self.d.ellipse([self.p(cx - rx, cy - ry), self.p(cx + rx, cy + ry)], outline=fill,
                       width=round(w * self.size * SS))

    def arc(self, cx, cy, rx, ry, a0, a1, w, fill=WHITE):
        self.d.arc([self.p(cx - rx, cy - ry), self.p(cx + rx, cy + ry)], a0, a1, fill=fill,
                   width=round(w * self.size * SS))

    def pie(self, cx, cy, rx, ry, a0, a1, fill=WHITE):
        self.d.pieslice([self.p(cx - rx, cy - ry), self.p(cx + rx, cy + ry)], a0, a1, fill=fill)

    def bar(self, x0, y0, x1, y1, w, fill=WHITE, cap=True):
        """A thick line from (x0, y0) to (x1, y1), round caps."""
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L * w / 2, dx / L * w / 2
        self.poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], fill)
        if cap:
            self.circle(x0, y0, w / 2, fill)
            self.circle(x1, y1, w / 2, fill)

    def star(self, cx, cy, r_out, r_in, n, rot=-90, fill=WHITE):
        pts = []
        for i in range(n * 2):
            r = r_out if i % 2 == 0 else r_in
            a = math.radians(rot + i * 180 / n)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        self.poly(pts, fill)

    def done(self):
        return self.im.resize((self.size, self.size), Image.LANCZOS)


# ---------------------------------------------------------------------------------------------------
# Structures (glyph sheet)
# ---------------------------------------------------------------------------------------------------

def colony(g):
    # a big domed habitat on a deck with one bold band, an antenna, a small side dome
    g.rect(0.06, 0.78, 0.94, 0.88, r=0.02)
    g.pie(0.44, 0.79, 0.34, 0.4, 180, 360)
    g.arc(0.44, 0.79, 0.34, 0.2, 180, 360, 0.05, MAGENTA)
    g.bar(0.44, 0.4, 0.44, 0.2, 0.05)
    g.circle(0.44, 0.17, 0.055)
    g.pie(0.84, 0.79, 0.12, 0.16, 180, 360)


def starport(g):
    # a ring station seen from above: rim, hub, four spokes, docking arms
    g.ring(0.5, 0.5, 0.36, 0.36, 0.085)
    g.circle(0.5, 0.5, 0.13)
    g.circle(0.5, 0.5, 0.05, MAGENTA)
    for a in (45, 135, 225, 315):
        r = math.radians(a)
        g.bar(0.5 + math.cos(r) * 0.12, 0.5 + math.sin(r) * 0.12,
              0.5 + math.cos(r) * 0.32, 0.5 + math.sin(r) * 0.32, 0.045, cap=False)
    for a in (0, 90, 180, 270):
        r = math.radians(a)
        x, y = 0.5 + math.cos(r) * 0.42, 0.5 + math.sin(r) * 0.42
        g.bar(0.5 + math.cos(r) * 0.36, 0.5 + math.sin(r) * 0.36, x, y, 0.06, cap=False)
        g.circle(x, y, 0.05)


def fabricator(g):
    # a gear
    cx, cy = 0.5, 0.5
    for i in range(8):
        a = math.radians(i * 45)
        g.bar(cx + math.cos(a) * 0.2, cy + math.sin(a) * 0.2, cx + math.cos(a) * 0.4,
              cy + math.sin(a) * 0.4, 0.13, cap=False)
    g.circle(cx, cy, 0.31)
    g.circle(cx, cy, 0.13, MAGENTA)


def shield(g):
    # a shield crest with a hexagon cell at its heart
    g.poly([(0.5, 0.08), (0.86, 0.2), (0.82, 0.55), (0.5, 0.92), (0.18, 0.55), (0.14, 0.2)])
    g.poly([(0.5, 0.16), (0.78, 0.25), (0.75, 0.53), (0.5, 0.82), (0.25, 0.53), (0.22, 0.25)], MAGENTA)
    g.poly([(0.5, 0.2), (0.74, 0.28), (0.71, 0.51), (0.5, 0.77), (0.29, 0.51), (0.26, 0.28)])
    hexr = 0.13
    g.poly([(0.5 + math.cos(math.radians(30 + 60 * i)) * hexr, 0.45 + math.sin(math.radians(30 + 60 * i)) * hexr)
            for i in range(6)], MAGENTA)


def laser_turret(g):
    # a pedestal, a round turret head, a long twin barrel up and right, a flare at the muzzle
    g.poly([(0.16, 0.9), (0.84, 0.9), (0.72, 0.74), (0.28, 0.74)])
    g.rect(0.38, 0.6, 0.62, 0.76)
    g.circle(0.5, 0.56, 0.17)
    g.bar(0.52, 0.5, 0.8, 0.22, 0.07, cap=False)
    g.bar(0.58, 0.58, 0.84, 0.31, 0.05, cap=False)
    g.star(0.86, 0.17, 0.11, 0.035, 4, rot=-45)
    g.circle(0.5, 0.56, 0.06, MAGENTA)


def plasma_cannon(g):
    # a heavy base, a boxy turret, a thick ringed barrel and a plasma orb leaving it
    g.rect(0.1, 0.8, 0.9, 0.9, r=0.02)
    g.poly([(0.18, 0.8), (0.24, 0.62), (0.62, 0.62), (0.7, 0.8)])
    g.rect(0.22, 0.44, 0.62, 0.64, r=0.04)
    g.bar(0.5, 0.52, 0.78, 0.36, 0.13, cap=False)
    for t in (0.35, 0.6):
        x, y = 0.5 + 0.28 * t, 0.52 - 0.16 * t
        g.bar(x - 0.02, y - 0.09, x + 0.02, y + 0.09, 0.025, MAGENTA, cap=False)
    g.circle(0.86, 0.3, 0.08)
    g.ring(0.86, 0.3, 0.13, 0.13, 0.025)


def hangar_bay(g):
    # a starfighter from above: pointed fuselage, swept wings, wingtip cannons, engine
    g.poly([(0.5, 0.06), (0.58, 0.3), (0.6, 0.78), (0.4, 0.78), (0.42, 0.3)])
    g.poly([(0.42, 0.42), (0.08, 0.72), (0.08, 0.8), (0.42, 0.66)])
    g.poly([(0.58, 0.42), (0.92, 0.72), (0.92, 0.8), (0.58, 0.66)])
    g.rect(0.06, 0.48, 0.11, 0.82, r=0.02)
    g.rect(0.89, 0.48, 0.94, 0.82, r=0.02)
    g.poly([(0.43, 0.78), (0.57, 0.78), (0.54, 0.92), (0.46, 0.92)])
    g.ellipse(0.5, 0.3, 0.035, 0.07, MAGENTA)


# ---------------------------------------------------------------------------------------------------
# Units (unit glyph sheet, side views pointing right)
# ---------------------------------------------------------------------------------------------------

def battlecruiser(g):
    # a long wedge hull, a bridge tower, engine blocks at the stern
    g.poly([(0.04, 0.52), (0.96, 0.6), (0.9, 0.66), (0.08, 0.68)])
    g.poly([(0.08, 0.52), (0.62, 0.52), (0.5, 0.45), (0.12, 0.44)])
    g.rect(0.22, 0.34, 0.38, 0.46, r=0.015)
    g.rect(0.26, 0.28, 0.32, 0.35)
    g.rect(0.0, 0.47, 0.06, 0.66, r=0.01)
    for x in (0.44, 0.6, 0.74):
        g.rect(x, 0.6, x + 0.04, 0.62, fill=MAGENTA)


def photon_missile(g):
    # a glowing orb with a burst of rays
    g.star(0.5, 0.5, 0.36, 0.15, 8, rot=-90)
    g.circle(0.5, 0.5, 0.17)


def antimatter_missile(g):
    # an atom: a core and three orbits
    g.circle(0.5, 0.5, 0.08)
    for a in (0, 60, 120):
        im = Image.new("L", g.im.size, 0)
        d = ImageDraw.Draw(im)
        s = g.size * SS
        d.ellipse([s * 0.18, s * 0.38, s * 0.82, s * 0.62], outline=255, width=round(0.035 * s))
        im = im.rotate(a, resample=Image.BICUBIC, center=(s / 2, s / 2))
        g.im.paste(Image.new("RGB", g.im.size, WHITE), (0, 0), im)


def rocketship(g):
    # a rocket on its side: nose, body, alien porthole, fins, flame
    g.poly([(0.18, 0.42), (0.68, 0.42), (0.86, 0.5), (0.68, 0.58), (0.18, 0.58)])
    g.circle(0.5, 0.5, 0.055, MAGENTA)
    g.circle(0.5, 0.5, 0.03)
    g.poly([(0.18, 0.42), (0.3, 0.42), (0.18, 0.3), (0.1, 0.3)])
    g.poly([(0.18, 0.58), (0.3, 0.58), (0.18, 0.7), (0.1, 0.7)])
    g.poly([(0.16, 0.45), (0.16, 0.55), (0.04, 0.5)])


def cells(sheet, cols, rows):
    w, h = sheet.size
    cw, ch = w // cols, h // rows
    return [sheet.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)) for r in range(rows) for c in range(cols)]


def draw_cell(fn, w, h):
    """Draws in a square of the cell's shorter side, centred in the cell."""
    s = min(w, h)
    g = Pen(s)
    fn(g)
    out = Image.new("RGB", (w, h), MAGENTA)
    out.paste(g.done(), ((w - s) // 2, (h - s) // 2))
    return out


def build(path, cols, rows, drawers):
    old = Image.open(path).convert("RGB")
    w, h = old.size
    cw, ch = w // cols, h // rows
    kept = cells(old, cols, rows)
    out = Image.new("RGB", (w, h), MAGENTA)
    for i, fn in enumerate(drawers):
        c, r = i % cols, i // cols
        cell = kept[i] if fn is None else draw_cell(fn, cw, ch)
        out.paste(cell, (c * cw, r * ch))
    return out


def main():
    glyphs = build(os.path.join(SRC, "glyph_sheet.png"), 3, 3,
                   [colony, starport, fabricator, shield, laser_turret, None, plasma_cannon, hangar_bay, None])
    units = build(os.path.join(SRC, "unit_glyph_sheet.png"), 5, 1,
                  [battlecruiser, photon_missile, antimatter_missile, None, rocketship])
    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        W = max(glyphs.width, units.width)
        sheet = Image.new("RGB", (W, glyphs.height + units.height), MAGENTA)
        sheet.paste(glyphs, (0, 0))
        sheet.paste(units, (0, glyphs.height))
        sheet.save(out)
        print("preview", out)
        return
    glyphs.save(os.path.join(SRC, "glyph_sheet.png"))
    units.save(os.path.join(SRC, "unit_glyph_sheet.png"))
    print("wrote glyph_sheet.png and unit_glyph_sheet.png")


if __name__ == "__main__":
    main()
