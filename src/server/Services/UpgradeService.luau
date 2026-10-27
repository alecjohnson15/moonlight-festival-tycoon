-- Handles upgrade requests. The client only names the upgrade it wants; the
-- server checks it, charges for it and builds it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Progression = require(ReplicatedStorage.Shared.Progression)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)

local Remotes = ReplicatedStorage.Remotes
local RequestUpgrade = Remotes.RequestUpgrade :: RemoteFunction
local StateSync = Remotes.StateSync :: RemoteEvent

local MAX_ID_LENGTH = 64

local UpgradeService = {}

local limiter = RateLimiter.new(0.2)

local function ownedIds(data): { string }
	local ids = {}
	for id in data.Owned do
		table.insert(ids, id)
	end
	return ids
end

local function onRequestUpgrade(player: Player, upgradeId: unknown): (boolean, string?)
	if typeof(upgradeId) ~= "string" or #upgradeId > MAX_ID_LENGTH then
		return false, "BadRequest"
	end
	if not limiter:allow(player) then
		return false, "TooFast"
	end
	local data = DataService.get(player)
	if not data then
		return false, "NotLoaded"
	end

	local ok, reason = Progression.purchase(data, Balance.Upgrades, upgradeId)
	if not ok then
		return false, reason
	end
	PlotService.build(player, upgradeId)
	EconomyService.publish(player)
	StateSync:FireClient(player, ownedIds(data))
	return true, nil
end

function UpgradeService.init()
	RequestUpgrade.OnServerInvoke = onRequestUpgrade
	DataService.onLoaded(function(player, data)
		StateSync:FireClient(player, ownedIds(data))
	end)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return UpgradeService
