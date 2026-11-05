-- Sells the game passes in Config/Catalog. Every pass is a fixed thing:
-- named cosmetics, the Moon Pass premium track, the VIP lounge or extra
-- emotes. There are no developer products, so nothing bought with Robux is
-- ever random and nothing gives coins or crates.
--
-- What a player owns is asked of Roblox each time they join and kept here
-- for the session, never stored in the save. The server opens purchase
-- prompts itself, after checking the pass is set up and not already owned.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local RequestPurchase = ReplicatedStorage.Remotes.RequestPurchase :: RemoteEvent

local PurchaseService = {}

local productsById = {}
local productsByPassId = {}
local owned: { [Player]: { [string]: boolean } } = {}
local checked: { [Player]: boolean } = {}
local callbacks: { (Player, string?) -> () } = {}
local promptLimiter = RateLimiter.new(1)

for _, product in Catalog do
	productsById[product.Id] = product
	if product.PassId ~= 0 then
		productsByPassId[product.PassId] = product
	end
end

local function changed(player: Player, productId: string?)
	for _, callback in callbacks do
		task.spawn(callback, player, productId)
	end
end

-- Runs callback(player, productId) when what a player owns changes: with
-- the pass's id after they buy it, and with nil once their passes have been
-- checked on joining.
function PurchaseService.onChanged(callback: (Player, string?) -> ())
	table.insert(callbacks, callback)
end

function PurchaseService.ready(player: Player): boolean
	return checked[player] == true
end

function PurchaseService.owns(player: Player, productId: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[productId] == true
end

-- Whether the player has a perk ("MoonPass", "VIP" or "Emotes").
function PurchaseService.hasPerk(player: Player, perk: string): boolean
	for productId in owned[player] or {} do
		local product = productsById[productId]
		if product and product.Perk == perk then
			return true
		end
	end
	return false
end

-- The cosmetics the player's passes give, as item id to true, for
-- Rules/Inventory's extra.
function PurchaseService.items(player: Player): { [string]: boolean }
	local items = {}
	for productId in owned[player] or {} do
		local product = productsById[productId]
		if product then
			for _, itemId in product.Items do
				items[itemId] = true
			end
		end
	end
	return items
end

-- The ids of every pass the player owns, for the shop.
function PurchaseService.list(player: Player): { string }
	local list = {}
	for productId in owned[player] or {} do
		table.insert(list, productId)
	end
	table.sort(list)
	return list
end

local function check(player: Player)
	local passes = {}
	owned[player] = passes
	for passId, product in productsByPassId do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok and result then
			passes[product.Id] = true
		elseif not ok then
			warn(`Could not check game pass {passId} for {player.UserId}: {result}`)
		end
	end
	if player.Parent then
		checked[player] = true
		changed(player, nil)
	end
end

local function onRequest(player: Player, productId: unknown)
	if typeof(productId) ~= "string" or not promptLimiter:allow(player) then
		return
	end
	local product = productsById[productId]
	if not product or product.PassId == 0 or PurchaseService.owns(player, productId) then
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, product.PassId)
end

function PurchaseService.init()
	RequestPurchase.OnServerEvent:Connect(onRequest)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local product = productsByPassId[passId]
		local passes = owned[player]
		if purchased and product and passes and not passes[product.Id] then
			passes[product.Id] = true
			changed(player, product.Id)
		end
	end)
	Players.PlayerAdded:Connect(check)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		checked[player] = nil
		promptLimiter:forget(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
end

return PurchaseService
