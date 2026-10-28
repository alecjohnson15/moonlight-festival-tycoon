-- Owns every coin change. ProductionService and AttractionService pay income
-- through addCoins on their server ticks, and UpgradeService spends through
-- Progression; nothing a client sends can set or add coins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Earnings = require(ReplicatedStorage.Shared.Earnings)
local DataService = require(script.Parent.DataService)

local EconomyService = {}

local function setLeaderstat(player: Player, coins: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		local value = Instance.new("IntValue")
		value.Name = "Coins"
		value.Parent = leaderstats
		leaderstats.Parent = player
	end
	local value = leaderstats:FindFirstChild("Coins") :: IntValue
	value.Value = coins
end

-- Pushes coins, income, visitors and purchases to the player's attributes,
-- which replicate to their client for the HUD and the guide.
function EconomyService.publish(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("IncomePerSecond", Earnings.perSecond(data.Owned, Balance))
	player:SetAttribute("VisitorsPerSecond", Earnings.visitorsPerSecond(data.Owned, Balance))
	-- How many upgrades they own, so the client's guide knows how far in
	-- they are.
	local purchases = 0
	for _ in data.Owned do
		purchases += 1
	end
	player:SetAttribute("Purchases", purchases)
	setLeaderstat(player, data.Coins)
end

function EconomyService.addCoins(player: Player, amount: number): boolean
	assert(amount >= 0 and amount == math.floor(amount), "coin amounts must be whole and positive")
	local data = DataService.get(player)
	if not data then
		return false
	end
	data.Coins += amount
	data.LifetimeCoins += amount
	player:SetAttribute("Coins", data.Coins)
	setLeaderstat(player, data.Coins)
	return true
end

function EconomyService.init()
	DataService.onLoaded(function(player)
		EconomyService.publish(player)
	end)
end

return EconomyService
