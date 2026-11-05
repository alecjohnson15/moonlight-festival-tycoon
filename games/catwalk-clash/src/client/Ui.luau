-- Shared pieces for the game's screens: colours, fonts, and helpers that
-- make labels, buttons, swatches and windows in one consistent style. Only
-- one window is open at a time; opening another closes the first.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Ui = {}

Ui.Colors = {
	Panel = Color3.fromRGB(30, 18, 48),
	Panel2 = Color3.fromRGB(48, 30, 74),
	Panel3 = Color3.fromRGB(66, 42, 100),
	Dark = Color3.fromRGB(16, 10, 28),
	Text = Color3.fromRGB(255, 246, 252),
	Muted = Color3.fromRGB(206, 186, 228),
	Pink = Color3.fromRGB(255, 70, 170),
	Aqua = Color3.fromRGB(70, 226, 240),
	Gold = Color3.fromRGB(255, 205, 90),
	Violet = Color3.fromRGB(160, 100, 255),
	Green = Color3.fromRGB(90, 226, 140),
	Red = Color3.fromRGB(255, 92, 110),
}
local C = Ui.Colors

Ui.Fonts = {
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
	Plain = Enum.Font.GothamMedium,
}

local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local player = Players.LocalPlayer

-- Set by client/Sounds so every button clicks.
Ui.clickSound = function() end

function Ui.make(className: string, props: { [string]: any }?, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props or {} do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end
local make = Ui.make

function Ui.corner(parent: Instance, radius: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

function Ui.stroke(parent: Instance, color: Color3, thickness: number?)
	return make("UIStroke", {
		Color = color,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function Ui.pad(parent: Instance, pixels: number)
	return make("UIPadding", {
		PaddingLeft = UDim.new(0, pixels),
		PaddingRight = UDim.new(0, pixels),
		PaddingTop = UDim.new(0, pixels),
		PaddingBottom = UDim.new(0, pixels),
	}, parent)
end

function Ui.list(parent: Instance, horizontal: boolean?, padding: number?, align: Enum.HorizontalAlignment?)
	return make("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
	}, parent)
end

function Ui.grid(parent: Instance, cell: Vector2, padding: number?)
	return make("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(padding or 6, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent)
end

-- A text label with the game's look; props override anything.
function Ui.label(parent: Instance?, props: { [string]: any }?): TextLabel
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Ui.Fonts.Body,
		TextSize = 14,
		TextColor3 = C.Text,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 20),
	}, parent)
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

-- A rounded button that squishes when pressed and clicks.
function Ui.button(
	parent: Instance?,
	text: string,
	color: Color3,
	onClick: (() -> ())?,
	props: { [string]: any }?
): TextButton
	local button = make("TextButton", {
		Size = UDim2.fromOffset(120, 36),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Font = Ui.Fonts.Title,
		Text = text,
		TextSize = 17,
		TextColor3 = C.Text,
	}, parent)
	Ui.corner(button, 10)
	make("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Transparency = 0.6,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}, button)
	local scale = make("UIScale", {}, button)
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
	end)
	if onClick then
		button.Activated:Connect(function()
			Ui.clickSound()
			onClick()
		end)
	end
	for key, value in props or {} do
		(button :: any)[key] = value
	end
	return button
end

-- A small rounded chip that shows whether it's chosen.
function Ui.chip(parent: Instance?, text: string, onClick: () -> ()): TextButton
	local chip = Ui.button(parent, text, C.Panel2, onClick, {
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 14,
		Font = Ui.Fonts.Body,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, chip)
	return chip
end

function Ui.setChosen(button: GuiButton, chosen: boolean, color: Color3?)
	button.BackgroundColor3 = if chosen then (color or C.Pink) else C.Panel2
end

function Ui.commas(value: number): string
	local text = tostring(math.floor(value))
	local result = text
	repeat
		local count
		result, count = string.gsub(result, "^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return result
end

function Ui.sparkles(value: number): string
	return `✦ {Ui.commas(value)}`
end

function Ui.time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- A ScreenGui in the player's screen.
function Ui.screen(name: string, order: number?): ScreenGui
	return make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = order or 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
end

-- True on a phone or tablet.
function Ui.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Keeps a frame's UIScale suited to the screen size.
function Ui.autoscale(target: GuiObject, base: number?)
	local scale = make("UIScale", {}, target)
	local function update()
		local camera = Workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local value = math.clamp(math.min(size.X / 1100, size.Y / (base or 720)), 0.6, 1.25)
		scale.Scale = value
		scale:SetAttribute("Base", value)
	end
	local watched: Camera? = nil
	local function watch()
		local camera = Workspace.CurrentCamera
		if camera and camera ~= watched then
			watched = camera
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()
	return scale
end

-- A scrolling area that grows with its contents.
function Ui.scroller(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local frame = make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Pink,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	return frame
end

export type Window = {
	Name: string,
	Gui: ScreenGui,
	Frame: Frame,
	Body: Frame,
	Title: TextLabel,
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	onOpen: (callback: () -> ()) -> (),
	onClose: (callback: () -> ()) -> (),
}

local windows: { Window } = {}

-- A panel with a title and a close button. size is in pixels at the base
-- scale; dock is "Centre" or "Left" (the wardrobe, leaving the character
-- in view).
function Ui.window(name: string, title: string, size: Vector2, accent: Color3, dock: string?): Window
	local gui = Ui.screen(name, 5)
	gui.Enabled = false
	local left = dock == "Left"
	local frame = make("Frame", {
		Name = "Window",
		AnchorPoint = if left then Vector2.new(0, 0.5) else Vector2.new(0.5, 0.5),
		Position = if left then UDim2.new(0, 14, 0.5, 0) else UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.04,
	}, gui)
	Ui.corner(frame, 16)
	Ui.stroke(frame, accent, 2.5)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 190, 220)),
		Rotation = 90,
	}, frame)
	Ui.autoscale(frame, size.Y + 80)
	local titleBar = make("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = accent,
	}, frame)
	Ui.corner(titleBar, 16)
	make("Frame", {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 1, -16),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, titleBar)
	local titleLabel = Ui.label(titleBar, {
		Text = title,
		Font = Ui.Fonts.Title,
		TextSize = 24,
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	make("UIStroke", { Color = Color3.fromRGB(40, 10, 50), Thickness = 1.5 }, titleLabel)
	local body = make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(12, 54),
		Size = UDim2.new(1, -24, 1, -66),
		BackgroundTransparency = 1,
	}, frame)

	local openCallbacks, closeCallbacks = {}, {}
	local window: Window
	window = {
		Name = name,
		Gui = gui,
		Frame = frame,
		Body = body,
		Title = titleLabel,
		open = function()
			for _, other in windows do
				if other ~= window and other.isOpen() then
					other.close()
				end
			end
			if gui.Enabled then
				return
			end
			gui.Enabled = true
			frame.Position = if left then UDim2.new(0, -20, 0.5, 0) else UDim2.fromScale(0.5, 0.56)
			TweenService:Create(frame, POP, {
				Position = if left then UDim2.new(0, 14, 0.5, 0) else UDim2.fromScale(0.5, 0.52),
			}):Play()
			for _, callback in openCallbacks do
				task.spawn(callback)
			end
		end,
		close = function()
			if not gui.Enabled then
				return
			end
			gui.Enabled = false
			for _, callback in closeCallbacks do
				task.spawn(callback)
			end
		end,
		isOpen = function()
			return gui.Enabled
		end,
		onOpen = function(callback)
			table.insert(openCallbacks, callback)
		end,
		onClose = function(callback)
			table.insert(closeCallbacks, callback)
		end,
	}
	Ui.button(titleBar, "✕", C.Dark, function()
		window.close()
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
		TextSize = 16,
	})
	table.insert(windows, window)
	return window
end

-- Closes whatever window is open.
function Ui.closeAll()
	for _, window in windows do
		window.close()
	end
end

-- A tab strip: returns a function to switch tabs by name.
function Ui.tabs(parent: Instance, names: { string }, onPick: (string) -> (), accent: Color3?): (string) -> ()
	local strip = make("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
	}, parent)
	Ui.list(strip, true, 6)
	local buttons = {}
	local function pick(name: string)
		for other, button in buttons do
			Ui.setChosen(button, other == name, accent)
		end
		onPick(name)
	end
	for index, name in names do
		local button = Ui.chip(strip, name, function()
			pick(name)
		end)
		button.LayoutOrder = index
		buttons[name] = button
	end
	return pick
end

-- Pops a GUI object in with a bounce.
-- Uses the object's own UIScale if it has one (from Ui.autoscale).
function Ui.pop(target: GuiObject)
	local scale = target:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = make("UIScale", {}, target)
	end
	local size = (scale :: UIScale):GetAttribute("Base") or (scale :: UIScale).Scale;
	(scale :: UIScale).Scale = size * 0.7
	TweenService:Create(scale :: UIScale, POP, { Scale = size }):Play()
end

return Ui
