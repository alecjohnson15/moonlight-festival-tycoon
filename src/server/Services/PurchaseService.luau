-- Sells the cosmetic catalog. The server opens purchase prompts itself, after
-- checking the item is set up and not already owned. A developer product is
-- confirmed only once its grant is saved, and the receipt ledger in the save
-- stops a retried receipt from granting twice. CosmeticService listens for
-- ownership changes to put new items on.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Lib = script.Parent.Parent.Lib
local RateLimiter = require(Lib.RateLimiter)
local ReceiptLedger = require(Lib.ReceiptLedger)
local DataService = require(script.Parent.DataService)

local RequestPurchase = ReplicatedStorage.Remotes.RequestPurchase :: RemoteEvent

local RECEIPT_WAIT_SECONDS = 30

local PurchaseService = {}

local itemsById = {}
local itemsByProductId = {}
local itemsByPassId = {}
local passesOwned: { [Player]: { [string]: boolean } } = {}
local passesChecked: { [Player]: boolean } = {}
local ownershipCallbacks: { (Player, string?) -> () } = {}
local promptLimiter = RateLimiter.new(1)

for _, item in Catalog do
	itemsById[item.Id] = item
	if item.Kind == "DeveloperProduct" and item.ProductId ~= 0 then
		itemsByProductId[item.ProductId] = item
	elseif item.Kind == "GamePass" and item.PassId ~= 0 then
		itemsByPassId[item.PassId] = item
	end
end

local function ownershipChanged(player: Player, itemId: string?)
	for _, callback in ownershipCallbacks do
		task.spawn(callback, player, itemId)
	end
end

-- Runs callback(player, itemId) when what a player owns changes: with the
-- item's id after they buy it, and with nil once their game passes have been
-- checked on joining.
function PurchaseService.onOwnershipChanged(callback: (Player, string?) -> ())
	table.insert(ownershipCallbacks, callback)
end

-- Whether the player's game passes have been checked since they joined, so
-- owns() can be trusted for them.
function PurchaseService.ready(player: Player): boolean
	return passesChecked[player] == true
end

function PurchaseService.owns(player: Player, itemId: string): boolean
	local data = DataService.get(player)
	if data and data.Cosmetics[itemId] then
		return true
	end
	local passes = passesOwned[player]
	return passes ~= nil and passes[itemId] == true
end

local function processReceipt(receipt)
	local item = itemsByProductId[receipt.ProductId]
	if not item then
		warn(`Receipt for unknown product {receipt.ProductId}; leaving it for a later retry`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.waitFor(player, RECEIPT_WAIT_SECONDS)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local granted = ReceiptLedger.grantOnce(data.Receipts, tostring(receipt.PurchaseId), os.time(), function()
		data.Cosmetics[item.Id] = true
	end)
	if granted then
		ownershipChanged(player, item.Id)
	end

	-- If this save fails, Roblox retries the receipt later and the ledger entry
	-- above stops the retry from granting the item again.
	if DataService.saveNow(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function loadPasses(player: Player)
	local owned = {}
	passesOwned[player] = owned
	for passId, item in itemsByPassId do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok and result then
			owned[item.Id] = true
		elseif not ok then
			warn(`Could not check game pass {passId} for {player.UserId}: {result}`)
		end
	end
	if player.Parent then
		passesChecked[player] = true
		ownershipChanged(player, nil)
	end
end

-- Prompts open only when the player asks, never on their own, and never for
-- something they already own.
local function onRequestPurchase(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" or not promptLimiter:allow(player) then
		return
	end
	local item = itemsById[itemId]
	if not item or PurchaseService.owns(player, itemId) then
		return
	end
	if item.Kind == "GamePass" and item.PassId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, item.PassId)
	elseif item.Kind == "DeveloperProduct" and item.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, item.ProductId)
	end
end

function PurchaseService.init()
	MarketplaceService.ProcessReceipt = processReceipt
	RequestPurchase.OnServerEvent:Connect(onRequestPurchase)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local item = itemsByPassId[passId]
		local owned = passesOwned[player]
		if purchased and item and owned and not owned[item.Id] then
			owned[item.Id] = true
			ownershipChanged(player, item.Id)
		end
	end)

	Players.PlayerAdded:Connect(loadPasses)
	Players.PlayerRemoving:Connect(function(player)
		passesOwned[player] = nil
		passesChecked[player] = nil
		promptLimiter:forget(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPasses, player)
	end
end

return PurchaseService
