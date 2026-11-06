#!/usr/bin/env python3
"""Galaxy Takeover text pass: re-theme player-facing strings for space (docs/ROADMAP.md).

Rewrites words inside Luau string literals only (never identifiers or comments), and only in
strings a player reads: ones with a space or a capital letter. Lowercase one-word strings are
internal keys ("port", "atom") and are left alone, as are the files in SKIP (analytics labels,
map / country / music names, which change with the space maps).

  python3 tools/space_text.py            # preview: file:line  before  ->  after
  python3 tools/space_text.py --write    # apply
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SKIP = {
    "src/server/Analytics.luau",
    "src/client/UI/Telemetry.luau",
    "src/shared/Assets/Soundtrack.luau",
    "src/shared/Assets/Flags.luau",
    "src/shared/Assets/ShopFlags.luau",
    "src/shared/Data/MapList.luau",
    "src/shared/Data/Nations.luau",
    "src/shared/Data/BotNames.luau",
    "src/client/UI/UIMaps.luau",
}
SKIP_DIRS = ("src/shared/Data/Maps", "src/server/MapData", "src/client/Dev", "src/server/Dev")

# Ordered (pattern, replacement). Longer phrases first. Replacements keep the case of the match
# (UPPER, Title, lower) via fix_case. \b word boundaries; plurals listed explicitly.
RULES = [
    # whole phrases that read badly word by word
    (r"can't nuke", "can't fire missiles at"),
    (r"at sea", "in flight"),
    (r"sea route", "route through the void"),
    (r"no coast on that sea", "no edge on that part of the void"),
    (r"on a coast", "at the edge of the void"),
    (r"your coast", "your territory"), (r"that coast", "there"),
    (r"on that sea", "across that part of the void"),
    (r"sank", "shot down"),
    # weapons (Defs.NUKE_TITLES and their mentions)
    (r"atom bombs", "photon missiles"), (r"atom bomb", "photon missile"),
    (r"hydrogen bombs", "antimatter missiles"), (r"hydrogen bomb", "antimatter missile"),
    (r"MIRVs", "cluster missiles"), (r"MIRV", "cluster missile"),
    (r"mega nukes", "nova bombs"), (r"mega nuke", "nova bomb"),
    (r"scattershots", "meteor swarms"), (r"scattershot", "meteor swarm"),
    (r"artillery shells", "plasma bolts"), (r"artillery shell", "plasma bolt"),
    (r"air strikes", "fighter strikes"), (r"air strike", "fighter strike"),
    (r"railgun slugs", "mass driver rounds"), (r"railgun slug", "mass driver round"),
    (r"slugs", "rounds"), (r"slug", "round"),
    (r"shells", "plasma bolts"), (r"shell", "plasma bolt"),
    (r"nukes", "missiles"), (r"nuked", "struck"), (r"nuke", "missile"),
    (r"nuclear", "missile"),
    (r"fallout", "radiation"),
    # structures (Defs.STRUCT_TITLES and their mentions)
    (r"SAM launchers", "laser turrets"), (r"SAM launcher", "laser turret"),
    (r"SAMs", "laser turrets"), (r"SAM", "laser turret"),
    (r"defense posts", "shield generators"), (r"defense post", "shield generator"),
    (r"artillery batteries", "plasma cannons"), (r"artillery battery", "plasma cannon"),
    (r"artillery", "plasma cannon"),
    (r"airfields", "hangar bays"), (r"airfield", "hangar bay"),
    (r"railguns", "mass drivers"), (r"railgun", "mass driver"),
    (r"factories", "fabricators"), (r"factory", "fabricator"),
    (r"cities", "colonies"), (r"city", "colony"),
    (r"ports", "starports"), (r"port", "starport"),
    # units
    (r"trade ships", "cargo freighters"), (r"trade ship", "cargo freighter"),
    (r"warships", "battlecruisers"), (r"warship", "battlecruiser"),
    (r"transport ships", "rocketships"), (r"transport ship", "rocketship"),
    (r"transport boats", "rocketships"), (r"transport boat", "rocketship"),
    (r"transports", "rocketships"), (r"transport", "rocketship"),
    (r"boats", "rocketships"), (r"boat", "rocketship"),
    (r"sunk", "shot down"), (r"sinks", "shoots down"), (r"sink", "shoot down"),
    (r"naval", "fleet"),
    (r"railways", "hyperlanes"), (r"railway", "hyperlane"),
    (r"rails", "hyperlanes"), (r"rail", "hyperlane"),
    (r"trains", "shuttles"), (r"train", "shuttle"),
    # troops are aliens
    (r"troops", "aliens"), (r"troop", "alien"),
    # the map
    (r"oceans", "the void"), (r"the oceans", "the void"),
    (r"the ocean", "the void"), (r"the sea", "the void"), (r"by sea", "through the void"),
    (r"overseas", "across the void"), (r"over sea", "across the void"),
    (r"ocean", "void"), (r"sea", "void"),
    (r"coastline", "edge of the void"), (r"coastal", "void-side"), (r"coasts", "void edges"), (r"coast", "void edge"),
    (r"countries", "factions"), (r"country", "faction"),
    (r"nations", "factions"), (r"nation", "faction"),
    (r"the real world", "the universe"), (r"the world", "the universe"), (r"world", "universe"),
    (r"(?<!not )(?<!only )(?<!to )(?<!can )(?<!could )land(?! on)(?! in)(?! at)", "territory"),
]

STR = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
WORD_RULES = [(re.compile(r"\b" + p + r"\b", re.I), r) for p, r in RULES]


ITEMS = {
    "photon missile", "photon missiles", "antimatter missile", "antimatter missiles",
    "cluster missile", "cluster missiles", "nova bomb", "nova bombs", "meteor swarm",
    "meteor swarms", "plasma bolt", "plasma bolts", "fighter strike", "fighter strikes",
    "mass driver round", "mass driver rounds", "laser turret", "laser turrets",
    "shield generator", "shield generators", "plasma cannon", "plasma cannons", "hangar bay",
    "hangar bays", "mass driver", "mass drivers", "cargo freighter", "cargo freighters",
}
ACRONYMS = {"SAM", "SAMs", "MIRV", "MIRVs"}


def fix_case(src, rep):
    if src in ACRONYMS:
        return rep.title() if rep in ITEMS else rep[:1].upper() + rep[1:]
    if src.isupper() and len(src) > 1:
        return rep.upper()
    if src[:1].isupper():
        if rep in ITEMS:
            return " ".join(w[:1].upper() + w[1:] for w in rep.split(" "))
        return rep[:1].upper() + rep[1:]
    return rep


def retheme(s):
    # protect rich-text tags and format specifiers by not touching inside <...>
    parts = re.split(r"(<[^>]*>)", s)
    out = []
    for part in parts:
        if part.startswith("<"):
            out.append(part)
            continue
        # one pass over all rules at each position, so a replacement is never re-replaced
        def sub_all(text):
            i = 0
            res = []
            while i < len(text):
                best = None
                for rx, rep in WORD_RULES:
                    m = rx.match(text, i)
                    if m and (best is None or len(m.group(0)) > len(best[0].group(0))):
                        best = (m, rep)
                if best:
                    m, rep = best
                    # \b at the start: previous char must not be a word char
                    if i == 0 or not (text[i - 1].isalnum() or text[i - 1] == "_"):
                        res.append(fix_case(m.group(0), rep))
                        i = m.end()
                        continue
                res.append(text[i])
                i += 1
            return "".join(res)
        out.append(sub_all(part))
    s2 = "".join(out)
    # articles: "a alien" -> "an alien"
    s2 = re.sub(r"\b([Aa]) (alien|antimatter|orbital)", lambda m: m.group(1) + "n " + m.group(2), s2, flags=re.I)
    s2 = re.sub(r"\b(A|a)n (rocketship|battlecruiser|laser|starport|colony|shield|plasma|photon|cluster|nova|meteor|mass|fighter|hangar|cargo|missile|fabricator)",
                lambda m: m.group(1) + " " + m.group(2), s2, flags=re.I)
    s2 = re.sub(r"\b([Aa]) edge", lambda m: m.group(1) + "n edge", s2)
    return s2


def display(s):
    return " " in s or re.search(r"[A-Z]", s) is not None


def main():
    write = "--write" in sys.argv
    changed_lines = 0
    for dp, _, fn in os.walk(os.path.join(ROOT, "src")):
        rel_dir = os.path.relpath(dp, ROOT).replace(os.sep, "/")
        if rel_dir.startswith(SKIP_DIRS):
            continue
        for f in sorted(fn):
            if not f.endswith(".luau"):
                continue
            rel = f"{rel_dir}/{f}"
            if rel in SKIP:
                continue
            path = os.path.join(ROOT, rel)
            lines = open(path, encoding="utf-8").read().split("\n")
            dirty = False
            for i, line in enumerate(lines):
                stripped = line.lstrip()
                if stripped.startswith("--"):
                    continue
                code, sep, comment = line.partition(" --")
                # lobby keys and instance names, not text a player reads
                if (".HVN = " in code or "self:_fx(" in code or "self:_plate(" in code or "Humans Vs" in code
                        or ".Name = " in code or "set_map_name(" in code or "Wikimedia" in code
                        or "Crates aren't available" in code):
                    continue

                def repl(m):
                    s = m.group(1)
                    if not display(s) or s.startswith(("rbxasset", "[", ".")) or ("/" in s and " " not in s):
                        return m.group(0)
                    out = retheme(s)
                    # a shouted string stays shouted ("BEATS A LONE SAM")
                    if out != s and s not in ACRONYMS and re.sub(r"%[a-z]", "", s).isupper():
                        # upper-case the words only; format codes (%d, %s) keep their case
                        out = re.sub(r"(%[-+ #0-9.]*[a-zA-Z])|([^%]+)",
                                     lambda m: m.group(1) or m.group(2).upper(), out)
                    return '"' + out + '"'

                new_code = STR.sub(repl, code)
                if new_code != code:
                    new_line = new_code + sep + comment
                    print(f"{rel}:{i + 1}:\n  - {code.strip()}\n  + {new_code.strip()}")
                    lines[i] = new_line
                    dirty = True
                    changed_lines += 1
            if dirty and write:
                open(path, "w", encoding="utf-8").write("\n".join(lines))
    print(f"\n{changed_lines} lines {'changed' if write else 'would change'}")


if __name__ == "__main__":
    main()
