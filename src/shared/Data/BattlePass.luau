--!strict
-- The Space Pass (Galaxy Takeover' battle pass): a season of TIERS tiers climbed with XP from every
-- match. Each tier has a free reward and a premium reward; premium (PRICE Robux, Products
-- "battlepass") unlocks the premium track for the season, tiers already reached included.
--
-- Shared by the server (server/Purchases: XP, claims, the purchase) and the client
-- (UI/BattlePassUI). Rewards: Stars, cosmetic crates and Space Pass exclusives (Data/PassCosmetics:
-- fleet skins, territory skins, insignia).
local BattlePass = {}

BattlePass.SEASON = 1
BattlePass.NAME = "Season 1: First Contact"
BattlePass.PRICE = 299 -- Robux (Products.battlepass)
BattlePass.TIERS = 30
BattlePass.XP_PER_TIER = 100

--- XP for a match: a tenth of its Stars, at least MIN and at most MAX, so the season's
--- TIERS * XP_PER_TIER = 3,000 XP take about 20 matches played very well (MAX each), 30 average ones
--- (an average match pays about 1,000 Stars) and 50 short ones (MIN). (Owner, 2026-11-05: "around
--- 20-50 matches".)
BattlePass.MIN_MATCH_XP = 60
BattlePass.MAX_MATCH_XP = 150
BattlePass.XP_PER_STAR = 0.1
function BattlePass.xp_for_match(stars: number): number
	local xp = math.floor((tonumber(stars) or 0) * BattlePass.XP_PER_STAR)
	return math.clamp(xp, BattlePass.MIN_MATCH_XP, BattlePass.MAX_MATCH_XP)
end

--- The highest tier reached with `xp` (0 before tier 1).
function BattlePass.tier_of(xp: number): number
	return math.clamp(math.floor((tonumber(xp) or 0) / BattlePass.XP_PER_TIER), 0, BattlePass.TIERS)
end

--- A reward: kind "stars" / "crate" / "item" (one Space Pass cosmetic) / "set" (several).
--- `items` are Data/Cosmetics ids (owned for good, worn at once in an empty slot); `stars` extra Stars.
export type Reward = {
	kind: string,
	n: number,
	icon: string,
	label: string,
	big: boolean?,
	items: { string }?,
	stars: number?,
	tag: string?,
}

local function stars(n: number, big: boolean?): Reward
	return { kind = "stars", n = n, icon = if big then "bp/money-bag" else "bp/glowing-star", label = tostring(n) .. " Stars", big = big }
end
local function crates(n: number, big: boolean?): Reward
	return {
		kind = "crate",
		n = n,
		icon = if n > 1 then "bp/package" else "bp/wrapped-gift",
		label = if n > 1 then tostring(n) .. " Crates" else "Crate",
		big = big,
	}
end
--- What an item reward says it is (the card's little tag).
BattlePass.TAGS = { ship = "FLEET SKIN", skin = "TERRITORY", flag = "INSIGNIA" }
--- (names and kinds live in Data/PassCosmetics; the card asks Data/Cosmetics for them)
local NAMES = {
	ship_neon = { "Neon Fleet", "ship" },
	ship_biotech = { "Biotech Fleet", "ship" },
	ship_royal = { "Royal Armada", "ship" },
	ship_stealth = { "Void Stalkers", "ship" },
	ship_golden = { "Golden Armada", "ship" },
	skin_nebula = { "Nebula Drift", "skin" },
	skin_hyperspace = { "Hyperspace", "skin" },
	skin_hive = { "Alien Hive", "skin" },
	skin_circuit = { "Circuit Core", "skin" },
	skin_supernova = { "Supernova", "skin" },
	ins_alien = { "Little Green", "flag" },
	ins_comet = { "Comet Chaser", "flag" },
	ins_saucer = { "Saucer Squad", "flag" },
	ins_planet = { "Ringed World", "flag" },
	ins_rocket = { "Rocket Ace", "flag" },
	ins_raider = { "Pixel Raider", "flag" },
	ins_galaxy = { "Milky Way", "flag" },
	ins_crown = { "Galactic Crown", "flag" },
}
local function item(id: string, big: boolean?): Reward
	local nk = NAMES[id] or { id, "skin" }
	return { kind = "item", n = 1, icon = "", label = nk[1], big = big, items = { id }, tag = BattlePass.TAGS[nk[2]] }
end

--- The season's rewards by tier. Premium leads with a fleet skin at tier 1 (yours the moment you
--- unlock it), then a cosmetic every two or three tiers between crates and Stars, and ends with the
--- Supernova set. Free has its own insignia and a territory skin.
local PREMIUM: { [number]: () -> Reward } = {
	[1] = function() return item("ship_neon") end,
	[2] = function() return item("ins_saucer") end,
	[3] = function() return crates(1) end,
	[4] = function() return item("skin_nebula") end,
	[6] = function() return crates(1) end,
	[7] = function() return item("ins_planet") end,
	[9] = function() return crates(1) end,
	[10] = function() return item("ship_biotech", true) end,
	[12] = function() return item("skin_hyperspace") end,
	[13] = function() return crates(1) end,
	[14] = function() return item("ins_rocket") end,
	[15] = function()
		local r = crates(2, true)
		r.icon = "bp/trophy"
		return r
	end,
	[17] = function() return item("ship_royal") end,
	[18] = function() return crates(1) end,
	[19] = function() return item("ins_raider") end,
	[20] = function() return item("skin_hive", true) end,
	[21] = function() return crates(1) end,
	[22] = function() return item("ins_galaxy") end,
	[24] = function() return crates(1) end,
	[25] = function() return item("ship_stealth", true) end,
	[27] = function()
		local r = crates(2, true)
		r.icon = "bp/trophy"
		return r
	end,
	[28] = function() return item("ins_crown") end,
	[30] = function()
		return {
			kind = "set",
			n = 1,
			icon = "bp/crown",
			label = "Supernova Set + 2,500 Stars",
			big = true,
			items = { "skin_supernova", "ship_golden" },
			stars = 2500,
			tag = "LEGENDARY",
		}
	end,
}
local FREE: { [number]: () -> Reward } = {
	[3] = function() return item("ins_alien") end,
	[5] = function() return crates(1) end,
	[10] = function() return crates(1) end,
	[15] = function() return item("skin_circuit", true) end,
	[20] = function() return crates(1) end,
	[25] = function() return item("ins_comet") end,
	[30] = function() return crates(2, true) end,
}

--- The reward of tier `tier` (1..TIERS) on track "free" or "premium".
function BattlePass.reward(tier: number, track: string): Reward
	if track == "premium" then
		local f = PREMIUM[tier]
		if f then
			return f()
		end
		return stars(150 + 25 * tier, tier == 5 or tier == 16 or tier == 29)
	end
	local f = FREE[tier]
	if f then
		return f()
	end
	return stars(50 + 10 * tier)
end

--- Every cosmetic the season gives on `track`, in tier order (the window's preview strip).
function BattlePass.items(track: string): { { tier: number, id: string } }
	local out = {}
	for t = 1, BattlePass.TIERS do
		local r = BattlePass.reward(t, track)
		for _, id in r.items or {} do
			table.insert(out, { tier = t, id = id })
		end
	end
	return out
end

--- The art shown on a tier's badge (a little story through the season).
BattlePass.TIER_ART = {
	[1] = "bp/rocket",
	[5] = "bp/alien",
	[10] = "bp/flying-saucer",
	[15] = "bp/ringed-planet",
	[20] = "bp/comet",
	[25] = "bp/milky-way",
	[30] = "bp/crown",
}

return BattlePass
