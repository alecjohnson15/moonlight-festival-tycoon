-- Plots, gates and buy buttons. Each plot has a gate across its front: an
-- unowned gate is solid and touching it claims the plot, after which it turns
-- see-through and carries the owner's name. On the owner's plot, a buy button
-- sits on the floor for every upgrade they can buy next; stepping on one asks
-- UpgradeService to buy it, and the upgrade is built while the button fades
-- away. Where a building forks into paths, a pad for each path appears side
-- by side, and buying one takes the others away for good. If the place has
-- no Workspace.Plots folder, a row of plots and a spawn plaza are generated,
-- so the game runs from an empty place file; WorldService then dresses them.
--
-- Each upgrade is built from the theme's model for it (see the theme pack's
-- Props), or as a greybox block if the theme has none. A built station is
-- named by its upgrade id and carries Kind and Type attributes, plus whatever
-- rates ProductionService and AttractionService publish on it, so clients can
-- animate it without asking the server. Anything just bought also carries
-- BuiltAt, the server time it was built, which clients use to play its
-- build-up animation.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Layout = require(Shared.Config.Layout)
local Theme = require(Shared.Config.Theme)
local Earnings = require(Shared.Earnings)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local DataService = require(script.Parent.DataService)

local FADE = TweenInfo.new(0.6)
local BUTTON_COLOR = Color3.fromRGB(76, 175, 80)
local WARNING_COLOR = Color3.fromRGB(255, 170, 120)
local PATH_LABEL_WIDTH = 7
local TRIGGER_HEIGHT = 3
local LABEL_FONT = Enum.Font.FredokaOne

local PlotService = {}

local plots: { BasePart } = {}
local plotOf: { [Player]: BasePart } = {}
local claimedCallbacks: { (Player) -> () } = {}
local buttonCallbacks: { (Player, string) -> () } = {}

local upgradesById = {}
for _, upgrade in Balance.Upgrades do
	upgradesById[upgrade.Id] = upgrade
end

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

local function addTextLine(billboard: BillboardGui, name: string, top: number, height: number, font: Enum.Font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromScale(0, top)
	label.Size = UDim2.fromScale(1, height)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Font = font
	label.Parent = billboard
	return label
end

local function addBillboard(parent: BasePart, name: string, height: number, pixelHeight: number): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Size = UDim2.fromOffset(220, pixelHeight)
	billboard.StudsOffset = Vector3.new(0, height, 0)
	billboard.MaxDistance = 120
	billboard.Parent = parent
	return billboard
end

-- A name with a caption line underneath, which the services keep up to date.
local function addStationLabel(parent: BasePart, title: string, height: number)
	local billboard = addBillboard(parent, "StationLabel", height, 56)
	addTextLine(billboard, "Title", 0, 0.6, LABEL_FONT).Text = title
	addTextLine(billboard, "Caption", 0.6, 0.4, Enum.Font.GothamBold).Text = ""
end

-- The part labels and effects attach to: the station itself for greybox, or
-- the model's primary part.
local function anchorOf(station: Instance): BasePart?
	if station:IsA("BasePart") then
		return station
	elseif station:IsA("Model") then
		return station.PrimaryPart or station:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function childFolder(plot: BasePart, name: string): Folder
	local folder = plot:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = plot
	end
	return folder :: Folder
end

local function buildGreyboxMap(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	local size = Layout.PlotSize
	for i = 1, Layout.PlotCount do
		local x = Layout.plotX(i)
		makePart(`Plot{i}`, Vector3.new(size, 1, size), CFrame.new(x, 0, 0), Color3.fromRGB(70, 92, 68), folder)
	end
	folder.Parent = Workspace

	-- A walkway along the front of the plots, with the spawn in the middle,
	-- in front of the courtyard between the middle two plots. Players spawn
	-- facing the courtyard (-Z).
	local plazaDepth = Layout.PlazaDepth
	local plazaZ = size / 2 + plazaDepth / 2
	makePart(
		"Plaza",
		Vector3.new(Layout.PlazaWidth, 1, plazaDepth),
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

local function moveToPlot(player: Player, character: Model)
	local plot = plotOf[player]
	if plot then
		local offset = Layout.ArrivalOffset
		character:PivotTo(plot.CFrame * CFrame.new(offset.X, 4, offset.Z))
	end
end

-- The point on the plot floor under the middle of a slot.
local function slotOrigin(plot: BasePart, slot): CFrame
	return plot.CFrame * CFrame.new(slot.X, plot.Size.Y / 2, slot.Z)
end

-- Marks something just built, so clients play its build-up animation. Whole
-- models stream to clients at once, so the animation never starts half-built.
local function finish(built: Instance, withEffect: boolean?)
	if built:IsA("Model") then
		built.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	if withEffect then
		built:SetAttribute("BuiltAt", Workspace:GetServerTimeNow())
	end
end

-- Boosts and vendors have no slot of their own. If the theme draws one, it
-- is added to the building it improves, so it goes when that building does,
-- in that building's slot or the yard beside it. A path tier's model is the
-- whole path so far, so it takes the place of the tier it names in its
-- Replaces attribute.
local function buildAddOn(plot: BasePart, folder: Folder, upgrade, withEffect: boolean?)
	local builder = Theme.Props[upgrade.Id]
	local station = folder:FindFirstChild(upgrade.Building)
	local slot = Layout.Slots[upgrade.Building]
	if not builder or not station or not slot or station:FindFirstChild(upgrade.Id) then
		return
	end
	local size = Vector3.new(slot.Size[1], slot.Size[2], slot.Size[3])
	local model = builder(slotOrigin(plot, slot), size, slot.Yard and slotOrigin(plot, slot.Yard))
	model.Name = upgrade.Id
	finish(model, withEffect)
	local replaces = model:GetAttribute("Replaces")
	local old = replaces and station:FindFirstChild(replaces)
	if old then
		old:Destroy()
	end
	model.Parent = station
end

-- Builds one owned upgrade on the player's plot: an artist's model from
-- ReplicatedStorage.Assets if the theme names one, else the theme's built
-- model, else a greybox block. With withEffect, clients animate it in.
function PlotService.build(player: Player, upgradeId: string, withEffect: boolean?)
	local plot = plotOf[player]
	local upgrade = upgradesById[upgradeId]
	if not plot or not upgrade then
		return
	end
	local folder = childFolder(plot, "Built")
	if upgrade.Building then
		buildAddOn(plot, folder, upgrade, withEffect)
		return
	end
	local slot = Layout.Slots[upgradeId]
	if not slot or folder:FindFirstChild(upgradeId) then
		return
	end

	local themed = Theme.Upgrades[upgradeId]
	local size = Vector3.new(slot.Size[1], slot.Size[2], slot.Size[3])
	local origin = slotOrigin(plot, slot)
	local middle = origin * CFrame.new(0, size.Y / 2, 0)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = themed.Model and assets and assets:FindFirstChild(themed.Model)
	local builder = Theme.Props[upgradeId]
	local station: Instance
	if template and template:IsA("Model") then
		local model = template:Clone()
		model:PivotTo(middle)
		station = model
	elseif builder then
		station = builder(origin, size)
	else
		station = makePart(upgradeId, size, middle, Color3.fromHex(themed.Color), folder)
		if upgrade.Type == "Showpiece" then
			-- Greybox showpieces glow so they read as the plot's landmark.
			local light = Instance.new("PointLight")
			light.Color = Color3.fromHex(themed.Color)
			light.Range = 28
			light.Brightness = 2
			light.Parent = station
		end
	end
	station.Name = upgradeId
	station:SetAttribute("Kind", upgrade.Kind)
	station:SetAttribute("Type", upgrade.Type)
	finish(station, withEffect)
	station.Parent = folder

	local anchor = anchorOf(station)
	if anchor then
		addStationLabel(anchor, themed.DisplayName, size.Y / 2 + 3)
	end
end

-- The built station for an upgrade on the player's plot, if there is one.
function PlotService.station(player: Player, upgradeId: string): Instance?
	local plot = plotOf[player]
	local folder = plot and plot:FindFirstChild("Built")
	return folder and folder:FindFirstChild(upgradeId)
end

-- Sets a station's caption line and attributes, skipping anything unchanged
-- so nothing replicates when nothing changed.
function PlotService.updateStation(player: Player, upgradeId: string, caption: string, attributes: { [string]: any })
	local station = PlotService.station(player, upgradeId)
	if not station then
		return
	end
	for name, value in attributes do
		if station:GetAttribute(name) ~= value then
			station:SetAttribute(name, value)
		end
	end
	local anchor = anchorOf(station)
	local billboard = anchor and anchor:FindFirstChild("StationLabel")
	local label = billboard and billboard:FindFirstChild("Caption")
	if label and label:IsA("TextLabel") and label.Text ~= caption then
		label.Text = caption
	end
end

-- Where an upgrade's buy button goes: a building's own spot, its shared
-- upgrades' spot, or its path's spot (see Config/Layout).
local function spotFor(upgrade): { X: number, Z: number }?
	local spots = Layout.Buttons[upgrade.Building or upgrade.Id]
	if not spots then
		return nil
	elseif not upgrade.Building then
		return spots.Build
	elseif upgrade.Path then
		return spots.Paths and spots.Paths[upgrade.Path]
	end
	return spots.Upgrades
end

-- The lines over a pad. A path's pads say which path they're on: the first
-- pads, side by side, pitch each path and warn the choice is for good.
local function labelButton(billboard: BillboardGui, upgrade, owned: { [string]: boolean })
	local path = upgrade.Path and Theme.Paths[upgrade.Building][upgrade.Path]
	local price = if upgrade.Cost == 0 then Theme.Strings.Free else `{Format.short(upgrade.Cost)} {Theme.Strings.Coins}`
	if not path then
		billboard.Size = UDim2.fromOffset(220, 72)
		addTextLine(billboard, "Title", 0, 0.45, LABEL_FONT).Text = Theme.Upgrades[upgrade.Id].DisplayName
		addTextLine(billboard, "Price", 0.45, 0.3, LABEL_FONT).Text = price
		addTextLine(billboard, "Gain", 0.75, 0.25, Enum.Font.GothamBold).Text = ""
		return
	end

	-- Sized in studs, not pixels, so pads side by side never overlap their
	-- labels however far away the player stands.
	local tier, count = Progression.pathTier(Balance.Upgrades, upgrade.Id)
	local choosing = Progression.chosenPaths(owned, Balance.Upgrades)[upgrade.Building] == nil
	billboard.Size = UDim2.fromScale(PATH_LABEL_WIDTH, if choosing then 4.5 else 3.6)
	billboard.StudsOffset = Vector3.new(0, if choosing then 5 else 4.5, 0)
	local share = if choosing then 1 / 5 else 1 / 4
	local heading = addTextLine(billboard, "Path", 0, share, LABEL_FONT)
	heading.TextColor3 = Color3.fromHex(path.Color)
	if choosing then
		heading.Text = path.DisplayName
		addTextLine(billboard, "Title", share, share, Enum.Font.GothamBold).Text = path.Blurb
	else
		heading.Text = Theme.Strings.PathTier:format(path.DisplayName, tier or 0, count or 0)
		addTextLine(billboard, "Title", share, share, LABEL_FONT).Text = Theme.Upgrades[upgrade.Id].DisplayName
	end
	addTextLine(billboard, "Price", share * 2, share, LABEL_FONT).Text = price
	addTextLine(billboard, "Gain", share * 3, share, Enum.Font.GothamBold).Text = ""
	if choosing then
		local warning = addTextLine(billboard, "Warning", share * 4, share, Enum.Font.GothamBold)
		warning.Text = Theme.Strings.PathChoice
		warning.TextColor3 = WARNING_COLOR
	end
end

-- Whether the owner's character is standing over a pad, so a pad that just
-- appeared under them doesn't buy before they step off and back on.
local function standingOn(player: Player, floor: CFrame): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local offset = floor:PointToObjectSpace(root.Position)
	return Vector2.new(offset.X, offset.Z).Magnitude < Layout.ButtonSize / 2 + 1.5
end

local function makeButton(player: Player, plot: BasePart, upgrade, folder: Folder, fadeIn: boolean, owned)
	local spot = spotFor(upgrade) :: { X: number, Z: number }
	local size = Layout.ButtonSize
	-- A round, glowing pad on a dark rim. Cylinders lie along X, so it is
	-- turned upright.
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local floor = plot.CFrame * CFrame.new(spot.X, plot.Size.Y / 2, spot.Z)
	local button = makePart(
		upgrade.Id,
		Vector3.new(0.6, size - 0.6, size - 0.6),
		floor * CFrame.new(0, 0.3, 0) * upright,
		BUTTON_COLOR,
		folder
	)
	button.Shape = Enum.PartType.Cylinder
	button.Material = Enum.Material.Neon
	button.CanCollide = false
	button.CanTouch = false
	button:SetAttribute("Cost", upgrade.Cost)
	button:SetAttribute("Building", upgrade.Building)
	button:SetAttribute("Path", upgrade.Path)
	-- The first pad of each path, while the building has no path yet. Picking
	-- one locks the others for good, so the first step only previews it.
	local choosing = upgrade.Path ~= nil and Progression.chosenPaths(owned, Balance.Upgrades)[upgrade.Building] == nil
	button:SetAttribute("Choice", choosing or nil)
	local rim = makePart(
		"Rim",
		Vector3.new(0.4, size, size),
		floor * CFrame.new(0, 0.2, 0) * upright,
		Color3.fromHex(Theme.Palette.ButtonRim),
		button
	)
	rim.Shape = Enum.PartType.Cylinder
	rim.CanCollide = false
	rim.CanTouch = false
	-- The pad and rim are only for show. What's stepped on is an invisible
	-- column over the pad, from just under the floor to a player's knees, so a
	-- step anywhere on the pad counts, even one that lands a little high.
	local trigger = makePart(
		"Trigger",
		Vector3.new(TRIGGER_HEIGHT, size, size),
		floor * CFrame.new(0, TRIGGER_HEIGHT / 2 - 0.5, 0) * upright,
		BUTTON_COLOR,
		button
	)
	trigger.Shape = Enum.PartType.Cylinder
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger.CanQuery = false

	local billboard = addBillboard(button, "ButtonLabel", 4, 72)
	billboard.MaxDistance = 80
	labelButton(billboard, upgrade, owned)

	if fadeIn then
		for _, part in { button, rim } do
			part.Transparency = 1
			TweenService:Create(part, FADE, { Transparency = 0 }):Play()
		end
	end

	-- A pad that appears under the owner, where they just bought the one
	-- before it, waits for them to step off first.
	local waitingForStepOff = false
	local function waitForStepOff()
		waitingForStepOff = true
		task.spawn(function()
			while button.Parent and standingOn(player, floor) do
				task.wait(0.2)
			end
			waitingForStepOff = false
		end)
	end
	if standingOn(player, floor) then
		waitForStepOff()
	end

	trigger.Touched:Connect(function(hit)
		-- Only the owner's own living character can buy from their plot.
		local character = hit.Parent
		if waitingForStepOff or not character or Players:GetPlayerFromCharacter(character) ~= player then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or button:GetAttribute("Sold") ~= nil then
			return
		end
		if choosing then
			-- The first step arms the pad, and the owner's screen shows what
			-- the path does and what it locks. Stepping off and back on
			-- within Layout.ConfirmSeconds picks it.
			local now = Workspace:GetServerTimeNow()
			local armedAt = button:GetAttribute("ArmedAt")
			if armedAt == nil or now - armedAt > Layout.ConfirmSeconds then
				for _, other in folder:GetChildren() do
					if other ~= button and other:GetAttribute("Building") == upgrade.Building then
						other:SetAttribute("ArmedAt", nil)
					end
				end
				button:SetAttribute("ArmedAt", now)
				waitForStepOff()
				return
			end
		end
		for _, callback in buttonCallbacks do
			task.spawn(callback, player, upgrade.Id)
		end
	end)
end

-- Fades out and removes a button whose upgrade was just bought.
local function retireButton(button: BasePart)
	button:SetAttribute("Sold", true)
	button.Name = "Sold"
	local trigger = button:FindFirstChild("Trigger")
	if trigger and trigger:IsA("BasePart") then
		trigger.CanTouch = false
	end
	local billboard = button:FindFirstChild("ButtonLabel")
	if billboard then
		billboard:Destroy()
	end
	TweenService:Create(button, FADE, { Transparency = 1 }):Play()
	local rim = button:FindFirstChild("Rim")
	if rim then
		TweenService:Create(rim, FADE, { Transparency = 1 }):Play()
	end
	Debris:AddItem(button, FADE.Time + 0.1)
end

-- Makes the owner's buttons match what they can buy next: removes buttons for
-- upgrades they own, adds buttons for newly unlocked ones (fading them in
-- when fadeIn is set), and updates what each would add per second.
function PlotService.refreshButtons(player: Player, fadeIn: boolean)
	local plot = plotOf[player]
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	local folder = childFolder(plot, "Buttons")
	local available = Progression.available(data.Owned, Balance.Upgrades)
	local wanted: { [string]: boolean } = {}
	for _, upgrade in available do
		wanted[upgrade.Id] = true
	end
	for _, button in folder:GetChildren() do
		if button:IsA("BasePart") and button:GetAttribute("Sold") == nil and not wanted[button.Name] then
			retireButton(button)
		end
	end

	local income = Earnings.perSecond(data.Owned, Balance)
	for _, upgrade in available do
		if spotFor(upgrade) then
			if not folder:FindFirstChild(upgrade.Id) then
				makeButton(player, plot, upgrade, folder, fadeIn, data.Owned)
			end
			local withUpgrade = table.clone(data.Owned)
			withUpgrade[upgrade.Id] = true
			local gain = Earnings.perSecond(withUpgrade, Balance) - income
			local button = folder:FindFirstChild(upgrade.Id)
			local billboard = button and button:FindFirstChild("ButtonLabel")
			local label = billboard and billboard:FindFirstChild("Gain")
			if label and label:IsA("TextLabel") then
				label.Text = if gain > 0 then Theme.Strings.UpgradeGain:format(Format.rate(gain)) else ""
			end
		end
	end
end

-- Runs callback(player, upgradeId) when the owner steps on a buy button.
function PlotService.onButtonStepped(callback: (Player, string) -> ())
	table.insert(buttonCallbacks, callback)
end

-- Runs callback(player) once a player has claimed a plot and it is built.
function PlotService.onClaimed(callback: (Player) -> ())
	table.insert(claimedCallbacks, callback)
end

function PlotService.plotOf(player: Player): BasePart?
	return plotOf[player]
end

local function setGate(plot: BasePart, owner: Player?)
	local gate = plot:FindFirstChild("Gate")
	if not gate or not gate:IsA("BasePart") then
		return
	end
	gate.CanCollide = owner == nil
	gate.Transparency = if owner then 0.85 else 0.2
	local billboard = gate:FindFirstChild("GateLabel")
	local label = billboard and billboard:FindFirstChild("Title")
	if label and label:IsA("TextLabel") then
		label.Text = if owner then Theme.Strings.PlotOwner:format(owner.DisplayName) else Theme.Strings.ClaimGate
	end
end

local function claimPlot(player: Player, plot: BasePart)
	-- One plot per player, one owner per plot, and only once the save is in.
	if plotOf[player] or plot:GetAttribute("OwnerUserId") ~= nil then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end

	plotOf[player] = plot
	plot:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("HasPlot", true)
	setGate(plot, player)

	for _, upgrade in Balance.Upgrades do
		if data.Owned[upgrade.Id] then
			PlotService.build(player, upgrade.Id, false)
		end
	end
	PlotService.refreshButtons(player, false)

	player.CharacterAdded:Connect(function(character)
		moveToPlot(player, character)
	end)
	for _, callback in claimedCallbacks do
		task.spawn(callback, player)
	end
end

-- Uses the plot's own Gate part if the place has one, or makes a greybox one.
local function setUpGate(plot: BasePart)
	local gate = plot:FindFirstChild("Gate")
	if not gate or not gate:IsA("BasePart") then
		local spec = Layout.Gate
		local width, height, depth = spec.Size[1], spec.Size[2], spec.Size[3]
		local cframe = plot.CFrame * CFrame.new(spec.X, plot.Size.Y / 2 + height / 2, spec.Z)
		gate = makePart("Gate", Vector3.new(width, height, depth), cframe, Color3.fromHex(Theme.Palette.Gate), plot)
		gate.Material = Enum.Material.ForceField
	end
	local part = gate :: BasePart
	if not part:FindFirstChild("GateLabel") then
		addTextLine(addBillboard(part, "GateLabel", part.Size.Y / 2 + 2, 40), "Title", 0, 1, LABEL_FONT)
	end
	setGate(plot, nil)

	part.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if player and humanoid and humanoid.Health > 0 then
			claimPlot(player, plot)
		end
	end)
end

local function releasePlot(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	plot:SetAttribute("OwnerUserId", nil)
	plot:SetAttribute("VisitorsPerSecond", nil)
	childFolder(plot, "Built"):ClearAllChildren()
	childFolder(plot, "Buttons"):ClearAllChildren()
	setGate(plot, nil)
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
	for _, plot in plots do
		setUpGate(plot)
	end

	-- Catch config mistakes at startup rather than mid-game.
	for _, problem in Progression.validate(Balance.Upgrades) do
		warn(`Balance config: {problem}`)
	end
	for _, problem in Earnings.validate(Balance) do
		warn(`Balance config: {problem}`)
	end

	Players.PlayerRemoving:Connect(releasePlot)
end

return PlotService
