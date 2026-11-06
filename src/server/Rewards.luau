--!strict
-- Stars for a match (shared/Data/Stars; spent in the Arsenal, shared/Data/Arsenal).
--
-- A public match runs on this server: MatchServer follows it (Stars.Tracker) and its results are paid
-- as they are (Rewards.pay). A solo match runs on the player's own device, so its result is the
-- client's word (OP.SOLO_RESULT): it is typed and bounded (Stars.sanitize), can't be longer than the
-- match really lasted on this server's clock (counted from the client's "match_start" report), and
-- never pays more than Stars.solo_cap of that real time. So a made-up report earns no faster than a
-- good player, and nothing at all without the time passing.
--
--   Rewards.configure(deps)          { add_stars = fn(player, n) -> (ok, balance), double = fn(player)
--                                      -> boolean, general = fn(player) -> boolean, send = fn(player,
--                                      payload), now = fn() -> s, log? }
-- A RoWorld General (Data/Subscription) gets Subscription.STARS_BONUS of the match's Stars on top
-- (before 2x Stars doubles: the "general" line).
--   Rewards.solo_started(player, mode)   the client's match_start ("solo0" / "solo1" / "solo2")
--   Rewards.solo_result(player, report)  OP.SOLO_RESULT (yields)
--   Rewards.pay(player, result, mode)    a result this server measured itself (yields)
--   Rewards.release(player)              PlayerRemoving
-- The payload sent to the client (OP.STARS): { lines = { { key, amount } }, total, balance, mode }.
-- Every paid result also pays level XP and counts in the player's stats (Data/Levels): deps.add_match
-- (server/Purchases.add_match) -> what changed, handed to deps.match_done (the client's OP.LEVEL and
-- the leaderboards).
local IS_ROBLOX = typeof(game) == "Instance"
local Stars: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Stars)
	else require("../shared/Data/Stars")
local Subscription: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Subscription)
	else require("../shared/Data/Subscription")

local Rewards = {}

--- Results one solo match may be paid for: its end, and one more for each life a takeover gave it.
Rewards.MAX_SOLO_PAYOUTS = 4
--- Slack on the real time a solo result may claim (the report's trip, the clock's grain), minutes.
Rewards.SLACK_MIN = 0.25

type Solo = { mode: string, paid_at: number, payouts: number }

local deps: { [string]: any } = {}
local solo: { [any]: Solo } = {}

function Rewards.configure(d: { [string]: any })
	for k, v in d do
		deps[k] = v
	end
end

--- Tests: forget everyone.
function Rewards.reset()
	table.clear(solo)
end

local function now(): number
	return if deps.now then deps.now() else os.clock()
end

local function deliver(player: any, lines: { { any } }, total: number, mode: string): number
	if total <= 0 then
		return 0
	end
	local ok, balance = deps.add_stars(player, total)
	if not ok then
		return 0
	end
	-- the Space Pass climbs with every paid match (Data/BattlePass.xp_for_match)
	if deps.add_xp then
		task.spawn(pcall, deps.add_xp, player, total)
	end
	if deps.send then
		pcall(deps.send, player, { lines = lines, total = total, balance = balance, mode = mode })
	end
	if deps.log then
		deps.log(string.format("[Rewards] %s +%d Stars (%s)", tostring(player.UserId), total, mode))
	end
	return total
end

local function with_double(player: any, lines: { { any } }, total: number): ({ { any } }, number)
	local base = total
	if total > 0 and deps.double and deps.double(player) == true then
		table.insert(lines, { "double", total })
		total *= 2
	end
	if base > 0 and deps.general and deps.general(player) == true then
		local extra = Subscription.bonus(base, Stars.QUANTUM)
		if extra > 0 then
			table.insert(lines, { "general", extra })
			total += extra
		end
	end
	return lines, total
end

--- Level XP and stats for a result (Data/Levels), off the caller's thread.
local function count_match(player: any, result: any, mode: string)
	if not deps.add_match then
		return
	end
	task.spawn(function()
		local ok, got = pcall(deps.add_match, player, result, mode)
		if ok and got ~= nil and deps.match_done then
			pcall(deps.match_done, player, got, mode)
		end
	end)
end

--- A result this server measured itself (a public match). Returns the Stars paid.
function Rewards.pay(player: any, result: any, mode: string?): number
	local m = mode or "public"
	count_match(player, result, m)
	local p = Stars.payout(result, m, false)
	local lines, total = with_double(player, p.lines, p.total)
	return deliver(player, lines, total, m)
end

function Rewards.solo_started(player: any, mode: any)
	if type(mode) ~= "string" or Stars.MODE_MULT[mode] == nil or mode == "public" then
		solo[player] = nil
		return
	end
	solo[player] = { mode = mode, paid_at = now(), payouts = 0 }
end

--- The client's result of the solo match it reported starting. Returns the Stars paid.
function Rewards.solo_result(player: any, report: any): number
	local m = solo[player]
	if m == nil or m.payouts >= Rewards.MAX_SOLO_PAYOUTS then
		return 0
	end
	local t = now()
	local real = math.max(0, (t - m.paid_at) / 60)
	local r = Stars.sanitize(report, real + Rewards.SLACK_MIN)
	m.payouts += 1
	m.paid_at = t
	if r.left then
		solo[player] = nil -- the match is over for this player
	end
	count_match(player, r, m.mode)
	local p = Stars.payout(r, m.mode, false)
	local lines, total = p.lines, p.total
	local cap = Stars.solo_cap(real)
	if total > cap then
		-- more than that much real time can pay: every line shrinks alike
		local k = cap / total
		total = 0
		for _, line in lines do
			line[2] = math.floor(line[2] * k / Stars.QUANTUM) * Stars.QUANTUM
			total += line[2]
		end
	end
	lines, total = with_double(player, lines, total)
	return deliver(player, lines, total, m.mode)
end

function Rewards.release(player: any)
	solo[player] = nil
end

return Rewards
