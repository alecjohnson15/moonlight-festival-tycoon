-- Owns every coin change. Income is paid on a server tick and the serve task
-- is rewarded here; nothing a client sends can set or add coins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Progression = require(ReplicatedStorage.Shared.Progression)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local DataService = require(script.Parent.DataService)

local EconomyService = {}

-- Fractions of a coin earned between ticks, so odd income rates aren't lost.
local carry: { [Player]: number } = {}
local serveLimiter = RateLimiter.new(Balance.ServeTask.CooldownSeconds)

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

-- Pushes coins and income to the player's attributes, which replicate to
-- their client for the HUD.
function EconomyService.publish(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("IncomePerSecond", Progression.incomePerSecond(data.Owned, Balance.Upgrades))
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

-- Called when the player uses the serve prompt on their own starter stall.
function EconomyService.rewardServe(player: Player): boolean
	local data = DataService.get(player)
	if not data or not serveLimiter:allow(player) then
		return false
	end
	data.Stats.ServeCount += 1
	return EconomyService.addCoins(player, Balance.ServeTask.Reward)
end

function EconomyService.init()
	DataService.onLoaded(function(player)
		EconomyService.publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		carry[player] = nil
		serveLimiter:forget(player)
	end)
end

function EconomyService.start()
	while true do
		local elapsed = task.wait(Balance.IncomeTickSeconds)
		for _, player in Players:GetPlayers() do
			local data = DataService.get(player)
			if data then
				local earned = Progression.incomePerSecond(data.Owned, Balance.Upgrades) * elapsed
					+ (carry[player] or 0)
				local whole = math.floor(earned)
				carry[player] = earned - whole
				if whole > 0 then
					EconomyService.addCoins(player, whole)
				end
			end
		end
	end
end

return EconomyService
