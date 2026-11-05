-- Everything a player keeps between rounds: coins, XP and level, the Moon
-- Pass, their cosmetics and outfit, and their stats. Answers the client's
-- requests (equip, buy, open a crate, claim a tier), pays out rounds, and
-- pushes a fresh snapshot to the player whenever something changes.
--
-- Coins come only from playing, the free pass track and nothing else.
-- Crates are opened with those coins, or given by the free track. Nothing a
-- player buys with Robux reaches this file except through PurchaseService's
-- fixed list of items and perks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CrateConfig = require(Shared.Config.Crates)
local Items = require(Shared.Config.Items)
local Shop = require(Shared.Config.Shop)
local CrateRules = require(Shared.Rules.Crates)
local Inventory = require(Shared.Rules.Inventory)
local Progress = require(Shared.Rules.Progress)
local Tips = require(Shared.Rules.Tips)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local PurchaseService = require(script.Parent.PurchaseService)

local Remotes = ReplicatedStorage.Remotes
local Request = Remotes.Request :: RemoteFunction
local ProfileRemote = Remotes.Profile :: RemoteEvent
local Notice = Remotes.Notice :: RemoteEvent

local ProfileService = {}

local handlers: { [string]: (Player, ...any) -> any } = {}
local outfitCallbacks: { (Player) -> () } = {}
local requestLimiter = RateLimiter.new(0.15)
local random = Random.new()

-- Adds a handler for Request(action, ...). Other services add theirs too.
function ProfileService.handle(action: string, handler: (Player, ...any) -> any)
	handlers[action] = handler
end

-- Runs callback(player) when what a player wears changes.
function ProfileService.onOutfit(callback: (Player) -> ())
	table.insert(outfitCallbacks, callback)
end

local function outfitChanged(player: Player)
	for _, callback in outfitCallbacks do
		task.spawn(callback, player)
	end
end

-- Puts the player's outfit on again, after something they wore may have
-- gone (a trade).
function ProfileService.refreshOutfit(player: Player)
	outfitChanged(player)
end

-- A corner card for one player.
function ProfileService.notify(player: Player, title: string, text: string, kind: string?)
	Notice:FireClient(player, { Title = title, Text = text, Kind = kind or "Info" })
end

function ProfileService.extra(player: Player): { [string]: boolean }
	return PurchaseService.items(player)
end

-- What the player wears, by kind.
function ProfileService.outfit(player: Player): { [string]: string }
	local data = DataService.get(player)
	if not data then
		return table.clone(Items.DEFAULTS)
	end
	return Inventory.outfit(data, ProfileService.extra(player))
end

function ProfileService.snapshot(player: Player): { [string]: any }?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local level, levelInto, levelCost = Progress.level(data.Xp)
	local tier, tierInto, perTier = Progress.tier(data.Pass.Xp)
	local premium = PurchaseService.hasPerk(player, "MoonPass")
	return {
		Coins = data.Coins,
		Xp = data.Xp,
		Level = level,
		LevelInto = levelInto,
		LevelCost = levelCost,
		Items = data.Items,
		Outfit = Inventory.outfit(data, ProfileService.extra(player)),
		Extra = ProfileService.extra(player),
		Passes = PurchaseService.list(player),
		Perks = {
			MoonPass = premium,
			VIP = PurchaseService.hasPerk(player, "VIP"),
			Emotes = PurchaseService.hasPerk(player, "Emotes"),
		},
		Pass = {
			Season = data.Pass.Season,
			Xp = data.Pass.Xp,
			Tier = tier,
			Into = tierInto,
			PerTier = perTier,
			Free = data.Pass.Free,
			Premium = data.Pass.Premium,
			Ready = #Progress.claimable(data.Pass, premium),
		},
		Pity = data.Pity,
		Stats = data.Stats,
		Settings = data.Settings,
		Tips = data.Tips,
		Mastery = data.Mastery,
	}
end

function ProfileService.push(player: Player)
	local snapshot = ProfileService.snapshot(player)
	if snapshot then
		ProfileRemote:FireClient(player, snapshot)
	end
end

local function setLeaderstats(player: Player)
	local data = DataService.get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	local level = stats:FindFirstChild("Level") :: IntValue?
	local wins = stats:FindFirstChild("Wins") :: IntValue?
	if level then
		level.Value = (Progress.level(data.Xp))
	end
	if wins then
		wins.Value = data.Stats.Wins
	end
end

function ProfileService.addCoins(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	data.Coins += amount
	data.Stats.CoinsEarned += amount
end

-- Adds XP to the level and the pass, and tells the player about a new
-- level or a new tier.
function ProfileService.addXp(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	local levelBefore = Progress.level(data.Xp)
	local tierBefore = Progress.tier(data.Pass.Xp)
	data.Xp += amount
	data.Pass.Xp += amount
	local levelAfter = Progress.level(data.Xp)
	local tierAfter = Progress.tier(data.Pass.Xp)
	if levelAfter > levelBefore then
		ProfileService.notify(player, "Level up!", `You're now level {levelAfter}.`, "Level")
	end
	if tierAfter > tierBefore then
		ProfileService.notify(
			player,
			`Moon Pass tier {tierAfter}`,
			"A reward is waiting. Open the Moon Pass to claim it.",
			"Pass"
		)
	end
	setLeaderstats(player)
end

-- Gives a copy of an item, unless it's one that can't be traded and the
-- player has it already. Returns the copy's uid, or nil.
local function grantItem(player: Player, itemId: string): string?
	local data = DataService.get(player)
	local item = Items.get(itemId)
	if not data or not item then
		return nil
	end
	if not Items.tradeable(itemId) and Inventory.owns(data, itemId, ProfileService.extra(player)) then
		return nil
	end
	return Inventory.add(data, player.UserId, itemId)
end

local function openCrate(player: Player, crate: CrateConfig.Crate): { [string]: any }
	local data = DataService.get(player) :: any
	local pity = data.Pity[crate.Id] or 0
	local itemId, rarity, nextPity = CrateRules.roll(crate, pity, function()
		return random:NextNumber()
	end)
	data.Pity[crate.Id] = nextPity
	data.Stats.CratesOpened += 1
	local uid = Inventory.add(data, player.UserId, itemId)
	AnalyticsService.crateOpened(player, crate.Id, rarity)
	return { Ok = true, Item = itemId, Rarity = rarity, Uid = uid, Crate = crate.Id }
end

-- Pays a finished round: coins, XP and the stats. pay is Rules/Progress's
-- pay, and summary the round summary it was worked out from.
function ProfileService.award(player: Player, pay: { Coins: number, Xp: number }, record: { [string]: any })
	local data = DataService.get(player)
	if not data then
		return
	end
	local stats = data.Stats
	stats.Rounds += 1
	stats.Wins += if record.Won then 1 else 0
	stats.Survived += if record.Survived then 1 else 0
	stats.Tags += record.Tags or 0
	stats.Takedowns += if record.Takedown then 1 else 0
	stats.Revives += record.Revives or 0
	stats.Clues += record.Clues or 0
	if record.Role == "Phantom" then
		stats.PhantomRounds += 1
		stats.PhantomWins += if record.Won then 1 else 0
	end
	ProfileService.addCoins(player, pay.Coins)
	ProfileService.addXp(player, pay.Xp)
	setLeaderstats(player)
	ProfileService.push(player)
end

-- Requests -------------------------------------------------------------

handlers.Snapshot = function(player)
	return ProfileService.snapshot(player)
end

handlers.Equip = function(player, itemId)
	local data = DataService.get(player)
	if not data or typeof(itemId) ~= "string" then
		return { Ok = false, Error = "NoSuchItem" }
	end
	local ok, err = Inventory.equip(data, itemId, ProfileService.extra(player))
	if ok then
		AnalyticsService.step(player, "Equipped")
		outfitChanged(player)
		ProfileService.push(player)
	end
	return { Ok = ok, Error = err }
end

handlers.Buy = function(player, itemId)
	local data = DataService.get(player)
	if not data or typeof(itemId) ~= "string" then
		return { Ok = false, Error = "NoSuchItem" }
	end
	local price = Shop.price(itemId)
	if not price then
		return { Ok = false, Error = "NotForSale" }
	end
	if Inventory.owns(data, itemId, ProfileService.extra(player)) then
		return { Ok = false, Error = "Owned" }
	end
	if data.Coins < price then
		return { Ok = false, Error = "NeedCoins" }
	end
	data.Coins -= price
	local uid = Inventory.add(data, player.UserId, itemId)
	Inventory.equip(data, itemId)
	outfitChanged(player)
	ProfileService.push(player)
	return { Ok = true, Item = itemId, Uid = uid }
end

handlers.OpenCrate = function(player, crateId)
	local data = DataService.get(player)
	local crate = typeof(crateId) == "string" and CrateConfig.get(crateId)
	if not data or not crate then
		return { Ok = false, Error = "NoSuchCrate" }
	end
	if data.Coins < crate.Price then
		return { Ok = false, Error = "NeedCoins" }
	end
	data.Coins -= crate.Price
	local result = openCrate(player, crate)
	ProfileService.push(player)
	return result
end

local function claim(player: Player, track: string, tier: number): { [string]: any }
	local data = DataService.get(player)
	if not data then
		return { Ok = false, Error = "NotLoaded" }
	end
	local premium = PurchaseService.hasPerk(player, "MoonPass")
	local reward, err = Progress.claim(data.Pass, track, tier, premium)
	if not reward then
		return { Ok = false, Error = err }
	end
	local result: { [string]: any } = { Ok = true, Track = track, Tier = tier }
	if reward.Coins then
		ProfileService.addCoins(player, reward.Coins)
		result.Coins = reward.Coins
	end
	if reward.Item then
		result.Item = reward.Item
		result.Uid = grantItem(player, reward.Item)
	end
	if reward.Crate then
		local crate = CrateConfig.get(reward.Crate)
		if crate then
			local opened = openCrate(player, crate)
			result.Item = opened.Item
			result.Rarity = opened.Rarity
			result.Crate = crate.Id
		end
	end
	return result
end

handlers.Claim = function(player, track, tier)
	if typeof(track) ~= "string" or typeof(tier) ~= "number" then
		return { Ok = false, Error = "NoSuchTier" }
	end
	local result = claim(player, track, tier)
	ProfileService.push(player)
	return result
end

handlers.ClaimAll = function(player)
	local data = DataService.get(player)
	if not data then
		return { Ok = false, Error = "NotLoaded" }
	end
	local premium = PurchaseService.hasPerk(player, "MoonPass")
	local results = {}
	for _, ready in Progress.claimable(data.Pass, premium) do
		table.insert(results, claim(player, ready.Track, ready.Tier))
	end
	ProfileService.push(player)
	return { Ok = #results > 0, Results = results }
end

-- The switches in Settings, all on or off.
local SETTINGS = { Music = true, ReduceMotion = true, Captions = true }

handlers.Setting = function(player, key, value)
	local data = DataService.get(player)
	if not data or typeof(key) ~= "string" or not SETTINGS[key] or typeof(value) ~= "boolean" then
		return { Ok = false }
	end
	data.Settings[key] = value
	return { Ok = true }
end

-- A first-time tip was shown: don't show it again.
handlers.TipSeen = function(player, id)
	local data = DataService.get(player)
	if not data or not Tips.valid(id) then
		return { Ok = false }
	end
	data.Tips[id] = true
	return { Ok = true }
end

local function onRequest(player: Player, action: unknown, ...: any): any
	if typeof(action) ~= "string" or (action ~= "Snapshot" and not requestLimiter:allow(player)) then
		return { Ok = false, Error = "Busy" }
	end
	local handler = handlers[action :: string]
	if not handler then
		return { Ok = false, Error = "Unknown" }
	end
	local ok, result = pcall(handler, player, ...)
	if not ok then
		warn(`Request {action} from {player.UserId} failed: {result}`)
		return { Ok = false, Error = "Failed" }
	end
	return result
end

local function onLoaded(player: Player, data)
	data.Pass = Progress.passFor(data.Pass)
	data.Sessions += 1
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = stats
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = stats
	stats.Parent = player
	setLeaderstats(player)
	ProfileService.push(player)
	outfitChanged(player)
	if data.Sessions == 1 then
		ProfileService.notify(
			player,
			"Welcome to the party!",
			"Every round, one guest is secretly the Phantom. Stay close to friends, collect clues and find them.",
			"Welcome"
		)
	end
end

function ProfileService.init()
	Request.OnServerInvoke = onRequest
	DataService.onLoaded(onLoaded)
	PurchaseService.onChanged(function(player, productId)
		if not DataService.get(player) then
			return
		end
		if productId then
			ProfileService.notify(player, "Thank you!", "Your purchase is ready. Check your inventory.", "Purchase")
		end
		outfitChanged(player)
		ProfileService.push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		requestLimiter:forget(player)
	end)
end

return ProfileService
