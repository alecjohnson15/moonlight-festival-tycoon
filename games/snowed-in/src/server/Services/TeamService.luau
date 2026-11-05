-- What the team shares: the stockpile, the hearth, the upgrades made at the
-- workbench and the pantry of cooked meals. All of it is attributes on
-- ReplicatedStorage.State ("Stock_Wood", "Flame", "Upgrade_SharpAxes",
-- "Pantry_RoastFish" and so on), so every HUD shows it without asking.
--
-- The hearth burns down a little every second of a run, faster at night,
-- and monsters douse it. If its flame reaches zero the run is lost.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Assist = require(ReplicatedStorage.Shared.Assist)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Stock = require(ReplicatedStorage.Shared.Stock)
local Lib = script.Parent.Parent.Lib
local Analytics = require(Lib.Analytics)
local Celebrate = require(Lib.Celebrate)
local Net = require(Lib.Net)
local RateLimiter = require(Lib.RateLimiter)
local RunStats = require(Lib.RunStats)
local GameLoop = require(script.Parent.GameLoop)
local WorldService = require(script.Parent.WorldService)

local State = ReplicatedStorage.State :: Configuration

local TeamService = {}

local stock: Stock.Counts = Stock.empty()
local flame = Balance.Hearth.StartFlame
local level = 1
local upgrades: { [string]: boolean } = {}
local pantry: { [string]: number } = {}
local upgradeCallbacks: { (string) -> () } = {}
local feedLimiter = RateLimiter.new(0.4)

local function publishStock()
	for _, resource in Resources.List do
		State:SetAttribute(`Stock_{resource.Id}`, stock[resource.Id] or 0)
	end
end

local function publishHearth()
	local config = Balance.Hearth.Levels[level]
	State:SetAttribute("Flame", math.floor(flame * 10 + 0.5) / 10)
	State:SetAttribute("MaxFlame", config.MaxFlame)
	State:SetAttribute("HearthLevel", level)
	State:SetAttribute("HearthRadius", config.Radius)
end

local function publishPantry()
	for _, meal in Recipes.Meals do
		State:SetAttribute(`Pantry_{meal.Id}`, pantry[meal.Id] or 0)
	end
end

function TeamService.stock(): Stock.Counts
	return stock
end

function TeamService.add(counts: Stock.Counts)
	Stock.add(stock, counts)
	publishStock()
end

-- Takes a cost from the stockpile. Returns false (and takes nothing) when
-- the team can't afford it.
function TeamService.spend(cost: Stock.Counts): boolean
	if not Stock.spend(stock, cost) then
		return false
	end
	publishStock()
	return true
end

function TeamService.level(): number
	return level
end

function TeamService.radius(): number
	return Balance.Hearth.Levels[level].Radius
end

function TeamService.flame(): number
	return flame
end

function TeamService.setFlame(value: number)
	flame = math.clamp(value, 0, Balance.Hearth.Levels[level].MaxFlame)
	publishHearth()
	if flame <= 0 and GameLoop.isPlaying() then
		Net.notice(nil, "The hearth went out...", "Big")
		GameLoop.lose()
	end
end

function TeamService.douse(amount: number)
	TeamService.setFlame(flame - amount)
end

function TeamService.hasUpgrade(id: string): boolean
	return upgrades[id] == true
end

function TeamService.grantUpgrade(id: string)
	upgrades[id] = true
	State:SetAttribute(`Upgrade_{id}`, true)
	for _, callback in upgradeCallbacks do
		task.spawn(callback, id)
	end
end

function TeamService.onUpgrade(callback: (string) -> ())
	table.insert(upgradeCallbacks, callback)
end

function TeamService.pantry(): { [string]: number }
	return pantry
end

function TeamService.addMeal(mealId: string, portions: number)
	pantry[mealId] = (pantry[mealId] or 0) + portions
	publishPantry()
end

-- Takes one portion of a meal out of the pantry. Returns false if there is
-- none.
function TeamService.takeMeal(mealId: string): boolean
	if (pantry[mealId] or 0) <= 0 then
		return false
	end
	pantry[mealId] -= 1
	publishPantry()
	return true
end

-- Puts everything back to the start of a run.
function TeamService.reset()
	stock = Stock.empty()
	level = 1
	flame = Balance.Hearth.StartFlame
	table.clear(pantry)
	for id in upgrades do
		State:SetAttribute(`Upgrade_{id}`, nil)
	end
	table.clear(upgrades)
	publishStock()
	publishHearth()
	publishPantry()
end

-- What one press of Feed would put on the fire: wood first, then coal.
local function feedCost(): (Stock.Counts?, number)
	local batch = Balance.Hearth.FeedBatch
	if (stock.Wood or 0) >= batch then
		return { Wood = batch }, batch * Balance.Hearth.Fuel.Wood
	elseif (stock.Coal or 0) >= 2 then
		return { Coal = 2 }, 2 * Balance.Hearth.Fuel.Coal
	elseif (stock.Wood or 0) > 0 then
		return { Wood = stock.Wood }, stock.Wood * Balance.Hearth.Fuel.Wood
	end
	return nil, 0
end

local feedPrompt: ProximityPrompt
local upgradePrompt: ProximityPrompt

local function refreshPrompts()
	local cost, gain = feedCost()
	if cost then
		feedPrompt.ActionText = `Feed the fire (+{gain})`
		feedPrompt.ObjectText = `Uses {Stock.describe(cost)} from the stockpile`
	else
		feedPrompt.ActionText = "Feed the fire"
		feedPrompt.ObjectText = "The stockpile has no wood or coal"
	end
	local nextLevel = Balance.Hearth.Levels[level + 1]
	upgradePrompt.Enabled = nextLevel ~= nil and GameLoop.isPlaying()
	if nextLevel then
		upgradePrompt.ActionText = `Build up the hearth (level {level + 1})`
		upgradePrompt.ObjectText = `Pushes the blizzard back. {Stock.describe(nextLevel.Cost)}`
	end
end

local function onFeed(player: Player)
	if not GameLoop.isPlaying() or not feedLimiter:allow(player) then
		return
	end
	local cost, gain = feedCost()
	if not cost then
		Net.notice(player, "The stockpile has no wood or coal. Chop some pines!", "Bad")
		return
	end
	local max = Balance.Hearth.Levels[level].MaxFlame
	if flame >= max - 1 then
		Net.notice(player, "The fire is already roaring.", "Info")
		return
	end
	if TeamService.spend(cost) then
		TeamService.setFlame(flame + gain)
		RunStats.add(player, "Fed", gain)
		Analytics.step(player, "FedHearth")
		Net.fx("Feed", { By = player.UserId })
	end
end

local function onUpgradeHearth(player: Player)
	if not GameLoop.isPlaying() then
		return
	end
	local nextLevel = Balance.Hearth.Levels[level + 1]
	if not nextLevel then
		return
	end
	if not TeamService.spend(nextLevel.Cost) then
		local missing = Stock.missing(stock, nextLevel.Cost)
		Net.notice(player, `Need {Stock.describe(missing or {})} more.`, "Bad")
		return
	end
	level += 1
	TeamService.setFlame(flame + 25)
	publishHearth()
	Net.notice(nil, `{player.DisplayName} built up the hearth! The blizzard pulls back.`, "Big")
	Net.fx("HearthUp", { Level = level })
	Celebrate.milestone("HearthUp")
	refreshPrompts()
end

function TeamService.init()
	local hearth = WorldService.get().Hearth
	local promptPart = hearth:FindFirstChild("Prompt") :: BasePart
	feedPrompt = Instance.new("ProximityPrompt")
	feedPrompt.Name = "Feed"
	feedPrompt.ActionText = "Feed the fire"
	feedPrompt.KeyboardKeyCode = Enum.KeyCode.E
	feedPrompt.HoldDuration = 0.4
	feedPrompt.MaxActivationDistance = 12
	feedPrompt.RequiresLineOfSight = false
	feedPrompt.Parent = promptPart
	feedPrompt.Triggered:Connect(onFeed)

	upgradePrompt = Instance.new("ProximityPrompt")
	upgradePrompt.Name = "Upgrade"
	upgradePrompt.KeyboardKeyCode = Enum.KeyCode.R
	upgradePrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	upgradePrompt.HoldDuration = 1
	upgradePrompt.MaxActivationDistance = 12
	upgradePrompt.RequiresLineOfSight = false
	upgradePrompt.UIOffset = Vector2.new(0, 80)
	upgradePrompt.Parent = promptPart
	upgradePrompt.Triggered:Connect(onUpgradeHearth)

	State:GetAttributeChangedSignal("Stock_Wood"):Connect(refreshPrompts)
	State:GetAttributeChangedSignal("Stock_Coal"):Connect(refreshPrompts)
	GameLoop.onPhase(function(phase)
		if phase == "Intermission" or phase == "Waiting" then
			TeamService.reset()
		end
		refreshPrompts()
	end)
	TeamService.reset()
	refreshPrompts()
	Players.PlayerRemoving:Connect(function(player)
		feedLimiter:forget(player)
	end)
end

function TeamService.start()
	-- The fire burns down a little every second of a run.
	while true do
		task.wait(1)
		if GameLoop.isPlaying() then
			local burn = if GameLoop.isNight()
				then Balance.Hearth.BurnPerSecondNight
				else Balance.Hearth.BurnPerSecondDay
			TeamService.setFlame(flame - burn * Assist.burn(#Players:GetPlayers()))
		end
	end
end

return TeamService
