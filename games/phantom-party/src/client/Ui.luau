-- The look every screen shares, and the small builders the screens use:
-- colours, fonts, rounded panels, buttons, a scale that fits the screen,
-- and pictures of items drawn from their real models.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Gear = require(Shared.Look.Gear)

local Ui = {}

-- The player's Reduce motion setting (Settings keeps it in step with the
-- save): pops, shuffles and flicker are skipped while it's on.
Ui.ReduceMotion = false

-- Grows a UIScale from its current size to target with a little bounce,
-- or jumps straight there with Reduce motion on.
function Ui.pop(scale: UIScale, target: number, seconds: number?)
	if Ui.ReduceMotion then
		scale.Scale = target
		return
	end
	TweenService:Create(scale, TweenInfo.new(seconds or 0.25, Enum.EasingStyle.Back), { Scale = target }):Play()
end

Ui.Colors = {
	Panel = Color3.fromRGB(24, 16, 38),
	Card = Color3.fromRGB(40, 28, 62),
	CardHover = Color3.fromRGB(56, 40, 84),
	Track = Color3.fromRGB(52, 40, 74),
	Text = Color3.fromRGB(255, 244, 222),
	Dim = Color3.fromRGB(176, 164, 200),
	Gold = Color3.fromRGB(255, 205, 90),
	Good = Color3.fromRGB(96, 214, 128),
	Bad = Color3.fromRGB(255, 92, 112),
	Accent = Color3.fromRGB(176, 103, 255),
	Robux = Color3.fromRGB(80, 200, 120),
}

Ui.Title = Enum.Font.FredokaOne
Ui.Body = Enum.Font.GothamBold

local player = Players.LocalPlayer

function Ui.make(className: string, props: { [string]: any }?, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props or {} do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

function Ui.hex(value: string): Color3
	return Color3.fromHex(value)
end

function Ui.rarityColor(rarity: string): Color3
	return Color3.fromHex(Items.RARITY_COLORS[rarity] or "#B8C0CC")
end

function Ui.round(parent: Instance, radius: number?)
	Ui.make("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

function Ui.stroke(parent: Instance, color: Color3, thickness: number?)
	return Ui.make("UIStroke", {
		Color = color,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function Ui.pad(parent: Instance, x: number, y: number?)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y or x),
		PaddingBottom = UDim.new(0, y or x),
	}, parent)
end

function Ui.list(parent: Instance, gap: number?, horizontal: boolean?)
	return Ui.make("UIListLayout", {
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
	}, parent)
end

function Ui.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = Ui.make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Ui.Body,
		TextSize = 14,
		TextColor3 = Ui.Colors.Text,
		Text = text,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 18),
	}, parent)
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

-- A button with a colour, rounded corners and a press bounce.
function Ui.button(parent: Instance, text: string, color: Color3, props: { [string]: any }?): TextButton
	local button = Ui.make("TextButton", {
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Font = Ui.Title,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.6,
		Text = text,
		Size = UDim2.fromOffset(110, 32),
	}, parent)
	Ui.round(button, 8)
	for key, value in props or {} do
		(button :: any)[key] = value
	end
	local scale = Ui.make("UIScale", {}, button)
	button.MouseButton1Down:Connect(function()
		scale.Scale = 0.94
	end)
	button.MouseButton1Up:Connect(function()
		Ui.pop(scale, 1, 0.15)
	end)
	button.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	return button
end

-- How big to draw the interface on this screen: smaller on a phone so
-- panels never cover the whole view.
function Ui.screenScale(): number
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(size.X / 1100, size.Y / 700), 0.62, 1.15)
end

function Ui.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Keeps a UIScale on parent matched to the screen.
function Ui.fitScale(parent: Instance): UIScale
	local scale = Ui.make("UIScale", { Scale = Ui.screenScale() }, parent)
	local function refresh()
		scale.Scale = Ui.screenScale()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local now = Workspace.CurrentCamera
		if now then
			now:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
		end
		refresh()
	end)
	return scale
end

function Ui.screen(name: string, order: number?): ScreenGui
	return Ui.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = order or 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
end

-- Pictures ---------------------------------------------------------------

local previews: { [string]: Model } = {}

local function previewOf(itemId: string): Model?
	if previews[itemId] == nil then
		local ok, model = pcall(Gear.preview, itemId)
		previews[itemId] = if ok then model else false :: any
	end
	local cached = previews[itemId]
	return if cached then cached:Clone() else nil
end

-- A still picture of an item, from its real model, filling parent.
function Ui.picture(parent: Instance, itemId: string, turned: number?): ViewportFrame
	local viewport = Ui.make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(180, 170, 200),
		LightColor = Color3.fromRGB(255, 244, 230),
		LightDirection = Vector3.new(-0.4, -0.7, -1),
	}, parent)
	local model = previewOf(itemId)
	if not model then
		return viewport
	end
	model.Parent = viewport
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, corner in
				{ Vector3.new(1, 1, 1), Vector3.new(-1, -1, -1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, -1) }
			do
				local point = part.CFrame:PointToWorldSpace(half * corner)
				low = low:Min(point)
				high = high:Max(point)
			end
		end
	end
	if low.X == math.huge then
		return viewport
	end
	local centre = (low + high) / 2
	local radius = math.max((high - low).Magnitude / 2, 0.5)
	local camera = Ui.make("Camera", { FieldOfView = 30 }, viewport)
	local angle = turned or 0.5
	local distance = radius / math.tan(math.rad(15)) * 1.05
	local eye = centre + Vector3.new(math.sin(angle) * distance, radius * 0.35, -math.cos(angle) * distance)
	camera.CFrame = CFrame.lookAt(eye, centre)
	viewport.CurrentCamera = camera
	return viewport
end

-- An item card's look: a rounded square with the item's picture, rarity
-- edge and name. Returns the card as a button.
function Ui.itemCard(parent: Instance, itemId: string, size: number): TextButton
	local item = Items.get(itemId)
	local rarity = item and item.Rarity or "Common"
	local card = Ui.make("TextButton", {
		Size = UDim2.fromOffset(size, size + 22),
		BackgroundColor3 = Ui.Colors.Card,
		AutoButtonColor = true,
		Text = "",
	}, parent)
	Ui.round(card, 8)
	Ui.stroke(card, Ui.rarityColor(rarity), 2)
	local frame = Ui.make("Frame", {
		Size = UDim2.fromOffset(size - 8, size - 8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
	}, card)
	Ui.picture(frame, itemId)
	Ui.label(card, item and item.Name or itemId, {
		Size = UDim2.new(1, -6, 0, 18),
		Position = UDim2.new(0, 3, 1, -20),
		TextSize = 11,
		TextScaled = true,
		Font = Ui.Body,
	})
	return card
end

-- Opens and closes panels so only one shows at a time.
local openPanel: GuiObject? = nil

function Ui.show(panel: GuiObject)
	if openPanel and openPanel ~= panel then
		openPanel.Visible = false
	end
	openPanel = panel
	panel.Visible = true
	local scale = panel:FindFirstChildOfClass("UIScale")
	if scale then
		local target = Ui.screenScale()
		scale.Scale = target * 0.9
		Ui.pop(scale, target, 0.2)
	end
end

function Ui.isOpen(panel: GuiObject): boolean
	return openPanel == panel and panel.Visible
end

function Ui.hide(panel: GuiObject)
	panel.Visible = false
	if openPanel == panel then
		openPanel = nil
	end
end

function Ui.hideAll()
	if openPanel then
		openPanel.Visible = false
		openPanel = nil
	end
end

-- A centred panel with a title bar and a close button. Returns the panel
-- and the frame its contents go in.
function Ui.panel(gui: ScreenGui, title: string, width: number, height: number): (Frame, Frame, TextLabel)
	local holder = Ui.make("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
	}, gui)
	Ui.round(holder, 12)
	Ui.stroke(holder, Ui.Colors.Accent, 2)
	Ui.fitScale(holder)
	local heading = Ui.label(holder, title, {
		Font = Ui.Title,
		TextSize = 22,
		Size = UDim2.new(1, -60, 0, 34),
		Position = UDim2.fromOffset(14, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.Gold,
	})
	local close = Ui.button(holder, "X", Ui.Colors.Bad, {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -38, 0, 8),
		TextSize = 16,
	})
	close.Activated:Connect(function()
		Ui.hide(holder)
	end)
	local body = Ui.make("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -24, 1, -52),
		Position = UDim2.fromOffset(12, 44),
		BackgroundTransparency = 1,
	}, holder)
	return holder, body, heading
end

-- A scrolling grid of cells of a fixed size.
function Ui.grid(parent: Instance, cell: Vector2, props: { [string]: any }?): ScrollingFrame
	local scroller = Ui.make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Ui.Colors.Accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
	}, parent)
	for key, value in props or {} do
		(scroller :: any)[key] = value
	end
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scroller)
	Ui.pad(scroller, 4)
	return scroller
end

-- Tabs along the top of a panel body. Returns the content frame and a
-- function to pick a tab.
function Ui.tabs(body: Frame, names: { string }, onPick: (string) -> ()): (Frame, (string) -> ())
	local bar = Ui.make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, body)
	Ui.list(bar, 6, true)
	local content = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 1, -38),
		Position = UDim2.fromOffset(0, 38),
		BackgroundTransparency = 1,
	}, body)
	local buttons = {}
	local function pick(name: string)
		for other, button in buttons do
			button.BackgroundColor3 = if other == name then Ui.Colors.Accent else Ui.Colors.Card
		end
		for _, child in content:GetChildren() do
			child:Destroy()
		end
		onPick(name)
	end
	for index, name in names do
		local button = Ui.button(bar, name, Ui.Colors.Card, {
			Size = UDim2.fromOffset(math.max(70, #name * 8 + 20), 28),
			TextSize = 13,
			LayoutOrder = index,
		})
		buttons[name] = button
		button.Activated:Connect(function()
			pick(name)
		end)
	end
	return content, pick
end

return Ui
