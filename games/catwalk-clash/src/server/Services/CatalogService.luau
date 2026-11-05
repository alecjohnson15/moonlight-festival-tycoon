-- The Roblox catalog inside the wardrobe: players search for accessories and
-- layered clothing made by UGC creators, try them on for free during the
-- round, and can buy any of them from Roblox. A sale made in the game pays
-- the creator and gives the game its affiliate share, so every outfit on the
-- runway helps creators earn.
--
-- The server checks every catalog item before a character wears it: it must
-- be an accessory or layered clothing type (never a body, head or gear), and
-- its details come from Roblox, not from the client.

local AvatarEditorService = game:GetService("AvatarEditorService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Game = require(ReplicatedStorage.Shared.Config.Game)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)

local Remotes = ReplicatedStorage.Remotes
local CatalogSearch = Remotes.CatalogSearch :: RemoteFunction
local CatalogBuy = Remotes.CatalogBuy :: RemoteEvent

local CatalogService = {}

export type Item = {
	Id: number,
	Name: string,
	Type: Enum.AccessoryType,
	Layered: boolean,
	Creator: string,
}

-- Asset types a look may hold, with the accessory type each becomes.
local ALLOWED: { [number]: { Type: Enum.AccessoryType, Layered: boolean } } = {
	[Enum.AvatarAssetType.Hat.Value] = { Type = Enum.AccessoryType.Hat, Layered = false },
	[Enum.AvatarAssetType.HairAccessory.Value] = { Type = Enum.AccessoryType.Hair, Layered = false },
	[Enum.AvatarAssetType.FaceAccessory.Value] = { Type = Enum.AccessoryType.Face, Layered = false },
	[Enum.AvatarAssetType.NeckAccessory.Value] = { Type = Enum.AccessoryType.Neck, Layered = false },
	[Enum.AvatarAssetType.ShoulderAccessory.Value] = { Type = Enum.AccessoryType.Shoulder, Layered = false },
	[Enum.AvatarAssetType.FrontAccessory.Value] = { Type = Enum.AccessoryType.Front, Layered = false },
	[Enum.AvatarAssetType.BackAccessory.Value] = { Type = Enum.AccessoryType.Back, Layered = false },
	[Enum.AvatarAssetType.WaistAccessory.Value] = { Type = Enum.AccessoryType.Waist, Layered = false },
	[Enum.AvatarAssetType.TShirtAccessory.Value] = { Type = Enum.AccessoryType.TShirt, Layered = true },
	[Enum.AvatarAssetType.ShirtAccessory.Value] = { Type = Enum.AccessoryType.Shirt, Layered = true },
	[Enum.AvatarAssetType.PantsAccessory.Value] = { Type = Enum.AccessoryType.Pants, Layered = true },
	[Enum.AvatarAssetType.JacketAccessory.Value] = { Type = Enum.AccessoryType.Jacket, Layered = true },
	[Enum.AvatarAssetType.SweaterAccessory.Value] = { Type = Enum.AccessoryType.Sweater, Layered = true },
	[Enum.AvatarAssetType.ShortsAccessory.Value] = { Type = Enum.AccessoryType.Shorts, Layered = true },
	[Enum.AvatarAssetType.LeftShoeAccessory.Value] = { Type = Enum.AccessoryType.LeftShoe, Layered = true },
	[Enum.AvatarAssetType.RightShoeAccessory.Value] = { Type = Enum.AccessoryType.RightShoe, Layered = true },
	[Enum.AvatarAssetType.DressSkirtAccessory.Value] = { Type = Enum.AccessoryType.DressSkirt, Layered = true },
}

-- Order layered clothing goes on in, innermost first.
local LAYER_ORDER: { [Enum.AccessoryType]: number } = {
	[Enum.AccessoryType.TShirt] = 1,
	[Enum.AccessoryType.Shirt] = 2,
	[Enum.AccessoryType.Pants] = 3,
	[Enum.AccessoryType.Shorts] = 4,
	[Enum.AccessoryType.DressSkirt] = 5,
	[Enum.AccessoryType.Sweater] = 6,
	[Enum.AccessoryType.Jacket] = 7,
	[Enum.AccessoryType.LeftShoe] = 8,
	[Enum.AccessoryType.RightShoe] = 8,
}

-- The wardrobe's catalog categories and the asset types each searches.
CatalogService.Categories = {
	Hats = { Enum.AvatarAssetType.Hat },
	Hair = { Enum.AvatarAssetType.HairAccessory },
	Face = { Enum.AvatarAssetType.FaceAccessory },
	Neck = { Enum.AvatarAssetType.NeckAccessory, Enum.AvatarAssetType.ShoulderAccessory },
	Back = { Enum.AvatarAssetType.BackAccessory, Enum.AvatarAssetType.WaistAccessory },
	Front = { Enum.AvatarAssetType.FrontAccessory },
	Tops = {
		Enum.AvatarAssetType.TShirtAccessory,
		Enum.AvatarAssetType.ShirtAccessory,
		Enum.AvatarAssetType.SweaterAccessory,
	},
	Jackets = { Enum.AvatarAssetType.JacketAccessory },
	Bottoms = { Enum.AvatarAssetType.PantsAccessory, Enum.AvatarAssetType.ShortsAccessory },
	Dresses = { Enum.AvatarAssetType.DressSkirtAccessory },
	Shoes = { Enum.AvatarAssetType.LeftShoeAccessory, Enum.AvatarAssetType.RightShoeAccessory },
}

local SORTS = {
	Popular = Enum.CatalogSortType.Bestselling,
	Relevance = Enum.CatalogSortType.Relevance,
	Favorites = Enum.CatalogSortType.MostFavorited,
	New = Enum.CatalogSortType.RecentlyCreated,
}

local PAGE_SIZE = 30
local MAX_PAGES = 6
local SEARCH_CACHE_SECONDS = 300
local MAX_KEYWORD = 40

local items: { [number]: Item | false } = {}
local loading: { [number]: { thread } } = {}
local searchCache: { [string]: { At: number, Pages: { { any } }, Source: any } } = {}
local searchLimiter = RateLimiter.new(Game.Cooldowns.Search)
local buyLimiter = RateLimiter.new(1)

-- The details of a catalog item, or nil if it can't be worn here. Yields
-- the first time an id is seen; later calls are instant.
function CatalogService.item(assetId: number): Item?
	if type(assetId) ~= "number" or assetId % 1 ~= 0 or assetId <= 0 then
		return nil
	end
	local known = items[assetId]
	if known ~= nil then
		return known or nil
	end
	local waiting = loading[assetId]
	if waiting then
		table.insert(waiting, coroutine.running())
		coroutine.yield()
		return items[assetId] or nil
	end
	loading[assetId] = {}
	local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, assetId, Enum.InfoType.Asset)
	local result: Item | false = false
	if ok and type(info) == "table" then
		local allowed = ALLOWED[info.AssetTypeId]
		if allowed then
			result = {
				Id = assetId,
				Name = tostring(info.Name or ""),
				Type = allowed.Type,
				Layered = allowed.Layered,
				Creator = if type(info.Creator) == "table" then tostring(info.Creator.Name or "") else "",
			}
		end
	end
	-- A failed lookup isn't remembered, so it is tried again next time.
	if ok then
		items[assetId] = result
	end
	local threads = loading[assetId]
	loading[assetId] = nil
	for _, thread in threads do
		task.spawn(thread)
	end
	return result or nil
end

-- The wearable items among ids, in order, looked up together.
function CatalogService.items(ids: { number }): { Item }
	local results: { Item? } = table.create(#ids)
	local pending = #ids
	local done = coroutine.running()
	local waiting = false
	for index, id in ids do
		task.spawn(function()
			results[index] = CatalogService.item(id)
			pending -= 1
			if pending == 0 and waiting then
				task.spawn(done)
			end
		end)
	end
	if pending > 0 then
		waiting = true
		coroutine.yield()
	end
	local list = {}
	for index = 1, #ids do
		local item = results[index]
		if item then
			table.insert(list, item)
		end
	end
	return list
end

-- The accessory list for HumanoidDescription:SetAccessories.
function CatalogService.accessories(list: { Item }): { { [string]: any } }
	local out = {}
	for _, item in list do
		local entry: { [string]: any } = { AssetId = item.Id, AccessoryType = item.Type, IsLayered = item.Layered }
		if item.Layered then
			entry.Order = LAYER_ORDER[item.Type] or 1
		end
		table.insert(out, entry)
	end
	return out
end

local function cleanKeyword(value: any): string
	if type(value) ~= "string" then
		return ""
	end
	local text = string.sub(value, 1, MAX_KEYWORD)
	text = string.gsub(text, "[%c]", "")
	return text
end

local function pageItems(page: { any }): { any }
	local out = {}
	for _, entry in page do
		if type(entry) == "table" and entry.ItemType == "Asset" and type(entry.Id) == "number" then
			table.insert(out, {
				Id = entry.Id,
				Name = tostring(entry.Name or ""),
				Price = if type(entry.Price) == "number" then entry.Price else nil,
				Creator = tostring(entry.CreatorName or ""),
			})
		end
	end
	return out
end

-- One page of search results: { Items, More }.
local function search(category: string, keyword: string, sort: string, page: number): { [string]: any }?
	local key = `{category}|{string.lower(keyword)}|{sort}`
	local cached = searchCache[key]
	if cached and os.clock() - cached.At > SEARCH_CACHE_SECONDS then
		searchCache[key] = nil
		cached = nil
	end
	if not cached then
		local params = CatalogSearchParams.new()
		params.AssetTypes = CatalogService.Categories[category]
		params.SearchKeyword = keyword
		params.SortType = SORTS[sort] or SORTS.Popular
		params.Limit = PAGE_SIZE
		params.IncludeOffSale = false
		local ok, pages = pcall(AvatarEditorService.SearchCatalogAsync, AvatarEditorService, params)
		if not ok then
			warn(`Catalog search failed: {pages}`)
			return nil
		end
		cached = { At = os.clock(), Pages = { pageItems(pages:GetCurrentPage()) }, Source = pages }
		searchCache[key] = cached
	end
	local entry = cached :: any
	while #entry.Pages < page and not entry.Source.IsFinished do
		local ok = pcall(function()
			entry.Source:AdvanceToNextPageAsync()
		end)
		if not ok then
			break
		end
		table.insert(entry.Pages, pageItems(entry.Source:GetCurrentPage()))
	end
	local results = entry.Pages[page] or {}
	local more = page < MAX_PAGES and (#entry.Pages > page or not entry.Source.IsFinished)
	return { Items = results, More = more }
end

local function onSearch(player: Player, request: any): any
	if type(request) ~= "table" or not searchLimiter:allow(player) then
		return { Busy = true }
	end
	local category = if type(request.Category) == "string" and CatalogService.Categories[request.Category]
		then request.Category
		else "Hats"
	local page = if type(request.Page) == "number" then math.clamp(math.floor(request.Page), 1, MAX_PAGES) else 1
	local sort = if type(request.Sort) == "string" and SORTS[request.Sort] then request.Sort else "Popular"
	local result = search(category, cleanKeyword(request.Keyword), sort, page)
	if not result then
		return { Failed = true }
	end
	return result
end

local function onBuy(player: Player, assetId: any)
	if not buyLimiter:allow(player) then
		return
	end
	-- Only wearable catalog items can be bought here.
	if CatalogService.item(assetId) then
		MarketplaceService:PromptPurchase(player, assetId)
	end
end

function CatalogService.init()
	CatalogSearch.OnServerInvoke = onSearch
	CatalogBuy.OnServerEvent:Connect(onBuy)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		searchLimiter:forget(player)
		buyLimiter:forget(player)
	end)
end

return CatalogService
