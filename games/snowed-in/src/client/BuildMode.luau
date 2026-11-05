-- Building: press B (or the Build button) for a bar of everything the team
-- can build, with what it costs from the stockpile. Picking one shows a
-- see-through copy on the snow that follows the cursor (the middle of the
-- screen on a phone), snapped to the grid, green where it can go and red
-- with the reason where it can't, using the same rules as the server
-- (shared/Grid). R turns it; clicking (or Place) asks the server to build
-- it, and the copy stays out for the next one until B, Esc or Cancel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Map = require(Shared.Config.Map)
local Resources = require(Shared.Config.Resources)
local Roles = require(Shared.Config.Roles)
local Structures = require(Shared.Config.Structures)
local Grid = require(Shared.Grid)
local Stock = require(Shared.Stock)
local Buildings = require(Shared.World.Buildings)
local Town = require(Shared.World.Town)
local Sounds = require(script.Parent.Sounds)
local UI = require(script.Parent.UI)

local State = ReplicatedStorage:WaitForChild("State") :: Configuration
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local BuildMode = {}

-- How far from the player they can build (the server allows a little more).
local REACH = 44
local GOOD = Color3.fromRGB(110, 224, 140)
local BAD = Color3.fromRGB(255, 110, 110)

local player = Players.LocalPlayer
local gui: ScreenGui
local bar: Frame
local list: Frame
local hint: TextLabel
local touchButtons: Frame
local buildButton: TextButton
local cards: { [string]: { Card: TextButton, Cost: TextLabel, Lock: TextLabel } } = {}
local open = false
local chosen: string? = nil
local turns = 0
local ghost: Model? = nil
local ghostParts: { BasePart } = {}
local reasonBoard: BillboardGui
local reasonLabel: TextLabel
local placeAt: Grid.Rect? = nil
local valid = false
local keep = Town.layout().Keep

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function stock(): Stock.Counts
	local counts = {}
	for _, resource in Resources.List do
		counts[resource.Id] = State:GetAttribute(`Stock_{resource.Id}`) or 0
	end
	return counts
end

local function cost(kind: string): Stock.Counts
	local def = Structures.ById[kind]
	local role = Roles.ById[player:GetAttribute("Role") or ""]
	if role and role.BuildDiscount then
		return Stock.discount(def.Cost, role.BuildDiscount)
	end
	return def.Cost
end

-- Why a structure can't be picked now, or nil if it can.
local function locked(kind: string): string?
	local def = Structures.ById[kind]
	if def.Role and player:GetAttribute("Role") ~= def.Role then
		return `{def.Role} only`
	end
	if (State:GetAttribute("HearthLevel") or 1) < def.Needs then
		return `Hearth level {def.Needs}`
	end
	return nil
end

local function builtRects(): { Grid.Rect }
	local rects = {}
	local folder = Workspace:FindFirstChild("Built")
	if folder then
		for _, model in folder:GetChildren() do
			local kind = model:GetAttribute("Kind")
			if kind and model:IsA("Model") then
				local pivot = model:GetPivot().Position
				table.insert(rects, Grid.place(kind, pivot.X, pivot.Z, model:GetAttribute("Turns") or 0))
			end
		end
	end
	return rects
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	table.clear(ghostParts)
	reasonBoard.Enabled = false
end

local function makeGhost(kind: string)
	clearGhost()
	local model = Buildings[kind](nil, CFrame.new())
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = math.max(part.Transparency, 0.45)
			part.Material = Enum.Material.ForceField
			table.insert(ghostParts, part)
		elseif part:IsA("Light") or part:IsA("ParticleEmitter") or part:IsA("Fire") then
			part:Destroy()
		end
	end
	model.Parent = Workspace
	ghost = model
	reasonBoard.Adornee = model.PrimaryPart
end

local function refreshCards()
	local counts = stock()
	for kind, entry in cards do
		local price = cost(kind)
		local lock = locked(kind)
		local afford = Stock.canAfford(counts, price)
		entry.Cost.Text = Stock.describe(price)
		entry.Cost.TextColor3 = if afford then UI.Colors.Text else UI.Colors.Bad
		entry.Lock.Text = lock or ""
		entry.Lock.Visible = lock ~= nil
		entry.Card.BackgroundColor3 = if kind == chosen
			then UI.Colors.Warm
			elseif lock then UI.Colors.Locked
			else UI.Colors.Card
	end
	local count = Workspace:GetAttribute("Structures") or 0
	hint.Text = if UI.touch()
		then `Built {count}/{Balance.Build.MaxStructures}. Aim with the camera, then Place.`
		else `Built {count}/{Balance.Build.MaxStructures} · Click to build · R to turn · B to close`
end

local function choose(kind: string?)
	if kind and locked(kind) then
		Sounds.play("Deny")
		return
	end
	chosen = if kind == chosen then nil else kind
	turns = 0
	if chosen then
		Sounds.play("Click")
		makeGhost(chosen)
	else
		clearGhost()
	end
	touchButtons.Visible = chosen ~= nil and UI.touch()
	refreshCards()
end

function BuildMode.close()
	open = false
	bar.Visible = false
	touchButtons.Visible = false
	chosen = nil
	clearGhost()
	buildButton.Text = "🔨 Build"
end

function BuildMode.open()
	local phase = State:GetAttribute("Phase")
	if phase ~= "Day" and phase ~= "Dusk" and phase ~= "Night" and phase ~= "Dawn" then
		return
	end
	UI.closeAll()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Put weapons away, so a click builds rather than swings.
		humanoid:UnequipTools()
	end
	open = true
	bar.Visible = true
	buildButton.Text = "✖ Close"
	refreshCards()
end

function BuildMode.toggle()
	if open then
		BuildMode.close()
	else
		BuildMode.open()
	end
end

function BuildMode.isOpen(): boolean
	return open
end

-- The point on the ground the player is pointing at.
local function pointer(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local location = if UI.touch() then camera.ViewportSize / 2 else UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(location.X, location.Y)
	if ray.Direction.Y >= -0.01 then
		return nil
	end
	return ray.Origin + ray.Direction * (-ray.Origin.Y / ray.Direction.Y)
end

local function update()
	if not chosen or not ghost then
		return
	end
	local point = pointer()
	local me = root()
	if not point or not me then
		return
	end
	-- Keep the spot within reach, along the line to where they point.
	local flat = Vector3.new(point.X - me.Position.X, 0, point.Z - me.Position.Z)
	if flat.Magnitude > REACH then
		point = Vector3.new(me.Position.X, 0, me.Position.Z) + flat.Unit * REACH
	end
	local rect = Grid.place(chosen, point.X, point.Z, turns)
	local rules = { HearthX = Map.Hearth[1], HearthZ = Map.Hearth[2], Keep = keep, Built = builtRects() }
	local ok, reason = Grid.check(rect, rules)
	if ok and not Stock.canAfford(stock(), cost(chosen)) then
		ok, reason = false, `Need {Stock.describe(Stock.missing(stock(), cost(chosen)) or {})}`
	end
	placeAt = rect
	valid = ok
	ghost:PivotTo(CFrame.new(rect.X, 0, rect.Z) * CFrame.Angles(0, Grid.turns(turns) * math.pi / 2, 0))
	for _, part in ghostParts do
		part.Color = if ok then GOOD else BAD
	end
	reasonBoard.Enabled = not ok
	reasonLabel.Text = reason or ""
end

local function place()
	if not chosen or not placeAt then
		return
	end
	if not valid then
		Sounds.play("Deny")
		return
	end
	Remotes.Build:FireServer(chosen, placeAt.X, placeAt.Z, turns)
end

local function buildBar()
	bar = UI.panel(gui, {
		Name = "BuildBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(640, 128),
		Visible = false,
	})
	UI.scale(bar)
	hint = UI.label(bar, "", {
		TextSize = 12,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 16),
	})
	list = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(8, 22),
		Size = UDim2.new(1, -16, 1, -28),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
	}, bar)
	UI.list(list, 6, true)
	local sorted = table.clone(Structures.List)
	table.sort(sorted, function(a, b)
		return a.Order < b.Order
	end)
	for _, def in sorted do
		local card = UI.button(list, "", {
			Size = UDim2.fromOffset(92, 96),
			BackgroundColor3 = UI.Colors.Card,
			LayoutOrder = def.Order,
		}, function()
			choose(def.Id)
		end)
		UI.label(card, def.Icon, {
			Font = Enum.Font.SourceSans,
			TextSize = 28,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 2),
			Size = UDim2.new(1, 0, 0, 32),
		})
		UI.label(card, def.Name, {
			Font = UI.Title,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(2, 34),
			Size = UDim2.new(1, -4, 0, 30),
		})
		local price = UI.label(card, "", {
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(2, 64),
			Size = UDim2.new(1, -4, 0, 28),
		})
		local lock = UI.label(card, "", {
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0.2,
			BackgroundColor3 = UI.Colors.Panel,
			TextColor3 = UI.Colors.Gold,
			Position = UDim2.fromOffset(4, 2),
			Size = UDim2.new(1, -8, 0, 16),
			Visible = false,
			ZIndex = 3,
		})
		UI.corner(lock, 4)
		cards[def.Id] = { Card = card, Cost = price, Lock = lock }
	end

	touchButtons = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -210),
		Size = UDim2.fromOffset(330, 50),
		Visible = false,
	}, gui)
	UI.scale(touchButtons)
	UI.list(touchButtons, 10, true)
	UI.button(touchButtons, "✔ Place", { Size = UDim2.fromOffset(110, 46), BackgroundColor3 = GOOD }, place)
	UI.button(touchButtons, "↻ Turn", { Size = UDim2.fromOffset(90, 46) }, function()
		turns += 1
	end)
	UI.button(touchButtons, "✖ Cancel", {
		Size = UDim2.fromOffset(100, 46),
		BackgroundColor3 = BAD,
		TextColor3 = UI.Colors.Text,
	}, function()
		choose(nil)
	end)

	buildButton = UI.button(gui, "🔨 Build", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -96, 1, -14),
		Size = UDim2.fromOffset(104, 44),
		Visible = false,
	}, BuildMode.toggle)
	UI.scale(buildButton)

	reasonBoard = Instance.new("BillboardGui")
	reasonBoard.Size = UDim2.fromOffset(220, 30)
	reasonBoard.StudsOffset = Vector3.new(0, 7, 0)
	reasonBoard.AlwaysOnTop = true
	reasonBoard.Enabled = false
	reasonBoard.Parent = gui
	reasonLabel = UI.label(reasonBoard, "", {
		Size = UDim2.fromScale(1, 1),
		Font = UI.Title,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = BAD,
		TextStrokeTransparency = 0.3,
	})
end

-- Shows the Build button while a run is on (the bar itself only opens then).
local function onPhase()
	local phase = State:GetAttribute("Phase")
	local playing = phase == "Day" or phase == "Dusk" or phase == "Night" or phase == "Dawn"
	buildButton.Visible = playing
	if not playing and open then
		BuildMode.close()
	end
end

local function arrange()
	-- On a phone the Build button sits above the jump button.
	if UI.touch() then
		buildButton.Position = UDim2.new(1, -14, 1, -170)
	else
		buildButton.Position = UDim2.new(1, -14, 1, -14)
		buildButton.AnchorPoint = Vector2.new(1, 1)
	end
end

function BuildMode.mount()
	gui = UI.screen("Build", 3)
	buildBar()
	UI.onRescale(arrange)
	UserInputService.LastInputTypeChanged:Connect(arrange)
	State:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	onPhase()
	State.AttributeChanged:Connect(function(name)
		if open and (name:sub(1, 6) == "Stock_" or name == "HearthLevel") then
			refreshCards()
		end
	end)
	Workspace:GetAttributeChangedSignal("Structures"):Connect(function()
		if open then
			refreshCards()
		end
	end)
	player:GetAttributeChangedSignal("Frozen"):Connect(function()
		if player:GetAttribute("Frozen") and open then
			BuildMode.close()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.B and not processed then
			BuildMode.toggle()
		elseif not open then
			return
		elseif input.KeyCode == Enum.KeyCode.R and not processed then
			turns += 1
		elseif input.KeyCode == Enum.KeyCode.Escape then
			BuildMode.close()
		elseif
			(input.UserInputType == Enum.UserInputType.MouseButton1 and not processed and not UI.touch())
			or (input.KeyCode == Enum.KeyCode.ButtonR1 and chosen)
		then
			place()
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return BuildMode
