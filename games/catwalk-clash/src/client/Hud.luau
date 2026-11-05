-- The always-on screen: the round pill at the top (what's happening, the
-- theme and the clock), the player's Sparkles and Style Score at the top
-- left, and the menu buttons down the left side. Buttons are added by the
-- modules that own each menu (Hud.addButton).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local C = Ui.Colors
local make = Ui.make

local Hud = {}

local gui: ScreenGui
local pill: Frame
local phaseLabel: TextLabel
local themeLabel: TextLabel
local clockLabel: TextLabel
local sparklesLabel: TextLabel
local scoreLabel: TextLabel
local rankLabel: TextLabel
local menu: Frame
local lastSecond = -1
local lastSparkles: number? = nil

local PHASE_TEXT = {
	Waiting = "Waiting for players",
	Lobby = "Next show soon",
	ThemeVote = "Vote for the theme!",
	Reveal = "The theme is...",
	Dressing = "Get dressed!",
	Showtime = "SHOWTIME",
	Crowning = "The crowning",
}

local function refreshPill()
	local phase = State.phase()
	local theme = State.theme()
	local text = PHASE_TEXT[phase] or phase
	if phase == "Showtime" then
		local match = State.round("Match")
		if type(match) == "string" and match ~= "" then
			text = `SHOWTIME · {match}`
		end
	elseif phase == "Dressing" then
		local ready = State.round("Ready")
		if type(ready) == "string" and ready ~= "" then
			text = `Get dressed! · Ready {ready}`
		end
	end
	phaseLabel.Text = text
	if theme then
		local spotlight = State.round("Spotlight") == theme.Id
		themeLabel.Text = if spotlight then `★ {theme.Name} · Spotlight x2` else theme.Name
		themeLabel.TextColor3 = if spotlight then C.Gold else C.Aqua
	else
		themeLabel.Text = "Catwalk Clash"
		themeLabel.TextColor3 = C.Aqua
	end
end

local function refreshProfile(profile)
	if lastSparkles and profile.Sparkles > lastSparkles then
		Sounds.play("Sparkle")
		Ui.pop(sparklesLabel)
	end
	lastSparkles = profile.Sparkles
	sparklesLabel.Text = Ui.sparkles(profile.Sparkles)
	scoreLabel.Text = `Style {profile.StyleScore}`
	rankLabel.Text = profile.Rank
end

-- Adds a menu button down the left side.
function Hud.addButton(order: number, icon: string, name: string, color: Color3, onClick: () -> ()): TextButton
	local button = Ui.button(menu, "", color, onClick, {
		Size = UDim2.fromOffset(58, 58),
		LayoutOrder = order,
	})
	Ui.label(button, {
		Text = icon,
		TextSize = 26,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 3),
		Font = Ui.Fonts.Title,
	})
	Ui.label(button, {
		Text = name,
		TextSize = 11,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -18),
	})
	return button
end

function Hud.mount()
	gui = Ui.screen("Hud", 2)

	-- The round pill.
	pill = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(330, 58),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.08,
	}, gui)
	Ui.corner(pill, 29)
	Ui.stroke(pill, C.Pink, 2)
	Ui.autoscale(pill)
	phaseLabel = Ui.label(pill, {
		Font = Ui.Fonts.Title,
		TextSize = 18,
		Position = UDim2.fromOffset(18, 6),
		Size = UDim2.new(1, -96, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	themeLabel = Ui.label(pill, {
		TextSize = 14,
		Position = UDim2.fromOffset(18, 30),
		Size = UDim2.new(1, -96, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Aqua,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local clockBack = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(72, 42),
		BackgroundColor3 = C.Pink,
	}, pill)
	Ui.corner(clockBack, 21)
	clockLabel = Ui.label(clockBack, {
		Font = Ui.Fonts.Title,
		TextSize = 22,
		Size = UDim2.fromScale(1, 1),
		Text = "0:00",
	})

	-- Sparkles and Style Score.
	local stats = make("Frame", {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(170, 66),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
	}, gui)
	Ui.corner(stats, 14)
	Ui.stroke(stats, C.Gold, 1.5)
	Ui.autoscale(stats)
	sparklesLabel = Ui.label(stats, {
		Font = Ui.Fonts.Title,
		TextSize = 22,
		TextColor3 = C.Gold,
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -16, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Ui.sparkles(0),
	})
	scoreLabel = Ui.label(stats, {
		TextSize = 13,
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(0.5, -10, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Style 1000",
	})
	rankLabel = Ui.label(stats, {
		TextSize = 13,
		Position = UDim2.new(0.5, -6, 0, 34),
		Size = UDim2.new(0.5, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Pink,
		Text = "",
	})

	-- The menu buttons.
	menu = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 10),
		Size = UDim2.fromOffset(58, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, gui)
	Ui.list(menu, false, 8)
	Ui.autoscale(menu)

	State.onRound(function(name)
		if name == "Phase" or name == "Theme" or name == "Match" or name == "Ready" or name == "Spotlight" then
			refreshPill()
			if name == "Phase" then
				Ui.pop(pill)
			end
		end
	end)
	State.onProfile(refreshProfile)
	refreshPill()

	RunService.RenderStepped:Connect(function()
		local left = State.timeLeft()
		local second = math.ceil(left)
		if second ~= lastSecond then
			lastSecond = second
			clockLabel.Text = Ui.time(left)
			local urgent = State.phase() == "Dressing" and second <= 10 and second > 0
			if urgent then
				Sounds.play("Tick")
				TweenService:Create(clockBack, TweenInfo.new(0.2), { BackgroundColor3 = C.Red }):Play()
			else
				clockBack.BackgroundColor3 = C.Pink
			end
		end
	end)
end

-- Hides the menu (during the runway walk, for example) or shows it.
function Hud.setMenuVisible(visible: boolean)
	if menu then
		menu.Visible = visible
	end
end

return Hud
