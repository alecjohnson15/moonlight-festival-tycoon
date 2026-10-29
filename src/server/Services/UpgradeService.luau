-- Buys upgrades when an owner steps on a buy button on their plot. The server
-- checks the purchase, charges for it and builds it; touching a button only
-- names the upgrade the player wants. Through the Notice remote, a player who
-- steps on a pad they can't afford yet is told how many more coins it needs,
-- and one who buys something is told how much more it earns them a second.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Earnings = require(ReplicatedStorage.Shared.Earnings)
local Progression = require(ReplicatedStorage.Shared.Progression)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local AttractionService = require(script.Parent.AttractionService)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local ProductionService = require(script.Parent.ProductionService)

local Notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local UpgradeService = {}

-- Touched fires many times while a player stands on a button.
local limiter = RateLimiter.new(0.25)
-- And a player waiting on a pad they can't afford hears so once in a while.
local shortLimiter = RateLimiter.new(2.5)

local upgradesById = {}
for _, upgrade in Balance.Upgrades do
	upgradesById[upgrade.Id] = upgrade
end

local function onButtonStepped(player: Player, upgradeId: string)
	if not limiter:allow(player) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local before = Earnings.perSecond(data.Owned, Balance)
	local bought, reason = Progression.purchase(data, Balance.Upgrades, upgradeId)
	if not bought then
		local upgrade = upgradesById[upgradeId]
		if reason == "TooExpensive" and upgrade and shortLimiter:allow(player) then
			Notice:FireClient(player, { Kind = "Short", Upgrade = upgradeId, Need = upgrade.Cost - data.Coins })
		end
		return
	end
	PlotService.build(player, upgradeId, true)
	local upgrade = upgradesById[upgradeId]
	Notice:FireClient(player, {
		Kind = "Built",
		Station = upgrade.Building or upgradeId,
		Gain = Earnings.perSecond(data.Owned, Balance) - before,
	})
	PlotService.refreshButtons(player, true)
	EconomyService.publish(player)
	ProductionService.refresh(player)
	AttractionService.refresh(player)
	CosmeticService.refresh(player)
end

function UpgradeService.init()
	PlotService.onButtonStepped(onButtonStepped)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
		shortLimiter:forget(player)
	end)
end

return UpgradeService
