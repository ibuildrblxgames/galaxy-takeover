--!strict
-- Planet names on planet maps (map.meta.planets, tools/maps/make_space_maps.py): a faint, spaced-out
-- name across the top of each planet, sized with the planet on screen. They read best zoomed out
-- (the whole system) and fade away when a planet fills the screen, so they never fight the
-- factions' names. Moons and the sun get none.
-- Under each name, the faction that holds most of the planet, in its own colour (2026-11-06, the owner:
-- a faction's planets are hard to pick out across the system; "maybe the name of the player hovers over
-- the planet"): OWNED_SHARE of the planet's tiles, counted on a grid every RECOUNT_S.
local RS = game:GetService("ReplicatedStorage")
local FONT_ID = 12187365977 -- Rubik (UITheme.FONT_ID)

local PlanetLayer = {}
PlanetLayer.__index = PlanetLayer

PlanetLayer.Z = 2
PlanetLayer.ALPHA = 0.55 -- text transparency at its strongest (faint)
PlanetLayer.MIN_PX = 9 -- smaller text is not drawn
PlanetLayer.MAX_PX = 34
PlanetLayer.FADE_FROM_PX = 520 -- a planet this wide on screen starts fading its name out...
PlanetLayer.FADE_TO_PX = 900 -- ...and has none by this width
PlanetLayer.OWNED_SHARE = 0.4 -- a faction with this share of a planet's tiles is named under it
PlanetLayer.RECOUNT_S = 1.0
PlanetLayer.SAMPLES = 24 -- grid cells across a planet's diameter (about 450 inside the circle)
PlanetLayer.OWNER_MIN_PX = 11

local _ = RS

function PlanetLayer.new(parent: Instance, view: any)
	local self = setmetatable({}, PlanetLayer) :: any
	local root = Instance.new("Frame")
	root.Name = "Planets"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = PlanetLayer.Z
	root.Parent = parent
	self.root = root
	self.view = view
	self._items = {} :: { any }
	self._map = nil :: any
	return self
end

local function spaced(name: string): string
	-- "Velgard" -> "V E L G A R D" (wide tracking, Roblox has no letter spacing)
	local up = string.upper(name)
	local out = {}
	for _, cp in utf8.codes(up) do
		table.insert(out, utf8.char(cp))
	end
	return table.concat(out, " ")
end

function PlanetLayer._build(self: any, map: any)
	for _, it in self._items do
		it.label:Destroy()
		it.owner_label:Destroy()
	end
	table.clear(self._items)
	self._map = map
	local meta = map and map.meta
	local planets = if type(meta) == "table" then meta.planets else nil
	if type(planets) ~= "table" then
		return
	end
	local s = tonumber(map.scale) or 1
	for _, p in planets do
		if p.biome == "star" or p.biome == "moon" then
			continue
		end
		local l = Instance.new("TextLabel")
		l.Name = tostring(p.name)
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Size = UDim2.fromOffset(600, 60)
		l.Text = spaced(tostring(p.name))
		l.FontFace = Font.fromId(FONT_ID, Enum.FontWeight.Bold)
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextTransparency = 1
		l.TextStrokeTransparency = 1
		l.ZIndex = PlanetLayer.Z
		l.Visible = false
		l.Parent = self.root
		local ol = Instance.new("TextLabel")
		ol.Name = tostring(p.name) .. "_owner"
		ol.BackgroundTransparency = 1
		ol.AnchorPoint = Vector2.new(0.5, 0)
		ol.Size = UDim2.fromOffset(600, 40)
		ol.Text = ""
		ol.FontFace = Font.fromId(FONT_ID, Enum.FontWeight.Heavy)
		ol.TextColor3 = Color3.new(1, 1, 1)
		ol.TextStrokeColor3 = Color3.fromRGB(8, 10, 24)
		ol.TextStrokeTransparency = 0.2
		ol.ZIndex = PlanetLayer.Z
		ol.Visible = false
		ol.Parent = self.root
		table.insert(self._items, {
			label = l,
			owner_label = ol,
			owner = 0,
			cx = p.x * s,
			cy = p.y * s,
			x = p.x * s,
			y = (p.y - p.r * 0.62) * s,
			r = p.r * s,
			px = -1,
		})
	end
end

function PlanetLayer.bind(self: any, state: any)
	self._state = state
	local map = state and state.map
	if map ~= self._map then
		self:_build(map)
	end
end

function PlanetLayer.unbind(self: any)
	self._state = nil
	for _, it in self._items do
		it.label.Visible = false
		it.owner_label.Visible = false
		it.owner = 0
	end
end

--- Which faction holds OWNED_SHARE of each planet (0: none), on a grid over the planet's disc.
function PlanetLayer._recount(self: any, state: any)
	local own = state.owner
	local map = state.map
	if own == nil or map == nil then
		return
	end
	local W, H = tonumber(map.W) or 0, tonumber(map.H) or 0
	if W <= 0 or H <= 0 then
		return
	end
	local n = PlanetLayer.SAMPLES
	for _, it in self._items do
		local counts = {}
		local total = 0
		local step = it.r * 2 / n
		for gy = 0, n - 1 do
			local y = it.cy - it.r + (gy + 0.5) * step
			for gx = 0, n - 1 do
				local x = it.cx - it.r + (gx + 0.5) * step
				local dx, dy = x - it.cx, y - it.cy
				if dx * dx + dy * dy <= it.r * it.r * 0.81 and x >= 0 and y >= 0 and x < W and y < H then
					total += 1
					local o = buffer.readi32(own, (math.floor(y) * W + math.floor(x)) * 4)
					if o > 0 then
						counts[o] = (counts[o] or 0) + 1
					end
				end
			end
		end
		local best, best_n = 0, 0
		for o, c in counts do
			if c > best_n then
				best, best_n = o, c
			end
		end
		if total == 0 or best_n < total * PlanetLayer.OWNED_SHARE then
			best = 0
		end
		if best ~= it.owner then
			it.owner = best
			local l = it.owner_label
			if best > 0 then
				local ok_n, name = pcall(state.owner_name, state, best)
				local ok_c, col = pcall(state.owner_color, state, best)
				l.Text = if ok_n and type(name) == "string" then name else ""
				if ok_c and typeof(col) == "Color3" then
					-- lifted a little so dark colours read on space
					local h, sat, v = col:ToHSV()
					l.TextColor3 = Color3.fromHSV(h, math.min(sat, 0.85), math.max(v, 0.85))
				end
			else
				l.Text = ""
			end
		end
	end
end

function PlanetLayer.destroy(self: any)
	self:unbind()
	self.root:Destroy()
end

--- The owner's own name plate (Map/NameLayer, on its biggest cluster) sits on this planet already.
function PlanetLayer._named_here(self: any, it: any): boolean
	local layers = self.view and self.view.layers
	local names = layers and layers.labels
	local t = names and names._targets and names._targets[it.owner]
	if type(t) ~= "table" or type(t[1]) ~= "number" or type(t[2]) ~= "number" then
		return false
	end
	local dx, dy = t[1] - it.cx, t[2] - it.cy
	return dx * dx + dy * dy <= it.r * it.r
end

function PlanetLayer.tick(self: any, _dt: number)
	local state = self._state
	if state == nil then
		return
	end
	if state.map ~= self._map then
		self:_build(state.map)
	end
	local cam = self.view.rig
	if cam == nil then
		return
	end
	local now = os.clock()
	if now >= (self._next_count or 0) then
		self._next_count = now + PlanetLayer.RECOUNT_S
		self:_recount(state)
	end
	local scale = cam.scale
	for _, it in self._items do
		local l = it.label
		local width = it.r * 2 * scale
		local px = math.clamp(math.floor(width * 0.075 + 0.5), 0, PlanetLayer.MAX_PX)
		local fade = math.clamp(
			(width - PlanetLayer.FADE_FROM_PX) / (PlanetLayer.FADE_TO_PX - PlanetLayer.FADE_FROM_PX),
			0,
			1
		)
		local x, y = cam:map_to_screen(it.x, it.y)
		local show = px >= PlanetLayer.MIN_PX and fade < 1 and cam:on_screen(x, y, 300)
		if show ~= l.Visible then
			l.Visible = show
		end
		if show then
			if px ~= it.px then
				it.px = px
				l.TextSize = px
			end
			l.TextTransparency = PlanetLayer.ALPHA + (1 - PlanetLayer.ALPHA) * fade
			l.Position = UDim2.fromOffset(x, y)
		end
		local ol = it.owner_label
		local show_owner = show and it.owner > 0 and ol.Text ~= "" and not self:_named_here(it)
		if show_owner ~= ol.Visible then
			ol.Visible = show_owner
		end
		if show_owner then
			local opx = math.max(PlanetLayer.OWNER_MIN_PX, math.floor(px * 0.85 + 0.5))
			if ol.TextSize ~= opx then
				ol.TextSize = opx
			end
			ol.TextTransparency = 0.05 + 0.95 * fade
			ol.TextStrokeTransparency = 0.2 + 0.8 * fade
			ol.Position = UDim2.fromOffset(x, y + px * 0.75)
		end
	end
end

return PlanetLayer
