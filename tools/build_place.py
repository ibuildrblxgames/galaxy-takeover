#!/usr/bin/env python3
"""Build a Roblox place file (.rbxlx) from a Rojo project file, without Rojo.

Usage:
  python3 tools/build_place.py [project.json] [-o build/GalacticWars.rbxlx]

Follows Rojo's sync rules for this project (all sources are Luau):
  dir/                      -> Folder (or a script, when it holds init*.luau)
  dir/init.luau             -> dir becomes a ModuleScript holding the rest of dir
  dir/init.server.luau      -> dir becomes a Script
  dir/init.client.luau      -> dir becomes a LocalScript
  name.server.luau          -> Script "name"
  name.client.luau          -> LocalScript "name"
  name.luau / name.lua      -> ModuleScript "name"
plus "$className", "$path", "$properties" and "globIgnorePaths" in the project file.
Rojo itself (`rojo build`) remains the reference; this exists so a place can be built where
Rojo isn't installed. Property values support the types this project uses (bool, number,
string, Color3 as [r, g, b], and enum names for a few known Enum properties).
"""
import fnmatch
import json
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Enum properties used by the project file -> {name: value}.
ENUMS = {
    "Technology": {"Legacy": 0, "Voxel": 1, "Compatibility": 2, "ShadowMap": 3, "Future": 4, "Unified": 5},
    "TonemapperPreset": {"Default": 0, "Retro": 1},
    "ScreenOrientation": {"LandscapeLeft": 0, "LandscapeRight": 1, "LandscapeSensor": 2,
                          "Portrait": 3, "Sensor": 4},
}

CLASS_BY_NAME = {"StarterPlayerScripts", "StarterCharacterScripts"}

SERVICES = {"ReplicatedStorage", "ServerScriptService", "StarterPlayer", "Players", "Lighting",
            "StarterGui", "Workspace", "ServerStorage", "ReplicatedFirst", "SoundService",
            "StarterPack", "Teams", "Chat", "TextChatService"}

_ref = [0]


def next_ref():
    _ref[0] += 1
    return "RBX%08X" % _ref[0]


def prop_xml(name, value):
    n = escape(name)
    if name in ENUMS:
        return f'<token name="{n}">{ENUMS[name][value]}</token>'
    if isinstance(value, bool):
        return f'<bool name="{n}">{"true" if value else "false"}</bool>'
    if isinstance(value, (int, float)):
        return f'<float name="{n}">{value}</float>'
    if isinstance(value, str):
        return f'<string name="{n}">{escape(value)}</string>'
    if isinstance(value, list) and len(value) == 3:
        r, g, b = value
        return f'<Color3 name="{n}"><R>{r}</R><G>{g}</G><B>{b}</B></Color3>'
    raise ValueError(f"unsupported property {name}={value!r}")


class Inst:
    def __init__(self, cls, name, props=None, source=None):
        self.cls, self.name = cls, name
        self.props = props or {}
        self.source = source
        self.children = []

    def xml(self, out, depth=1):
        pad = "\t" * depth
        out.append(f'{pad}<Item class="{self.cls}" referent="{next_ref()}">')
        out.append(f'{pad}\t<Properties>')
        out.append(f'{pad}\t\t<string name="Name">{escape(self.name)}</string>')
        for k, v in self.props.items():
            out.append(f"{pad}\t\t{prop_xml(k, v)}")
        if self.source is not None:
            src = self.source.replace("]]>", "]]]]><![CDATA[>")
            out.append(f'{pad}\t\t<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>')
        out.append(f'{pad}\t</Properties>')
        for c in self.children:
            c.xml(out, depth + 1)
        out.append(f"{pad}</Item>")


def script_kind(fname):
    """(class, instance name, is_init) for a Luau file name, or None if not a script."""
    for ext in (".luau", ".lua"):
        if fname.endswith(ext):
            stem = fname[: -len(ext)]
            break
    else:
        return None
    if stem.endswith(".server"):
        cls, stem = "Script", stem[:-7]
    elif stem.endswith(".client"):
        cls, stem = "LocalScript", stem[:-7]
    else:
        cls = "ModuleScript"
    return cls, stem, stem == "init"


def ignored(rel, globs):
    rel = rel.replace(os.sep, "/")
    return any(fnmatch.fnmatch(rel, g) or fnmatch.fnmatch(rel, g.replace("**/", "")) for g in globs)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def from_path(path, name, globs):
    """Instance for a file or directory on disk."""
    rel = os.path.relpath(path, ROOT)
    if os.path.isfile(path):
        kind = script_kind(os.path.basename(path))
        if not kind:
            raise ValueError(f"unsupported file {rel}")
        return Inst(kind[0], name, source=read(path))
    entries = sorted(os.listdir(path))
    init = None
    for e in entries:
        k = script_kind(e)
        if k and k[2]:
            init = (e, k[0])
    inst = Inst(init[1], name, source=read(os.path.join(path, init[0]))) if init else Inst("Folder", name)
    for e in entries:
        full = os.path.join(path, e)
        if ignored(os.path.relpath(full, ROOT), globs) or (init and e == init[0]):
            continue
        if os.path.isdir(full):
            inst.children.append(from_path(full, e, globs))
            continue
        k = script_kind(e)
        if k:
            inst.children.append(Inst(k[0], k[1], source=read(full)))
    return inst


def from_node(name, node, globs):
    if "$path" in node:
        inst = from_path(os.path.join(ROOT, node["$path"]), name, globs)
        if name in SERVICES:
            inst.cls = name
    else:
        inst = Inst(node.get("$className", name if name in SERVICES or name in CLASS_BY_NAME else "Folder"), name)
    inst.props.update(node.get("$properties", {}))
    for k, v in node.items():
        if not k.startswith("$"):
            inst.children.append(from_node(k, v, globs))
    return inst


def main():
    args = sys.argv[1:]
    out_path = os.path.join(ROOT, "build", "GalacticWars.rbxlx")
    if "-o" in args:
        i = args.index("-o")
        out_path = os.path.abspath(args[i + 1])
        del args[i:i + 2]
    project = os.path.join(ROOT, args[0] if args else "default.project.json")
    proj = json.loads(read(project))
    globs = proj.get("globIgnorePaths", [])
    tree = proj["tree"]
    out = ['<roblox version="4">']
    for name, node in tree.items():
        if not name.startswith("$"):
            from_node(name, node, globs).xml(out)
    out.append("</roblox>")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print(f"wrote {out_path} ({os.path.getsize(out_path) // 1024} KB, {_ref[0]} instances)")


if __name__ == "__main__":
    main()
