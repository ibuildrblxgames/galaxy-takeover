--!nonstrict
-- Social rewards on the title screen (2026-11-06, the owner): "when they join the game they have the
-- group pop up and it says join the group for 1 free crate", and "rewarding inviting friends".
--   * the group card: pops up once a session for a player who hasn't had the group crate; JOIN GROUP
--     opens Roblox's own join prompt (GroupService:PromptJoinAsync), then the server checks the
--     membership and gives the crate (server/Purchases.claim_group). A member who joined elsewhere
--     gets it without asking. A small chip stays on the title until the crate is claimed;
--   * INVITE FRIENDS: Roblox's invite prompt (SocialService:PromptGameInvite). A friend who comes from
--     it and finishes their first match gets a crate, and so does the inviter (up to INVITE_CAP friends;
--     Purchases.note_referral / add_match);
--   * a note for each reward given (session.social).
--
--   Social.new(session, audio?)   ui:set_screen(name)
local Players = game:GetService("Players")
local GroupService = game:GetService("GroupService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local EmbeddedImage = require(script.Parent:WaitForChild("EmbeddedImage")) :: any

local Social = {}
Social.__index = Social

Social.GROUP_ID = 469759771 -- Bold Pixel Studios (server/Purchases.GROUP_ID)
Social.GROUP_NAME = "Bold Pixel Studios"
Social.POPUP_DELAY_S = 4 -- after the title screen first shows

local FONT_ID = 12187365977 -- Rubik
local function font(w: Enum.FontWeight)
	return Font.fromId(FONT_ID, w)
end
local HEAVY, BOLD, MED = font(Enum.FontWeight.Heavy), font(Enum.FontWeight.Bold), font(Enum.FontWeight.Medium)
local C = {
	ink = Color3.fromRGB(14, 10, 40),
	top = Color3.fromRGB(40, 36, 110),
	bottom = Color3.fromRGB(16, 14, 50),
	cyan = Color3.fromRGB(56, 225, 255),
	gold = Color3.fromRGB(255, 205, 60),
	gold_hi = Color3.fromRGB(255, 236, 140),
	green = Color3.fromRGB(70, 225, 120),
	white = Color3.new(1, 1, 1),
	dim = Color3.fromRGB(170, 165, 220),
}

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
local function corner(p, r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 14) }, p)
end
local function stroke(p, col, th, tr)
	return make("UIStroke", {
		Color = col,
		Thickness = th,
		Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, p)
end
local function vgrad(p, a, b)
	return make("UIGradient", { Rotation = 90, Color = ColorSequence.new(a, b) }, p)
end
local function text(parent, props)
	local t = make("TextLabel", { BackgroundTransparency = 1, TextColor3 = C.white, FontFace = BOLD, TextSize = 16 }, parent)
	for k, v in pairs(props) do
		(t :: any)[k] = v
	end
	return t
end
local function emoji(parent, name, size, props)
	local l = make("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), ScaleType = Enum.ScaleType.Fit }, parent)
	for k, v in pairs(props or {}) do
		(l :: any)[k] = v
	end
	pcall(EmbeddedImage.apply, l, name, "")
	return l
end
local function hover(btn)
	local sc = make("UIScale", { Scale = 1 }, btn)
	btn.MouseEnter:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
end

function Social.new(session: any, audio: any?)
	local self = setmetatable({}, Social)
	self.session = session
	self.audio = audio
	self.screen = "title"
	self.popped = false
	self.claiming = false

	local gui = make("ScreenGui", {
		Name = "Social",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 62,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	self.scale = make("UIScale", { Scale = 1 }, root)
	self.root = root
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

	self:_build_buttons()
	self:_build_popup()
	self:_build_toast()

	if session ~= nil then
		if session.inventory_changed then
			session.inventory_changed:Connect(function()
				self:refresh()
			end)
		end
		if session.social then
			session.social:Connect(function(d)
				self:_on_social(d)
			end)
		end
	end
	self:refresh()
	return self
end

function Social._sfx(self, name)
	if self.audio and self.audio.play_sfx then
		pcall(self.audio.play_sfx, self.audio, name)
	end
end

function Social._state(self): any
	local inv = self.session and self.session.inventory
	return inv and inv.social
end

-- ---------------------------------------------------------------------------------------------

function Social._build_buttons(self)
	-- INVITE FRIENDS (right side, under the flag shop)
	local b = make("TextButton", {
		Name = "InviteFriends",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, -30),
		Size = UDim2.fromOffset(236, 62),
		BackgroundColor3 = C.white,
		AutoButtonColor = false,
		Text = "",
	}, self.root)
	corner(b, 18)
	vgrad(b, Color3.fromRGB(90, 230, 140), Color3.fromRGB(30, 160, 90))
	stroke(b, C.ink, 3)
	emoji(b, "bp/package", 42, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 32, 0.5, 0) })
	local t = text(b, {
		Position = UDim2.fromOffset(60, 8),
		Size = UDim2.fromOffset(170, 24),
		Text = "INVITE FRIENDS",
		FontFace = HEAVY,
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	stroke(t, C.ink, 2.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	self.invite_sub = text(b, {
		Position = UDim2.fromOffset(60, 34),
		Size = UDim2.fromOffset(170, 18),
		Text = "Free crate for you both",
		FontFace = BOLD,
		TextSize = 13,
		TextColor3 = C.ink,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	hover(b)
	b.Activated:Connect(function()
		self:_sfx("ui_open")
		pcall(function()
			local opts = Instance.new("ExperienceInviteOptions")
			opts.PromptMessage = "Invite friends: when one plays their first match, you both get a free crate!"
			SocialService:PromptGameInvite(Players.LocalPlayer, opts)
		end)
	end)
	self.invite_button = b

	-- the group chip (until the group crate is claimed)
	local g = make("TextButton", {
		Name = "GroupChip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 42),
		Size = UDim2.fromOffset(236, 62),
		BackgroundColor3 = C.white,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
	}, self.root)
	corner(g, 18)
	vgrad(g, C.top, C.bottom)
	stroke(g, C.gold, 2.5)
	emoji(g, "bp/package", 40, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 32, 0.5, 0) })
	text(g, {
		Position = UDim2.fromOffset(60, 8),
		Size = UDim2.fromOffset(170, 24),
		Text = "FREE CRATE",
		FontFace = HEAVY,
		TextSize = 21,
		TextColor3 = C.gold_hi,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	text(g, {
		Position = UDim2.fromOffset(60, 34),
		Size = UDim2.fromOffset(170, 18),
		Text = "Join our group",
		FontFace = BOLD,
		TextSize = 13,
		TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	hover(g)
	g.Activated:Connect(function()
		self:_sfx("ui_open")
		self:_show_popup()
	end)
	self.group_chip = g
end

function Social._build_popup(self)
	local dim = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 20,
	}, self.root)
	dim.Activated:Connect(function()
		self:_hide_popup()
	end)
	self.dim = dim
	local w = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 330),
		BackgroundColor3 = C.white,
		Visible = false,
		ZIndex = 21,
	}, self.root)
	corner(w, 26)
	vgrad(w, C.top, C.bottom)
	stroke(w, C.gold, 3)
	self.popup_scale = make("UIScale", { Scale = 1 }, w)
	self.popup = w
	emoji(w, "bp/package", 110, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), ZIndex = 22 })
	local title = text(w, {
		Position = UDim2.fromOffset(0, 128),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "1 FREE CRATE!",
		FontFace = HEAVY,
		TextSize = 36,
		TextColor3 = C.gold_hi,
		ZIndex = 22,
	})
	stroke(title, C.ink, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	text(w, {
		Position = UDim2.fromOffset(30, 170),
		Size = UDim2.new(1, -60, 0, 44),
		Text = "Join " .. Social.GROUP_NAME .. ", the team behind Galaxy Takeover, and get a free crate. Members hear about updates and events first.",
		FontFace = MED,
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = C.dim,
		ZIndex = 22,
	})
	local join = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 226),
		Size = UDim2.fromOffset(300, 56),
		BackgroundColor3 = C.white,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 22,
	}, w)
	corner(join, 16)
	vgrad(join, Color3.fromRGB(255, 196, 70), Color3.fromRGB(225, 120, 30))
	stroke(join, C.ink, 3)
	local jt = text(join, {
		Size = UDim2.fromScale(1, 1),
		Text = "JOIN GROUP",
		FontFace = HEAVY,
		TextSize = 24,
		ZIndex = 23,
	})
	stroke(jt, C.ink, 2.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	self.join_text = jt
	hover(join)
	join.Activated:Connect(function()
		self:_join()
	end)
	local later = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 290),
		Size = UDim2.fromOffset(200, 26),
		BackgroundTransparency = 1,
		Text = "Maybe later",
		FontFace = BOLD,
		TextSize = 14,
		TextColor3 = C.dim,
		ZIndex = 22,
	}, w)
	later.Activated:Connect(function()
		self:_hide_popup()
	end)
end

function Social._build_toast(self)
	local t = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(440, 84),
		BackgroundColor3 = C.white,
		Visible = false,
		ZIndex = 30,
	}, self.root)
	corner(t, 20)
	vgrad(t, C.top, C.bottom)
	stroke(t, C.green, 3)
	emoji(t, "bp/package", 56, { Position = UDim2.fromOffset(14, 14), ZIndex = 31 })
	self.toast_title = text(t, {
		Position = UDim2.fromOffset(82, 12),
		Size = UDim2.fromOffset(340, 30),
		Text = "+1 CRATE!",
		FontFace = HEAVY,
		TextSize = 26,
		TextColor3 = C.green,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
	})
	self.toast_sub = text(t, {
		Position = UDim2.fromOffset(82, 44),
		Size = UDim2.fromOffset(340, 32),
		Text = "",
		FontFace = BOLD,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 31,
	})
	self.toast = t
	self.toast_scale = make("UIScale", { Scale = 1 }, t)
end

-- ---------------------------------------------------------------------------------------------

function Social._toast(self, title, sub, good)
	self.toast_title.Text = title
	self.toast_title.TextColor3 = if good then C.green else C.gold_hi
	self.toast_sub.Text = sub
	self.toast.Visible = true
	self.toast_scale.Scale = 0.6
	TweenService:Create(self.toast_scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	self._n = (self._n or 0) + 1
	local n = self._n
	task.delay(5, function()
		if self._n == n then
			self.toast.Visible = false
		end
	end)
end

function Social._show_popup(self)
	self.dim.Visible = true
	self.popup.Visible = true
	self.popup_scale.Scale = 0.85
	TweenService:Create(self.popup_scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

function Social._hide_popup(self)
	self.dim.Visible = false
	self.popup.Visible = false
end

function Social._join(self)
	if self.claiming then
		return
	end
	self.claiming = true
	self.join_text.Text = "…"
	task.spawn(function()
		local member = false
		pcall(function()
			member = Players.LocalPlayer:IsInGroup(Social.GROUP_ID)
		end)
		if not member then
			local ok, status = pcall(function()
				return GroupService:PromptJoinAsync(Social.GROUP_ID)
			end)
			member = ok and status == Enum.GroupMembershipStatus.Joined
				or (ok and status == Enum.GroupMembershipStatus.AlreadyMember)
		end
		self.join_text.Text = "JOIN GROUP"
		self.claiming = false
		if member then
			self:_hide_popup()
			if self.session and self.session.claim_group then
				self.session:claim_group()
			end
		end
	end)
end

function Social._on_social(self, d)
	if d.kind == "group" then
		if d.result == "granted" then
			self:_sfx("unlock")
			self:_toast("+1 CRATE!", "Thanks for joining " .. Social.GROUP_NAME .. "! It's in your Locker.", true)
		elseif d.result == "not_member" then
			self:_toast("ALMOST!", "Roblox hasn't caught up yet: try JOIN GROUP again in a moment.", false)
		end
	elseif d.kind == "invite" and d.result == "granted" then
		self:_sfx("unlock")
		local who = if type(d.name) == "string" and d.name ~= "" then d.name else "your friend"
		self:_toast("+1 CRATE!", "For playing with " .. who .. ". It's in your Locker.", true)
	end
	self:refresh()
end

--- A window over the title (Main) hides the INVITE FRIENDS button and the group chip meanwhile.
function Social.set_covered(self, on: boolean)
	if self.covered ~= on then
		self.covered = on
		self:refresh()
	end
end

function Social.refresh(self)
	local s = self:_state()
	local title = self.screen == "title" and not self.covered
	self.invite_button.Visible = title
	if s ~= nil then
		local n, cap = tonumber(s.invites) or 0, tonumber(s.invite_cap) or 10
		self.invite_sub.Text = if n >= cap
			then "Thanks for spreading the word!"
			elseif n > 0 then string.format("Free crate for you both · %d/%d", n, cap)
			else "Free crate for you both"
	end
	local unclaimed = s ~= nil and s.group ~= true
	self.group_chip.Visible = title and unclaimed
	if unclaimed and title and not self.popped and not self.claiming then
		self.popped = true
		task.delay(Social.POPUP_DELAY_S, function()
			local s2 = self:_state()
			if self.screen ~= "title" or s2 == nil or s2.group == true then
				return
			end
			if self.covered then
				self.popped = false -- (asked again once the window over the title closes)
				return
			end
			-- already a member (joined on the website): no need to ask, just give it
			local member = false
			pcall(function()
				member = Players.LocalPlayer:IsInGroup(Social.GROUP_ID)
			end)
			if member then
				if self.session and self.session.claim_group then
					self.session:claim_group()
				end
			else
				self:_show_popup()
			end
		end)
	end
	if not unclaimed and self.popup.Visible then
		self:_hide_popup()
	end
end

function Social.set_screen(self, name: string)
	self.screen = name
	if name ~= "title" then
		self:_hide_popup()
	end
	self:refresh()
end

return Social
