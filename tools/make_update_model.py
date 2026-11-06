#!/usr/bin/env python3
"""Packs the built place's code into one model, for updating the published game from Studio.

Studio's "Publish As -> Overwrite" of a local .rbxlx onto Galaxy Takeover's place hangs at "Upload in
progress" (2026-11-05, three tries). This way works instead:

  1. python3 tools/build_place.py && python3 tools/make_update_model.py   (-> build/GT_Update.rbxmx)
  2. Studio: open the Galaxy Takeover cloud place (Bold Pixel Studios), File -> Import Roblox Model,
     pick GT_Update.rbxmx (it lands in Workspace).
  3. Run in the command bar (edit mode):
       local u=workspace.GT_Update local n=0 for _,p in {{'ReplicatedStorage',game.ReplicatedStorage},
       {'ReplicatedFirst',game.ReplicatedFirst},{'ServerScriptService',game.ServerScriptService},
       {'StarterPlayerScripts',game.StarterPlayer.StarterPlayerScripts}} do for _,c in u[p[1]]:GetChildren()
       do local old=p[2]:FindFirstChild(c.Name) if old then old:Destroy() end c.Parent=p[2] n+=1 end end
       u:Destroy() print('GT update applied: '..n)
  4. File -> Publish.

The place's code lives in four instances (ReplicatedStorage.Airfront, ReplicatedFirst's loading script,
ServerScriptService.AirfrontServer, StarterPlayerScripts.AirfrontClient); the model holds them in
folders named after their service. Lighting and the rest of the place don't change between builds.

Usage: python3 tools/make_update_model.py [--place build/GalacticWars.rbxlx] [--out build/GT_Update.rbxmx]
"""
import argparse
import copy
import os
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def folder(parent, name, ref):
    f = ET.SubElement(parent, "Item", {"class": "Folder", "referent": ref})
    props = ET.SubElement(f, "Properties")
    ET.SubElement(props, "string", {"name": "Name"}).text = name
    return f


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--place", default=os.path.join(ROOT, "build", "GalacticWars.rbxlx"))
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "GT_Update.rbxmx"))
    a = ap.parse_args()
    src = ET.parse(a.place).getroot()
    out = ET.Element("roblox", src.attrib)
    bundle = folder(out, "GT_Update", "RBXGTUPDATE")
    n = 0
    for it in src.findall("Item"):
        cls = it.get("class")
        if cls in ("ReplicatedStorage", "ReplicatedFirst", "ServerScriptService"):
            f = folder(bundle, cls, "RBXGT_" + cls)
            for c in it.findall("Item"):
                f.append(copy.deepcopy(c))
                n += 1
        elif cls == "StarterPlayer":
            f = folder(bundle, "StarterPlayerScripts", "RBXGT_SPS")
            for sps in it.findall("Item"):
                if sps.get("class") == "StarterPlayerScripts":
                    for c in sps.findall("Item"):
                        f.append(copy.deepcopy(c))
                        n += 1
    ET.ElementTree(out).write(a.out, encoding="utf-8", xml_declaration=False)
    print(f"wrote {a.out}: {n} instances, {os.path.getsize(a.out) // 1024} KB")


if __name__ == "__main__":
    main()
