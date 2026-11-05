-- Everything bought with Sparkles, the Style Pass claims, saved outfits,
-- catalog favourites, settings and the VIP Lounge door. Every request is
-- checked here; the client only asks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Game = require(Config.Game)
local Wardrobe = require(Config.Wardrobe)
local Poses = require(Config.Poses)
local Entrances = require(Config.Entrances)
local Words = require(Config.Words)
local Layout = require(Config.Layout)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local DataService = require(script.Parent.DataService)
local ProfileService = require(script.Parent.ProfileService)
local PurchaseService = require(script.Parent.PurchaseService)
local CatalogService = require(script.Parent.CatalogService)
local LookService = require(script.Parent.LookService)
local Analytics = require(script.Parent.AnalyticsService)

local Remotes = ReplicatedStorage.Remotes

local ShopService = {}

local KIND_CONFIG = { Piece = Wardrobe, Pose = Poses, Entrance = Entrances }

local shopLimiter = RateLimiter.new(Game.Cooldowns.Shop)
local looksLimiter = RateLimiter.new(Game.Cooldowns.Shop)
local favoriteLimiter = RateLimiter.new(0.2)
local settingsLimiter = RateLimiter.new(0.3)
local loungeLimiter = RateLimiter.new(1)

local function getItem(kind: any, id: any): any
	local config = if type(kind) == "string" then KIND_CONFIG[kind] else nil
	if not config or type(id) ~= "string" then
		return nil
	end
	return config.get(id)
end

-- Buys a piece, pose or entrance with Sparkles.
local function onShopBuy(player: Player, request: any)
	if type(request) ~= "table" or not shopLimiter:allow(player) then
		return
	end
	local item = getItem(request.Kind, request.Id)
	if not item or item.Price <= 0 or item.Pass or item.Season then
		return
	end
	if ProfileService.owns(player, request.Kind, item.Id) then
		ProfileService.notify(player, "Info", `You already own {item.Name}.`)
		return
	end
	if not ProfileService.spend(player, item.Price) then
		ProfileService.notify(player, "Deny", `You need {item.Price} Sparkles for {item.Name}.`)
		return
	end
	ProfileService.giveItem(player, request.Kind, item.Id)
	ProfileService.notify(player, "Purchase", `{item.Name} is yours!`, { Item = item.Id })
end

local function onClaimTier(player: Player, request: any)
	if type(request) ~= "table" or not shopLimiter:allow(player) then
		return
	end
	local ok, reason = ProfileService.claimTier(player, request.Tier, request.Track)
	if not ok and reason == "NeedPass" then
		ProfileService.notify(player, "Info", "That reward is on the premium track. Get the Style Pass to claim it.")
	end
end

local function closetSize(player: Player): number
	if ProfileService.hasPass(player, "big_closet") then
		return Game.Looks.ClosetSlots
	end
	return Game.Looks.FreeSlots
end

local function randomName(): { number }
	return { math.random(1, #Words.First), math.random(1, #Words.Second) }
end

local function validIndex(list: { any }, index: any): boolean
	return type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #list
end

-- Saved outfits: Save, Wear, Delete and Rename. Names are picked from two
-- word lists (Config/Words), so nobody types free text into a name.
local function onLooks(player: Player, request: any)
	if type(request) ~= "table" or not looksLimiter:allow(player) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local action = request.Action
	if action == "Save" then
		local dressed = LookService.current(player)
		if not dressed then
			return
		end
		local size = closetSize(player)
		if validIndex(data.Looks, request.Index) then
			data.Looks[request.Index].Look = dressed.Look
		elseif #data.Looks < size then
			table.insert(data.Looks, { Name = randomName(), Look = dressed.Look })
			ProfileService.record(player, "SaveLook", 1)
		else
			local message = if size < Game.Looks.ClosetSlots
				then `Your closet is full ({size} outfits). Big Closet holds {Game.Looks.ClosetSlots}.`
				else "Your closet is full. Replace an outfit to save this one."
			ProfileService.notify(player, "Deny", message)
			return
		end
		ProfileService.notify(player, "Saved", "Outfit saved to your closet!")
		Analytics.event(player, "OutfitSaved", #data.Looks)
	elseif action == "Wear" then
		if validIndex(data.Looks, request.Index) then
			LookService.set(player, data.Looks[request.Index].Look)
		end
	elseif action == "Delete" then
		if validIndex(data.Looks, request.Index) then
			table.remove(data.Looks, request.Index)
		end
	elseif action == "Rename" then
		local name = request.Name
		if
			validIndex(data.Looks, request.Index)
			and type(name) == "table"
			and validIndex(Words.First, name[1])
			and validIndex(Words.Second, name[2])
		then
			data.Looks[request.Index].Name = { name[1], name[2] }
		end
	end
	ProfileService.push(player)
end

-- Catalog favourites, by asset id.
local function onFavorite(player: Player, request: any)
	if type(request) ~= "table" or not favoriteLimiter:allow(player) then
		return
	end
	local data = DataService.get(player)
	local id = request.Id
	if not data or type(id) ~= "number" then
		return
	end
	local index = table.find(data.Favorites, id)
	if request.On then
		if index or #data.Favorites >= Game.Looks.MaxFavorites then
			return
		end
		if CatalogService.item(id) then
			table.insert(data.Favorites, id)
		end
	elseif index then
		table.remove(data.Favorites, index)
	end
	ProfileService.push(player)
end

local function onSettings(player: Player, request: any)
	if type(request) ~= "table" or not settingsLimiter:allow(player) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	for _, name in { "Music", "Effects", "WatchOnly", "ReducedMotion" } do
		if type(request[name]) == "boolean" then
			data.Settings[name] = request[name]
		end
	end
	ProfileService.push(player)
end

-- Takes a VIP up to the lounge, or offers the pass to anyone else.
function ShopService.enterLounge(player: Player)
	if not loungeLimiter:allow(player) then
		return
	end
	if not ProfileService.hasPass(player, "vip") then
		ProfileService.notify(player, "Info", "The VIP Lounge is for VIP pass owners.")
		PurchaseService.prompt(player, "vip")
		return
	end
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(Layout.Lounge.Inside)
	end
end

function ShopService.init()
	Remotes.ShopBuy.OnServerEvent:Connect(onShopBuy)
	Remotes.ClaimTier.OnServerEvent:Connect(onClaimTier)
	Remotes.Looks.OnServerEvent:Connect(onLooks)
	Remotes.Favorite.OnServerEvent:Connect(onFavorite)
	Remotes.Settings.OnServerEvent:Connect(onSettings)
	Remotes.Lounge.OnServerEvent:Connect(function(player)
		ShopService.enterLounge(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in { shopLimiter, looksLimiter, favoriteLimiter, settingsLimiter, loungeLimiter } do
			limiter:forget(player)
		end
	end)
end

return ShopService
