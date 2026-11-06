--!nonstrict
-- The lobby's level card and leaderboard (2026-11-05, the owner: "a leaderboard button where players
-- can click and show players on winstreaks and basic stats" and "a level system ... each 10 levels
-- unlocks a crate, and wins can get you more xp"). Built from plain Roblox instances in its own
-- ScreenGui, beside the Space Pass launcher (UI/BattlePassUI) on the title screen:
--   * the level card: the player's level, XP to the next and the next crate level;
--   * the LEADERBOARD button: a window with the player's stats (level, wins, matches, win rate, win
--     streak, best streak, knockouts, solo wins) and the game-wide boards (server/Leaderboards):
--     win streaks now, best streaks, wins, levels;
--   * after every match: the XP it paid, and LEVEL UP (with the crate every 10th level gives).
--
--   StatsUI.new(session, audio?)   -- session: client/Session (inventory.lvl, request_leaderboard,
--                                     leaderboard, level_gained)
--   ui:set_screen(name) / ui:open() / ui:close()
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Airfront = RS:WaitForChild("Airfront")
local Levels = require(Airfront:WaitForChild("Data"):WaitForChild("Levels")) :: any
local EmbeddedImage = require(script.Parent:WaitForChild("EmbeddedImage")) :: any

local StatsUI = {}
StatsUI.__index = StatsUI

local FONT_ID = 12187365977 -- Rubik
local function font(w: Enum.FontWeight)
	return Font.fromId(FONT_ID, w)
end
local HEAVY, BOLD, MED = font(Enum.FontWeight.Heavy), font(Enum.FontWeight.Bold), font(Enum.FontWeight.Medium)

local C = {
	ink = Color3.fromRGB(14, 10, 40),
	panel_top = Color3.fromRGB(40, 36, 110),
	panel_bottom = Color3.fromRGB(16, 14, 50),
	card = Color3.fromRGB(34, 30, 92),
	card_hi = Color3.fromRGB(58, 50, 140),
	row = Color3.fromRGB(28, 25, 78),
	me = Color3.fromRGB(70, 56, 20),
	cyan = Color3.fromRGB(56, 225, 255),
	green = Color3.fromRGB(70, 225, 120),
	gold = Color3.fromRGB(255, 205, 60),
	gold_hi = Color3.fromRGB(255, 236, 140),
	orange = Color3.fromRGB(255, 140, 50),
	white = Color3.new(1, 1, 1),
	dim = Color3.fromRGB(160, 155, 210),
}

--- The boards' tabs: (board, label, emoji, how a value reads)
local TABS = {
	{ "streak", "WIN STREAKS", "bp/fire", "streak" },
	{ "best", "BEST STREAK", "bp/military-medal", "streak" },
	{ "wins", "WINS", "bp/trophy", "wins" },
	{ "level", "LEVEL", "bp/glowing-star", "level" },
}
local MEDALS = { "bp/1st-place-medal", "bp/2nd-place-medal", "bp/3rd-place-medal" }

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
	return make("UICorner", { CornerRadius = UDim.new(0, r or 14) }, p)
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
	pcall(EmbeddedImage.apply, l, name, "")
	return l
end
local function headshot(uid: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", uid)
end
local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function StatsUI.new(session: any, audio: any?)
	local self = setmetatable({}, StatsUI)
	self.session = session
	self.audio = audio
	self.open_ = false
	self.screen = "title"
	self.tab = "streak"
	self.data = nil

	local gui = make("ScreenGui", {
		Name = "Stats",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 61,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	self.scale = make("UIScale", { Scale = 1 }, root)
	self.root = root

	self:_build_launchers()
	self:_build_window()
	self:_build_toast()

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
		if session.leaderboard then
			session.leaderboard:Connect(function(data)
				self.data = data
				self:_fill_board()
			end)
		end
		if session.level_gained then
			session.level_gained:Connect(function(g)
				self:_on_level(g)
			end)
		end
	end
	self:refresh()
	return self
end

function StatsUI._sfx(self: any, name: string)
	if self.audio and self.audio.play_sfx then
		pcall(self.audio.play_sfx, self.audio, name)
	end
end

--- The player's level and stats (server/Purchases.level_state), or a level-1 player's.
function StatsUI._lvl(self: any): any
	local inv = self.session and self.session.inventory
	local l = inv and inv.lvl
	if type(l) ~= "table" then
		local level, into, need = Levels.level_of(0)
		return {
			xp = 0, level = level, into = into, need = need, matches = 0, wins = 0, streak = 0, best = 0,
			kills = 0, solo = 0, solo_wins = 0,
		}
	end
	return l
end

-- ---------------------------------------------------------------------------------------------
-- Launchers (title screen, left, under the Space Pass)
-- ---------------------------------------------------------------------------------------------

local LAUNCH_W = 250

function StatsUI._build_launchers(self: any)
	-- the level card: the badge, the bar, the next crate
	local card = make("TextButton", {
		Name = "LevelCard",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 200),
		Size = UDim2.fromOffset(LAUNCH_W, 62),
		BackgroundColor3 = C.white,
		AutoButtonColor = false,
		Text = "",
	}, self.root)
	corner(card, 18)
	vgrad(card, C.panel_top, C.panel_bottom)
	stroke(card, C.cyan, 2, 0.35)
	local badge = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = C.white,
	}, card)
	corner(badge, 24)
	vgrad(badge, C.gold_hi, C.orange)
	stroke(badge, C.ink, 3)
	self.badge_text = text(badge, {
		Size = UDim2.fromScale(1, 1),
		Text = "1",
		FontFace = HEAVY,
		TextSize = 22,
		TextColor3 = C.ink,
	})
	self.card_title = text(card, {
		Position = UDim2.fromOffset(66, 7),
		Size = UDim2.fromOffset(120, 20),
		Text = "LEVEL 1",
		FontFace = HEAVY,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	self.card_xp = text(card, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 9),
		Size = UDim2.fromOffset(110, 16),
		Text = "0 / 100 XP",
		FontFace = MED,
		TextSize = 13,
		TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local bar = make("Frame", {
		Position = UDim2.fromOffset(66, 31),
		Size = UDim2.new(1, -78, 0, 9),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.2,
	}, card)
	corner(bar, 5)
	self.card_fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.white }, bar)
	corner(self.card_fill, 5)
	make("UIGradient", { Color = ColorSequence.new(C.cyan, C.green) }, self.card_fill)
	self.card_crate = text(card, {
		Position = UDim2.fromOffset(66, 42),
		Size = UDim2.new(1, -78, 0, 15),
		Text = "Crate at level 10",
		FontFace = MED,
		TextSize = 12,
		TextColor3 = C.gold_hi,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	card.Activated:Connect(function()
		self:_sfx("ui_open")
		self:open()
	end)
	self.level_card = card

	-- the leaderboard button
	local b = make("TextButton", {
		Name = "LeaderboardButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 270),
		Size = UDim2.fromOffset(LAUNCH_W, 62),
		BackgroundColor3 = C.white,
		AutoButtonColor = false,
		Text = "",
	}, self.root)
	corner(b, 18)
	vgrad(b, Color3.fromRGB(255, 196, 70), Color3.fromRGB(225, 120, 30))
	stroke(b, C.ink, 3)
	self.launch_trophy = emoji(b, "bp/trophy", 44, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 34, 0.5, 0),
	})
	local lt = text(b, {
		Position = UDim2.fromOffset(64, 8),
		Size = UDim2.fromOffset(180, 26),
		Text = "LEADERBOARD",
		FontFace = HEAVY,
		TextSize = 23,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	stroke(lt, C.ink, 2.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	self.launch_sub = text(b, {
		Position = UDim2.fromOffset(64, 35),
		Size = UDim2.fromOffset(180, 18),
		Text = "Win streaks & stats",
		FontFace = BOLD,
		TextSize = 14,
		TextColor3 = C.ink,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for _, btn in { card, b } do
		local sc = make("UIScale", { Scale = 1 }, btn)
		btn.MouseEnter:Connect(function()
			TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end)
	end
	b.Activated:Connect(function()
		self:_sfx("ui_open")
		self:open()
	end)
	self.launcher = b
end

-- ---------------------------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------------------------

local WIN_W, WIN_H = 900, 560
local SIDE_W = 290

function StatsUI._stat_tile(self: any, parent: Instance, x: number, y: number, label: string, key: string)
	local f = make("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(125, 58),
		BackgroundColor3 = C.card,
		ZIndex = 13,
	}, parent)
	corner(f, 12)
	text(f, {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(110, 14),
		Text = label,
		FontFace = BOLD,
		TextSize = 12,
		TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 14,
	})
	self.tiles[key] = text(f, {
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.fromOffset(110, 30),
		Text = "0",
		FontFace = HEAVY,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 14,
	})
end

function StatsUI._build_window(self: any)
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
		Size = UDim2.fromOffset(WIN_W, WIN_H),
		BackgroundColor3 = C.white,
		Visible = false,
		ZIndex = 11,
	}, self.root)
	corner(w, 26)
	vgrad(w, C.panel_top, C.panel_bottom)
	stroke(w, C.cyan, 3, 0.25)
	self.window = w
	self.window_scale = make("UIScale", { Scale = 1 }, w)

	-- header
	emoji(w, "bp/trophy", 62, { Position = UDim2.fromOffset(22, 14), ZIndex = 12 })
	local title = text(w, {
		Position = UDim2.fromOffset(94, 18),
		Size = UDim2.fromOffset(420, 44),
		Text = "LEADERBOARD",
		FontFace = HEAVY,
		TextSize = 42,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	})
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.white, C.gold) }, title)
	stroke(title, C.ink, 4, 0).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	text(w, {
		Position = UDim2.fromOffset(96, 60),
		Size = UDim2.fromOffset(500, 20),
		Text = "Multiplayer matches only · updated every minute",
		FontFace = MED,
		TextSize = 15,
		TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
	})
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Color3.fromRGB(230, 70, 90),
		Text = "X",
		FontFace = HEAVY,
		TextSize = 22,
		TextColor3 = C.white,
		AutoButtonColor = true,
		ZIndex = 13,
	}, w)
	corner(close, 22)
	stroke(close, C.ink, 3)
	close.Activated:Connect(function()
		self:close()
	end)

	-- your stats (left)
	local side = make("Frame", {
		Position = UDim2.fromOffset(20, 96),
		Size = UDim2.fromOffset(SIDE_W, WIN_H - 116),
		BackgroundColor3 = C.row,
		ZIndex = 12,
	}, w)
	corner(side, 18)
	stroke(side, C.cyan, 1.5, 0.6)
	local me = Players.LocalPlayer
	make("ImageLabel", {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = C.card_hi,
		Image = headshot(me.UserId),
		ZIndex = 13,
	}, side)
	local hs = side:FindFirstChildOfClass("ImageLabel")
	corner(hs, 28)
	text(side, {
		Position = UDim2.fromOffset(80, 16),
		Size = UDim2.fromOffset(196, 24),
		Text = me.DisplayName,
		FontFace = HEAVY,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 13,
	})
	self.side_level = text(side, {
		Position = UDim2.fromOffset(80, 42),
		Size = UDim2.fromOffset(196, 20),
		Text = "Level 1",
		FontFace = BOLD,
		TextSize = 16,
		TextColor3 = C.gold_hi,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	})
	local bar = make("Frame", {
		Position = UDim2.fromOffset(14, 82),
		Size = UDim2.fromOffset(SIDE_W - 28, 12),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.1,
		ZIndex = 13,
	}, side)
	corner(bar, 6)
	self.side_fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.white, ZIndex = 14 }, bar)
	corner(self.side_fill, 6)
	make("UIGradient", { Color = ColorSequence.new(C.cyan, C.green) }, self.side_fill)
	self.side_xp = text(side, {
		Position = UDim2.fromOffset(14, 98),
		Size = UDim2.fromOffset(SIDE_W - 28, 16),
		Text = "0 / 100 XP",
		FontFace = MED,
		TextSize = 13,
		TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	})
	self.side_crate = text(side, {
		Position = UDim2.fromOffset(14, 116),
		Size = UDim2.fromOffset(SIDE_W - 28, 16),
		Text = "Next crate at level 10",
		FontFace = BOLD,
		TextSize = 13,
		TextColor3 = C.gold_hi,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	})
	self.tiles = {}
	local x0, x1 = 14, 14 + 125 + 12
	self:_stat_tile(side, x0, 144, "WIN STREAK", "streak")
	self:_stat_tile(side, x1, 144, "BEST STREAK", "best")
	self:_stat_tile(side, x0, 210, "WINS", "wins")
	self:_stat_tile(side, x1, 210, "MATCHES", "matches")
	self:_stat_tile(side, x0, 276, "WIN RATE", "rate")
	self:_stat_tile(side, x1, 276, "KNOCKOUTS", "kills")
	self:_stat_tile(side, x0, 342, "SOLO WINS", "solo_wins")
	self:_stat_tile(side, x1, 342, "TOTAL XP", "xp")
	self.side_hint = text(side, {
		Position = UDim2.fromOffset(14, 408),
		Size = UDim2.fromOffset(SIDE_W - 28, 30),
		Text = "Win multiplayer matches for big XP. Every 10 levels unlocks a crate!",
		FontFace = MED,
		TextSize = 12,
		TextColor3 = C.dim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
	})

	-- the boards (right)
	local bx = 20 + SIDE_W + 16
	local bw = WIN_W - bx - 20
	self.tab_buttons = {}
	local tab_w = math.floor((bw - 3 * 8) / 4)
	for i, t in TABS do
		local board, label, icon = t[1], t[2], t[3]
		local tb = make("TextButton", {
			Position = UDim2.fromOffset(bx + (i - 1) * (tab_w + 8), 96),
			Size = UDim2.fromOffset(tab_w, 42),
			BackgroundColor3 = C.card,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 12,
		}, w)
		corner(tb, 12)
		local st = stroke(tb, C.gold, 2, 1)
		emoji(tb, icon, 24, { Position = UDim2.fromOffset(8, 9), ZIndex = 13 })
		text(tb, {
			Position = UDim2.fromOffset(36, 0),
			Size = UDim2.new(1, -40, 1, 0),
			Text = label,
			FontFace = HEAVY,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 13,
		})
		tb.Activated:Connect(function()
			self:_sfx("ui_click")
			self.tab = board
			self:_fill_board()
		end)
		self.tab_buttons[board] = { button = tb, stroke = st }
	end
	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(bx, 148),
		Size = UDim2.fromOffset(bw, WIN_H - 168),
		BackgroundColor3 = C.row,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.cyan,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 12,
	}, w)
	corner(list, 18)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 14),
	}, list)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	self.list = list
	self.list_note = text(w, {
		Position = UDim2.fromOffset(bx, 148),
		Size = UDim2.fromOffset(bw, WIN_H - 168),
		Text = "Loading…",
		FontFace = BOLD,
		TextSize = 18,
		TextColor3 = C.dim,
		TextWrapped = true,
		ZIndex = 13,
	})
end

function StatsUI._row(self: any, rank: number, row: any, how: string, mine: boolean)
	local f = make("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = if mine then C.me else (if rank % 2 == 1 then C.card else C.row),
		LayoutOrder = rank,
		ZIndex = 13,
	}, self.list)
	corner(f, 12)
	if mine then
		stroke(f, C.gold, 2)
	end
	if MEDALS[rank] then
		emoji(f, MEDALS[rank], 34, { Position = UDim2.fromOffset(8, 9), ZIndex = 14 })
	else
		text(f, {
			Position = UDim2.fromOffset(4, 0),
			Size = UDim2.fromOffset(46, 52),
			Text = "#" .. rank,
			FontFace = HEAVY,
			TextSize = 17,
			TextColor3 = C.dim,
			ZIndex = 14,
		})
	end
	local hs = make("ImageLabel", {
		Position = UDim2.fromOffset(56, 6),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = C.card_hi,
		Image = headshot(row.id),
		ZIndex = 14,
	}, f)
	corner(hs, 20)
	text(f, {
		Position = UDim2.fromOffset(106, 6),
		Size = UDim2.new(1, -250, 0, 22),
		Text = tostring(row.display or row.name or "?"),
		FontFace = HEAVY,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 14,
	})
	text(f, {
		Position = UDim2.fromOffset(106, 28),
		Size = UDim2.new(1, -250, 0, 16),
		Text = "@" .. tostring(row.name or "?"),
		FontFace = MED,
		TextSize = 13,
		TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 14,
	})
	local v = tonumber(row.value) or 0
	local shown
	if how == "level" then
		shown = "Lv " .. tostring((Levels.level_of(v)))
	elseif how == "streak" then
		shown = commas(v) .. (if v == 1 then " win" else " wins")
	else
		shown = commas(v)
	end
	text(f, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 0),
		Size = UDim2.fromOffset(130, 52),
		Text = shown,
		FontFace = HEAVY,
		TextSize = 20,
		TextColor3 = if how == "streak" and v >= 3 then C.orange else C.gold_hi,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 14,
	})
	if how == "streak" and v >= 3 then
		emoji(f, "bp/fire", 26, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -150, 0.5, 0),
			ZIndex = 14,
		})
	end
end

function StatsUI._fill_board(self: any)
	for board, t in self.tab_buttons do
		local on = board == self.tab
		t.button.BackgroundColor3 = if on then C.card_hi else C.card
		t.stroke.Transparency = if on then 0 else 1
	end
	for _, c in self.list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	if self.data == nil then
		self.list_note.Text = "Loading…"
		self.list_note.Visible = true
		return
	end
	local how = "wins"
	for _, t in TABS do
		if t[1] == self.tab then
			how = t[4]
		end
	end
	local rows = (self.data.boards or {})[self.tab] or {}
	local shown = 0
	local my_id = Players.LocalPlayer.UserId
	for i, row in rows do
		if type(row) == "table" and (tonumber(row.value) or 0) > 0 then
			shown += 1
			self:_row(i, row, how, row.id == my_id)
		end
	end
	self.list.CanvasPosition = Vector2.new(0, 0)
	if shown == 0 then
		self.list_note.Text = if self.tab == "streak"
			then "No one is on a win streak right now.\nWin a multiplayer match to start yours!"
			else "No one here yet.\nPlay multiplayer matches to get on the board!"
		self.list_note.Visible = true
	else
		self.list_note.Visible = false
	end
end

-- ---------------------------------------------------------------------------------------------
-- Level-up note (after a match)
-- ---------------------------------------------------------------------------------------------

function StatsUI._build_toast(self: any)
	local t = make("Frame", {
		Name = "LevelToast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(420, 92),
		BackgroundColor3 = C.white,
		Visible = false,
		ZIndex = 30,
	}, self.root)
	corner(t, 20)
	vgrad(t, C.panel_top, C.panel_bottom)
	stroke(t, C.gold, 3)
	self.toast_scale = make("UIScale", { Scale = 1 }, t)
	self.toast_icon = emoji(t, "bp/glowing-star", 62, { Position = UDim2.fromOffset(14, 15), ZIndex = 31 })
	self.toast_title = text(t, {
		Position = UDim2.fromOffset(88, 12),
		Size = UDim2.fromOffset(320, 34),
		Text = "LEVEL UP!",
		FontFace = HEAVY,
		TextSize = 30,
		TextColor3 = C.gold_hi,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
	})
	self.toast_sub = text(t, {
		Position = UDim2.fromOffset(88, 48),
		Size = UDim2.fromOffset(320, 36),
		Text = "",
		FontFace = BOLD,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 31,
	})
	self.toast = t
end

function StatsUI._on_level(self: any, g: any)
	local up = g.level > g.level_before
	if up then
		self.toast_title.Text = "LEVEL UP!  " .. tostring(g.level)
		self.toast_title.TextColor3 = C.gold_hi
		if g.crates > 0 then
			self.toast_sub.Text = string.format("+%d XP · You unlocked a crate! It's in your Locker.", g.xp)
			pcall(EmbeddedImage.apply, self.toast_icon, "bp/package", "")
		else
			self.toast_sub.Text = string.format(
				"+%d XP · Next crate at level %d",
				g.xp,
				Levels.next_crate_level(g.level)
			)
			pcall(EmbeddedImage.apply, self.toast_icon, "bp/glowing-star", "")
		end
		self:_sfx("unlock")
	else
		local l = self:_lvl()
		self.toast_title.Text = string.format("+%d XP", g.xp)
		self.toast_title.TextColor3 = C.cyan
		self.toast_sub.Text = string.format("Level %d · %s / %s XP", l.level, commas(l.into), commas(l.need))
		pcall(EmbeddedImage.apply, self.toast_icon, "bp/sparkles", "")
	end
	local t = self.toast
	t.Visible = true
	self.toast_scale.Scale = 0.6
	TweenService:Create(self.toast_scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	self._toast_n = (self._toast_n or 0) + 1
	local n = self._toast_n
	task.delay(if up then 5 else 3, function()
		if self._toast_n == n then
			t.Visible = false
		end
	end)
	self:refresh()
end

-- ---------------------------------------------------------------------------------------------

function StatsUI.refresh(self: any)
	local l = self:_lvl()
	local frac = if l.need > 0 then math.clamp(l.into / l.need, 0, 1) else 0
	self.badge_text.Text = tostring(l.level)
	self.badge_text.TextSize = if l.level >= 100 then 16 else 22
	self.card_title.Text = "LEVEL " .. tostring(l.level)
	self.card_xp.Text = string.format("%s / %s XP", commas(l.into), commas(l.need))
	self.card_fill.Size = UDim2.fromScale(frac, 1)
	local next_crate = Levels.next_crate_level(l.level)
	self.card_crate.Text = string.format("Crate at level %d", next_crate)
	self.side_level.Text = "Level " .. tostring(l.level)
	self.side_fill.Size = UDim2.fromScale(frac, 1)
	self.side_xp.Text = string.format("%s / %s XP to level %d", commas(l.into), commas(l.need), l.level + 1)
	self.side_crate.Text = string.format("Next crate at level %d", next_crate)
	local tiles = self.tiles
	tiles.streak.Text = tostring(l.streak)
	tiles.streak.TextColor3 = if l.streak >= 3 then C.orange else C.white
	tiles.best.Text = tostring(l.best)
	tiles.wins.Text = commas(l.wins)
	tiles.matches.Text = commas(l.matches)
	tiles.rate.Text = if l.matches > 0 then string.format("%d%%", math.floor(l.wins / l.matches * 100 + 0.5)) else "–"
	tiles.kills.Text = commas(l.kills)
	tiles.solo_wins.Text = commas(l.solo_wins)
	tiles.xp.Text = commas(l.xp)
	self.launch_sub.Text = if l.streak > 0
		then string.format("You're on a %d-win streak!", l.streak)
		else "Win streaks & stats"
end

function StatsUI.open(self: any)
	if self.open_ then
		return
	end
	self.open_ = true
	self:refresh()
	self.dim.Visible = true
	self.window.Visible = true
	self.window_scale.Scale = 0.85
	TweenService:Create(self.window_scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	self:_fill_board()
	if self.session and self.session.request_leaderboard then
		self.session:request_leaderboard()
	end
end

function StatsUI.close(self: any)
	self.open_ = false
	self.dim.Visible = false
	self.window.Visible = false
end

--- The launchers show on the title screen only (the level note shows anywhere).
--- A window over the title (the Locker, the shop, a crate opening, the Space Pass: Main) hides the
--- level card and the LEADERBOARD button meanwhile; they sit in a ScreenGui above those windows.
function StatsUI.set_covered(self: any, on: boolean)
	self.covered = on
	local v = self.screen == "title" and not on
	self.launcher.Visible = v
	self.level_card.Visible = v
end

function StatsUI.set_screen(self: any, name: string)
	self.screen = name
	self.launcher.Visible = name == "title" and not self.covered
	self.level_card.Visible = name == "title" and not self.covered
	if name ~= "title" and self.open_ then
		self:close()
	end
end

return StatsUI
