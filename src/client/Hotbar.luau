-- The hotbar: everything the player can hold, as a row of small slots at the
-- bottom of the screen, each with a picture of the item made from its own
-- model. It takes the place of Roblox's own backpack bar, which shows only an
-- item's name unless the item has an uploaded icon image; every model in the
-- game is built from parts in code, so there are no images to upload. Click
-- or tap a slot, or press its number (L1 and R1 on a gamepad), to hold that
-- item or put it away, and its name shows for a moment over the bar.
--
-- The server gives and takes the items (the held cosmetic from the wardrobe,
-- the arena's bonker); this only equips what the player already has.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GOLD = Color3.fromRGB(255, 205, 90)
local PANEL = Color3.fromRGB(26, 18, 40)
local HELD = Color3.fromRGB(70, 48, 100)
local TEXT = Color3.fromRGB(255, 244, 214)
local DIM = Color3.fromRGB(170, 160, 190)
local FONT = Enum.Font.FredokaOne
local SLOT = 54
local GAP = 6
local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}
local NAME_SECONDS = 1.6
-- Held items are built with the grip at the origin, +Y up and -Z forward.
-- The picture turns them mostly side on, so a lantern's arm or a scythe's
-- blade shows, and leans them to the right the way a sword or a broom
-- usually sits in an icon.
local POSE = CFrame.Angles(0, 0, math.rad(40)) * CFrame.Angles(0, math.rad(-60), 0)
local FIELD_OF_VIEW = 30
-- Room left round the item in its picture.
local MARGIN = 1.15

type Slot = { Button: TextButton, Stroke: UIStroke }

local Hotbar = {}

local player = Players.LocalPlayer
local tools: { Tool } = {}
local slots: { [Tool]: Slot } = {}
local queued = false
local nameShown = 0

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local gui = make("ScreenGui", { Name = "Hotbar", ResetOnSpawn = false })
local holder = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.fromOffset(#KEYS * (SLOT + GAP), SLOT + 26),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
local holderScale = make("UIScale", {}, holder)
local bar = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.new(1, 0, 0, SLOT),
	BackgroundTransparency = 1,
}, holder)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, GAP),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, bar)
local nameLabel = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 16,
	TextColor3 = TEXT,
	TextStrokeTransparency = 0.3,
	TextTransparency = 1,
	TextStrokeColor3 = Color3.fromRGB(40, 10, 60),
}, holder)

-- The eight corners of a part's box, where it sits.
local function corners(part: BasePart): { Vector3 }
	local half = part.Size / 2
	local list = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(list, part.CFrame * Vector3.new(x * half.X, y * half.Y, z * half.Z))
			end
		end
	end
	return list
end

-- A picture of the tool: copies of the parts you can see, placed as they sit
-- against its Handle and posed, in a viewport with a camera that fits them.
local function picture(tool: Tool, parent: GuiObject)
	local handle = tool:FindFirstChild("Handle")
	local origin = if handle and handle:IsA("BasePart") then handle.CFrame else CFrame.new()
	local viewport = make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 160, 190),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-0.5, -0.8, 1),
	}, parent)
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in tool:GetDescendants() do
		local copy = if part:IsA("BasePart") and part.Transparency < 1 then part:Clone() else nil
		if copy then
			-- Only what changes how it looks comes along: meshes and decals.
			for _, inside in copy:GetDescendants() do
				if not (inside:IsA("DataModelMesh") or inside:IsA("FaceInstance")) then
					inside:Destroy()
				end
			end
			copy.Anchored = true
			copy.CFrame = POSE * origin:ToObjectSpace(part.CFrame)
			copy.Parent = viewport
			for _, point in corners(copy) do
				low, high = low:Min(point), high:Max(point)
			end
		end
	end
	if low.X > high.X then
		return
	end
	-- Looking at its front, along +Z.
	local centre, extent = (low + high) / 2, high - low
	local half = math.max(extent.X, extent.Y) / 2 * MARGIN
	local distance = half / math.tan(math.rad(FIELD_OF_VIEW / 2)) + extent.Z / 2
	local camera = make("Camera", {
		FieldOfView = FIELD_OF_VIEW,
		CFrame = CFrame.lookAt(centre - Vector3.zAxis * distance, centre),
	}, viewport)
	viewport.CurrentCamera = camera
end

local function showName(text: string)
	nameLabel.Text = text
	nameLabel.TextTransparency = 0
	nameLabel.TextStrokeTransparency = 0.3
	nameShown = os.clock()
	local shownAt = nameShown
	task.delay(NAME_SECONDS, function()
		if nameShown == shownAt then
			TweenService:Create(nameLabel, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
				:Play()
		end
	end)
end

local function humanoid(): Humanoid?
	local character = player.Character
	local found = character and character:FindFirstChildOfClass("Humanoid")
	return if found and found.Health > 0 then found else nil
end

-- Holds the tool, or puts it away if it's already held.
local function toggle(tool: Tool)
	local wearer = humanoid()
	if not wearer then
		return
	end
	if tool.Parent == player.Character then
		wearer:UnequipTools()
	else
		wearer:EquipTool(tool)
		showName(tool.Name)
	end
end

local function makeSlot(tool: Tool, index: number): Slot
	local button = make("TextButton", {
		Size = UDim2.fromOffset(SLOT, SLOT),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = index,
	}, bar)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, button)
	local stroke = make("UIStroke", {
		Color = DIM,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, button)
	picture(tool, button)
	make("TextLabel", {
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 13,
		TextColor3 = DIM,
		TextStrokeTransparency = 0.5,
		Text = tostring(index),
		Visible = UserInputService.KeyboardEnabled,
		ZIndex = 2,
	}, button)
	button.Activated:Connect(function()
		toggle(tool)
	end)
	button.MouseEnter:Connect(function()
		showName(tool.Name)
	end)
	return { Button = button, Stroke = stroke }
end

-- Marks the slot of whatever is held.
local function showHeld()
	for tool, slot in slots do
		local held = tool.Parent ~= nil and tool.Parent == player.Character
		slot.Stroke.Color = if held then GOLD else DIM
		slot.Stroke.Thickness = if held then 2.5 else 1.5
		slot.Button.BackgroundColor3 = if held then HELD else PANEL
	end
end

-- Brings the slots up to date with the tools in the backpack and in hand.
-- Each tool keeps its slot while it stays, and new ones go on the end.
local function refresh()
	queued = false
	local present: { [Tool]: boolean } = {}
	local found: { Tool } = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and not present[child] then
				present[child] = true
				table.insert(found, child)
			end
		end
	end
	local changed = false
	for index = #tools, 1, -1 do
		if not present[tools[index]] then
			table.remove(tools, index)
			changed = true
		end
	end
	for _, tool in found do
		if not table.find(tools, tool) and #tools < #KEYS then
			table.insert(tools, tool)
			changed = true
		end
	end
	if changed then
		for _, slot in slots do
			slot.Button:Destroy()
		end
		table.clear(slots)
		for index, tool in tools do
			slots[tool] = makeSlot(tool, index)
		end
		holder.Visible = #tools > 0
	end
	showHeld()
end

local function queue()
	if not queued then
		queued = true
		task.defer(refresh)
	end
end

local function watch(place: Instance)
	place.ChildAdded:Connect(queue)
	place.ChildRemoved:Connect(queue)
	queue()
end

local function onInput(input: InputObject, processed: boolean)
	if processed then
		return
	end
	local index = table.find(KEYS, input.KeyCode)
	if index then
		local tool = tools[index]
		if tool then
			toggle(tool)
		end
	elseif (input.KeyCode == Enum.KeyCode.ButtonR1 or input.KeyCode == Enum.KeyCode.ButtonL1) and #tools > 0 then
		local step = if input.KeyCode == Enum.KeyCode.ButtonR1 then 1 else -1
		local held = 0
		for at, tool in tools do
			if tool.Parent == player.Character then
				held = at
			end
		end
		if held == 0 and step < 0 then
			held = 1
		end
		toggle(tools[(held + step - 1) % #tools + 1])
	end
end

local function place()
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	holderScale.Scale = math.clamp(height / 900, 0.9, 1.25)
end

function Hotbar.mount()
	-- Roblox's own bar would show the same items again, by name.
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
				return
			end
			task.wait(0.5)
		end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	for _, child in player:GetChildren() do
		if child:IsA("Backpack") then
			watch(child)
		end
	end
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child)
		end
	end)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
	UserInputService.InputBegan:Connect(onInput)
	local watched: Camera? = nil
	local function watchCamera()
		local camera = Workspace.CurrentCamera
		if camera and camera ~= watched then
			watched = camera
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
		end
		place()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

return Hotbar
