-- The heads-up display: a cash counter with a moon coin that counts up to the
-- player's coins, with +N popping off it as they earn, their income and
-- visitors per second, a hint to claim a plot until they have one, and a
-- button for the music. Buying happens on the plot itself, by stepping on buy
-- buttons, so there is no upgrade menu here. It only shows what the server
-- reports; there is deliberately no shop here yet either, as the brief wants
-- players to see progress before any shop appears.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Format)
local Sounds = require(script.Parent.Sounds)

local GOLD = Color3.fromRGB(255, 205, 90)
local PANEL = Color3.fromRGB(26, 18, 40)
local TEXT = Color3.fromRGB(255, 244, 214)
local GAIN = Color3.fromRGB(150, 255, 140)
local SPEND = Color3.fromRGB(255, 120, 120)
local FONT = Enum.Font.FredokaOne
local POP = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
local FLOAT_SECONDS = 1.1
-- Earnings this close together share one popup.
local MERGE_SECONDS = 0.3

local Hud = {}

local player = Players.LocalPlayer

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function round(parent: Instance, radius: UDim?)
	make("UICorner", { CornerRadius = radius or UDim.new(1, 0) }, parent)
end

local function outline(parent: Instance, color: Color3, thickness: number)
	make("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local gui = make("ScreenGui", { Name = "Hud", ResetOnSpawn = false })

-- The cash counter.
local cash = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(250, 56),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.1,
}, gui)
round(cash)
outline(cash, GOLD, 2.5)
make("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(70, 46, 100), Color3.fromRGB(26, 18, 40)),
}, cash)
local cashScale = make("UIScale", {}, cash)

-- A moon coin: a gold disc with a pale crescent on it.
local coin = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 6, 0.5, 0),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = GOLD,
}, cash)
round(coin)
outline(coin, Color3.fromRGB(150, 95, 20), 2)
make("UIGradient", {
	Rotation = 45,
	Color = ColorSequence.new(Color3.fromRGB(255, 236, 150), Color3.fromRGB(235, 160, 40)),
}, coin)
local moon = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(24, 24),
	BackgroundColor3 = Color3.fromRGB(255, 250, 225),
}, coin)
round(moon)
local shade = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 6, 0.5, -4),
	Size = UDim2.fromOffset(22, 22),
	BackgroundColor3 = Color3.fromRGB(245, 190, 70),
}, coin)
round(shade)

local amount = make("TextLabel", {
	Position = UDim2.fromOffset(58, 6),
	Size = UDim2.new(1, -70, 1, -12),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = TEXT,
	Text = "0",
}, cash)
make("UIStroke", { Color = Color3.fromRGB(60, 30, 10), Thickness = 1.5 }, amount)

-- Income and visitors under the counter.
local rates = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(230, 24),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.25,
}, gui)
round(rates)
local function rateLabel(x: number, color: Color3): TextLabel
	return make("TextLabel", {
		Position = UDim2.fromScale(x, 0),
		Size = UDim2.fromScale(0.5, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = color,
	}, rates)
end
local incomeLabel = rateLabel(0, GAIN)
local visitorsLabel = rateLabel(0.5, Color3.fromRGB(200, 185, 255))
make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, rates)

local claimHint = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(440, 44),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = TEXT,
	Text = Theme.Strings.ClaimHint,
}, gui)
round(claimHint, UDim.new(0, 12))
outline(claimHint, GOLD, 2)
make("UIPadding", {
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
	PaddingTop = UDim.new(0, 6),
	PaddingBottom = UDim.new(0, 6),
}, claimHint)
local hintScale = make("UIScale", {}, claimHint)

local musicButton = make("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -12),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = TEXT,
	Text = "♪",
	Visible = false,
}, gui)
round(musicButton)
outline(musicButton, GOLD, 2)
local musicNote = make("TextLabel", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(1, 8, 0.5, 0),
	Size = UDim2.fromOffset(110, 24),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = TEXT,
	TextTransparency = 1,
}, musicButton)

local shown = 0
local target = 0
-- Whether the save's coins have arrived, so loading them doesn't pop up as
-- earnings.
local loaded = false
local lastPopup: TextLabel?
local lastPopupAt = 0
local lastPopupAmount = 0

-- A "+N" (or "-N" for spending) that floats up off the counter and fades.
local function popup(delta: number)
	local now = os.clock()
	if delta > 0 and lastPopup and lastPopup.Parent and now - lastPopupAt < MERGE_SECONDS then
		lastPopupAmount += delta
		lastPopup.Text = `+{Format.whole(lastPopupAmount)}`
		return
	end
	local label = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 8, 0.5, 0),
		Size = UDim2.fromOffset(140, 30),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if delta > 0 then GAIN else SPEND,
		TextStrokeTransparency = 0.3,
		Text = if delta > 0 then `+{Format.whole(delta)}` else `-{Format.whole(-delta)}`,
	}, cash)
	if delta > 0 then
		lastPopup, lastPopupAt, lastPopupAmount = label, now, delta
	end
	local info = TweenInfo.new(FLOAT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, {
		Position = UDim2.new(1, 8, 0.5, 40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(FLOAT_SECONDS, function()
		label:Destroy()
	end)
end

local function onCoins()
	local coins = player:GetAttribute("Coins") or 0
	if not loaded then
		loaded, shown, target = true, coins, coins
		return
	end
	local delta = coins - target
	target = coins
	if delta > 0 then
		popup(delta)
		TweenService:Create(cashScale, POP, { Scale = 1.08 }):Play()
	elseif delta < 0 then
		-- Spending shows straight away; earning counts up.
		popup(delta)
		shown = coins
		Sounds.play("Purchase")
	end
end

local function refresh()
	incomeLabel.Text = Theme.Strings.IncomePerSecond:format(math.floor(player:GetAttribute("IncomePerSecond") or 0))
	visitorsLabel.Text =
		Theme.Strings.VisitorsPerSecond:format(Format.rate(player:GetAttribute("VisitorsPerSecond") or 0))
	claimHint.Visible = player:GetAttribute("HasPlot") ~= true
end

local function onRenderStep(dt: number)
	if shown ~= target then
		shown += (target - shown) * (1 - math.exp(-dt * 8))
		if math.abs(target - shown) < 0.5 then
			shown = target
		end
	end
	amount.Text = Format.whole(shown)
	if claimHint.Visible then
		hintScale.Scale = 1 + math.sin(os.clock() * 3) * 0.03
	end
end

local function showMusic()
	local on = Sounds.loopsOn()
	musicButton.TextTransparency = if on then 0 else 0.6
	musicNote.Text = if on then Theme.Strings.MusicOn else Theme.Strings.MusicOff
	musicNote.TextTransparency = 0
	TweenService:Create(musicNote, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
end

function Hud.mount()
	gui.Parent = player:WaitForChild("PlayerGui")
	loaded = player:GetAttribute("Coins") ~= nil
	target = player:GetAttribute("Coins") or 0
	shown = target
	player:GetAttributeChangedSignal("Coins"):Connect(onCoins)
	for _, name in { "IncomePerSecond", "VisitorsPerSecond", "HasPlot" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	player:GetAttributeChangedSignal("HasPlot"):Connect(function()
		if player:GetAttribute("HasPlot") == true then
			Sounds.play("Claim")
		end
	end)
	refresh()

	musicButton.Visible = Sounds.hasLoops()
	musicButton.Activated:Connect(function()
		Sounds.setLoops(not Sounds.loopsOn())
		showMusic()
	end)
	RunService.RenderStepped:Connect(onRenderStep)
end

return Hud
