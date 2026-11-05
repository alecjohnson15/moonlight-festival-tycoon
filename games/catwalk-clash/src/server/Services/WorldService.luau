-- Builds the map and keeps its signs up to date: the three show screens,
-- the world Style Score leaderboard, the Hall of Fame statue of the last
-- champion, and the VIP Lounge gate.

local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Build.World)
local Layout = require(Shared.Config.Layout)
local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)

local WorldService = {}

local LEADERBOARD_STORE = "StyleScoresV1"
local LEADERBOARD_SECONDS = 120

local refs: World.Refs = nil :: any
local board: OrderedDataStore? = nil
local names: { [number]: string } = {}

function WorldService.refs(): World.Refs
	return refs
end

-- Sets the three show screens at once. Any nil line keeps its text.
function WorldService.screens(top: string?, main: string?, sub: string?)
	for _, gui in { refs.PlazaScreen, refs.StageScreen, refs.BackstageScreen } do
		local background = gui:FindFirstChild("Background")
		if background then
			if top then
				(background:FindFirstChild("Top") :: TextLabel).Text = top
			end
			if main then
				(background:FindFirstChild("Main") :: TextLabel).Text = main
			end
			if sub then
				(background:FindFirstChild("Sub") :: TextLabel).Text = sub
			end
		end
	end
end

local function nameFor(userId: number): string
	local known = names[userId]
	if known then
		return known
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and name then
		names[userId] = name
		return name
	end
	return "Someone"
end

local function writeScores()
	if not board then
		return
	end
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data and data.Stats.Walks > 0 then
			pcall(function()
				(board :: OrderedDataStore):SetAsync(tostring(player.UserId), data.StyleScore)
			end)
		end
	end
end

local function refreshBoard()
	if not board then
		return
	end
	local ok, pages = pcall(function()
		return (board :: OrderedDataStore):GetSortedAsync(false, 10)
	end)
	if not ok then
		return
	end
	local list = refs.Leaderboard:FindFirstChild("List")
	for row, entry in pages:GetCurrentPage() do
		local label = list and list:FindFirstChild(`Row{row}`) :: TextLabel?
		local userId = tonumber(entry.key)
		if label and userId then
			label.Text = `{row}.  {nameFor(userId)}  ·  {entry.value}`
		end
	end
end

-- Puts the champion on the Hall of Fame plinth: a copy of their outfit on a
-- golden stand, with their name.
function WorldService.setChampion(name: string, themeName: string, model: Model?)
	local statue = refs.Statue
	statue:ClearAllChildren()
	local plaque = refs.HallOfFame;
	(plaque:FindFirstChild("Name") :: TextLabel).Text = `{name} · {themeName}`
	if not model then
		return
	end
	local archivable = model.Archivable
	model.Archivable = true
	local ok, copy = pcall(model.Clone, model)
	model.Archivable = archivable
	if not ok or not copy then
		return
	end
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("BillboardGui") or descendant:IsA("Sound") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.PlatformStand = true
	end
	local _, size = copy:GetBoundingBox()
	local base = Layout.HallOfFame.Position - Vector3.new(0, 4.9, 0) + Vector3.new(0, 1.9, 0)
	copy:PivotTo(CFrame.new(base + Vector3.new(0, size.Y / 2, 0)) * Layout.HallOfFame.Rotation)
	copy.Parent = statue
end

function WorldService.init()
	World.lighting(Lighting)
	refs = World.build(workspace)
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, LEADERBOARD_STORE)
	if ok then
		board = store
	end
	refs.Prompts.Vip.Triggered:Connect(function(player)
		ShopService.enterLounge(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local data = DataService.get(player)
		if board and data and data.Stats.Walks > 0 then
			pcall(function()
				(board :: OrderedDataStore):SetAsync(tostring(player.UserId), data.StyleScore)
			end)
		end
	end)
end

function WorldService.start()
	task.spawn(function()
		while true do
			writeScores()
			refreshBoard()
			task.wait(LEADERBOARD_SECONDS)
		end
	end)
end

return WorldService
