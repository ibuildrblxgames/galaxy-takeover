--!strict
-- Player levels (2026-11-05, the owner: "players start on level 1 and earn xp and level up as they
-- play more in the game. Each 10 levels unlocks a crate, and wins can get you more xp").
--
-- Every match a player finishes pays XP (Levels.xp_for): a base for taking part, a little for each
-- minute played and each rival knocked out, more for a top-three place, and a large bonus for a
-- win. Multiplayer matches pay in full; solo matches against the AI pay a share by difficulty. Each
-- level needs a little more XP than the one before (Levels.need), and every 10th level reached
-- (10, 20, 30, ...) gives one crate (server/Purchases.add_match).
--
-- The same record keeps the player's stats for the lobby's leaderboard (UI/StatsUI): matches, wins
-- and win streaks count multiplayer matches only (a solo result is the client's word; wins there
-- would be easy to fake), solo wins are counted apart.
--
--   Levels.need(level) -> XP from `level` to the next
--   Levels.level_of(xp) -> level, xp into it, XP the level needs
--   Levels.xp_for(result, mode) -> { total, lines = { { key, amount } } }
--   Levels.crates_between(from_level, to_level) -> crates earned going from one to the other
local Levels = {}

Levels.MAX_LEVEL = 999
Levels.CRATE_EVERY = 10

--- XP from level 1 to 2; each level after needs STEP more, up to CAP.
Levels.FIRST = 100
Levels.STEP = 20
Levels.CAP = 600

--- XP for one finished match (multiplayer; solo is scaled by SOLO_MULT).
Levels.BASE = 40
Levels.PER_MINUTE = 6
Levels.MINUTES_CAP = 10
Levels.PER_KILL = 10
Levels.KILLS_CAP = 6
Levels.PLACE = { 30, 20, 10 } -- 1st, 2nd, 3rd (a winner gets the win bonus instead)
Levels.WIN = 200
--- A solo match against the AI pays this share of the above, by difficulty.
Levels.SOLO_MULT = { solo0 = 0.4, solo1 = 0.6, solo2 = 0.8 }
--- Leaving before the end keeps this share (nothing for a win: you can't win by leaving).
Levels.LEFT_MULT = 0.5

Levels.LABELS = {
	base = "Played",
	minutes = "Time",
	kills = "Knockouts",
	place = "Top 3",
	win = "Victory",
	solo = "Solo",
}

function Levels.need(level: number): number
	return math.min(Levels.FIRST + Levels.STEP * (math.max(1, math.floor(level)) - 1), Levels.CAP)
end

--- (level, xp into it, xp the level needs) for `xp` XP in total. Level 1 at 0 XP.
function Levels.level_of(xp: number): (number, number, number)
	local left = math.max(0, math.floor(tonumber(xp) or 0))
	local level = 1
	while level < Levels.MAX_LEVEL do
		local n = Levels.need(level)
		if left < n then
			return level, left, n
		end
		left -= n
		level += 1
	end
	return level, 0, Levels.need(level)
end

--- Total XP at the start of `level`.
function Levels.xp_at(level: number): number
	local t = 0
	for l = 1, math.clamp(math.floor(level), 1, Levels.MAX_LEVEL) - 1 do
		t += Levels.need(l)
	end
	return t
end

function Levels.crates_between(from_level: number, to_level: number): number
	if to_level <= from_level then
		return 0
	end
	return math.floor(to_level / Levels.CRATE_EVERY) - math.floor(from_level / Levels.CRATE_EVERY)
end

--- The next level that gives a crate, from `level`.
function Levels.next_crate_level(level: number): number
	return (math.floor(level / Levels.CRATE_EVERY) + 1) * Levels.CRATE_EVERY
end

local function num(x: any): number
	local n = tonumber(x) or 0
	return if n ~= n then 0 else n
end

--- XP for a match result (Data/Stars.Result) in `mode` ("public" | "solo0" | "solo1" | "solo2").
function Levels.xp_for(result: any, mode: string): { total: number, lines: { { any } } }
	local r = if type(result) == "table" then result else {}
	local lines = {}
	if r.spawned ~= true then
		return { total = 0, lines = lines }
	end
	local function add(key: string, n: number)
		n = math.floor(n + 0.5)
		if n > 0 then
			table.insert(lines, { key, n })
		end
	end
	add("base", Levels.BASE)
	add("minutes", math.min(num(r.minutes), Levels.MINUTES_CAP) * Levels.PER_MINUTE)
	add("kills", math.min(math.floor(num(r.kills)), Levels.KILLS_CAP) * Levels.PER_KILL)
	local won = r.won == true and r.left ~= true
	if won then
		add("win", Levels.WIN)
	else
		local place = math.floor(num(r.place))
		local bonus = Levels.PLACE[place]
		if bonus ~= nil and math.floor(num(r.field)) > place then
			add("place", bonus)
		end
	end
	local k = 1.0
	if mode ~= "public" then
		k *= Levels.SOLO_MULT[mode] or 0
	end
	if r.left == true and not won then
		k *= Levels.LEFT_MULT
	end
	local total = 0
	for _, l in lines do
		l[2] = math.floor(l[2] * k + 0.5)
		total += l[2]
	end
	return { total = total, lines = lines }
end

return Levels
