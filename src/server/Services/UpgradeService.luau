-- Buys upgrades when an owner steps on a buy button on their plot. The server
-- checks the purchase, charges for it and builds it; touching a button only
-- names the upgrade the player wants.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Progression = require(ReplicatedStorage.Shared.Progression)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local AttractionService = require(script.Parent.AttractionService)
local CosmeticService = require(script.Parent.CosmeticService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local ProductionService = require(script.Parent.ProductionService)

local UpgradeService = {}

-- Touched fires many times while a player stands on a button.
local limiter = RateLimiter.new(0.25)

local function onButtonStepped(player: Player, upgradeId: string)
	if not limiter:allow(player) then
		return
	end
	local data = DataService.get(player)
	if not data or not Progression.purchase(data, Balance.Upgrades, upgradeId) then
		return
	end
	PlotService.build(player, upgradeId, true)
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
	end)
end

return UpgradeService
