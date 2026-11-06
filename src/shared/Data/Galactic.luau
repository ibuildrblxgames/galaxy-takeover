--!strict
-- Galaxy Takeover's cosmetics that other players see (2026-11-06, the owner: the flag shop, the
-- crates and the Space Pass "aren't appealing ... better rewards, better options than flags"):
--
--   effects (kind "fx")      your weapons' colours: a nuke's explosion, its shockwave ring, its
--                            fire and smoke, and the trail of your missiles (Map/FxLayer, UnitLayer);
--   titles (kind "plate")    a glowing title over your faction's name on the map (Map/NameLayer);
--   skins (kind "skin")      legendary territory patterns, the shop's own.
--
-- Every item is a shop item (Data/Shop: key, item id "shop_<key>", one developer product each, the
-- Galactic Shop's daily rotation) unless `shop = false`; `crate = true` puts it in the crates as well
-- (Data/Cosmetics.all). `pass = true` items are the Space Pass's own (Data/BattlePass), neither sold
-- nor in a crate. One id each, however it's got: a second copy pays Stars back (server/Purchases).
--
-- Colours are 0xRRGGBB. An effect: `color` (the fire and the ring), `color2` (the flash and the
-- trail's head). A title: `text` (what shows on the map), `color` / `color2` (its gradient, top to
-- bottom), `glow` (its outline).
local Galactic = {}

type Entry = { [string]: any }

Galactic.EFFECTS = {
	{ key = "fx_plasma", name = "Plasma Blast", rarity = "rare", color = 0x38E1FF, color2 = 0xC8FAFF, crate = true },
	{ key = "fx_toxic", name = "Toxic Blast", rarity = "rare", color = 0x6CFF4A, color2 = 0xE2FFB0, crate = true },
	{ key = "fx_crimson", name = "Crimson Blast", rarity = "rare", color = 0xFF3B4E, color2 = 0xFFC0C6, crate = true },
	{ key = "fx_frost", name = "Frost Blast", rarity = "rare", color = 0x9FD8FF, color2 = 0xFFFFFF, crate = true },
	{ key = "fx_void", name = "Void Blast", rarity = "epic", color = 0x9B4DFF, color2 = 0xF0D8FF, crate = true },
	{ key = "fx_solar", name = "Solar Flare", rarity = "epic", color = 0xFFC83C, color2 = 0xFFFBE0, crate = true },
	{ key = "fx_nebula", name = "Nebula Burst", rarity = "epic", color = 0xFF5FD2, color2 = 0x9FE8FF, crate = true },
	{ key = "fx_blackhole", name = "Black Hole", rarity = "legendary", color = 0x5A1FB0, color2 = 0xFFFFFF, crate = true },
	{ key = "fx_supernova", name = "Supernova", rarity = "pass", color = 0xFFE27A, color2 = 0xFFFFFF, pass = true, shop = false },
}

Galactic.TITLES = {
	{ key = "title_commander", name = "Commander", text = "COMMANDER", rarity = "rare", color = 0xE6F4FF, color2 = 0x7FB8FF, glow = 0x10204A, crate = true },
	{ key = "title_raider", name = "Raider", text = "RAIDER", rarity = "rare", color = 0xFFE0D0, color2 = 0xFF7A4A, glow = 0x3A1208, crate = true },
	{ key = "title_pioneer", name = "Pioneer", text = "PIONEER", rarity = "rare", color = 0xE8FFE8, color2 = 0x5FE07A, glow = 0x0C2A14, crate = true },
	{ key = "title_warlord", name = "Warlord", text = "WARLORD", rarity = "epic", color = 0xFFD0D0, color2 = 0xE02A3C, glow = 0x2A0408, crate = true },
	{ key = "title_starlord", name = "Star Lord", text = "STAR LORD", rarity = "epic", color = 0xF4E8FF, color2 = 0xA35BFF, glow = 0x1E0838, crate = true },
	{ key = "title_conqueror", name = "Conqueror", text = "CONQUEROR", rarity = "epic", color = 0xFFF4D8, color2 = 0xFF9A2E, glow = 0x2E1604, crate = true },
	{ key = "title_emperor", name = "Emperor", text = "EMPEROR", rarity = "legendary", color = 0xFFFBE6, color2 = 0xFFB22E, glow = 0x3A2400, crate = true },
	{ key = "title_overlord", name = "Overlord", text = "OVERLORD", rarity = "legendary", color = 0xFFE8F4, color2 = 0xFF3B8E, glow = 0x2A0618, crate = true },
	{ key = "title_galaxyking", name = "Galaxy King", text = "GALAXY KING", rarity = "legendary", color = 0xFFFFFF, color2 = 0x38E1FF, glow = 0x061A30 },
	{ key = "title_supernova", name = "Supernova", text = "SUPERNOVA", rarity = "pass", color = 0xFFFFFF, color2 = 0xFFC83C, glow = 0x3A2000, pass = true, shop = false },
}

--- The shop's legendary territory skins (Data/Cosmetics' skin format: a mask tiled over your land,
--- '#' in the `accent` colour).
Galactic.SKINS = {
	{
		key = "skin_aurora",
		name = "Aurora",
		rarity = "legendary",
		scale = 0,
		accent = 0x5CFFC8,
		mask = { "#.......", ".#......", "..#.....", "...#....", "...#....", "..#.....", ".#......", "#......." },
	},
	{
		key = "skin_molten",
		name = "Molten Core",
		rarity = "legendary",
		scale = 0,
		accent = 0xFF6A1F,
		mask = { "..#..#..", ".#.##.#.", "#......#", ".#....#.", ".#....#.", "#......#", ".#.##.#.", "..#..#.." },
	},
	{
		key = "skin_royalnebula",
		name = "Royal Nebula",
		rarity = "legendary",
		scale = 0,
		accent = 0xC77DFF,
		mask = { "....#...", "...###..", "....#...", "........", "#.......", "........", "......#.", "........" },
	},
}

--- Developer products of the shop's items (tools: created on the Creator Dashboard, 2026-11-06).
Galactic.PRODUCTS = {
	fx_plasma = 3729030914,
	fx_toxic = 3729030918,
	fx_crimson = 3729030928,
	fx_frost = 3729030931,
	fx_void = 3729030935,
	fx_solar = 3729030942,
	fx_nebula = 3729030949,
	fx_blackhole = 3729030953,
	title_commander = 3729030960,
	title_raider = 3729030966,
	title_pioneer = 3729030975,
	title_warlord = 3729030983,
	title_starlord = 3729030990,
	title_conqueror = 3729030994,
	title_emperor = 3729030999,
	title_overlord = 3729031005,
	title_galaxyking = 3729031013,
	skin_aurora = 3729031016,
	skin_molten = 3729031024,
	skin_royalnebula = 3729031034,
} :: { [string]: number }

local all: { Entry } = {}
for _, e in Galactic.EFFECTS do
	local it = table.clone(e) :: Entry
	it.kind = "fx"
	table.insert(all, it)
end
for _, e in Galactic.TITLES do
	local it = table.clone(e) :: Entry
	it.kind = "plate"
	table.insert(all, it)
end
for _, e in Galactic.SKINS do
	local it = table.clone(e) :: Entry
	it.kind = "skin"
	table.insert(all, it)
end

--- Every item (effects, titles, skins), with `kind`.
function Galactic.all(): { Entry }
	return all
end

local by_key: { [string]: Entry } = {}
for _, it in all do
	by_key[it.key] = it
end
function Galactic.get(key: any): Entry?
	return if type(key) == "string" then by_key[key] else nil
end

--- A colour number as Color3.
function Galactic.color3(n: number): Color3
	return Color3.fromRGB(bit32.rshift(n, 16) % 256, bit32.rshift(n, 8) % 256, n % 256)
end

--- An effect's colours by its item (nil: the default look).
function Galactic.fx_colors(it: any): (Color3?, Color3?)
	if type(it) ~= "table" or it.kind ~= "fx" then
		return nil, nil
	end
	return Galactic.color3(it.color), Galactic.color3(it.color2 or it.color)
end

return Galactic
