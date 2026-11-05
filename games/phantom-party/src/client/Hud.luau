-- The always-on parts of the screen, kept small and at the edges:
--   - top middle: what's happening (waiting, the vote, the round's clock and
--     how many are still standing), the player's role during a round, and
--     the Truth Bell's fill;
--   - top left: coins and level;
--   - left edge: the menu buttons that open each panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Roles = require(Shared.Config.Roles)
local Rewards = require(Shared.Config.Rewards)
local Corner = require(script.Parent.Corner)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Hud = {}

local gui = Ui.screen("Hud", 1)
local menuButtons: { [string]: TextButton } = {}
local openers: { [string]: () -> () } = {}

-- Top middle -------------------------------------------------------------

local top = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(260, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
Ui.list(top, 4).HorizontalAlignment = Enum.HorizontalAlignment.Center
Ui.fitScale(top)

local pill = Ui.make("Frame", {
	Size = UDim2.fromOffset(250, 34),
	BackgroundColor3 = Ui.Colors.Panel,
	BackgroundTransparency = 0.1,
	LayoutOrder = 1,
}, top)
Ui.round(pill, 17)
local pillStroke = Ui.stroke(pill, Ui.Colors.Accent, 1.5)
local pillText = Ui.label(pill, "", {
	Size = UDim2.fromScale(1, 1),
	Font = Ui.Title,
	TextSize = 17,
})

local roleChip = Ui.make("Frame", {
	Size = UDim2.fromOffset(200, 24),
	BackgroundColor3 = Ui.Colors.Panel,
	BackgroundTransparency = 0.1,
	Visible = false,
	LayoutOrder = 2,
}, top)
Ui.round(roleChip, 12)
local roleStroke = Ui.stroke(roleChip, Ui.Colors.Gold, 1.5)
local roleText = Ui.label(roleChip, "", { Size = UDim2.fromScale(1, 1), Font = Ui.Title, TextSize = 14 })

local bellFrame = Ui.make("Frame", {
	Size = UDim2.fromOffset(250, 18),
	BackgroundColor3 = Ui.Colors.Track,
	Visible = false,
	LayoutOrder = 3,
}, top)
Ui.round(bellFrame, 9)
local bellFill = Ui.make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(150, 210, 255),
}, bellFrame)
Ui.round(bellFill, 9)
local bellText = Ui.label(bellFrame, "Truth Bell", {
	Size = UDim2.fromScale(1, 1),
	TextSize = 11,
	TextStrokeTransparency = 0.5,
	ZIndex = 2,
})
Ui.make("Frame", {
	Size = UDim2.new(0, 2, 1, 0),
	Position = UDim2.fromScale(Rewards.ClueRoomAt / 100, 0),
	BackgroundColor3 = Ui.Colors.Gold,
	ZIndex = 3,
}, bellFrame)

-- Other screens can add a row under the top middle (client/Leads).
function Hud.top(): Frame
	return top
end

-- Top left ---------------------------------------------------------------

local wallet = Ui.make("Frame", {
	Position = UDim2.fromOffset(10, 6),
	Size = UDim2.fromOffset(160, 50),
	BackgroundColor3 = Ui.Colors.Panel,
	BackgroundTransparency = 0.1,
}, gui)
Ui.round(wallet, 10)
Ui.stroke(wallet, Ui.Colors.Gold, 1.5)
Ui.fitScale(wallet)
local coinIcon = Ui.make("Frame", {
	Size = UDim2.fromOffset(18, 18),
	Position = UDim2.fromOffset(8, 5),
	BackgroundColor3 = Ui.Colors.Gold,
}, wallet)
Ui.round(coinIcon, 9)
Ui.stroke(coinIcon, Color3.fromRGB(190, 130, 30), 2)
local coinText = Ui.label(wallet, "0", {
	Position = UDim2.fromOffset(32, 4),
	Size = UDim2.new(1, -40, 0, 20),
	Font = Ui.Title,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Ui.Colors.Gold,
})
local levelText = Ui.label(wallet, "Level 1", {
	Position = UDim2.fromOffset(8, 26),
	Size = UDim2.new(1, -16, 0, 12),
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local xpTrack = Ui.make("Frame", {
	Position = UDim2.fromOffset(8, 40),
	Size = UDim2.new(1, -16, 0, 5),
	BackgroundColor3 = Ui.Colors.Track,
}, wallet)
Ui.round(xpTrack, 3)
local xpFill = Ui.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Ui.Colors.Accent }, xpTrack)
Ui.round(xpFill, 3)

-- Left menu --------------------------------------------------------------

local menu = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(58, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
Ui.list(menu, 6)
Ui.fitScale(menu)

local MENU = {
	{ Name = "Shop", Color = Color3.fromRGB(255, 140, 60) },
	{ Name = "Items", Color = Color3.fromRGB(80, 160, 255) },
	{ Name = "Crates", Color = Color3.fromRGB(176, 103, 255) },
	{ Name = "Pass", Color = Color3.fromRGB(255, 205, 90) },
	{ Name = "Trade", Color = Color3.fromRGB(60, 200, 170) },
	{ Name = "Emotes", Color = Color3.fromRGB(255, 100, 170) },
	{ Name = "Settings", Color = Color3.fromRGB(120, 112, 150) },
}

for index, entry in MENU do
	local button = Ui.button(menu, entry.Name, entry.Color, {
		Size = UDim2.fromOffset(58, 40),
		TextSize = 13,
		LayoutOrder = index,
	})
	Ui.stroke(button, Color3.fromRGB(20, 12, 30), 2)
	local badge = Ui.make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -2, 0, 2),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Ui.Colors.Bad,
		Visible = false,
		ZIndex = 3,
	}, button)
	Ui.round(badge, 8)
	Ui.label(badge, "", { Name = "Count", Size = UDim2.fromScale(1, 1), TextSize = 10, ZIndex = 4 })
	button.Activated:Connect(function()
		Sounds.play("Click")
		local open = openers[entry.Name]
		if open then
			open()
		end
	end)
	menuButtons[entry.Name] = button
end

-- Other screens add what their menu button opens.
function Hud.onMenu(name: string, open: () -> ())
	openers[name] = open
end

-- Opens a menu's panel, as if its button was pressed.
function Hud.open(name: string)
	local open = openers[name]
	if open then
		open()
	end
end

function Hud.badge(name: string, count: number)
	local button = menuButtons[name]
	local badge = button and button:FindFirstChild("Badge") :: Frame?
	if not badge then
		return
	end
	badge.Visible = count > 0
	local label = badge:FindFirstChild("Count") :: TextLabel?
	if label then
		label.Text = if count > 9 then "9+" else tostring(count)
	end
end

-- Updates ----------------------------------------------------------------

local lastCoins: number? = nil

local function refreshProfile()
	local profile = State.Profile
	if not profile then
		return
	end
	coinText.Text = Format.whole(profile.Coins)
	if lastCoins and profile.Coins > lastCoins then
		local scale = coinText:FindFirstChildOfClass("UIScale") or Ui.make("UIScale", {}, coinText)
		scale.Scale = 1.25
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	lastCoins = profile.Coins
	levelText.Text = `Level {profile.Level}`
	xpFill.Size = UDim2.fromScale(math.clamp(profile.LevelInto / math.max(1, profile.LevelCost), 0, 1), 1)
	Hud.badge("Pass", profile.Pass.Ready or 0)
end

local function refreshRole()
	local role = State.Role and Roles.List[State.Role]
	roleChip.Visible = role ~= nil and State.Round.InRound
	if role then
		local color = Color3.fromHex(role.Color)
		roleText.Text = `You are the {string.upper(role.Name)}`
		roleText.TextColor3 = color
		roleStroke.Color = color
	end
end

local function refreshBell()
	local live = State.Round.State == "Playing"
	bellFrame.Visible = live
	local value = State.Bell.Value or 0
	TweenService:Create(bellFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(value / 100, 1) }):Play()
	if State.Bell.Room then
		bellText.Text = `Truth Bell: the Phantom was in the {State.Bell.Room}`
	elseif State.Bell.Spent then
		bellText.Text = "The Truth Bell has rung tonight"
	else
		bellText.Text = `Truth Bell {value}%`
	end
end

local lastTick = -1

local function stateLine(): (string, Color3)
	local round = State.Round
	local left = math.ceil(State.left(round.EndsAt))
	if round.State == "Waiting" then
		return "Waiting for party guests", Ui.Colors.Accent
	elseif round.State == "Intermission" then
		return `Next party in {Format.clock(left)}`, Ui.Colors.Accent
	elseif round.State == "Reveal" then
		return if round.InRound then "Who's behind the mask?" else `Starting at {round.MapName or "the party"}`,
			Ui.Colors.Gold
	elseif round.State == "Playing" then
		local census = State.Census
		local color = if left <= 30 then Ui.Colors.Bad else Ui.Colors.Gold
		if left <= 10 and left ~= lastTick and round.InRound then
			lastTick = left
			Sounds.play("Tick")
		end
		local standing = if census.Total > 0 then ` · {census.Alive} standing` else ""
		return `{Format.clock(left)}{standing}`, color
	elseif round.State == "Results" then
		return "Results", Ui.Colors.Gold
	end
	return "", Ui.Colors.Accent
end

function Hud.start()
	State.on("Profile", refreshProfile)
	State.on("Role", refreshRole)
	State.on("Round", function()
		refreshRole()
		refreshBell()
	end)
	State.on("Bell", function()
		refreshBell()
		if State.Bell.Room then
			Sounds.play("Bell")
		end
	end)
	State.on("Me", function(message)
		if typeof(message) == "table" and message.Text then
			Corner.note(if message.State == "Alive" then "Revived!" else "Oops!", message.Text, Ui.Colors.Good, 7)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local text, color = stateLine()
		pillText.Text = text
		pillText.TextColor3 = color
		pillStroke.Color = color
	end)
	refreshProfile()
	refreshRole()
	refreshBell()
end

return Hud
