#!/usr/bin/env python3
"""Galaxy Takeover maps, generated procedurally (no outside data): the tile byte format of
src/shared/Core/WorldMap.luau, written like tools/maps/make_maps.py writes the Earth maps.

How space maps onto the map format (docs/ROADMAP.md):
  land tiles (bit 7)   star sectors, claimable. Their magnitude picks the terrain class:
                         0-9   star field     (Defs.T_PLAINS)
                         10-19 asteroid field (Defs.T_HIGHLAND)
                         20-30 nebula core    (Defs.T_MOUNTAIN)
                         31    impassable (black hole / dead star) = WorldMap.TB_IMPASSABLE
  water tiles          the void between sectors; only rocketships (transport boats) cross it.

Maps:
  galaxy  "Spiral Galaxy": four noisy spiral arms around a core, a black hole at the centre,
          star clusters (islands) scattered in the void between the arms.

Usage: python3 tools/maps/make_space_maps.py [--only galaxy] [--preview <dir>] [--seed N]
"""
import argparse
import math
import os
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_maps  # noqa: E402  (postprocess, write_module, lua helpers)

REPO = make_maps.REPO
LAND, SHORE, OCEAN = 0x80, 0x40, 0x20
IMPASSABLE = 0x9F
FOUR = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool)

# Alien factions (the AI players). Shown as names on the map; no flags yet (insignia later).
FACTIONS = [
    "Zorgon Empire", "Krell Hive", "Vortan Collective", "Nebulon Dominion", "Xal'Tar Clans",
    "Quorrian League", "Skarn Brood", "Lumina Concord", "Draxis Legion", "Ophidian Coil",
    "Thar Syndicate", "Velorian Crown", "Grox Swarm", "Ixari Union", "Morrow Reach",
    "Cindral Pact", "Sylph Choir", "Rhuun Horde", "Pallas Order", "Kethrax Brood",
    "Orryn Kingdoms", "Zeph Nomads", "Talvori Accord", "Gorm Ironclads", "Ysolde Matriarchy",
    "Hexari Mind", "Brakk Raiders", "Solari Ascendancy", "Umbral Host", "Qeth Assembly",
    "Nyx Covenant", "Vashti Republic", "Korvath Tribes", "Elyxian Court", "Mire Spawn",
    "Astrid Federation", "Jorun Clans", "Phaedra Circle", "Torrak Warband", "Zinnari Guild",
    "Oblivar Shroud", "Kaelith Spire", "Drogan Throng", "Ventari Cartel", "Seraph Array",
    "Gloom Weavers", "Halcyon Trust", "Prax Directorate", "Ulnar Pack", "Chorus of Vael",
    "Strix Armada", "Obsidian Choir", "Tenebris Cult", "Arcturan Guard", "Fenric Pride",
    "Vexil Remnant", "Ormund Forge", "Cyrene Isles", "Mok'Tar Khanate", "Lyra Expanse",
    "Ashen Veil", "Kryll Swarm", "Pyron Dynasty", "Zaltu Commune", "Eidolon Host",
]


# ---------------------------------------------------------------------------------------------------
# Noise
# ---------------------------------------------------------------------------------------------------

def value_noise(rng, h, w, cells):
    """Smooth noise in [0, 1]: a cells x cells random grid upsampled with cubic splines."""
    gh, gw = max(2, int(cells * h / max(h, w)) + 3), max(2, int(cells * w / max(h, w)) + 3)
    g = rng.random((gh, gw))
    z = ndimage.zoom(g, (h / (gh - 3) * 1.0, w / (gw - 3) * 1.0), order=3, mode="reflect")
    z = z[:h, :w]
    if z.shape != (h, w):
        z = np.pad(z, ((0, h - z.shape[0]), (0, w - z.shape[1])), mode="edge")
    return np.clip(z, 0, 1)


def fbm(rng, h, w, base, octaves=5, gain=0.5):
    total, amp, norm = np.zeros((h, w)), 1.0, 0.0
    cells = base
    for _ in range(octaves):
        total += amp * value_noise(rng, h, w, cells)
        norm += amp
        amp *= gain
        cells *= 2
    return total / norm


# ---------------------------------------------------------------------------------------------------
# Spiral galaxy
# ---------------------------------------------------------------------------------------------------

def galaxy(seed, W=2000, H=1200):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    ux = (xx - W / 2) / (W * 0.46)
    vy = (yy - H / 2) / (H * 0.46)
    r = np.sqrt(ux * ux + vy * vy)
    theta = np.arctan2(vy, ux)

    warp = fbm(rng, H, W, 6, 4) - 0.5
    detail = fbm(rng, H, W, 18, 5)
    ridge = 1 - np.abs(2 * fbm(rng, H, W, 10, 5) - 1)

    arms, pitch = 4, 0.32
    phase = theta - np.log(r + 0.02) / pitch + warp * 1.6
    arm = (0.5 + 0.5 * np.cos(arms * phase)) ** 2.2
    envelope = np.exp(-((r / 0.92) ** 6))
    core = np.exp(-((r / 0.22) ** 2))
    density = np.maximum(arm * envelope, core * 1.1)
    field = density + (detail - 0.5) * 0.55
    land = field > 0.42
    land &= r < 1.04

    # star clusters: noisy blobs out in the void
    for _ in range(46):
        for _try in range(40):
            cx, cy = rng.integers(60, W - 60), rng.integers(60, H - 60)
            if not land[cy, cx] and 0.25 < r[cy, cx] < 1.0:
                break
        rad = rng.uniform(5, 18)
        y0, y1, x0, x1 = int(cy - rad * 2), int(cy + rad * 2), int(cx - rad * 2), int(cx + rad * 2)
        sub = detail[y0:y1, x0:x1]
        dy, dx = np.mgrid[y0:y1, x0:x1]
        dd = np.sqrt((dx - cx) ** 2 + (dy - cy) ** 2) / rad
        land[y0:y1, x0:x1] |= (dd + (sub - 0.5) * 0.9) < 1.0

    # tidy like the Earth maps: no specks, no tiny void pockets
    make_maps.tidy(land)

    # terrain classes
    mag = np.zeros((H, W), np.uint8)
    plains = np.clip((density * 9.0), 0, 9).astype(np.uint8)
    mag[:] = plains
    asteroid = (ridge > 0.86) & (density < 0.75)
    mag[asteroid] = (10 + np.clip((ridge[asteroid] - 0.86) / 0.14 * 9, 0, 9)).astype(np.uint8)
    nebula = (density + (detail - 0.5) * 0.4) > 0.86
    mag[nebula] = (20 + np.clip((density[nebula] - 0.86) / 0.3 * 10, 0, 10)).astype(np.uint8)

    tiles = np.where(land, LAND | mag, 0).astype(np.uint8)
    # the black hole at the heart: impassable, ringed by a nebula accretion disc
    bh = r < 0.035
    disc = (r >= 0.035) & (r < 0.07)
    tiles[disc & land] = LAND | 26
    tiles[bh] = IMPASSABLE
    return tiles, land & ~bh


# ---------------------------------------------------------------------------------------------------
# Planet system
# ---------------------------------------------------------------------------------------------------

# biome ids shared with src/client/Map/MapSurface.luau (PLANET_BIOMES); 0 = asteroid rock
BIOMES = ["asteroid", "terran", "desert", "ice", "lava", "jungle", "toxic", "crystal", "ocean", "moon", "star"]
PLANET_BIOMES = ["terran", "desert", "ice", "lava", "jungle", "toxic", "crystal", "ocean"]
SYLL_A = ["Ka", "Zeph", "Vor", "Ly", "Thal", "Ori", "Neb", "Xan", "Cy", "Dra", "Hel", "Mor", "Sol", "Tar",
          "Vel", "Qua", "Eri", "Pyr", "Rho", "Ul", "Gal", "Ny", "Ast", "Ven"]
SYLL_B = ["ros", "thea", "nis", "dor", "lux", "vara", "mir", "zon", "tis", "phos", "gard", "rion", "dune",
          "ria", "kar", "lith", "mos", "tera", "vex", "na"]
SUFFIX = ["", "", "", " Prime", " II", " IV", " Major", " Minor", " VII", "", ""]


def planet_name(rng, used):
    for _ in range(200):
        n = rng.choice(SYLL_A) + rng.choice(SYLL_B) + rng.choice(SUFFIX)
        if n not in used:
            used.add(n)
            return n
    return "Planet %d" % len(used)


def blob(mask, cx, cy, r, noise, rough=0.22):
    """Marks a noisy disc of radius r at (cx, cy) in mask."""
    H, W = mask.shape
    y0, y1 = max(0, int(cy - r * 1.4)), min(H, int(cy + r * 1.4) + 1)
    x0, x1 = max(0, int(cx - r * 1.4)), min(W, int(cx + r * 1.4) + 1)
    dy, dx = np.mgrid[y0:y1, x0:x1]
    d = np.sqrt((dx - cx) ** 2 + (dy - cy) ** 2) / r
    mask[y0:y1, x0:x1] |= (d + (noise[y0:y1, x0:x1] - 0.5) * rough) < 1.0


def system(seed, W=2000, H=1200):
    rng = np.random.default_rng(seed)
    pyrng = __import__("random").Random(seed)
    cx, cy = W / 2, H / 2
    edge = fbm(rng, H, W, 40, 4)
    relief = fbm(rng, H, W, 22, 5)
    ridge = 1 - np.abs(2 * fbm(rng, H, W, 14, 5) - 1)
    land = np.zeros((H, W), bool)
    planets = []
    used = set()

    def orbit(R, a):
        return cx + R * 1.62 * math.cos(a), cy + R * 0.92 * math.sin(a)

    def far_enough(x, y, r, gap):
        if x - r < 30 or x + r > W - 30 or y - r < 30 or y + r > H - 30:
            return False
        if math.hypot((x - cx) / 1.62, (y - cy) / 0.92) < 130 + r / 1.3:
            return False
        return all(math.hypot(x - p["x"], y - p["y"]) > r + p["r"] + gap for p in planets)

    def add_planet(R, a, r, biome, gap=26):
        for _ in range(60):
            x, y = orbit(R + pyrng.uniform(-18, 18), a + pyrng.uniform(-0.12, 0.12))
            if far_enough(x, y, r, gap):
                p = {"x": round(x), "y": round(y), "r": round(r), "biome": biome, "name": planet_name(pyrng, used)}
                planets.append(p)
                return p
        return None

    # inner ring: 4 planets, linked by asteroid bridges
    inner = []
    a0 = pyrng.uniform(0, math.tau)
    for i in range(4):
        p = add_planet(232, a0 + i * math.tau / 4, pyrng.uniform(72, 86), PLANET_BIOMES[pyrng.randrange(8)])
        if p:
            inner.append(p)

    def add_moons(p, n):
        for k in range(n):
            for _try in range(40):
                ang = pyrng.uniform(0, math.tau)
                mr = pyrng.uniform(12, 20)
                dist = p["r"] + mr + pyrng.uniform(16, 30)
                mx, my = p["x"] + math.cos(ang) * dist, p["y"] + math.sin(ang) * dist
                if far_enough(mx, my, mr, 12):
                    planets.append({"x": round(mx), "y": round(my), "r": round(mr), "biome": "moon",
                                    "name": p["name"] + " " + "abc"[k]})
                    break

    # everything past the asteroid belt: planets scattered to fill the system, biggest first
    # every type in turn (shuffled), so a system always has all eight
    base = list(PLANET_BIOMES)
    pyrng.shuffle(base)
    biomes = base * 8
    placed = 0
    for target_r in sorted((pyrng.uniform(88, 150) for _ in range(24)), reverse=True):
        for _try in range(300):
            x, y = pyrng.uniform(40, W - 40), pyrng.uniform(40, H - 40)
            if math.hypot((x - cx) / 1.62, (y - cy) / 0.92) < 360 + target_r / 1.3:
                continue
            if far_enough(x, y, target_r, 40):
                p = {"x": round(x), "y": round(y), "r": round(target_r), "biome": biomes[placed],
                     "name": planet_name(pyrng, used)}
                planets.append(p)
                placed += 1
                if target_r > 115:
                    add_moons(p, pyrng.randint(1, 2))
                elif pyrng.random() < 0.35:
                    add_moons(p, 1)
                break
    for p in planets:
        blob(land, p["x"], p["y"], p["r"], edge, 0.18 if p["biome"] != "moon" else 0.3)

    # asteroid bridges between neighbouring inner planets (a curved, noisy chain of rock)
    bridges = []
    for i in range(len(inner)):
        a, b = inner[i], inner[(i + 1) % len(inner)]
        steps = int(math.hypot(b["x"] - a["x"], b["y"] - a["y"]) / 4)
        bend = pyrng.uniform(-0.18, 0.18)
        for k in range(steps + 1):
            t = k / steps
            x = a["x"] + (b["x"] - a["x"]) * t
            y = a["y"] + (b["y"] - a["y"]) * t
            # bow outward from the sun a little
            ox, oy = x - cx, y - cy
            L = math.hypot(ox, oy) or 1
            bow = math.sin(t * math.pi) * (40 + bend * 200)
            x += ox / L * bow
            y += oy / L * bow
            blob(land, x, y, 7 + 3 * math.sin(t * 9 + i), edge, 0.6)
        bridges.append((a["name"], b["name"]))

    # asteroid belt between the inner and middle rings: small rocks (islands)
    for _ in range(140):
        a = pyrng.uniform(0, math.tau)
        x, y = orbit(310 + pyrng.gauss(0, 14), a)
        r = pyrng.uniform(3.5, 7.5)
        if far_enough(x, y, r, 6):
            blob(land, x, y, r, edge, 0.7)

    make_maps.tidy(land)

    # terrain: per planet, relief noise picks plains / highlands / mountains
    mag = np.clip(relief * 12, 0, 9).astype(np.uint8)
    high = (relief > 0.56) & (relief <= 0.66)
    mag[high] = (10 + (relief[high] - 0.56) / 0.1 * 9).astype(np.uint8)
    mount = (relief > 0.66) | (ridge > 0.93)
    mag[mount] = (20 + np.clip((relief[mount] - 0.66) / 0.2 * 10, 0, 10)).astype(np.uint8)
    # rock outside planets (bridges, belt) is asteroid field
    inside = np.zeros((H, W), bool)
    for p in planets:
        blob(inside, p["x"], p["y"], p["r"] * 1.05, edge, 0.0)
    rock = land & ~inside
    mag[rock] = (10 + (ridge[rock] * 9)).astype(np.uint8)
    tiles = np.where(land, LAND | mag, 0).astype(np.uint8)

    # the sun: impassable
    sun_r = 92
    sun = np.zeros((H, W), bool)
    blob(sun, cx, cy, sun_r, edge, 0.08)
    tiles[sun] = IMPASSABLE
    planets.insert(0, {"x": round(cx), "y": round(cy), "r": sun_r, "biome": "star", "name": "Sol Invictus"})
    return tiles, land & ~sun, planets


# ---------------------------------------------------------------------------------------------------
# Factions
# ---------------------------------------------------------------------------------------------------

def place_planet_factions(planets, rng):
    """One faction per planet, a second on the big ones, none on moons or the sun."""
    names = list(FACTIONS)
    rng.shuffle(names)
    out = []
    for p in planets:
        if p["biome"] in ("star", "moon"):
            continue
        spots = [(p["x"], p["y"])]
        n = 4 if p["r"] >= 130 else 3 if p["r"] >= 105 else 2 if p["r"] >= 80 else 1
        if n > 1:
            a = rng.uniform(0, math.tau)
            d = p["r"] * 0.52
            spots = [(p["x"] + math.cos(a + k * math.tau / n) * d, p["y"] + math.sin(a + k * math.tau / n) * d)
                     for k in range(n)]
        for x, y in spots:
            out.append({"name": names[len(out) % len(names)], "flag": "", "x": round(x), "y": round(y)})
    return out


def place_factions(land, rng, count, min_gap):
    H, W = land.shape
    # inland tiles only (not on the edge of the void), away from the black hole
    inner = ndimage.binary_erosion(land, structure=FOUR, iterations=6)
    ys, xs = np.nonzero(inner)
    order = rng.permutation(len(xs))
    placed = []
    gap2 = min_gap * min_gap
    for i in order:
        x, y = int(xs[i]), int(ys[i])
        if all((x - px) ** 2 + (y - py) ** 2 >= gap2 for px, py in placed):
            placed.append((x, y))
            if len(placed) >= count:
                break
    names = list(FACTIONS)
    rng.shuffle(names)
    return [{"name": names[i % len(names)], "flag": "", "x": x, "y": y} for i, (x, y) in enumerate(placed)]


# ---------------------------------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------------------------------

class Proj:
    def __init__(self, w, h):
        self.w, self.h = w, h


SPECS = {
    "system": {
        "id": "system", "name": "Star System", "module": "StarSystem",
        "categories": ["featured", "world", "system"], "frequency": 30, "modifiers": [], "world": True,
    },
    "galaxy": {
        "id": "galaxy", "name": "Spiral Galaxy", "module": "Galaxy", "categories": ["featured", "world", "galaxy"],
        "frequency": 30, "modifiers": [], "world": True, "factions": 64, "min_gap": 70,
    },
}


PREVIEW_BIOME = {  # (plains, highland, mountain) RGB, as MapSurface draws them
    "asteroid": ((118, 108, 118), (128, 116, 126), (150, 140, 150)),
    "terran": ((92, 158, 88), (128, 146, 92), (206, 210, 214)),
    "desert": ((214, 170, 104), (186, 136, 84), (150, 104, 74)),
    "ice": ((206, 226, 242), (164, 194, 222), (244, 250, 255)),
    "lava": ((92, 44, 40), (126, 54, 40), (238, 112, 44)),
    "jungle": ((46, 128, 72), (38, 100, 62), (98, 160, 92)),
    "toxic": ((150, 178, 62), (112, 140, 52), (204, 222, 94)),
    "crystal": ((118, 108, 204), (88, 168, 210), (204, 162, 255)),
    "ocean": ((58, 136, 190), (46, 110, 170), (118, 190, 222)),
    "moon": ((166, 166, 176), (132, 132, 144), (204, 204, 214)),
}


def biome_index(planets, H, W):
    idx = np.zeros((H, W), np.uint8)
    for p in planets or []:
        if p["biome"] == "star":
            continue
        r = p["r"] * 1.25 + 2
        y0, y1 = max(0, int(p["y"] - r)), min(H, int(p["y"] + r) + 1)
        x0, x1 = max(0, int(p["x"] - r)), min(W, int(p["x"] + r) + 1)
        dy, dx = np.mgrid[y0:y1, x0:x1]
        m = (dx - p["x"]) ** 2 + (dy - p["y"]) ** 2 <= r * r
        idx[y0:y1, x0:x1][m] = BIOMES.index(p["biome"])
    return idx


def preview_png(tiles, nations, path, planets=None):
    """A quick look in the game's space palette."""
    H, W = tiles.shape
    img = np.zeros((H, W, 3), np.uint8)
    land = tiles >= 128
    mag = tiles & 31
    shore = (tiles & SHORE) != 0
    img[:] = (10, 12, 34)
    rng = np.random.default_rng(1)
    stars = (rng.random((H, W)) < 0.004) & ~land
    img[stars] = (190, 200, 255)
    bidx = biome_index(planets, H, W)
    for bi, name in enumerate(BIOMES):
        if name == "star":
            continue
        cols = PREVIEW_BIOME[name]
        sel = land & (bidx == bi)
        img[sel & (mag < 10)] = cols[0]
        img[sel & (mag >= 10) & (mag < 20)] = cols[1]
        img[sel & (mag >= 20) & (mag < 31)] = cols[2]
        rim = tuple(min(255, c + 50) for c in cols[0])
        img[sel & shore & (mag < 31)] = rim
    sunm = tiles == IMPASSABLE
    if planets and planets[0]["biome"] == "star":
        sp = planets[0]
        yy, xx = np.mgrid[0:H, 0:W]
        d = np.sqrt((xx - sp["x"]) ** 2 + (yy - sp["y"]) ** 2) / sp["r"]
        sun_col = np.stack([255 - 0 * d, 250 - 110 * d, 200 - 190 * d], -1).clip(0, 255).astype(np.uint8)
        img[sunm] = sun_col[sunm]
        halo = (~land) & (d < 1.6) & ~stars
        k = ((1.6 - d) / 0.6).clip(0, 1)[..., None]
        img[halo] = (img[halo] * (1 - k[halo] * 0.8) + np.array([255, 140, 40]) * k[halo] * 0.8).astype(np.uint8)
    else:
        img[sunm] = (0, 0, 0)
    im = Image.fromarray(img)
    from PIL import ImageDraw  # noqa: PLC0415
    d = ImageDraw.Draw(im)
    for n in nations:
        d.ellipse([n["x"] - 5, n["y"] - 5, n["x"] + 5, n["y"] + 5], fill=(255, 220, 90), outline=(0, 0, 0))
    for p in planets or []:
        if p["biome"] not in ("star", "moon"):
            d.text((p["x"] - 30, p["y"] + p["r"] + 4), p["name"], fill=(230, 235, 255))
    im.save(path)


def write_registry_rows(rows, default=None):
    """Adds or replaces the space maps' rows in src/shared/Data/MapList.luau, keeping the others."""
    path = os.path.join(REPO, "src", "shared", "Data", "MapList.luau")
    s = open(path, encoding="utf-8").read()
    for spec, w, h, land_tiles, n in rows:
        fields = [
            "id = %s" % make_maps.lua_str(spec["id"]),
            "name = %s" % make_maps.lua_str(spec["name"]),
            "module = %s" % make_maps.lua_str(spec["module"]),
            "width = %d" % w, "height = %d" % h, "k_lin = 1.0",
            "categories = %s" % make_maps.lua_list(spec["categories"]),
            "multiplayer_frequency = %d" % spec["frequency"],
        ]
        if spec["modifiers"]:
            fields.append("forced_modifiers = %s" % make_maps.lua_list(spec["modifiers"]))
        fields += ["land_tiles = %d" % land_tiles, "nations = %d" % n]
        if spec.get("world"):
            fields.append("replicated = true")
        row = "\t{ %s }," % ", ".join(fields)
        pat = re.compile(r"^\t\{ id = %s,.*$\n" % re.escape(make_maps.lua_str(spec["id"])), re.M)
        if pat.search(s):
            s = pat.sub(row + "\n", s)
        else:
            s = s.replace("MapList.maps = {\n", "MapList.maps = {\n" + row + "\n", 1)
    if default:
        s = re.sub(r'MapList.DEFAULT = "[^"]*"', 'MapList.DEFAULT = "%s"' % default, s)
    open(path, "w", encoding="utf-8").write(s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--preview")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--no-write", action="store_true")
    ap.add_argument("--default")
    a = ap.parse_args()
    rows = []
    for key, spec in SPECS.items():
        if a.only and a.only != key:
            continue
        rng = np.random.default_rng(a.seed + 100)
        planets = None
        if key == "system":
            tiles, land, planets = system(a.seed)
            nations = place_planet_factions(planets, rng)
        else:
            tiles, land = galaxy(a.seed)
            nations = place_factions(land, rng, spec["factions"], spec["min_gap"])
        H, W = tiles.shape
        out = make_maps.postprocess(bytes(tiles.ravel()), W, H)
        final = np.frombuffer(out, np.uint8).reshape(H, W)
        land_tiles = int(((final & LAND) != 0).sum() - (final == IMPASSABLE).sum())
        print(f"{key}: {W}x{H}, {land_tiles} sector tiles, {len(nations)} factions")
        if a.preview:
            os.makedirs(a.preview, exist_ok=True)
            preview_png(final, nations, os.path.join(a.preview, key + ".png"), planets)
        if not a.no_write:
            size = make_maps.write_module(spec, Proj(W, H), out, land_tiles, nations)
            # the header names Earth data; these maps are generated
            p = make_maps.module_path(spec)
            txt = open(p, encoding="utf-8").read().replace(
                "-- GENERATED by tools/maps/make_maps.py from public-domain data (Natural Earth, NOAA ETOPO1). Do not edit.",
                "-- GENERATED by tools/maps/make_space_maps.py (procedural, seed %d). Do not edit." % a.seed, 1)
            if planets:
                rows_lua = "".join(
                    "\t\t{ name = %s, biome = %s, x = %d, y = %d, r = %d },\n"
                    % (make_maps.lua_str(q["name"]), make_maps.lua_str(q["biome"]), q["x"], q["y"], q["r"]) for q in planets)
                txt = txt.replace('\tcodec = "zstd+base64",', "\tplanets = {\n" + rows_lua + "\t},\n\tcodec = \"zstd+base64\",", 1)
            open(p, "w", encoding="utf-8").write(txt)
            print(f"  wrote {os.path.relpath(p, REPO)} ({size // 1024} KB terrain)")
            rows.append((spec, W, H, land_tiles, len(nations)))
    if rows:
        write_registry_rows(rows, a.default)


if __name__ == "__main__":
    main()
