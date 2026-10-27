-- Gives each player a plot and builds the upgrades they own on it. If the
-- place has no Workspace.Plots folder, a greybox row of plots and a spawn
-- plaza are generated, so the game runs from an empty place file.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Layout = require(Shared.Config.Layout)
local Theme = require(Shared.Config.Theme)
local Progression = require(Shared.Progression)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local PlotService = {}

local plots: { BasePart } = {}
local plotOf: { [Player]: BasePart } = {}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addLabel(parent: BasePart, text: string, height: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, height, 0)
	billboard.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	billboard.Parent = parent
end

local function buildGreyboxMap(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	local size, spacing, count = Layout.PlotSize, Layout.PlotSpacing, Layout.PlotCount
	for i = 1, count do
		local x = (i - (count + 1) / 2) * spacing
		makePart(`Plot{i}`, Vector3.new(size, 1, size), CFrame.new(x, 0, 0), Color3.fromRGB(70, 92, 68), folder)
	end
	folder.Parent = Workspace

	-- A walkway along the front of the plots, with the spawn in the middle.
	local plazaDepth = 40
	local plazaZ = size / 2 + plazaDepth / 2
	makePart(
		"Plaza",
		Vector3.new(count * spacing, 1, plazaDepth),
		CFrame.new(0, 0, plazaZ),
		Color3.fromRGB(60, 60, 72),
		Workspace
	)
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.CFrame = CFrame.new(0, 1, plazaZ)
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = Workspace
	return folder
end

local function builtFolder(plot: BasePart): Folder
	local folder = plot:FindFirstChild("Built")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Built"
		folder.Parent = plot
	end
	return folder :: Folder
end

local function moveToPlot(player: Player, character: Model)
	local plot = plotOf[player]
	if plot then
		local offset = Layout.ArrivalOffset
		character:PivotTo(plot.CFrame * CFrame.new(offset.X, 4, offset.Z))
	end
end

local function addServePrompt(player: Player, target: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Theme.Strings.ServeAction
	prompt.ObjectText = Theme.Upgrades[Balance.ServeTask.UpgradeId].DisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(triggeredBy)
		-- Prompts are visible to everyone, but only the owner earns from theirs.
		if triggeredBy == player then
			EconomyService.rewardServe(player)
		end
	end)
	prompt.Parent = target
end

-- Builds one owned upgrade on the player's plot. Boosts have no slot and are
-- not drawn yet.
function PlotService.build(player: Player, upgradeId: string)
	local plot = plotOf[player]
	local slot = Layout.Slots[upgradeId]
	if not plot or not slot then
		return
	end
	local folder = builtFolder(plot)
	if folder:FindFirstChild(upgradeId) then
		return
	end

	local themed = Theme.Upgrades[upgradeId]
	local width, height, depth = slot.Size[1], slot.Size[2], slot.Size[3]
	local cframe = plot.CFrame * CFrame.new(slot.X, plot.Size.Y / 2 + height / 2, slot.Z)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = themed.Model and assets and assets:FindFirstChild(themed.Model)
	local anchor: BasePart
	if template and template:IsA("Model") then
		local model = template:Clone()
		model.Name = upgradeId
		model:PivotTo(cframe)
		model.Parent = folder
		anchor = (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) :: BasePart
	else
		anchor = makePart(upgradeId, Vector3.new(width, height, depth), cframe, Color3.fromHex(themed.Color), folder)
		addLabel(anchor, themed.DisplayName, height / 2 + 2)
	end

	if upgradeId == Balance.ServeTask.UpgradeId then
		addServePrompt(player, anchor)
	end
end

function PlotService.plotOf(player: Player): BasePart?
	return plotOf[player]
end

local function claimPlot(player: Player, data)
	local taken: { [BasePart]: boolean } = {}
	for _, plot in plotOf do
		taken[plot] = true
	end
	local free: BasePart? = nil
	for _, plot in plots do
		if not taken[plot] then
			free = plot
			break
		end
	end
	if not free then
		-- Players.MaxPlayers should match Layout.PlotCount so this never happens.
		player:Kick("This festival is full. Please join another server.")
		return
	end

	plotOf[player] = free
	free:SetAttribute("OwnerUserId", player.UserId)
	addLabel(free, Theme.Strings.PlotOwner:format(player.DisplayName), 12)

	for _, upgrade in Balance.Upgrades do
		if data.Owned[upgrade.Id] then
			PlotService.build(player, upgrade.Id)
		end
	end

	player.CharacterAdded:Connect(function(character)
		moveToPlot(player, character)
	end)
	if player.Character then
		moveToPlot(player, player.Character)
	end
end

local function releasePlot(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	plot:SetAttribute("OwnerUserId", nil)
	builtFolder(plot):ClearAllChildren()
	local label = plot:FindFirstChildWhichIsA("BillboardGui")
	if label then
		label:Destroy()
	end
end

function PlotService.init()
	local folder = Workspace:FindFirstChild("Plots") or buildGreyboxMap()
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(plots, child)
		end
	end
	table.sort(plots, function(a, b)
		return a.Name < b.Name
	end)

	-- Catch config mistakes at startup rather than mid-game.
	for _, problem in Progression.validate(Balance.Upgrades) do
		warn(`Balance config: {problem}`)
	end

	DataService.onLoaded(claimPlot)
	Players.PlayerRemoving:Connect(releasePlot)
end

return PlotService
