-- Each player's own festival (Config/Festival). Every plot has decoration
-- spots round its edge, dressed with the defaults until someone claims it.
-- On a claimed plot the owner also gets a sign under the arch with their
-- festival's name, a board by Ghost Catcher's booth where they pick the
-- name, colours and decorations, and a shelf that fills with their trophies.
-- Parts the theme marks with Kit.paint take the owner's palette.
--
-- The client only asks for a choice through the Festival remote; the server
-- checks it is unlocked, saves it and builds it. Unlocks come from playing:
-- upgrades, Ghost Catcher rounds and Moonlight Parades, checked here every
-- second. The player's attributes carry their choices and unlocks for the
-- board, and a note goes to them through the Notice remote when something
-- new unlocks. Nothing here touches coins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ActivityConfig = require(Shared.Config.Activity)
local Balance = require(Shared.Config.Balance)
local Config = require(Shared.Config.Festival)
local Layout = require(Shared.Config.Layout)
local Theme = require(Shared.Config.Theme)
local Festival = require(Shared.Festival)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local Remote = ReplicatedStorage.Remotes.Festival :: RemoteEvent
local Notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local CHECK_SECONDS = 1

type Unlocks = { Palettes: { [string]: boolean }, Decor: { [string]: boolean } }

local FestivalService = {}

local plots: { BasePart } = {}
local ownerOf: { [BasePart]: Player } = {}
-- The festival on each staged plot (FestivalService.stage), shaped like a save.
local staged: { [BasePart]: any } = {}
local plotOf: { [Player]: BasePart } = {}
-- What each player had unlocked when last told, and what their progress
-- looked like then.
local seen: { [Player]: Unlocks } = {}
local signatures: { [Player]: string } = {}
local limiter = RateLimiter.new(0.2)

local nameCounts = {}
for index, words in Theme.FestivalNames do
	nameCounts[index] = #words
end

for _, problem in Festival.validate(Config, #Layout.Decor, Balance.Upgrades, ActivityConfig.Wisps) do
	warn(`Festival config: {problem}`)
end

local function progressOf(data): Festival.Progress
	return { Owned = data.Owned, ActivityBest = data.Activity.Best, Parades = data.Parade.Joined }
end

local function unlocksOf(data): Unlocks
	local progress = progressOf(data)
	return {
		Palettes = Festival.unlocked(Config.Palettes, progress, Balance.Upgrades),
		Decor = Festival.unlocked(Config.Decor, progress, Balance.Upgrades),
	}
end

local function nameText(words: { number }): string
	local parts = {}
	for index, list in Theme.FestivalNames do
		parts[index] = list[words[index] or 1] or ""
	end
	return Theme.Strings.FestivalName:format(table.unpack(parts))
end

local function floorAt(plot: BasePart, x: number, z: number): CFrame
	return plot.CFrame * CFrame.new(x, plot.Size.Y / 2, z)
end

local function sizeOf(spec): Vector3
	return Vector3.new(spec.Size[1], spec.Size[2], spec.Size[3])
end

local function folderOf(plot: BasePart): Folder
	local folder = plot:FindFirstChild("Festival")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Festival"
		folder.Parent = plot
	end
	return folder :: Folder
end

local function destroyChild(parent: Instance, name: string)
	local child = parent:FindFirstChild(name)
	if child then
		child:Destroy()
	end
end

-- The palette a plot is painted in: its owner's, or the first.
local function paletteFor(plot: BasePart): string
	local owner = ownerOf[plot]
	local data = staged[plot] or (owner and DataService.get(owner))
	if not data then
		return Config.Palettes[1].Id
	end
	return Festival.paletteOf(Config, data.Festival, unlocksOf(data).Palettes)
end

local function colorsOf(id: string): { Color3 }
	local themed = Theme.Palettes[id] or Theme.Palettes[Config.Palettes[1].Id]
	return { Color3.fromHex(themed.Colors[1]), Color3.fromHex(themed.Colors[2]) }
end

local function paintPart(part: Instance, colors: { Color3 })
	local color = colors[part:GetAttribute("Paint") :: number]
	if color and part:IsA("BasePart") then
		part.Color = color
	end
end

local function paint(plot: BasePart)
	local colors = colorsOf(paletteFor(plot))
	for _, descendant in plot:GetDescendants() do
		if descendant:GetAttribute("Paint") ~= nil then
			paintPart(descendant, colors)
		end
	end
end

-- Builds the decoration in one spot, replacing whatever was there.
local function buildSpot(plot: BasePart, index: number, spot: number, id: string)
	local folder = folderOf(plot)
	local decor = folder:FindFirstChild("Decor")
	if not decor then
		decor = Instance.new("Folder")
		decor.Name = "Decor"
		decor.Parent = folder
	end
	for _, child in (decor :: Folder):GetChildren() do
		if child:GetAttribute("Spot") == spot then
			child:Destroy()
		end
	end
	local place = Layout.Decor[spot]
	-- Facing the middle of the plot.
	local yaw = math.atan2(-place.X, -place.Z)
	local base = floorAt(plot, place.X, place.Z) * CFrame.Angles(0, yaw, 0)
	local model = Theme.Festival.decor(id, base, index * 101 + spot * 7)
	model:SetAttribute("Spot", spot)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = decor
end

local function buildDecor(plot: BasePart, index: number, data)
	local unlocked = data and unlocksOf(data).Decor
	for spot in Layout.Decor do
		buildSpot(plot, index, spot, Festival.decorAt(Config, data and data.Festival, unlocked, spot))
	end
end

local function buildSign(plot: BasePart, data)
	local folder = folderOf(plot)
	destroyChild(folder, "NameSign")
	Theme.Festival.nameSign(folder, floorAt(plot, 0, 0), nameText(data.Festival.Name))
end

local function buildShelf(plot: BasePart, data)
	local folder = folderOf(plot)
	destroyChild(folder, "Shelf")
	local colors = {}
	for _, done in Festival.finishedPaths(data.Owned, Balance.Upgrades) do
		table.insert(colors, Color3.fromHex(Theme.Paths[done.Building][done.Path].Color))
	end
	local spec = Layout.Shelf
	local shelf = Theme.Festival.shelf(floorAt(plot, spec.X, spec.Z), sizeOf(spec), {
		Paths = colors,
		Best = data.Activity.Best,
		KOs = data.Arena.KOs,
		Parades = data.Parade.Joined,
	})
	shelf.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	shelf.Parent = folder
end

local function buildBoard(player: Player, plot: BasePart)
	local folder = folderOf(plot)
	destroyChild(folder, "Board")
	local spec = Layout.Board
	local board = Theme.Festival.board(floorAt(plot, spec.X, spec.Z), sizeOf(spec))
	board.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FestivalPrompt"
	prompt.ActionText = Theme.Strings.FestivalPrompt
	prompt.ObjectText = Theme.Strings.FestivalBoard
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	-- Each client hides the prompt on plots that aren't theirs.
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt.Parent = board.PrimaryPart
	prompt.Triggered:Connect(function(who)
		if who == player then
			Remote:FireClient(player, { Kind = "Open" })
		end
	end)
	board.Parent = folder
end

-- Puts the player's choices and unlocks on their attributes for the board,
-- and tells them about anything newly unlocked.
local function publish(player: Player, data)
	local unlocks = unlocksOf(data)
	local spots = {}
	for spot in Layout.Decor do
		spots[spot] = Festival.decorAt(Config, data.Festival, unlocks.Decor, spot)
	end
	player:SetAttribute("FestivalName", nameText(data.Festival.Name))
	player:SetAttribute("FestivalWords", table.concat(data.Festival.Name, ","))
	player:SetAttribute("FestivalPalette", Festival.paletteOf(Config, data.Festival, unlocks.Palettes))
	player:SetAttribute("FestivalDecor", table.concat(spots, ","))
	player:SetAttribute("FestivalPalettes", Festival.encode(unlocks.Palettes))
	player:SetAttribute("FestivalUnlocked", Festival.encode(unlocks.Decor))

	local before = seen[player]
	if before then
		local names = {}
		for _, id in Festival.newlyUnlocked(Config.Palettes, before.Palettes, unlocks.Palettes) do
			table.insert(names, Theme.Palettes[id].DisplayName)
		end
		for _, id in Festival.newlyUnlocked(Config.Decor, before.Decor, unlocks.Decor) do
			table.insert(names, Theme.Decor[id].DisplayName)
		end
		if #names > 0 then
			Notice:FireClient(player, { Kind = "Festival", Names = names })
		end
	end
	seen[player] = unlocks
end

local function signatureOf(data): string
	local owned = 0
	for _ in data.Owned do
		owned += 1
	end
	return `{owned}:{data.Activity.Best}:{data.Parade.Joined}:{data.Arena.KOs}`
end

local function indexOf(plot: BasePart): number
	return table.find(plots, plot) or 1
end

local function onClaimed(player: Player)
	local plot = PlotService.plotOf(player)
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	ownerOf[plot] = player
	plotOf[player] = plot
	if not Festival.validName(data.Festival.Name, nameCounts) then
		data.Festival.Name = Festival.defaultName(player.UserId, nameCounts)
	end
	buildSign(plot, data)
	buildBoard(player, plot)
	buildShelf(plot, data)
	buildDecor(plot, indexOf(plot), data)
	paint(plot)
	signatures[player] = signatureOf(data)
	publish(player, data)
end

local function onRemoving(player: Player)
	local plot = plotOf[player]
	plotOf[player] = nil
	seen[player] = nil
	signatures[player] = nil
	limiter:forget(player)
	if plot and ownerOf[plot] == player then
		ownerOf[plot] = nil
		local folder = folderOf(plot)
		for _, name in { "NameSign", "Board", "Shelf" } do
			destroyChild(folder, name)
		end
		buildDecor(plot, indexOf(plot), nil)
	end
end

-- A choice from the board: a new name, palette or decoration.
local function onRequest(player: Player, message: unknown)
	if type(message) ~= "table" or not limiter:allow(player) then
		return
	end
	local request = message :: { [string]: any }
	local data = DataService.get(player)
	local plot = plotOf[player]
	if not data or not plot then
		return
	end
	local unlocks = unlocksOf(data)
	if request.Kind == "Name" then
		if not Festival.validName(request.Words, nameCounts) then
			return
		end
		local words = {}
		for index in nameCounts do
			words[index] = request.Words[index]
		end
		data.Festival.Name = words
		buildSign(plot, data)
	elseif request.Kind == "Palette" then
		local id = request.Id
		if type(id) ~= "string" or not unlocks.Palettes[id] then
			return
		end
		data.Festival.Palette = id
		paint(plot)
	elseif request.Kind == "Decor" then
		local spot, id = request.Spot, request.Id
		if type(spot) ~= "number" or not Layout.Decor[spot] or type(id) ~= "string" or not unlocks.Decor[id] then
			return
		end
		data.Festival.Decor[tostring(spot)] = id
		buildSpot(plot, indexOf(plot), spot, id)
	else
		return
	end
	publish(player, data)
end

-- Dresses a staged plot (PlotService.stage) in the festival in data, which
-- is shaped like a save: its name sign, trophies, decorations and colours.
function FestivalService.stage(plot: BasePart, data)
	staged[plot] = data
	buildSign(plot, data)
	buildShelf(plot, data)
	buildDecor(plot, indexOf(plot), data)
	paint(plot)
end

function FestivalService.init()
	local folder = Workspace:FindFirstChild("Plots")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(plots, child)
			end
		end
	end
	table.sort(plots, function(a, b)
		return a.Name < b.Name
	end)
	for index, plot in plots do
		buildDecor(plot, index, nil)
		-- Paints whatever is built on the plot as it arrives.
		plot.DescendantAdded:Connect(function(descendant)
			if descendant:GetAttribute("Paint") ~= nil then
				paintPart(descendant, colorsOf(paletteFor(plot)))
			end
		end)
	end
	PlotService.onClaimed(onClaimed)
	Players.PlayerRemoving:Connect(onRemoving)
	Remote.OnServerEvent:Connect(onRequest)
end

-- Notices progress that unlocks something or changes the trophies.
function FestivalService.start()
	while true do
		task.wait(CHECK_SECONDS)
		for player, plot in plotOf do
			local data = DataService.get(player)
			if data then
				local signature = signatureOf(data)
				if signature ~= signatures[player] then
					signatures[player] = signature
					buildShelf(plot, data)
					publish(player, data)
				end
			end
		end
	end
end

return FestivalService
