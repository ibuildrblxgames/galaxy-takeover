--!strict
-- Planet names on planet maps (map.meta.planets, tools/maps/make_space_maps.py): a faint, spaced-out
-- name across the top of each planet, sized with the planet on screen. They read best zoomed out
-- (the whole system) and fade away when a planet fills the screen, so they never fight the
-- factions' names. Moons and the sun get none.
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
		table.insert(self._items, {
			label = l,
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
	end
end

function PlanetLayer.destroy(self: any)
	self:unbind()
	self.root:Destroy()
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
	end
end

return PlanetLayer
