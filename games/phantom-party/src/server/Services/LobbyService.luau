-- Builds Moonlit Plaza, the lobby, and keeps it running: spawn points round
-- the fountain, a prompt at each shop that opens its panel on the client,
-- the VIP lounge's velvet rope, the board that says what's next and the
-- global leaderboards.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Game = require(ReplicatedStorage.Shared.Config.Game)
local Lobby = require(ReplicatedStorage.Shared.Look.Lobby)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local OutfitService = require(script.Parent.OutfitService)

local BOARD_SECONDS = 120
local BOARD_ROWS = 10
local WRITE_SECONDS = 300

local LobbyService = {}

local model: Model? = nil
local spawnPoints: { BasePart } = {}
local boardLabel: TextLabel? = nil
local stores: { [string]: OrderedDataStore } = {}
local names: { [number]: string } = {}

local function origin(): CFrame
	local at = Game.LobbyOrigin
	return CFrame.new(at[1], at[2], at[3])
end

-- A random spot to put a player in the lobby.
function LobbyService.spawnCFrame(): CFrame
	if #spawnPoints == 0 then
		return origin() + Vector3.new(0, 5, 20)
	end
	local point = spawnPoints[math.random(1, #spawnPoints)]
	return point.CFrame + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
end

-- Sends a character back to the lobby without respawning it.
function LobbyService.bringBack(character: Model)
	character:PivotTo(LobbyService.spawnCFrame())
end

-- What the board over the gate says.
function LobbyService.setBoard(text: string)
	if boardLabel then
		boardLabel.Text = text
	end
end

local function makeSpawns(lobby: Model)
	local folder = lobby:FindFirstChild("Spawns")
	if not folder then
		return
	end
	for _, marker in folder:GetChildren() do
		if marker:IsA("BasePart") then
			local spawn = Instance.new("SpawnLocation")
			spawn.Name = "LobbySpawn"
			spawn.Anchored = true
			spawn.CanCollide = false
			spawn.CanQuery = false
			spawn.Transparency = 1
			spawn.Size = Vector3.new(4, 1, 4)
			spawn.CFrame = marker.CFrame
			spawn.Neutral = true
			spawn.Duration = 0
			spawn.Parent = folder
			table.insert(spawnPoints, spawn)
			marker:Destroy()
		end
	end
end

-- Each shop gets a prompt. The client opens the panel named by its Station
-- attribute when the prompt is used (client/Stations).
local function makePrompts(lobby: Model)
	local folder = lobby:FindFirstChild("Stations")
	if not folder then
		return
	end
	for _, marker in folder:GetChildren() do
		if marker:IsA("BasePart") and marker:GetAttribute("Station") ~= "Stage" then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Open"
			prompt.ObjectText = marker:GetAttribute("Label") or marker.Name
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.HoldDuration = 0
			prompt:SetAttribute("Station", marker:GetAttribute("Station"))
			prompt.Parent = marker
		end
	end
end

-- Leaderboards ---------------------------------------------------------

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then name else "Someone"
	return names[userId]
end

local function screenGui(board: Instance): Frame?
	local screen = board:FindFirstChild("Screen")
	if not screen or not screen:IsA("BasePart") then
		return nil
	end
	local gui = screen:FindFirstChild("Rows")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "Rows"
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0
		gui.Parent = screen
		local frame = Instance.new("Frame")
		frame.Name = "List"
		frame.Size = UDim2.new(1, -24, 1, -24)
		frame.Position = UDim2.fromOffset(12, 12)
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = frame
	end
	return gui:FindFirstChild("List") :: Frame?
end

local function row(list: Frame, order: number, left: string, right: string, color: Color3)
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 1 / (BOARD_ROWS + 0.5), -4)
	line.BackgroundTransparency = 1
	line.LayoutOrder = order
	line.Parent = list
	for index, text in { left, right } do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = if index == 1 then UDim2.fromScale(0.68, 1) else UDim2.fromScale(0.32, 1)
		label.Position = if index == 1 then UDim2.new() else UDim2.fromScale(0.68, 0)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.TextXAlignment = if index == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		label.Text = text
		label.Parent = line
	end
end

local function refreshBoard(board: Instance)
	local stat = board:GetAttribute("Stat")
	local store = stat and stores[stat]
	local list = screenGui(board)
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if not store then
		row(list, 1, "Opens when the game", "", Color3.fromRGB(200, 190, 230))
		row(list, 2, "is published", "", Color3.fromRGB(200, 190, 230))
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, BOARD_ROWS)
	end)
	if not ok then
		row(list, 1, "Back soon", "", Color3.fromRGB(200, 190, 230))
		return
	end
	local gold = Color3.fromRGB(255, 214, 102)
	local plain = Color3.fromRGB(240, 232, 255)
	for rank, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key) or 0
		row(list, rank, `{rank}. {nameOf(userId)}`, Format.short(entry.value), if rank <= 3 then gold else plain)
	end
end

local function writeStats(player: Player, data)
	for stat, store in stores do
		local value = data.Stats[stat]
		if typeof(value) == "number" and value > 0 then
			local ok, err = pcall(function()
				store:SetAsync(tostring(player.UserId), math.floor(value))
			end)
			if not ok then
				warn(`Couldn't write {stat} for {player.UserId}: {err}`)
			end
		end
	end
end

local function openStores(boards: Instance)
	for _, board in boards:GetChildren() do
		local stat = board:GetAttribute("Stat")
		if stat then
			local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, `Top_{stat}`)
			if ok then
				stores[stat] = store
			end
		end
	end
end

function LobbyService.init()
	local lobby = Lobby.build(origin())
	lobby.Parent = Workspace
	model = lobby
	makeSpawns(lobby)
	makePrompts(lobby)
	local gate = lobby:FindFirstChild("VipGate")
	if gate and gate:IsA("BasePart") then
		gate.CollisionGroup = OutfitService.GATE_GROUP
	end
	local board = lobby:FindFirstChild("MapBoard")
	local gui = board and board:FindFirstChildWhichIsA("SurfaceGui")
	boardLabel = gui and gui:FindFirstChildWhichIsA("TextLabel")
	if boardLabel then
		boardLabel.TextWrapped = true
	end
	DataService.onLeaving(function(player, data)
		writeStats(player, data)
	end)
end

function LobbyService.start()
	local lobby = model :: Model
	local boards = lobby:FindFirstChild("Boards")
	if not boards then
		return
	end
	openStores(boards)
	task.spawn(function()
		while true do
			task.wait(WRITE_SECONDS)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					writeStats(player, data)
				end
			end
		end
	end)
	while true do
		for _, board in boards:GetChildren() do
			task.spawn(refreshBoard, board)
		end
		task.wait(BOARD_SECONDS)
	end
end

return LobbyService
