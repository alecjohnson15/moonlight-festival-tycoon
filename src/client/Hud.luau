-- The heads-up display: coins, income, visitors and the next upgrades to buy,
-- each with what it would add per second. It shows what the server reports
-- and sends upgrade requests; the server decides every outcome. There is
-- deliberately no shop here yet: the brief wants players to see progress
-- before any shop appears.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Theme = require(Shared.Config.Theme)
local Earnings = require(Shared.Earnings)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestUpgrade = Remotes:WaitForChild("RequestUpgrade") :: RemoteFunction
local StateSync = Remotes:WaitForChild("StateSync") :: RemoteEvent

local MAX_CHOICES = 3
local STATUS_SECONDS = 2
local AFFORDABLE = Color3.fromRGB(76, 153, 92)
local UNAFFORDABLE = Color3.fromRGB(70, 70, 82)

local Hud = {}

local player = Players.LocalPlayer
local owned: { [string]: boolean } = {}
local buttons: { [string]: TextButton } = {}
local requestPending = false
local statusToken = 0

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function coins(): number
	return player:GetAttribute("Coins") or 0
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

local choices = make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(240, MAX_CHOICES * 64),
	BackgroundTransparency = 1,
}, gui)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, choices)

local statusLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(320, 36),
	BackgroundColor3 = Color3.fromRGB(24, 24, 36),
	BackgroundTransparency = 0.2,
	Font = Enum.Font.GothamMedium,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, statusLabel)

local function showStatus(text: string)
	statusToken += 1
	local token = statusToken
	statusLabel.Text = text
	statusLabel.Visible = true
	task.delay(STATUS_SECONDS, function()
		if statusToken == token then
			statusLabel.Visible = false
		end
	end)
end

local function requestUpgrade(upgradeId: string)
	if requestPending then
		return
	end
	requestPending = true
	local called, ok, reason = pcall(RequestUpgrade.InvokeServer, RequestUpgrade, upgradeId)
	requestPending = false
	if not called then
		showStatus(Theme.Strings.NotLoaded)
	elseif not ok and Theme.Strings[reason] then
		showStatus(Theme.Strings[reason])
	end
end

local function refreshLabels()
	coinsLabel.Text = `{coins()} {Theme.Strings.Coins}`
	incomeLabel.Text = Theme.Strings.IncomePerSecond:format(math.floor(player:GetAttribute("IncomePerSecond") or 0))
	visitorsLabel.Text = Theme.Strings.VisitorsPerSecond:format(Format.rate(player:GetAttribute("VisitorsPerSecond") or 0))
	for id, button in buttons do
		local upgrade = Progression.find(Balance.Upgrades, id)
		button.BackgroundColor3 = if upgrade and coins() >= upgrade.Cost then AFFORDABLE else UNAFFORDABLE
	end
end

local function rebuildChoices()
	for _, button in buttons do
		button:Destroy()
	end
	table.clear(buttons)

	local available = Progression.available(owned, Balance.Upgrades)
	local income = Earnings.perSecond(owned, Balance)
	for index = 1, math.min(#available, MAX_CHOICES) do
		local upgrade = available[index]
		local cost = if upgrade.Cost == 0 then Theme.Strings.Free else `{upgrade.Cost} {Theme.Strings.Coins}`
		local withUpgrade = table.clone(owned)
		withUpgrade[upgrade.Id] = true
		local gain = Earnings.perSecond(withUpgrade, Balance) - income
		local details = if gain > 0 then `{cost}  {Theme.Strings.UpgradeGain:format(Format.rate(gain))}` else cost
		local button = make("TextButton", {
			Name = upgrade.Id,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 56),
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			Text = `{Theme.Upgrades[upgrade.Id].DisplayName}\n{details}`,
			AutoButtonColor = true,
		}, choices)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, button)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, button)
		button.Activated:Connect(function()
			requestUpgrade(upgrade.Id)
		end)
		buttons[upgrade.Id] = button
	end
	refreshLabels()
end

function Hud.mount()
	gui.Parent = player:WaitForChild("PlayerGui")

	StateSync.OnClientEvent:Connect(function(ownedIds: { string })
		table.clear(owned)
		for _, id in ownedIds do
			owned[id] = true
		end
		rebuildChoices()
	end)
	player:GetAttributeChangedSignal("Coins"):Connect(refreshLabels)
	player:GetAttributeChangedSignal("IncomePerSecond"):Connect(refreshLabels)
	player:GetAttributeChangedSignal("VisitorsPerSecond"):Connect(refreshLabels)
	refreshLabels()
end

return Hud
