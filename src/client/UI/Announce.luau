--!nonstrict
-- Chat extras (2026-11-06, the owner): an OWNER tag before the game owner's name in chat, and admin
-- announcements ("/announce <text>", server/ServerMain): a banner across the top of the screen for
-- SHOW_S and a system line in the chat.
--
--   Announce.new(session, owner_user_id)
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Announce = {}
Announce.__index = Announce

Announce.SHOW_S = 10
Announce.OWNER_TAG = '<font color="#FFC83C"><b>[OWNER]</b></font> '
Announce.CHAT_LINE = '<font color="#38E1FF"><b>[ANNOUNCEMENT]</b></font> %s'

local FONT_ID = 12187365977 -- Rubik
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

local function escape(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Announce.new(session: any, owner_user_id: number?)
	local self = setmetatable({}, Announce)
	self.owner = tonumber(owner_user_id) or 0
	-- the owner tag (every message the client shows, this server's and Global chat's)
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")
		local src = message.TextSource
		if src ~= nil and self.owner > 0 and src.UserId == self.owner then
			props.PrefixText = Announce.OWNER_TAG .. message.PrefixText
		end
		return props
	end

	local gui = make("ScreenGui", {
		Name = "Announce",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 90,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	local banner = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(0, 640, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 18) }, banner)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(40, 36, 110), Color3.fromRGB(16, 14, 50)),
	}, banner)
	make("UIStroke", {
		Color = Color3.fromRGB(56, 225, 255),
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, banner)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 20),
	}, banner)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, banner)
	self.title = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = "ANNOUNCEMENT",
		FontFace = Font.fromId(FONT_ID, Enum.FontWeight.Heavy),
		TextSize = 18,
		TextColor3 = Color3.fromRGB(56, 225, 255),
		LayoutOrder = 1,
	}, banner)
	self.body = make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = "",
		FontFace = Font.fromId(FONT_ID, Enum.FontWeight.Bold),
		TextSize = 20,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		LayoutOrder = 2,
	}, banner)
	self.scale = make("UIScale", { Scale = 1 }, banner)
	self.banner = banner

	if session ~= nil and session.announcement ~= nil then
		session.announcement:Connect(function(a)
			self:show(a.text, a.from)
		end)
	end
	return self
end

function Announce.show(self: any, text: string, from: string?)
	self.title.Text = if from ~= nil and from ~= "" then "ANNOUNCEMENT · " .. string.upper(from) else "ANNOUNCEMENT"
	self.body.Text = text
	self.banner.Visible = true
	self.scale.Scale = 0.7
	TweenService:Create(self.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	self._n = (self._n or 0) + 1
	local n = self._n
	task.delay(Announce.SHOW_S, function()
		if self._n == n then
			self.banner.Visible = false
		end
	end)
	pcall(function()
		local ch = TextChatService:FindFirstChild("TextChannels")
		ch = ch and ch:FindFirstChild("RBXGeneral")
		if ch then
			ch:DisplaySystemMessage(string.format(Announce.CHAT_LINE, escape(text)))
		end
	end)
end

return Announce
