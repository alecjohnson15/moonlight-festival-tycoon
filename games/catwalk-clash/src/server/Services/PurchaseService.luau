-- Sells the Robux items in Config/Catalog. The server opens purchase prompts
-- itself, only when a player asks, and never for something they already
-- own. A developer product is confirmed only once its grant is saved, and
-- the receipt ledger in the save stops a retried receipt from granting
-- twice. ProfileService says what a product grants (setGrant) and listens
-- for ownership changes.
--
-- In Studio every game pass counts as owned, so everything can be tried on;
-- the live game never does that.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Season = require(ReplicatedStorage.Shared.Config.Season)
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
local grant: ((Player, any, any) -> ())? = nil
local inStudio = RunService:IsStudio()

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

-- Runs callback(player, itemId) when a player's game passes change: with the
-- pass id after they buy one, and with nil once their passes have been
-- checked on joining.
function PurchaseService.onOwnershipChanged(callback: (Player, string?) -> ())
	table.insert(ownershipCallbacks, callback)
end

-- Sets what happens when a developer product is bought: grant(player, item,
-- save) changes the save; it must not yield.
function PurchaseService.setGrant(callback: (Player, any, any) -> ())
	grant = callback
end

-- Whether the player owns a game pass, by its id in Config/Catalog.
function PurchaseService.ownsPass(player: Player, passId: string): boolean
	if inStudio then
		return itemsById[passId] ~= nil and itemsById[passId].Kind == "GamePass"
	end
	local owned = passesOwned[player]
	return owned ~= nil and owned[passId] == true
end

-- Every pass the player owns, as a set of ids.
function PurchaseService.passes(player: Player): { [string]: boolean }
	local set = {}
	for id, item in itemsById do
		if item.Kind == "GamePass" and PurchaseService.ownsPass(player, id) then
			set[id] = true
		end
	end
	return set
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
	if not data or not grant then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local granted = ReceiptLedger.grantOnce(data.Receipts, tostring(receipt.PurchaseId), os.time(), function()
		(grant :: any)(player, item, data)
	end)
	if granted then
		ownershipChanged(player, item.Id)
	end

	-- If this save fails, Roblox retries the receipt later and the ledger entry
	-- above stops the retry from granting again.
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

local function onRequestPurchase(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" or not promptLimiter:allow(player) then
		return
	end
	local item = itemsById[itemId]
	if not item then
		return
	end
	-- A season's pass is never sold once its season is over.
	if itemId == Season.Pass and os.time() >= Season.Ends then
		return
	end
	if item.Kind == "GamePass" and item.PassId ~= 0 and not PurchaseService.ownsPass(player, itemId) then
		MarketplaceService:PromptGamePassPurchase(player, item.PassId)
	elseif item.Kind == "DeveloperProduct" and item.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, item.ProductId)
	end
end

-- Opens the prompt for a pass, for the VIP gate and other in-world doors.
function PurchaseService.prompt(player: Player, itemId: string)
	onRequestPurchase(player, itemId)
end

function PurchaseService.ready(player: Player): boolean
	return passesChecked[player] == true
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
