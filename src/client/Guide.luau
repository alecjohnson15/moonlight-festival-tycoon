-- The guide: what to do next, always on screen. A line at the bottom of the
-- screen names the next goal, with a bar while saving up for it. Until a
-- player knows their way round, and whenever they could buy something but
-- haven't for a while, a beam runs from them to the goal with an arrow
-- bobbing over it. Free gates shine with a tall beacon until the player has
-- a haunt.
--
-- It also shows the notes the server sends through the Notice remote, such
-- as a pad that needs more coins, and the preview of a path pad stepped on
-- once: what the path does, what it adds per second, what it locks, and a
-- see-through model of what it builds. Everything here is drawn on this
-- client only, from attributes the server publishes; the server decides
-- everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Config.Layout)
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Format)
local Kit = require(Shared.Kit)
local Sounds = require(script.Parent.Sounds)

local Notice = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice") :: RemoteEvent

local GOLD = Color3.fromRGB(255, 205, 90)
local PANEL = Color3.fromRGB(26, 18, 40)
local TEXT = Color3.fromRGB(255, 244, 214)
local WARN = Color3.fromRGB(255, 170, 120)
local BAR = Color3.fromRGB(110, 220, 120)
local BEAM = Color3.fromRGB(255, 222, 130)
local FONT = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamBold
local Strings = Theme.Strings

-- The beam shows for a player's first purchases, and again whenever they
-- could buy something but haven't for a while.
local GUIDED_PURCHASES = 6
local IDLE_SECONDS = 40
-- Close enough to the goal that the beam isn't needed.
local NEAR_GOAL = 9
local NOTE_SECONDS = 3.5
local GOAL_STEP = 0.2
local BEACON_HEIGHT = 70

export type Goal = {
	Text: string,
	Progress: number?,
	ProgressText: string?,
	Target: Vector3?,
	-- Whether the beam should point at it even once the player knows the game.
	Urgent: boolean?,
}

local Guide = {}

local player = Players.LocalPlayer
local lastPurchaseAt = os.clock()

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function round(parent: Instance, radius: UDim?)
	make("UICorner", { CornerRadius = radius or UDim.new(0, 12) }, parent)
end

local function outline(parent: Instance, color: Color3, thickness: number): UIStroke
	return make(
		"UIStroke",
		{ Color = color, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		parent
	)
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = BODY,
		TextColor3 = TEXT,
		TextScaled = true,
		TextWrapped = true,
	}, parent)
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

local gui = make("ScreenGui", { Name = "Guide", ResetOnSpawn = false })
local screenScale = make("UIScale", {}, gui)

-- The goal line.
local goalPanel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(470, 46),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.1,
}, gui)
round(goalPanel)
outline(goalPanel, GOLD, 2)
local goalText = text(goalPanel, {
	Position = UDim2.fromOffset(14, 6),
	Size = UDim2.new(1, -28, 0, 34),
	Font = FONT,
})
local goalBar = make("Frame", {
	Position = UDim2.fromOffset(14, 44),
	Size = UDim2.new(1, -28, 0, 16),
	BackgroundColor3 = Color3.fromRGB(50, 38, 70),
	Visible = false,
}, goalPanel)
round(goalBar, UDim.new(1, 0))
local goalFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = BAR }, goalBar)
round(goalFill, UDim.new(1, 0))
local goalBarText = text(goalBar, { Size = UDim2.fromScale(1, 1), ZIndex = 2, TextStrokeTransparency = 0.4 })

-- Notes, and the path preview card, just above the goal line.
local note = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -86),
	Size = UDim2.fromOffset(430, 62),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.05,
	Visible = false,
}, gui)
round(note)
local noteStroke = outline(note, GOLD, 2.5)
local noteTitle = text(note, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 28), Font = FONT })
local noteText = text(note, { Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 18) })
local noteScale = make("UIScale", {}, note)
local noteUntil = 0

local card = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -86),
	Size = UDim2.fromOffset(430, 150),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.05,
	Visible = false,
}, gui)
round(card)
local cardStroke = outline(card, GOLD, 3)
local cardTitle = text(card, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 32), Font = FONT })
local cardBlurb = text(card, { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 20) })
local cardGain = text(card, { Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 0, 20), TextColor3 = BAR })
local cardLocks =
	text(card, { Position = UDim2.fromOffset(14, 86), Size = UDim2.new(1, -28, 0, 20), TextColor3 = WARN })
text(card, {
	Position = UDim2.fromOffset(14, 110),
	Size = UDim2.new(1, -28, 0, 22),
	Font = FONT,
	TextColor3 = GOLD,
	Text = Strings.PathConfirm,
})
local cardTimer = make("Frame", {
	Position = UDim2.new(0, 14, 1, -10),
	Size = UDim2.new(1, -28, 0, 4),
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
}, card)

-- The beam and the arrow over the goal. The beam runs from an attachment on
-- the character to one in the terrain at the goal.
local goalAttachment = make("Attachment", { Name = "GuideGoal" }, Workspace.Terrain)
local beam = make("Beam", {
	Name = "GuideBeam",
	Attachment1 = goalAttachment,
	Width0 = 0.7,
	Width1 = 0.7,
	FaceCamera = true,
	LightEmission = 1,
	LightInfluence = 0,
	Color = ColorSequence.new(BEAM),
	Transparency = NumberSequence.new(0.2, 0.45),
	Segments = 1,
	Enabled = false,
}, Workspace.Terrain)
local characterAttachment: Attachment? = nil

local arrow = Kit.model(nil, "GuideArrow")
for side = -1, 1, 2 do
	Kit.glow(
		arrow,
		CFrame.new(side * 0.75, 0.75, 0) * CFrame.Angles(0, 0, side * math.pi / 4),
		Vector3.new(0.6, 2.4, 0.6),
		BEAM
	)
end
Kit.glow(arrow, CFrame.new(0, 3, 0), Vector3.new(0.6, 3, 0.6), BEAM)
arrow.WorldPivot = CFrame.new()

local beacons: { [BasePart]: BasePart } = {}
local preview: { Pad: BasePart, Model: Model? }? = nil
local currentGoal: Goal? = nil

local function myPlot(): BasePart?
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:IsA("BasePart") and plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- What a pad is called: a path's name on the pads that pick a path, else
-- the upgrade's.
local function padName(pad: BasePart): string
	local building, path = pad:GetAttribute("Building"), pad:GetAttribute("Path")
	if pad:GetAttribute("Choice") and building and path then
		return Theme.Paths[building][path].DisplayName
	end
	local themed = Theme.Upgrades[pad.Name]
	return if themed then themed.DisplayName else pad.Name
end

local function openPads(plot: BasePart): { BasePart }
	local list = {}
	local buttons = plot:FindFirstChild("Buttons")
	if buttons then
		for _, pad in buttons:GetChildren() do
			if pad:IsA("BasePart") and pad:GetAttribute("Cost") ~= nil and pad:GetAttribute("Sold") == nil then
				table.insert(list, pad)
			end
		end
	end
	table.sort(list, function(a, b)
		return a:GetAttribute("Cost") < b:GetAttribute("Cost")
	end)
	return list
end

local function armedPad(pads: { BasePart }): BasePart?
	local now = Workspace:GetServerTimeNow()
	for _, pad in pads do
		local armedAt = pad:GetAttribute("ArmedAt")
		if armedAt and now - armedAt <= Layout.ConfirmSeconds then
			return pad
		end
	end
	return nil
end

local function nearestFreeGate(): BasePart?
	local plots = Workspace:FindFirstChild("Plots")
	local root = rootPart()
	local best, bestDistance = nil, math.huge
	if plots then
		for _, plot in plots:GetChildren() do
			local gate = plot:FindFirstChild("Gate")
			if plot:GetAttribute("OwnerUserId") == nil and gate and gate:IsA("BasePart") then
				local distance = if root then (gate.Position - root.Position).Magnitude else 0
				if distance < bestDistance then
					best, bestDistance = gate, distance
				end
			end
		end
	end
	return best
end

-- Works out the next goal from what the server has published.
local function findGoal(): Goal?
	local plot = myPlot()
	if not plot then
		local gate = nearestFreeGate()
		return { Text = Strings.GoalClaim, Target = gate and gate.Position, Urgent = true }
	end
	local pads = openPads(plot)
	if #pads == 0 then
		return { Text = Strings.GoalDone }
	end
	local armed = armedPad(pads)
	if armed then
		return { Text = Strings.GoalConfirm:format(padName(armed)), Target = armed.Position, Urgent = true }
	end

	local coins = player:GetAttribute("Coins") or 0
	local affordable, cheapest = nil, pads[1]
	for _, pad in pads do
		if coins >= pad:GetAttribute("Cost") then
			affordable = pad
			break
		end
	end
	local pad = affordable or cheapest
	if pad:GetAttribute("Choice") then
		local building = pad:GetAttribute("Building")
		local themed = building and Theme.Upgrades[building]
		return {
			Text = Strings.GoalPick:format(if themed then themed.DisplayName else ""),
			Target = pad.Position,
			Urgent = affordable ~= nil and os.clock() - lastPurchaseAt > IDLE_SECONDS,
		}
	end
	if affordable then
		return {
			Text = Strings.GoalBuy:format(padName(pad)),
			Target = pad.Position,
			Urgent = os.clock() - lastPurchaseAt > IDLE_SECONDS,
		}
	end
	local cost = pad:GetAttribute("Cost")
	return {
		Text = Strings.GoalSave:format(padName(pad)),
		Progress = if cost > 0 then math.clamp(coins / cost, 0, 1) else 1,
		ProgressText = Strings.GoalProgress:format(Format.whole(coins), Format.whole(cost)),
		Target = pad.Position,
	}
end

local function showGoal(goal: Goal?)
	currentGoal = goal
	goalPanel.Visible = goal ~= nil
	if not goal then
		return
	end
	goalText.Text = goal.Text
	local hasBar = goal.Progress ~= nil
	goalBar.Visible = hasBar
	goalPanel.Size = UDim2.fromOffset(470, if hasBar then 68 else 46)
	if hasBar then
		goalFill.Size = UDim2.fromScale(goal.Progress :: number, 1)
		goalBarText.Text = goal.ProgressText or ""
	end
end

local function showNote(title: string, body: string, color: Color3?)
	noteTitle.Text = title
	noteTitle.TextColor3 = color or GOLD
	noteStroke.Color = color or GOLD
	noteText.Text = body
	note.Visible = not card.Visible
	noteUntil = os.clock() + NOTE_SECONDS
	noteScale.Scale = 0.7
	TweenService:Create(noteScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

-- A see-through model of what a path pad builds, on the building it
-- improves, while its pad is armed.
local function hologram(plot: BasePart, pad: BasePart, color: Color3): Model?
	local building = pad:GetAttribute("Building")
	local builder = Theme.Props[pad.Name]
	local slot = building and Layout.Slots[building]
	if not builder or not slot then
		return nil
	end
	local origin = plot.CFrame * CFrame.new(slot.X, plot.Size.Y / 2, slot.Z)
	local model = builder(origin, Vector3.new(slot.Size[1], slot.Size[2], slot.Size[3]))
	-- Only to look at: nothing to bump into or step on, and no tags, so
	-- nothing animates it.
	local function untag(instance: Instance)
		for _, tag in instance:GetTags() do
			instance:RemoveTag(tag)
		end
	end
	untag(model)
	for _, descendant in model:GetDescendants() do
		untag(descendant)
		if descendant:IsA("BasePart") then
			descendant.Material = Enum.Material.ForceField
			descendant.Color = color
			descendant.CastShadow = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Light") or descendant:IsA("ParticleEmitter") or descendant:IsA("SurfaceGui") then
			descendant:Destroy()
		end
	end
	model.Name = "PathPreview"
	model.Parent = Workspace
	return model
end

local function clearPreview()
	if preview and preview.Model then
		preview.Model:Destroy()
	end
	preview = nil
	card.Visible = false
end

local function updatePreview()
	local plot = myPlot()
	local pad = plot and armedPad(openPads(plot))
	if not plot or not pad then
		clearPreview()
		return
	end
	local building, path = pad:GetAttribute("Building"), pad:GetAttribute("Path")
	local paths = building and Theme.Paths[building]
	local themed = paths and path and paths[path]
	if not themed then
		clearPreview()
		return
	end
	local color = Color3.fromHex(themed.Color)
	if not preview or preview.Pad ~= pad then
		clearPreview()
		preview = { Pad = pad, Model = hologram(plot, pad, color) }
	end
	local others = {}
	for _, other in openPads(plot) do
		local otherPath = other:GetAttribute("Path")
		if other ~= pad and other:GetAttribute("Building") == building and otherPath and paths[otherPath] then
			table.insert(others, paths[otherPath].DisplayName)
		end
	end
	local label = pad:FindFirstChild("ButtonLabel")
	local gain = label and label:FindFirstChild("Gain")
	cardTitle.Text = themed.DisplayName
	cardTitle.TextColor3 = color
	cardStroke.Color = color
	cardBlurb.Text = themed.Blurb
	cardGain.Text = if gain
			and gain:IsA("TextLabel")
			and gain.Text ~= ""
		then Strings.PathGain:format(gain.Text)
		else ""
	cardLocks.Text = if #others > 0 then Strings.PathLocks:format(table.concat(others, ", ")) else ""
	local left = Layout.ConfirmSeconds - (Workspace:GetServerTimeNow() - (pad:GetAttribute("ArmedAt") or 0))
	cardTimer.Size = UDim2.new(math.clamp(left / Layout.ConfirmSeconds, 0, 1), -28, 0, 4)
	card.Visible = true
	note.Visible = false
end

-- Beacons over free gates, while this player has no haunt.
local function updateBeacons(hasPlot: boolean)
	local plots = Workspace:FindFirstChild("Plots")
	local wanted: { [BasePart]: boolean } = {}
	if plots and not hasPlot then
		for _, plot in plots:GetChildren() do
			local gate = plot:FindFirstChild("Gate")
			if plot:GetAttribute("OwnerUserId") == nil and gate and gate:IsA("BasePart") then
				wanted[gate] = true
			end
		end
	end
	for gate, beacon in beacons do
		if not wanted[gate] then
			beacon:Destroy()
			beacons[gate] = nil
		end
	end
	for gate in wanted do
		if not beacons[gate] then
			local beacon = Kit.glow(
				Workspace,
				gate.CFrame * CFrame.new(0, BEACON_HEIGHT / 2 - gate.Size.Y / 2, 0),
				Vector3.new(3, BEACON_HEIGHT, 3),
				GOLD
			)
			beacon.Name = "GateBeacon"
			beacon.CanQuery = false
			beacon.Transparency = 0.6
			beacons[gate] = beacon
		end
	end
end

local function onCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and root:IsA("BasePart") then
		characterAttachment = make("Attachment", { Name = "GuideFrom", Position = Vector3.new(0, -1.5, 0) }, root)
		beam.Attachment0 = characterAttachment
	end
end

local sinceGoal = GOAL_STEP
local function onRenderStep(dt: number)
	sinceGoal += dt
	if sinceGoal >= GOAL_STEP then
		sinceGoal = 0
		local hasPlot = myPlot() ~= nil
		showGoal(findGoal())
		updateBeacons(hasPlot)
		updatePreview()
	end
	if note.Visible and os.clock() > noteUntil then
		note.Visible = false
	end

	local t = os.clock()
	for _, beacon in beacons do
		beacon.Transparency = 0.55 + math.sin(t * 2.5) * 0.15
	end

	local goal = currentGoal
	local root = rootPart()
	local target = goal and goal.Target
	local guided = goal ~= nil
		and target ~= nil
		and (goal.Urgent or (player:GetAttribute("Purchases") or 0) < GUIDED_PURCHASES)
	local far = root ~= nil and target ~= nil and (target - root.Position).Magnitude > NEAR_GOAL
	if guided and far and target then
		goalAttachment.WorldPosition = target + Vector3.new(0, 1, 0)
		beam.Enabled = characterAttachment ~= nil and characterAttachment.Parent ~= nil
		arrow.Parent = Workspace
		arrow:PivotTo(CFrame.new(target + Vector3.new(0, 6 + math.sin(t * 3) * 0.6, 0)) * CFrame.Angles(0, t * 1.5, 0))
	else
		beam.Enabled = false
		arrow.Parent = nil
	end
	-- Keep the panels a readable size on small screens.
	local camera = Workspace.CurrentCamera
	if camera then
		local width = camera.ViewportSize.X
		screenScale.Scale = math.clamp(width / 1100, 0.7, 1)
	end
end

function Guide.mount()
	gui.Parent = player:WaitForChild("PlayerGui")
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	player:GetAttributeChangedSignal("Purchases"):Connect(function()
		lastPurchaseAt = os.clock()
	end)
	player:GetAttributeChangedSignal("HasPlot"):Connect(function()
		if player:GetAttribute("HasPlot") == true then
			showNote(Strings.Welcome, Strings.WelcomeHint)
		end
	end)
	Notice.OnClientEvent:Connect(function(message)
		if type(message) ~= "table" then
			return
		end
		if message.Kind == "Short" then
			local themed = Theme.Upgrades[message.Upgrade]
			local name = if themed then themed.DisplayName else ""
			showNote(Strings.ShortCoins:format(Format.whole(message.Need or 0), name), Strings.ShortHint, WARN)
			Sounds.play("Deny")
		end
	end)
	RunService.RenderStepped:Connect(onRenderStep)
end

return Guide
