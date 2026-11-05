-- A player's progress between shows: Sparkles, Style Score and rank, stats,
-- what they own, the Style Pass, daily challenges and the login streak. It
-- sends each player a snapshot of their profile whenever it changes, puts a
-- name tag over their head and keeps the leaderboard columns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Game = require(Config.Game)
local Wardrobe = require(Config.Wardrobe)
local Poses = require(Config.Poses)
local Entrances = require(Config.Entrances)
local Season = require(Config.Season)
local Quests = require(Config.Quests)
local Ranks = require(Config.Ranks)
local Palette = require(Config.Palette)
local Progress = require(Shared.Progress)
local StyleScore = require(Shared.StyleScore)
local DataService = require(script.Parent.DataService)
local PurchaseService = require(script.Parent.PurchaseService)
local PlayerHooks = require(script.Parent.Parent.Lib.PlayerHooks)

local Remotes = ReplicatedStorage.Remotes
local ProfileRemote = Remotes.Profile :: RemoteEvent
local Notice = Remotes.Notice :: RemoteEvent

local ProfileService = {}

local pushQueued: { [Player]: boolean } = {}

local KINDS = {
	Piece = { Config = Wardrobe, Owned = "Pieces" },
	Pose = { Config = Poses, Owned = "Poses" },
	Entrance = { Config = Entrances, Owned = "Entrances" },
}

local function getItem(kind: string, id: string): any
	local info = KINDS[kind]
	if not info or type(id) ~= "string" then
		return nil
	end
	return info.Config.get(id)
end

function ProfileService.hasPass(player: Player, passId: string): boolean
	return PurchaseService.ownsPass(player, passId)
end

-- Whether a player may wear or use an item: free ones always, pass items
-- with the pass, and Sparkles or Style Pass items once earned.
function ProfileService.owns(player: Player, kind: string, id: string): boolean
	local item = getItem(kind, id)
	if not item then
		return false
	end
	local data = DataService.get(player)
	if data and data.Owned[KINDS[kind].Owned][id] then
		return true
	end
	if item.Pass then
		return PurchaseService.ownsPass(player, item.Pass)
	end
	return item.Price == 0 and item.Season == nil
end

function ProfileService.rankOf(score: number)
	return StyleScore.rank(Ranks, score)
end

-- Sends a short message to the player's corner cards.
function ProfileService.notify(player: Player, kind: string, text: string, extra: { [string]: any }?)
	local message = { Kind = kind, Text = text }
	for key, value in extra or {} do
		message[key] = value
	end
	Notice:FireClient(player, message)
end

local function snapshot(player: Player, data): { [string]: any }
	local rank = ProfileService.rankOf(data.StyleScore)
	return {
		Sparkles = data.Sparkles,
		StyleScore = data.StyleScore,
		Rank = rank.Name,
		RankColor = rank.Color,
		Stats = data.Stats,
		Owned = data.Owned,
		Passes = PurchaseService.passes(player),
		Looks = data.Looks,
		Current = data.Current,
		Favorites = data.Favorites,
		Pass = data.Pass,
		Quests = data.Quests,
		Streak = data.Streak,
		Settings = data.Settings,
		SeasonId = Season.Id,
	}
end

-- Sends the player their profile, at most once a frame however many
-- changes happen together.
function ProfileService.push(player: Player)
	if pushQueued[player] then
		return
	end
	pushQueued[player] = true
	task.defer(function()
		pushQueued[player] = nil
		local data = DataService.get(player)
		if data and player.Parent then
			ProfileRemote:FireClient(player, snapshot(player, data))
		end
	end)
end

local function updateTag(player: Player)
	local data = DataService.get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local tag = head:FindFirstChild("NameTag") :: BillboardGui?
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "NameTag"
		gui.Size = UDim2.fromOffset(180, 46)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 70
		gui.LightInfluence = 0
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.Size = UDim2.fromScale(1, 0.55)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Color = Color3.fromRGB(40, 10, 50)
		stroke.Parent = name
		local rank = Instance.new("TextLabel")
		rank.Name = "Rank"
		rank.Position = UDim2.fromScale(0, 0.55)
		rank.Size = UDim2.fromScale(1, 0.45)
		rank.BackgroundTransparency = 1
		rank.Font = Enum.Font.GothamBold
		rank.TextScaled = true
		rank.Parent = gui
		local rankStroke = stroke:Clone()
		rankStroke.Parent = rank
		gui.Parent = head
		tag = gui
	end
	local gui = tag :: BillboardGui
	local rank = ProfileService.rankOf(data.StyleScore)
	local vip = PurchaseService.ownsPass(player, "vip")
	local nameLabel = gui:FindFirstChild("Name") :: TextLabel
	local rankLabel = gui:FindFirstChild("Rank") :: TextLabel
	nameLabel.Text = if vip then `VIP {player.DisplayName}` else player.DisplayName
	nameLabel.TextColor3 = if vip then Palette.resolve("Gold") else Color3.new(1, 1, 1)
	local crowns = if data.Stats.Crowns > 0 then `  👑{data.Stats.Crowns}` else ""
	rankLabel.Text = `{rank.Name} · {data.StyleScore}{crowns}`
	rankLabel.TextColor3 = Palette.resolve(rank.Color)
end

local function updateStats(player: Player)
	local data = DataService.get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	(stats:FindFirstChild("Style") :: IntValue).Value = data.StyleScore;
	(stats:FindFirstChild("Crowns") :: IntValue).Value = data.Stats.Crowns
end

-- Call after anything that changes what others see about the player.
function ProfileService.refresh(player: Player)
	updateTag(player)
	updateStats(player)
	ProfileService.push(player)
end

function ProfileService.addSparkles(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	data.Sparkles += math.floor(amount)
	ProfileService.push(player)
end

-- Takes Sparkles if the player has enough. Returns whether it did.
function ProfileService.spend(player: Player, amount: number): boolean
	local data = DataService.get(player)
	if not data or amount < 0 or data.Sparkles < amount then
		return false
	end
	data.Sparkles -= amount
	ProfileService.push(player)
	return true
end

local grantReward: (Player, any, any, string) -> ()

-- Adds Style Pass XP; tells the player about each tier they reach.
function ProfileService.addXp(player: Player, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.Pass = Progress.passFor(data.Pass, Season)
	local reached = Progress.addXp(data.Pass, Season, amount, os.time())
	for _, tier in reached do
		ProfileService.notify(
			player,
			"Tier",
			`Style Pass tier {tier} reached! Claim it on the pass board.`,
			{ Tier = tier }
		)
	end
	ProfileService.push(player)
end

-- Pays out a reward table ({ Sparkles, Xp }) times a multiplier.
function ProfileService.reward(
	player: Player,
	reward: { Sparkles: number?, Xp: number? },
	multiplier: number?,
	reason: string?
)
	local scale = multiplier or 1
	local sparkles = math.floor((reward.Sparkles or 0) * scale)
	local xp = math.floor((reward.Xp or 0) * scale)
	if sparkles > 0 then
		ProfileService.addSparkles(player, sparkles)
	end
	if xp > 0 then
		ProfileService.addXp(player, xp)
	end
	if reason and (sparkles > 0 or xp > 0) then
		ProfileService.notify(player, "Reward", reason, { Sparkles = sparkles, Xp = xp })
	end
end

-- Counts an event towards today's challenges and pays out any completed.
function ProfileService.record(player: Player, event: string, amount: number?)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.Quests = Progress.questsToday(data.Quests, Quests, os.time() // 86400)
	local completed = Progress.recordQuest(data.Quests, Quests, event, amount or 1)
	for _, quest in completed do
		ProfileService.reward(player, { Sparkles = quest.Sparkles, Xp = quest.Xp }, 1, `Challenge done: {quest.Text}!`)
	end
	ProfileService.push(player)
end

-- Gives an item for keeps (Sparkles purchase or Style Pass reward).
function ProfileService.giveItem(player: Player, kind: string, id: string)
	local data = DataService.get(player)
	if data and KINDS[kind] and getItem(kind, id) then
		data.Owned[KINDS[kind].Owned][id] = true
		ProfileService.push(player)
	end
end

grantReward = function(player: Player, data, reward, label: string)
	if reward.Sparkles then
		data.Sparkles += reward.Sparkles
	end
	for _, kind in { "Piece", "Pose", "Entrance" } do
		local id = reward[kind]
		if id and getItem(kind, id) then
			data.Owned[KINDS[kind].Owned][id] = true
		end
	end
	ProfileService.notify(player, "Reward", label, { Sparkles = reward.Sparkles or 0, Xp = 0 })
end

-- Claims a Style Pass tier reward. Returns whether it worked.
function ProfileService.claimTier(player: Player, tier: any, track: any): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "NotLoaded"
	end
	data.Pass = Progress.passFor(data.Pass, Season)
	local premium = PurchaseService.ownsPass(player, Season.Pass)
	local ok, reason = Progress.canClaim(data.Pass, Season, tier, track, premium)
	if not ok then
		return false, reason
	end
	data.Pass[track][tostring(tier)] = true
	grantReward(player, data, Season.Tiers[tier][track], `Style Pass tier {tier} claimed!`)
	ProfileService.push(player)
	return true, nil
end

local function onLoaded(player: Player, data)
	data.Sessions += 1
	data.Pass = Progress.passFor(data.Pass, Season)
	local today = os.time() // 86400
	data.Quests = Progress.questsToday(data.Quests, Quests, today)
	local streakDay = Progress.claimStreak(data.Streak, today)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local style = Instance.new("IntValue")
	style.Name = "Style"
	style.Parent = stats
	local crowns = Instance.new("IntValue")
	crowns.Name = "Crowns"
	crowns.Parent = stats
	stats.Parent = player

	ProfileService.refresh(player)
	if streakDay then
		local amount = Progress.streakReward(Game.Rewards.Streak, streakDay)
		task.delay(4, function()
			if player.Parent then
				ProfileService.reward(player, { Sparkles = amount }, 1, `Day {streakDay} login streak!`)
			end
		end)
	end
end

function ProfileService.init()
	DataService.onLoaded(onLoaded)
	PurchaseService.setGrant(function(player, item, data)
		if item.Sparkles then
			data.Sparkles += item.Sparkles
			ProfileService.notify(player, "Reward", `Thanks! {item.Sparkles} Sparkles added.`, {
				Sparkles = item.Sparkles,
				Xp = 0,
			})
			ProfileService.push(player)
		end
	end)
	PurchaseService.onOwnershipChanged(function(player, itemId)
		if itemId then
			ProfileService.notify(player, "Purchase", "Thank you! Your new items are ready in the wardrobe.")
		end
		ProfileService.refresh(player)
	end)
	PlayerHooks.eachCharacter(function(player, character)
		character:WaitForChild("Head", 10)
		updateTag(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		pushQueued[player] = nil
	end)
end

return ProfileService
