--!nonstrict
-- The Space Pass window (Data/BattlePass) and its launcher on the title screen: a bright, chunky,
-- kid-friendly season track. Each tier has a free reward (top row) and a premium reward (bottom row,
-- gold, locked until premium is bought). Built from plain Roblox instances in its own ScreenGui.
--
--   BattlePassUI.new(session, audio?)   -- session: client/Session (inventory.bp, bp_claim, bp_result)
--   ui:set_screen(name)                 -- the launcher shows on the title screen only
--   ui:open() / ui:close()
--
-- Art: Google's Noto Emoji (Apache 2.0) embedded in the place (Assets/Embedded "bp/<name>"), the
-- Robux icon is Roblox's own texture. Buying premium prompts Products.battlepass (0 until the
-- product exists in Galaxy Takeover' experience: the button says it goes on sale then).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Airfront = RS:WaitForChild("Airfront")
local BattlePass = require(Airfront:WaitForChild("Data"):WaitForChild("BattlePass")) :: any
local Products = require(Airfront:WaitForChild("Data"):WaitForChild("Products")) :: any
local EmbeddedImage = require(script.Parent:WaitForChild("EmbeddedImage")) :: any
local Cosmetics = require(Airfront:WaitForChild("Data"):WaitForChild("Cosmetics")) :: any

local BattlePassUI = {}
BattlePassUI.__index = BattlePassUI

local FONT_ID = 12187365977 -- Rubik
local ROBUX = "rbxasset://textures/ui/common/robux@3x.png"
local function font(w: Enum.FontWeight)
	return Font.fromId(FONT_ID, w)
end
local HEAVY, BOLD, MED = font(Enum.FontWeight.Heavy), font(Enum.FontWeight.Bold), font(Enum.FontWeight.Medium)

local C = {
	ink = Color3.fromRGB(14, 10, 40),
	panel_top = Color3.fromRGB(70, 40, 170),
	panel_bottom = Color3.fromRGB(25, 18, 80),
	card = Color3.fromRGB(40, 30, 110),
	card_hi = Color3.fromRGB(70, 56, 170),
	cyan = Color3.fromRGB(56, 225, 255),
	green = Color3.fromRGB(70, 225, 120),
	green_lo = Color3.fromRGB(20, 150, 70),
	gold = Color3.fromRGB(255, 205, 60),
	gold_hi = Color3.fromRGB(255, 236, 140),
	gold_lo = Color3.fromRGB(230, 130, 20),
	pink = Color3.fromRGB(255, 90, 190),
	white = Color3.new(1, 1, 1),
	dim = Color3.fromRGB(150, 145, 200),
}

local COL_W = 132
local CARD_W, CARD_H = 116, 150

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local function corner(p: Instance, r: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 16) }, p)
end
local function stroke(p: Instance, col: Color3, th: number, tr: number?)
	return make("UIStroke", {
		Color = col,
		Thickness = th,
		Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, p)
end
local function vgrad(p: Instance, top: Color3, bottom: Color3)
	return make("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) }, p)
end
local function text(parent: Instance, props: { [string]: any }): TextLabel
	local t = make("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = C.white,
		FontFace = BOLD,
		TextSize = 18,
	}, parent)
	for k, v in pairs(props) do
		(t :: any)[k] = v
	end
	return t
end
local function emoji(parent: Instance, name: string, size: number, props: { [string]: any }?): ImageLabel
	local l = make("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		ScaleType = Enum.ScaleType.Fit,
	}, parent)
	for k, v in pairs(props or {}) do
		(l :: any)[k] = v
	end
	EmbeddedImage.apply(l, name, "")
	return l
end
--- A Space Pass cosmetic's own picture: a fleet skin's ships, an insignia, a territory skin's pattern.
local function item_art(parent: Instance, id: string, size: number, props: { [string]: any }): ImageLabel
	local it = Cosmetics.item(id)
	local l = make("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		ScaleType = Enum.ScaleType.Fit,
	}, parent)
	for k, v in pairs(props) do
		(l :: any)[k] = v
	end
	if it == nil then
		return l
	end
	if it.kind == "ship" then
		l.Size = UDim2.fromOffset(math.floor(size * 1.55), math.floor(size * 0.55))
		l.ResampleMode = Enum.ResamplerMode.Pixelated
		EmbeddedImage.apply(l, it.preview, "")
	elseif it.kind == "flag" then
		l.Size = UDim2.fromOffset(math.floor(size * 1.3), math.floor(size * 0.87))
		EmbeddedImage.apply(l, it.embedded or "", "")
		l.ImageRectOffset = Vector2.new(it.x, it.y)
		l.ImageRectSize = Vector2.new(it.w, it.h)
	else
		l.Size = UDim2.fromOffset(math.floor(size * 0.9), math.floor(size * 0.9))
		corner(l, 12)
		stroke(l, C.white, 2, 0.4)
		local ok, Locker = pcall(function()
			return require(script.Parent:WaitForChild("Locker")) :: any
		end)
		if ok and type(Locker) == "table" and Locker.show_item then
			pcall(Locker.show_item, l, it)
		end
	end
	return l
end

--- A chunky "candy" button: a bright face over a darker lip, text with a dark outline.
local function candy(parent: Instance, label: string, face: Color3, lip: Color3, size: UDim2): (TextButton, TextLabel)
	local b = make("TextButton", {
		Size = size,
		BackgroundColor3 = lip,
		AutoButtonColor = false,
		Text = "",
	}, parent)
	corner(b, 14)
	local f = make("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -5),
		BackgroundColor3 = C.white,
	}, b)
	corner(f, 14)
	vgrad(f, face:Lerp(C.white, 0.35), face)
	local t = text(f, {
		Size = UDim2.fromScale(1, 1),
		Text = label,
		FontFace = HEAVY,
		TextSize = 20,
		TextColor3 = C.white,
	})
	stroke(t, C.ink, 2.5, 0.2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { Size = size + UDim2.fromOffset(6, 4) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { Size = size }):Play()
	end)
	return b, t
end

--- "5 fleet skins, 5 territory skins, 6 insignia, crates and Stars!" from the premium track.
function BattlePassUI.premium_pitch(): string
	local n = { ship = 0, skin = 0, flag = 0 }
	for _, e in BattlePass.items("premium") do
		local it = Cosmetics.item(e.id)
		if it ~= nil and n[it.kind] ~= nil then
			n[it.kind] += 1
		end
	end
	return string.format("%d fleet skins, %d territory skins, %d insignia, crates and Stars!", n.ship, n.skin, n.flag)
end

-- =============================================================================================

function BattlePassUI.new(session: any, audio: any?)
	local self = setmetatable({}, BattlePassUI)
	self.session = session
	self.audio = audio
	self.columns = {}
	self.pending = {}
	self.open_ = false
	self.screen = "title"

	local gui = make("ScreenGui", {
		Name = "SpacePass",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 60,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	self.scale = make("UIScale", { Scale = 1 }, root)
	self.root = root

	self:_build_launcher()
	self:_build_window()

	local function rescale()
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		local s = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.5, 1.4)
		self.scale.Scale = s
		root.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	if session ~= nil then
		if session.inventory_changed then
			session.inventory_changed:Connect(function()
				self:refresh()
			end)
		end
		if session.bp_result then
			session.bp_result:Connect(function(tier, track, ok, reason)
				self:_on_result(tier, track, ok, reason)
			end)
		end
	end
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_uid, product_id, purchased)
		if purchased and product_id == (Products.battlepass and Products.battlepass.id) then
			self:_toast("Premium unlocked! Claim your rewards!", C.gold)
			self:_sfx("unlock")
		end
	end)
	-- a little life: the launcher's rocket bobs, the premium button shines
	local t0 = os.clock()
	RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if self.launch_rocket then
			self.launch_rocket.Position = UDim2.new(0, 34, 0.5, math.sin(t * 3) * 4)
			self.launch_rocket.Rotation = math.sin(t * 2) * 6
		end
		if self.shine then
			self.shine.Offset = Vector2.new(((t * 0.6) % 2) * 2 - 1.5, 0)
		end
		if self.open_ and self.claim_pulse then
			local k = 1 + math.sin(t * 6) * 0.04
			for _, sc in self.claim_pulse do
				sc.Scale = k
			end
		end
	end)
	self:refresh()
	return self
end

function BattlePassUI._sfx(self: any, name: string)
	if self.audio and self.audio.play_sfx then
		pcall(self.audio.play_sfx, self.audio, name)
	end
end

function BattlePassUI._bp(self: any): any
	local inv = self.session and self.session.inventory
	local bp = inv and inv.bp
	if type(bp) ~= "table" then
		return { xp = 0, premium = false, free = {}, prem = {} }
	end
	return bp
end

local function has(list: any, tier: number): boolean
	if type(list) ~= "table" then
		return false
	end
	for _, v in list do
		if tonumber(v) == tier then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------------------------------------
-- Launcher (title screen, left)
-- ---------------------------------------------------------------------------------------------

function BattlePassUI._build_launcher(self: any)
	local b = make("TextButton", {
		Name = "SpacePassButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 120),
		Size = UDim2.fromOffset(250, 84),
		BackgroundColor3 = C.panel_bottom,
		AutoButtonColor = false,
		Text = "",
	}, self.root)
	corner(b, 20)
	vgrad(b, C.pink, C.panel_top)
	stroke(b, C.gold, 3)
	self.launch_rocket = emoji(b, "bp/rocket", 56, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 34, 0.5, 0) })
	text(b, {
		Position = UDim2.fromOffset(70, 10),
		Size = UDim2.fromOffset(170, 26),
		Text = "SPACE PASS",
		FontFace = HEAVY,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	self.launch_sub = text(b, {
		Position = UDim2.fromOffset(70, 36),
		Size = UDim2.fromOffset(170, 18),
		Text = "Tier 0",
		FontFace = BOLD,
		TextSize = 15,
		TextColor3 = C.gold_hi,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local bar = make("Frame", {
		Position = UDim2.fromOffset(70, 60),
		Size = UDim2.fromOffset(164, 10),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.3,
	}, b)
	corner(bar, 5)
	self.launch_fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.cyan }, bar)
	corner(self.launch_fill, 5)
	-- a red dot when there's something to claim
	self.launch_dot = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Color3.fromRGB(255, 60, 70),
		Visible = false,
	}, b)
	corner(self.launch_dot, 11)
	stroke(self.launch_dot, C.white, 2)
	self.launch_dot_text = text(self.launch_dot, { Size = UDim2.fromScale(1, 1), Text = "!", FontFace = HEAVY, TextSize = 15 })
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { Size = UDim2.fromOffset(260, 88) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { Size = UDim2.fromOffset(250, 84) }):Play()
	end)
	b.Activated:Connect(function()
		self:_sfx("ui_open")
		self:open()
	end)
	self.launcher = b
end

-- ---------------------------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------------------------

function BattlePassUI._build_window(self: any)
	local dim = make("TextButton", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 10,
	}, self.root)
	dim.Activated:Connect(function()
		self:close()
	end)
	self.dim = dim
	local w = make("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1060, 600),
		BackgroundColor3 = C.white,
		Visible = false,
		ZIndex = 11,
	}, self.root)
	corner(w, 28)
	vgrad(w, C.panel_top, C.panel_bottom)
	stroke(w, C.cyan, 3, 0.2)
	self.window = w
	self.window_scale = make("UIScale", { Scale = 1 }, w)

	-- header
	emoji(w, "bp/rocket", 92, { Position = UDim2.fromOffset(22, 12), ZIndex = 12 })
	local title = text(w, {
		Position = UDim2.fromOffset(122, 18),
		Size = UDim2.fromOffset(420, 52),
		Text = "SPACE PASS",
		FontFace = HEAVY,
		TextSize = 50,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	})
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.white, C.gold) }, title)
	stroke(title, C.ink, 4, 0).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	text(w, {
		Position = UDim2.fromOffset(124, 70),
		Size = UDim2.fromOffset(420, 24),
		Text = BattlePass.NAME,
		FontFace = BOLD,
		TextSize = 20,
		TextColor3 = C.cyan,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	})
	-- level + XP
	self.tier_text = text(w, {
		Position = UDim2.fromOffset(124, 100),
		Size = UDim2.fromOffset(200, 26),
		Text = "TIER 0",
		FontFace = HEAVY,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	})
	local bar = make("Frame", {
		Position = UDim2.fromOffset(240, 106),
		Size = UDim2.fromOffset(300, 16),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.2,
		ZIndex = 12,
	}, w)
	corner(bar, 8)
	self.xp_fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.white, ZIndex = 13 }, bar)
	corner(self.xp_fill, 8)
	make("UIGradient", { Color = ColorSequence.new(C.cyan, C.green) }, self.xp_fill)
	self.xp_text = text(w, {
		Position = UDim2.fromOffset(548, 100),
		Size = UDim2.fromOffset(160, 26),
		Text = "0 / 100 XP",
		FontFace = BOLD,
		TextSize = 17,
		TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	})

	-- premium card (top right)
	local prem = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -70, 0, 16),
		Size = UDim2.fromOffset(330, 116),
		BackgroundColor3 = C.white,
		ZIndex = 12,
	}, w)
	corner(prem, 20)
	vgrad(prem, Color3.fromRGB(120, 60, 200), Color3.fromRGB(60, 30, 130))
	stroke(prem, C.gold, 3)
	emoji(prem, "bp/crown", 58, { Position = UDim2.fromOffset(10, 8), ZIndex = 13 })
	self.prem_title = text(prem, {
		Position = UDim2.fromOffset(74, 10),
		Size = UDim2.fromOffset(250, 24),
		Text = "GO PREMIUM!",
		FontFace = HEAVY,
		TextSize = 22,
		TextColor3 = C.gold_hi,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	})
	self.prem_sub = text(prem, {
		Position = UDim2.fromOffset(74, 34),
		Size = UDim2.fromOffset(250, 34),
		Text = "30 extra rewards: crates, Stars and the Crown!",
		FontFace = MED,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	})
	local buy, buy_t = candy(prem, "", C.gold, C.gold_lo, UDim2.fromOffset(300, 44))
	buy.Position = UDim2.fromOffset(15, 66)
	buy.ZIndex = 13
	buy_t.Text = ""
	local face = buy:FindFirstChild("Face") :: Frame
	face.ZIndex = 14
	buy_t.ZIndex = 15
	-- "UNLOCK  [robux] 299" laid out as a row
	local row = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 15 }, face)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	}, row)
	local lt = text(row, {
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		Text = "UNLOCK",
		FontFace = HEAVY,
		TextSize = 22,
		TextColor3 = C.ink,
		ZIndex = 15,
	})
	local _ = lt
	make("ImageLabel", {
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 24),
		Image = ROBUX,
		ImageColor3 = C.ink,
		ZIndex = 15,
	}, row)
	text(row, {
		LayoutOrder = 3,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		Text = tostring(BattlePass.PRICE),
		FontFace = HEAVY,
		TextSize = 24,
		TextColor3 = C.ink,
		ZIndex = 15,
	})
	-- a shine sweeping across the button
	local shine = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0,
		ZIndex = 16,
	}, face)
	corner(shine, 14)
	self.shine = make("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, shine)
	buy.Activated:Connect(function()
		self:_sfx("ui_click")
		self:_buy()
	end)
	self.buy = buy
	self.prem_card = prem

	-- close
	local x, _xt = candy(w, "X", Color3.fromRGB(255, 80, 100), Color3.fromRGB(160, 30, 50), UDim2.fromOffset(46, 46))
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, -12, 0, 12)
	x.ZIndex = 13
	for _, d in x:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 14
		end
	end
	x.Activated:Connect(function()
		self:_sfx("ui_back")
		self:close()
	end)

	-- track labels
	local function row_tag(y: number, label: string, col: Color3, icon: string)
		local f = make("Frame", {
			Position = UDim2.fromOffset(16, y),
			Size = UDim2.fromOffset(92, CARD_H),
			BackgroundColor3 = col,
			ZIndex = 12,
		}, w)
		corner(f, 18)
		emoji(f, icon, 48, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), ZIndex = 13 })
		local t = text(f, {
			Position = UDim2.fromOffset(0, 84),
			Size = UDim2.new(1, 0, 0, 40),
			Text = label,
			FontFace = HEAVY,
			TextSize = 18,
			TextWrapped = true,
			ZIndex = 13,
		})
		stroke(t, C.ink, 2, 0.3).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	end
	row_tag(176, "FREE", Color3.fromRGB(60, 130, 230), "bp/glowing-star")
	row_tag(176 + CARD_H + 26, "PREMIUM", Color3.fromRGB(230, 150, 30), "bp/crown")

	-- the scrolling track
	local track = make("ScrollingFrame", {
		Position = UDim2.fromOffset(118, 140),
		Size = UDim2.new(1, -134, 0, 420),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.fromOffset(COL_W * BattlePass.TIERS + 20, 0),
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = C.cyan,
		ZIndex = 12,
	}, w)
	self.track = track
	for tier = 1, BattlePass.TIERS do
		self.columns[tier] = self:_column(track, tier)
	end
	-- a toast line under the track
	self.toast = text(w, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(700, 26),
		Text = "",
		FontFace = HEAVY,
		TextSize = 20,
		TextTransparency = 1,
		ZIndex = 20,
	})
	stroke(self.toast, C.ink, 3, 1).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
end

function BattlePassUI._card(self: any, parent: Instance, tier: number, track: string, y: number): any
	local premium = track == "premium"
	local reward = BattlePass.reward(tier, track)
	local card = make("Frame", {
		Position = UDim2.fromOffset((COL_W - CARD_W) / 2, y),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundColor3 = C.white,
		ZIndex = 13,
	}, parent)
	corner(card, 18)
	if premium then
		vgrad(card, Color3.fromRGB(255, 200, 80), Color3.fromRGB(220, 110, 30))
	else
		vgrad(card, C.card_hi, C.card)
	end
	local st = stroke(card, if premium then C.gold_hi else C.cyan, 2.5, 0.25)
	local ic
	if reward.kind == "item" and reward.items then
		ic = item_art(card, reward.items[1], 62, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 50),
			ZIndex = 14,
		})
	else
		ic = emoji(card, reward.icon, if reward.big then 70 else 60, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 46),
			ZIndex = 14,
		})
	end
	if reward.tag then
		-- what it is, in a little pill on top: FLEET SKIN / TERRITORY / INSIGNIA / LEGENDARY
		local tag = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 5),
			Size = UDim2.fromOffset(CARD_W - 22, 17),
			BackgroundColor3 = if reward.tag == "LEGENDARY" then C.pink else C.ink,
			BackgroundTransparency = 0.15,
			ZIndex = 15,
		}, card)
		corner(tag, 9)
		text(tag, {
			Size = UDim2.fromScale(1, 1),
			Text = reward.tag,
			FontFace = HEAVY,
			TextSize = 11,
			TextColor3 = if premium then C.gold_hi else C.cyan,
			ZIndex = 16,
		})
	end
	local lab = text(card, {
		Position = UDim2.fromOffset(4, 82),
		Size = UDim2.new(1, -8, 0, 22),
		Text = reward.label,
		FontFace = HEAVY,
		TextSize = if #reward.label > 12 then 13 else 16,
		TextWrapped = true,
		ZIndex = 14,
	})
	stroke(lab, C.ink, 2, 0.25).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	-- the action: CLAIM / done / locked
	local btn, bt = candy(card, "CLAIM", C.green, C.green_lo, UDim2.fromOffset(CARD_W - 16, 34))
	btn.Position = UDim2.fromOffset(8, CARD_H - 40)
	btn.ZIndex = 14
	for _, d in btn:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 15
		end
	end
	bt.TextSize = 18
	local pulse = make("UIScale", { Scale = 1 }, btn)
	local state = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -23),
		Size = UDim2.fromOffset(32, 32),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 15,
	}, card)
	local lock = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 6, 30),
		BackgroundTransparency = 0.45,
		Visible = false,
		ZIndex = 16,
	}, card)
	corner(lock, 18)
	emoji(lock, "bp/locked", 44, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), ZIndex = 17 })
	btn.Activated:Connect(function()
		self:_claim(tier, track)
	end)
	return { card = card, btn = btn, bt = bt, state = state, lock = lock, icon = ic, stroke = st, pulse = pulse }
end

function BattlePassUI._column(self: any, track: Instance, tier: number): any
	local col = make("Frame", {
		Position = UDim2.fromOffset((tier - 1) * COL_W + 6, 0),
		Size = UDim2.fromOffset(COL_W, 400),
		BackgroundTransparency = 1,
		ZIndex = 12,
	}, track)
	local pill = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(78, 28),
		BackgroundColor3 = C.ink,
		ZIndex = 13,
	}, col)
	corner(pill, 14)
	local pt = text(pill, { Size = UDim2.fromScale(1, 1), Text = tostring(tier), FontFace = HEAVY, TextSize = 18, ZIndex = 14 })
	local art = BattlePass.TIER_ART[tier]
	if art then
		emoji(col, art, 30, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 30, 0, 18), ZIndex = 14 })
	end
	return {
		col = col,
		pill = pill,
		pill_text = pt,
		free = self:_card(col, tier, "free", 36),
		premium = self:_card(col, tier, "premium", 36 + CARD_H + 26),
	}
end

-- ---------------------------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------------------------

function BattlePassUI.refresh(self: any)
	local bp = self:_bp()
	local xp = tonumber(bp.xp) or 0
	local tier = BattlePass.tier_of(xp)
	local into = xp - tier * BattlePass.XP_PER_TIER
	local maxed = tier >= BattlePass.TIERS
	local frac = if maxed then 1 else math.clamp(into / BattlePass.XP_PER_TIER, 0, 1)
	self.tier_text.Text = "TIER " .. tostring(tier)
	self.xp_fill.Size = UDim2.fromScale(frac, 1)
	self.xp_text.Text = if maxed then "MAXED OUT!" else string.format("%d / %d XP", into, BattlePass.XP_PER_TIER)
	self.launch_sub.Text = string.format("Tier %d of %d", tier, BattlePass.TIERS)
	self.launch_fill.Size = UDim2.fromScale(if maxed then 1 else (tier + frac) / BattlePass.TIERS, 1)
	local premium = bp.premium == true
	self.prem_title.Text = if premium then "PREMIUM ACTIVE!" else "GO PREMIUM!"
	self.prem_sub.Text = if premium
		then "Every gold reward is yours to claim. Keep playing to climb!"
		else BattlePassUI.premium_pitch()
	self.buy.Visible = not premium
	local claimable = 0
	self.claim_pulse = {}
	for t, c in self.columns do
		local reached = t <= tier
		c.pill.BackgroundColor3 = if reached then C.cyan else C.ink
		c.pill_text.TextColor3 = if reached then C.ink else C.dim
		for _, track in { "free", "premium" } do
			local card = c[track]
			local claimed = has(if track == "premium" then bp.prem else bp.free, t)
			local locked_prem = track == "premium" and not premium
			local busy = self.pending[t .. track] == true
			card.lock.Visible = locked_prem
			card.btn.Visible = reached and not claimed and not locked_prem
			card.bt.Text = if busy then "..." else "CLAIM"
			card.state.Visible = claimed
			if claimed and not card.ticked then
				card.ticked = true
				EmbeddedImage.apply(card.state, "bp/check-mark-button", "")
			end
			if card.btn.Visible then
				claimable += 1
				table.insert(self.claim_pulse, card.pulse)
			end
		end
	end
	self.launch_dot.Visible = claimable > 0
	self.launch_dot_text.Text = if claimable > 9 then "9+" else tostring(claimable)
	self._tier = tier
end

function BattlePassUI._claim(self: any, tier: number, track: string)
	local key = tier .. track
	if self.pending[key] then
		return
	end
	local s = self.session
	if s == nil or not s:bp_claim(tier, track) then
		self:_toast("Can't reach the server right now. Try again in a moment.", C.pink)
		return
	end
	self.pending[key] = true
	self:_sfx("ui_confirm")
	self:refresh()
end

local REASONS = {
	["not reached"] = "Play more matches to reach that tier!",
	premium = "That one is a Premium reward. Unlock Premium to claim it!",
	claimed = "Already claimed!",
}

function BattlePassUI._on_result(self: any, tier: number, track: string, ok: boolean, reason: string?)
	self.pending[tier .. track] = nil
	if ok then
		local r = BattlePass.reward(tier, track)
		self:_toast(
			if r.items then "You got " .. r.label .. "! It's in your Locker." else "You got " .. r.label .. "!",
			C.gold_hi
		)
		self:_sfx("star_get")
		local c = self.columns[tier]
		local card = c and c[track]
		if card then
			local sc = make("UIScale", { Scale = 1.25 }, card.icon)
			TweenService:Create(sc, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			task.delay(0.5, function()
				sc:Destroy()
			end)
		end
	else
		local msg = (reason and REASONS[reason]) or "Couldn't claim that right now. Try again soon."
		self:_toast(msg, C.pink)
		self:_sfx("ui_error")
	end
	self:refresh()
end

function BattlePassUI._buy(self: any)
	local p = Products.battlepass
	if p == nil or (tonumber(p.id) or 0) <= 0 then
		self:_toast("Premium goes on sale when Galaxy Takeover launches!", C.gold_hi)
		return
	end
	pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, p.id)
	end)
end

function BattlePassUI._toast(self: any, msg: string, col: Color3)
	local t = self.toast
	t.Text = msg
	t.TextColor3 = col
	t.TextTransparency = 0
	local st = t:FindFirstChildOfClass("UIStroke")
	if st then
		st.Transparency = 0.2
	end
	self._toast_n = (self._toast_n or 0) + 1
	local n = self._toast_n
	task.delay(2.8, function()
		if self._toast_n == n then
			TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			if st then
				TweenService:Create(st, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
	end)
end

function BattlePassUI.open(self: any)
	self.open_ = true
	self:refresh()
	self.dim.Visible = true
	self.window.Visible = true
	self.window_scale.Scale = 0.85
	TweenService:Create(self.window_scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- start at the player's tier
	local tier = self._tier or 0
	local x = math.max(0, (tier - 2) * COL_W)
	self.track.CanvasPosition = Vector2.new(x, 0)
end

function BattlePassUI.close(self: any)
	self.open_ = false
	self.dim.Visible = false
	self.window.Visible = false
end

--- The launcher shows on the title screen only.
function BattlePassUI.set_screen(self: any, name: string)
	self.screen = name
	self.launcher.Visible = name == "title"
	if name ~= "title" and self.open_ then
		self:close()
	end
end

return BattlePassUI
