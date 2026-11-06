--!strict
-- The lobby's leaderboards (UI/StatsUI; 2026-11-05, the owner: "a leaderboard button where players
-- can click and show players on winstreaks and basic stats"). Four boards, each an OrderedDataStore
-- shared by every server of the experience:
--   streak   multiplayer wins in a row now (a loss puts it back to 0)
--   best     the longest win streak ever
--   wins     multiplayer wins
--   level    total level XP (shown as the level)
-- A player's entries are written when a match changes them (Leaderboards.record, from
-- server/Rewards' match_done). The top of each board is read at most every REFRESH_S per server and
-- kept, with the players' names, for every client that asks (OP.LEADERBOARD).
--
--   Leaderboards.configure(deps)   { stores = { [board] = OrderedDataStore }?, names = fn({ id }) ->
--                                    { [id] = { name, display } }?, now = fn() -> s, log? }
--   Leaderboards.record(player, stats)   stats: Data/Levels' record (Purchases.add_match's `stats`)
--   Leaderboards.top() -> { boards = { [board] = { { id, name, display, value } } }, at } (yields)
local Leaderboards = {}

Leaderboards.BOARDS = { "streak", "best", "wins", "level" }
Leaderboards.STORE_PREFIX = "lb_"
Leaderboards.STORE_VERSION = "_v1"
Leaderboards.SIZE = 50
Leaderboards.REFRESH_S = 60

local deps: { [string]: any } = {}
local cache: any = nil
local refreshing = false
local names: { [number]: { name: string, display: string } } = {}
--- what was last written for each player and board (no write when it didn't change)
local written: { [number]: { [string]: number } } = {}

function Leaderboards.configure(d: { [string]: any })
	for k, v in d do
		deps[k] = v
	end
end

local function now(): number
	return if deps.now then deps.now() else os.clock()
end

local function log(text: string)
	if deps.log then
		deps.log("[Leaderboards] " .. text)
	end
end

local function store(board: string): any
	if deps.stores then
		return deps.stores[board]
	end
	local ok, s = pcall(function()
		return game:GetService("DataStoreService")
			:GetOrderedDataStore(Leaderboards.STORE_PREFIX .. board .. Leaderboards.STORE_VERSION)
	end)
	if ok then
		deps.stores = deps.stores or {}
		deps.stores[board] = s
		return s
	end
	return nil
end

--- The value a player's stats put on `board`.
function Leaderboards.value(board: string, stats: any): number
	local v = tonumber(if type(stats) == "table" then stats[if board == "level" then "xp" else board] else 0) or 0
	return if v ~= v then 0 else math.max(0, math.floor(v))
end

function Leaderboards.record(player: any, stats: any)
	local uid = player.UserId
	if type(uid) ~= "number" or uid <= 0 then
		return -- (Studio's test players have negative ids)
	end
	local last = written[uid] or {}
	written[uid] = last
	for _, board in Leaderboards.BOARDS do
		local v = Leaderboards.value(board, stats)
		if last[board] ~= v then
			local s = store(board)
			if s ~= nil then
				local ok, err = pcall(function()
					s:SetAsync(tostring(uid), v)
				end)
				if ok then
					last[board] = v
				else
					log(string.format("%s for %d not written: %s", board, uid, tostring(err)))
				end
			end
		end
	end
	-- the player's own row shows at once on this server
	if cache ~= nil then
		for _, board in Leaderboards.BOARDS do
			for _, row in cache.boards[board] or {} do
				if row.id == uid then
					row.value = Leaderboards.value(board, stats)
				end
			end
		end
	end
end

function Leaderboards.forget(player: any)
	written[player.UserId] = nil
end

local function resolve_names(ids: { number })
	local want = {}
	for _, id in ids do
		if names[id] == nil then
			table.insert(want, id)
		end
	end
	if #want == 0 then
		return
	end
	if deps.names then
		local ok, got = pcall(deps.names, want)
		if ok and type(got) == "table" then
			for id, n in got do
				names[id] = n
			end
		end
		return
	end
	-- UserService takes up to 200 ids a call
	for i = 1, #want, 100 do
		local chunk = table.move(want, i, math.min(i + 99, #want), 1, {})
		local ok, infos = pcall(function()
			return game:GetService("UserService"):GetUserInfosByUserIdsAsync(chunk)
		end)
		if ok and type(infos) == "table" then
			for _, info in infos do
				names[info.Id] = { name = info.Username, display = info.DisplayName }
			end
		end
	end
end

local function refresh()
	local boards = {}
	local ids = {}
	local seen = {}
	for _, board in Leaderboards.BOARDS do
		local rows = {}
		local s = store(board)
		if s ~= nil then
			local ok, pages = pcall(function()
				return s:GetSortedAsync(false, Leaderboards.SIZE, 1)
			end)
			if ok and pages ~= nil then
				local ok2, page = pcall(function()
					return pages:GetCurrentPage()
				end)
				if ok2 and type(page) == "table" then
					for _, e in page do
						local id = tonumber(e.key)
						if id ~= nil then
							table.insert(rows, { id = id, value = tonumber(e.value) or 0 })
							if not seen[id] then
								seen[id] = true
								table.insert(ids, id)
							end
						end
					end
				end
			elseif not ok then
				log(board .. " not read: " .. tostring(pages))
			end
		end
		boards[board] = rows
	end
	resolve_names(ids)
	for _, rows in boards do
		for _, row in rows do
			local n = names[row.id]
			row.name = if n then n.name else ("Player " .. tostring(row.id))
			row.display = if n then n.display else row.name
		end
	end
	cache = { boards = boards, at = now() }
end

--- The boards (read again when older than REFRESH_S; one read at a time). Yields.
function Leaderboards.top(): any
	if cache == nil or now() - cache.at >= Leaderboards.REFRESH_S then
		if refreshing then
			local t0 = os.clock()
			while refreshing and os.clock() - t0 < 10 do
				task.wait(0.1)
			end
		else
			refreshing = true
			local ok, err = pcall(refresh)
			refreshing = false
			if not ok then
				log("refresh failed: " .. tostring(err))
			end
		end
	end
	return cache or { boards = {}, at = now() }
end

--- Tests: forget everything.
function Leaderboards.reset()
	cache = nil
	refreshing = false
	table.clear(names)
	table.clear(written)
end

return Leaderboards
