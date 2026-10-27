-- The heads-up display: coins, income and visitors, plus a hint to claim a
-- plot until the player has one. Buying happens on the plot itself, by
-- stepping on buy buttons, so there is no upgrade menu here. It only shows
-- what the server reports; there is deliberately no shop here yet either, as
-- the brief wants players to see progress before any shop appears.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Format)

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

local gui = make("ScreenGui", { Name = "Hud", ResetOnSpawn = false })

local topBar = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(260, 84),
	BackgroundColor3 = Color3.fromRGB(24, 24, 36),
	BackgroundTransparency = 0.2,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, topBar)

local coinsLabel = make("TextLabel", {
	Size = UDim2.fromScale(1, 0.5),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 214, 102),
}, topBar)

local incomeLabel = make("TextLabel", {
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromScale(1, 0.27),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
}, topBar)

local visitorsLabel = make("TextLabel", {
	Position = UDim2.fromScale(0, 0.77),
	Size = UDim2.fromScale(1, 0.23),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(200, 200, 230),
}, topBar)

local claimHint = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(420, 40),
	BackgroundColor3 = Color3.fromRGB(24, 24, 36),
	BackgroundTransparency = 0.2,
	Font = Enum.Font.GothamMedium,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = Theme.Strings.ClaimHint,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, claimHint)
make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, claimHint)

local function refresh()
	coinsLabel.Text = `{player:GetAttribute("Coins") or 0} {Theme.Strings.Coins}`
	incomeLabel.Text = Theme.Strings.IncomePerSecond:format(math.floor(player:GetAttribute("IncomePerSecond") or 0))
	visitorsLabel.Text = Theme.Strings.VisitorsPerSecond:format(Format.rate(player:GetAttribute("VisitorsPerSecond") or 0))
	claimHint.Visible = player:GetAttribute("HasPlot") ~= true
end

function Hud.mount()
	gui.Parent = player:WaitForChild("PlayerGui")
	for _, name in { "Coins", "IncomePerSecond", "VisitorsPerSecond", "HasPlot" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return Hud
