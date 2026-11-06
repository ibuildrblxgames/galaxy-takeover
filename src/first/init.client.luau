--!nonstrict
-- Galaxy Takeover loading screen (ReplicatedFirst): replaces Roblox's default loading screen the
-- moment a player joins. Deep space with a drifting three-depth starfield, nebula glows, a ringed
-- planet with an orbiting moon, rocketships carrying alien legions across the sky, the GALACTIC
-- WARS wordmark (same Rubik Heavy, white-to-gold as the title screen) and a hyperdrive charge bar.
--
-- It stays up until the game has loaded and the client has built its UI (ReplicatedFirst
-- attribute GW_ClientReady, set by client/Main), at least MIN_SHOW_S, then makes a hyperspace
-- jump (stars stretch into streaks, a flash) and fades out over the title screen. It sets
-- GW_LoadingDone when it is gone so the title can play its entrance then.
--
-- Built only from Frames, TextLabels and the game's soft-glow textures: nothing to upload. Any
-- error tears it down so it can never block the game.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local MIN_SHOW_S = 3.2 -- long enough to read the logo on a fast join
local MAX_WAIT_S = 30.0 -- never wait longer than this for the client
local JUMP_S = 1.1 -- hyperspace streak time
local FADE_S = 0.55 -- fade over the title after the flash

local FONT_ID = 12187365977 -- Rubik (UITheme.FONT_ID)
local GLOW = "rbxassetid://104131590526993" -- UiShapes.title_glow: soft radial glow
local DISC_GLOW = "rbxassetid://127006968676737" -- UiShapes.disc_glow

local SPACE_TOP = Color3.fromRGB(4, 5, 22)
local SPACE_BOTTOM = Color3.fromRGB(14, 6, 34)
local GOLD = Color3.new(1.0, 0.8, 0.52)
local CYAN = Color3.fromRGB(90, 214, 255)
local VIOLET = Color3.fromRGB(150, 90, 255)
local MAGENTA = Color3.fromRGB(255, 80, 190)
local INK = Color3.new(0.0, 0.02, 0.08)

local STATUS = {
	"Charging hyperdrive",
	"Fueling rocketships",
	"Waking the alien legions",
	"Charting the galaxy",
	"Arming planetary defenses",
	"Calibrating missile silos",
	"Scanning for hostile fleets",
}

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

local function corner(parent: Instance, r: UDim?)
	return make("UICorner", { CornerRadius = r or UDim.new(1, 0) }, parent)
end

local gui = make("ScreenGui", {
	Name = "GalacticWarsLoading",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 10000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local conn: RBXScriptConnection? = nil
local function teardown()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	gui:Destroy()
	ReplicatedFirst:SetAttribute("GW_LoadingDone", true)
end

local ok, err = pcall(function()
	-- =========================================================================================
	-- Backdrop
	-- =========================================================================================
	local bg = make("Frame", {
		Name = "Space",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 1,
	}, gui)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, SPACE_TOP),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(8, 6, 30)),
			ColorSequenceKeypoint.new(1, SPACE_BOTTOM),
		}),
	}, bg)

	-- Nebulae: big tinted glows that breathe and drift.
	local nebulae = {}
	local function nebula(color: Color3, x: number, y: number, size: number, alpha: number, speed: number)
		local n = make("ImageLabel", {
			Image = GLOW,
			ImageColor3 = color,
			ImageTransparency = 1 - alpha,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(size, size * 0.62),
			ZIndex = 2,
		}, bg)
		table.insert(nebulae, { inst = n, x = x, y = y, alpha = alpha, speed = speed, phase = math.random() * 6.28 })
	end
	nebula(VIOLET, 0.22, 0.32, 1.25, 0.42, 0.05)
	nebula(CYAN, 0.78, 0.22, 0.9, 0.22, 0.07)
	nebula(MAGENTA, 0.62, 0.78, 1.0, 0.2, 0.04)
	nebula(Color3.fromRGB(70, 60, 255), 0.4, 0.62, 1.4, 0.18, 0.03)

	-- Starfield: three depths drifting left (parallax), each star twinkling.
	local starLayer = make("Frame", {
		Name = "Stars",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, bg)
	local stars = {}
	local STAR_TINTS = { Color3.new(1, 1, 1), Color3.fromRGB(200, 225, 255), Color3.fromRGB(255, 236, 210), CYAN }
	for i = 1, 170 do
		local depth = if i <= 100 then 0.25 elseif i <= 150 then 0.6 else 1.0
		local px = if depth == 1.0 then 3 elseif depth == 0.6 then 2 else 1
		if depth == 0.25 and math.random() < 0.15 then
			px = 2
		end
		local s = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(px, px),
			BackgroundColor3 = STAR_TINTS[math.random(1, #STAR_TINTS)],
			BorderSizePixel = 0,
			ZIndex = 3,
		}, starLayer)
		corner(s)
		table.insert(stars, {
			inst = s,
			x = math.random(),
			y = math.random(),
			depth = depth,
			px = px,
			base = 0.05 + math.random() * 0.35,
			amp = 0.15 + math.random() * 0.45,
			freq = 0.6 + math.random() * 2.2,
			phase = math.random() * 6.28,
		})
	end

	-- =========================================================================================
	-- Planet (lower right): atmosphere glow, banded sphere, night side, tilted ring, a moon.
	-- =========================================================================================
	local planetHolder = make("Frame", {
		Name = "Planet",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.83, 0.8),
		Size = UDim2.fromScale(0.36, 0.36),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, bg)
	make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }, planetHolder)
	make("ImageLabel", {
		Image = DISC_GLOW,
		ImageColor3 = CYAN,
		ImageTransparency = 0.5,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.55, 1.55),
		ZIndex = 4,
	}, planetHolder)
	local sphere = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 5,
	}, planetHolder)
	corner(sphere)
	local bands = make("UIGradient", {
		Rotation = 70,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(120, 240, 255)),
			ColorSequenceKeypoint.new(0.22, Color3.fromRGB(40, 150, 220)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(70, 90, 210)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(110, 70, 200)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(45, 40, 130)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(20, 18, 70)),
		}),
	}, sphere)
	-- night side: dark shading from the lower right
	local night = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(2, 2, 14),
		BorderSizePixel = 0,
		ZIndex = 6,
	}, sphere)
	corner(night)
	make("UIGradient", {
		Rotation = 40,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 0.85),
			NumberSequenceKeypoint.new(0.8, 0.15),
			NumberSequenceKeypoint.new(1, 0.0),
		}),
	}, night)
	-- rim light on the lit edge
	make("UIStroke", {
		Color = Color3.fromRGB(170, 245, 255),
		Thickness = 2,
		Transparency = 0.35,
	}, sphere)
	-- tilted ring: a belt of glowing particles orbiting the planet, hidden behind it on the far side
	local RING_TILT = math.rad(-16)
	local ringDots = {}
	local RING_TINTS = {
		Color3.fromRGB(255, 214, 160),
		Color3.fromRGB(210, 180, 255),
		Color3.fromRGB(170, 230, 255),
	}
	for i = 1, 260 do
		local band = if i <= 170 then 0.74 + math.random() * 0.07 else 0.62 + math.random() * 0.05
		local px = if math.random() < 0.25 then 3 else 2
		local d = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(px, px),
			BackgroundColor3 = RING_TINTS[math.random(1, #RING_TINTS)],
			BorderSizePixel = 0,
			ZIndex = 7,
		}, planetHolder)
		corner(d)
		table.insert(ringDots, {
			inst = d,
			a = math.random() * math.pi * 2,
			r = band,
			base = if band < 0.7 then 0.35 else 0.05 + math.random() * 0.3,
		})
	end
	-- the moon
	local moon = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(0.13, 0.13),
		BackgroundColor3 = Color3.fromRGB(205, 200, 230),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, planetHolder)
	corner(moon)
	make("UIGradient", {
		Rotation = 45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.1),
			NumberSequenceKeypoint.new(1, 0.75),
		}),
	}, moon)

	-- A far, small red planet upper left.
	local far = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.12, 0.2),
		Size = UDim2.fromScale(0.05, 0.05),
		BackgroundColor3 = Color3.fromRGB(255, 120, 90),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, bg)
	make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }, far)
	corner(far)
	make("UIGradient", {
		Rotation = 30,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 0.85),
		}),
	}, far)

	-- =========================================================================================
	-- Rocketships: an alien-troop rocket crosses the sky now and then, trailing exhaust.
	-- =========================================================================================
	local fleet = make("Frame", {
		Name = "Fleet",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 9,
	}, bg)
	local function rocket(scale: number): Frame
		local r = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(64 * scale, 22 * scale),
			BackgroundTransparency = 1,
			ZIndex = 10,
		}, fleet)
		-- flame (behind the body, to the left), flickers
		local flame = make("Frame", {
			Name = "Flame",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(0.22, 0, 0.5, 0),
			Size = UDim2.new(0.42, 0, 0.42, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 10,
		}, r)
		corner(flame)
		make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 120)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 170, 60)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 250, 220)),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.35),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}, flame)
		-- fins
		for _, sgn in ipairs({ -1, 1 }) do
			local fin = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.3, 0, 0.5 + sgn * 0.36, 0),
				Size = UDim2.new(0.18, 0, 0.3, 0),
				Rotation = sgn * 28,
				BackgroundColor3 = Color3.fromRGB(255, 90, 110),
				BorderSizePixel = 0,
				ZIndex = 11,
			}, r)
			corner(fin, UDim.new(0.3, 0))
		end
		-- body
		local body = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.2, 0, 0.5, 0),
			Size = UDim2.new(0.64, 0, 0.62, 0),
			BackgroundColor3 = Color3.fromRGB(235, 240, 255),
			BorderSizePixel = 0,
			ZIndex = 12,
		}, r)
		corner(body)
		make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 150, 190)),
			}),
		}, body)
		-- nose cone
		local nose = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.83, 0, 0.5, 0),
			Size = UDim2.new(0.22, 0, 0.62, 0),
			BackgroundColor3 = Color3.fromRGB(255, 90, 110),
			BorderSizePixel = 0,
			ZIndex = 13,
		}, r)
		corner(nose)
		-- porthole: a green alien face peeking out
		local port = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.56, 0, 0.5, 0),
			Size = UDim2.new(0.2, 0, 0.5, 0),
			BackgroundColor3 = Color3.fromRGB(120, 255, 140),
			BorderSizePixel = 0,
			ZIndex = 14,
		}, r)
		corner(port)
		make("UIStroke", { Color = Color3.fromRGB(60, 80, 140), Thickness = math.max(1, 2 * scale) }, port)
		return r
	end

	local flights = {}
	local trail = {}
	local function launch(now: number)
		local scale = 0.7 + math.random() * 0.6
		local r = rocket(scale)
		local fromLeft = math.random() < 0.75
		local y0 = 0.25 + math.random() * 0.5
		local x0 = if fromLeft then -0.08 else 1.08
		local x1 = if fromLeft then 1.08 else -0.08
		local y1 = y0 - (0.15 + math.random() * 0.25)
		table.insert(flights, {
			inst = r,
			x0 = x0,
			y0 = y0,
			x1 = x1,
			y1 = y1,
			t0 = now,
			dur = 5.5 + math.random() * 2.5,
			scale = scale,
			next_puff = now,
		})
	end

	-- =========================================================================================
	-- Wordmark, tag line, status and the hyperdrive bar (centre column, scaled to the screen).
	-- =========================================================================================
	local column = make("Frame", {
		Name = "Column",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(1100, 420),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, gui)
	local uiScale = make("UIScale", { Scale = 1 }, column)

	-- warm glow behind the wordmark, as on the title screen
	make("ImageLabel", {
		Image = GLOW,
		ImageColor3 = Color3.fromRGB(255, 190, 120),
		ImageTransparency = 0.55,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(1100, 300),
		ZIndex = 20,
	}, column)

	local word = make("Frame", {
		Name = "Wordmark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(0, 120),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, column)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, word)
	local heavy = Font.fromId(FONT_ID, Enum.FontWeight.Heavy)
	local glyphs = {}
	local text = "GALAXY TAKEOVER"
	for i = 1, #text do
		local ch = text:sub(i, i)
		if ch == " " then
			make("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(26, 10), BackgroundTransparency = 1 }, word)
		else
			local g = make("TextLabel", {
				LayoutOrder = i,
				Text = ch,
				FontFace = heavy,
				TextSize = 100,
				TextColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(0, 120),
				AutomaticSize = Enum.AutomaticSize.X,
				TextTransparency = 1,
				ZIndex = 22,
			}, word)
			make("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.42, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(0.8, GOLD),
					ColorSequenceKeypoint.new(1, GOLD),
				}),
			}, g)
			local st = make("UIStroke", {
				Color = INK,
				Thickness = 6,
				Transparency = 1,
				LineJoinMode = Enum.LineJoinMode.Round,
			}, g)
			table.insert(glyphs, { label = g, stroke = st, i = #glyphs + 1 })
		end
	end

	local tagRow = make("Frame", {
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 196),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, column)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tagRow)
	local function hairline(order: number, flip: boolean)
		local h = make("Frame", {
			LayoutOrder = order,
			Size = UDim2.fromOffset(90, 2),
			BackgroundColor3 = CYAN,
			BorderSizePixel = 0,
			ZIndex = 21,
		}, tagRow)
		make("UIGradient", {
			Transparency = if flip
				then NumberSequence.new(0.1, 1)
				else NumberSequence.new(1, 0.1),
		}, h)
		return h
	end
	hairline(1, false)
	local tag = make("TextLabel", {
		LayoutOrder = 2,
		Text = "C O N Q U E R   T H E   U N I V E R S E",
		FontFace = Font.fromId(FONT_ID, Enum.FontWeight.SemiBold),
		TextSize = 17,
		TextColor3 = Color3.fromRGB(205, 230, 255),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		TextTransparency = 1,
		ZIndex = 21,
	}, tagRow)
	hairline(3, true)

	-- hyperdrive bar
	local barBack = make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 300),
		Size = UDim2.fromOffset(460, 10),
		BackgroundColor3 = Color3.fromRGB(20, 24, 60),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 21,
	}, column)
	corner(barBack)
	make("UIStroke", { Color = Color3.fromRGB(110, 140, 255), Thickness = 1, Transparency = 0.5 }, barBack)
	local barFill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 22,
	}, barBack)
	corner(barFill)
	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, VIOLET),
			ColorSequenceKeypoint.new(0.6, CYAN),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 255, 255)),
		}),
	}, barFill)
	-- a bright spark riding the end of the fill
	local spark = make("ImageLabel", {
		Image = DISC_GLOW,
		ImageColor3 = Color3.fromRGB(200, 250, 255),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(46, 46),
		ZIndex = 23,
	}, barBack)
	local status = make("TextLabel", {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 322),
		Size = UDim2.fromOffset(600, 22),
		Text = "",
		FontFace = Font.fromId(FONT_ID, Enum.FontWeight.Medium),
		TextSize = 15,
		TextColor3 = Color3.fromRGB(170, 190, 235),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, column)

	-- licence notice (LICENSE section 7(b): kept visible on the loading screen)
	make("TextLabel", {
		Name = "Credits",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "© OpenFront and Contributors  ·  Galaxy Takeover is a modified version of RoWorld  ·  GNU AGPL v3",
		FontFace = Font.fromId(FONT_ID, Enum.FontWeight.Medium),
		TextSize = 11,
		TextColor3 = Color3.fromRGB(150, 160, 200),
		TextTransparency = 0.25,
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, gui)

	-- flash for the jump
	local flash = make("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(225, 240, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
	}, gui)

	gui.Parent = playerGui
	-- load the Rubik weights now so the wordmark doesn't flash in a fallback font
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ glyphs[1].label, tag, status })
		end)
	end)

	-- =========================================================================================
	-- Animation
	-- =========================================================================================
	local start = os.clock()
	local shown = 0.0 -- displayed progress (eased toward the target)
	local initialQueue = math.max(ContentProvider.RequestQueueSize, 1)
	local statusIndex = math.random(1, #STATUS)
	local statusAt = 0.0
	local nextLaunch = start + 0.6
	local jumpAt: number? = nil
	local fadeAt: number? = nil
	local fadeList: { any }? = nil

	local function viewport(): Vector2
		local cam = workspace.CurrentCamera
		return if cam then cam.ViewportSize else Vector2.new(1280, 720)
	end

	local function clientReady(): boolean
		return ReplicatedFirst:GetAttribute("GW_ClientReady") == true
	end

	local function targetProgress(now: number): number
		local loaded = game:IsLoaded()
		local q = ContentProvider.RequestQueueSize
		initialQueue = math.max(initialQueue, q)
		local assets = 1 - q / initialQueue
		local p = if loaded then 0.55 + 0.25 * assets else 0.5 * assets
		if clientReady() then
			p = 0.92
		end
		-- creep on slowly so the bar never looks stuck
		p = math.max(p, math.min(0.85, (now - start) / 14))
		if jumpAt then
			p = 1
		end
		return p
	end

	local function collectFade(): { any }
		local list = {}
		for _, d in ipairs(gui:GetDescendants()) do
			if d == flash then
				continue
			end
			if d:IsA("ImageLabel") then
				table.insert(list, { d, "ImageTransparency", d.ImageTransparency })
				table.insert(list, { d, "BackgroundTransparency", d.BackgroundTransparency })
			elseif d:IsA("TextLabel") then
				table.insert(list, { d, "TextTransparency", d.TextTransparency })
				table.insert(list, { d, "BackgroundTransparency", d.BackgroundTransparency })
			elseif d:IsA("Frame") then
				table.insert(list, { d, "BackgroundTransparency", d.BackgroundTransparency })
			elseif d:IsA("UIStroke") then
				table.insert(list, { d, "Transparency", d.Transparency })
			end
		end
		return list
	end

	conn = RunService.RenderStepped:Connect(function(dt: number)
		local now = os.clock()
		local t = now - start
		local vp = viewport()
		uiScale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.42, 1.6)
		local cx, cy = vp.X * 0.5, vp.Y * 0.5

		-- nebulae breathe
		for _, n in ipairs(nebulae) do
			local w = math.sin(t * n.speed * 6 + n.phase)
			n.inst.Position = UDim2.fromScale(n.x + w * 0.015, n.y + math.cos(t * n.speed * 5 + n.phase) * 0.012)
			if not fadeAt then
				n.inst.ImageTransparency = 1 - n.alpha * (0.85 + 0.15 * w)
			end
		end

		-- stars: drift, or streak during the jump
		local jt = if jumpAt then math.clamp((now - jumpAt) / JUMP_S, 0, 1) else 0
		for _, s in ipairs(stars) do
			if jt <= 0 then
				s.x = (s.x - dt * 0.006 * s.depth) % 1
				s.inst.Position = UDim2.fromOffset(s.x * vp.X, s.y * vp.Y)
				if not fadeAt then
					s.inst.BackgroundTransparency =
						math.clamp(s.base + s.amp * (0.5 + 0.5 * math.sin(t * s.freq + s.phase)), 0, 0.95)
				end
			else
				local dx, dy = s.x * vp.X - cx, s.y * vp.Y - cy
				local dist = math.max(math.sqrt(dx * dx + dy * dy), 1)
				local ux, uy = dx / dist, dy / dist
				local push = 1 + jt * jt * 2.6 * (0.6 + s.depth)
				local len = s.px + jt * jt * 520 * (0.35 + s.depth)
				local px = cx + ux * dist * push
				local py = cy + uy * dist * push
				s.inst.Position = UDim2.fromOffset(px, py)
				s.inst.Size = UDim2.fromOffset(len, math.max(1, s.px * 0.8))
				s.inst.Rotation = math.deg(math.atan2(uy, ux))
				s.inst.BackgroundTransparency = math.clamp(0.05 + s.base * 0.4, 0, 1)
			end
		end

		-- planet: ring shimmer, slow band drift, moon orbit
		bands.Rotation = 70 + math.sin(t * 0.15) * 6
		local ma = t * 0.35
		local mx, my = math.cos(ma) * 0.86, math.sin(ma) * 0.2
		moon.Position = UDim2.fromScale(0.5 + mx * math.cos(math.rad(-16)) - my * math.sin(math.rad(-16)),
			0.52 + mx * math.sin(math.rad(-16)) + my * math.cos(math.rad(-16)))
		moon.ZIndex = if math.sin(ma) > 0 then 8 else 4
		local ct, st = math.cos(RING_TILT), math.sin(RING_TILT)
		for _, d in ipairs(ringDots) do
			local a = d.a + t * 0.06
			local ex, ey = math.cos(a) * d.r, math.sin(a) * d.r * 0.24
			d.inst.Position = UDim2.fromScale(0.5 + ex * ct - ey * st, 0.52 + ex * st + ey * ct)
			local front = math.sin(a) > 0
			d.inst.ZIndex = if front then 7 else 4
			if not fadeAt then
				-- the far side is dimmer; the near side glints
				d.inst.BackgroundTransparency = math.clamp(d.base + (if front then 0 else 0.35)
					+ 0.15 * math.sin(t * 3 + d.a * 7), 0, 0.95)
			end
		end
		planetHolder.Position = UDim2.fromScale(0.83, 0.8 + math.sin(t * 0.4) * 0.006)

		-- rocketships
		if not jumpAt and now >= nextLaunch and #flights < 2 then
			launch(now)
			nextLaunch = now + 2.8 + math.random() * 2.5
		end
		for i = #flights, 1, -1 do
			local f = flights[i]
			local u = (now - f.t0) / f.dur
			if u >= 1 or jt > 0.2 then
				f.inst:Destroy()
				table.remove(flights, i)
			else
				local x = f.x0 + (f.x1 - f.x0) * u
				local y = f.y0 + (f.y1 - f.y0) * u + math.sin(u * math.pi) * -0.05
				f.inst.Position = UDim2.fromScale(x, y)
				local ang = math.deg(math.atan2((f.y1 - f.y0) * vp.Y, (f.x1 - f.x0) * vp.X))
				f.inst.Rotation = ang
				local flame = f.inst:FindFirstChild("Flame")
				if flame then
					local k = 0.8 + 0.25 * math.sin(now * 40 + i)
					flame.Size = UDim2.new(0.42 * k, 0, 0.42, 0)
				end
				if now >= f.next_puff then
					f.next_puff = now + 0.05
					local p = make("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(x, y),
						Size = UDim2.fromOffset(5 * f.scale, 5 * f.scale),
						BackgroundColor3 = Color3.fromRGB(255, 190, 140),
						BackgroundTransparency = 0.3,
						BorderSizePixel = 0,
						ZIndex = 9,
					}, fleet)
					corner(p)
					table.insert(trail, { inst = p, t0 = now })
				end
			end
		end
		for i = #trail, 1, -1 do
			local p = trail[i]
			local a = (now - p.t0) / 1.4
			if a >= 1 then
				p.inst:Destroy()
				table.remove(trail, i)
			else
				p.inst.BackgroundTransparency = 0.3 + 0.7 * a
				p.inst.BackgroundColor3 = Color3.fromRGB(255, 190, 140):Lerp(Color3.fromRGB(120, 110, 255), a)
			end
		end

		-- wordmark: letters land one after another, then a soft pulse
		for _, g in ipairs(glyphs) do
			local a = math.clamp((t - 0.25 - g.i * 0.06) / 0.45, 0, 1)
			local e = 1 - (1 - a) ^ 3
			if not fadeAt then
				g.label.TextTransparency = 1 - e
				g.stroke.Transparency = 1 - e * 0.45
			end
		end
		if not fadeAt then
			tag.TextTransparency = 1 - math.clamp((t - 1.2) / 0.6, 0, 1)
		end

		-- progress
		local target = targetProgress(now)
		shown += (target - shown) * math.min(1, dt * (if jumpAt then 10 else 3))
		barFill.Size = UDim2.fromScale(shown, 1)
		spark.Position = UDim2.fromScale(shown, 0.5)
		spark.ImageTransparency = if fadeAt then spark.ImageTransparency else 0.15 + 0.2 * math.sin(t * 9)
		if not jumpAt then
			if t - statusAt > 1.6 then
				statusAt = t
				statusIndex = statusIndex % #STATUS + 1
			end
			local dots = string.rep(".", 1 + math.floor(t * 2.5) % 3)
			status.Text = string.format("%s%s   %d%%", STATUS[statusIndex], dots, math.floor(shown * 100 + 0.5))
		else
			status.Text = "JUMPING TO HYPERSPACE   100%"
		end

		-- leave: ready (or timed out) and shown long enough -> jump -> flash -> fade
		if not jumpAt then
			-- (Studio review: workspace attribute GW_HOLD_LOADING keeps it up; never set when shipped)
			local ready = clientReady() and game:IsLoaded() and workspace:GetAttribute("GW_HOLD_LOADING") ~= true
			if (ready and t >= MIN_SHOW_S) or (t >= MAX_WAIT_S and workspace:GetAttribute("GW_HOLD_LOADING") ~= true) then
				jumpAt = now
			end
		elseif not fadeAt then
			local j = now - jumpAt
			flash.BackgroundTransparency = 1 - math.clamp((j - JUMP_S * 0.6) / (JUMP_S * 0.4), 0, 1) * 0.85
			if j >= JUMP_S then
				fadeAt = now
				fadeList = collectFade()
				ReplicatedFirst:SetAttribute("GW_LoadingDone", true)
			end
		else
			local f = math.clamp((now - fadeAt) / FADE_S, 0, 1)
			local e = f * f * (3 - 2 * f)
			for _, entry in ipairs(fadeList :: { any }) do
				local inst, prop, from = entry[1], entry[2], entry[3]
				if inst.Parent then
					inst[prop] = from + (1 - from) * e
				end
			end
			flash.BackgroundTransparency = 0.15 + 0.85 * e
			if f >= 1 then
				teardown()
			end
		end
	end)
end)

if not ok then
	warn("[GalacticWars] loading screen failed: " .. tostring(err))
	teardown()
end
