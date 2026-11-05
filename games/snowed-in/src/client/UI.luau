-- A small kit for the game's screens: colours, fonts, panels, buttons and
-- windows, so every menu looks like part of the same game. Windows are
-- modal: opening one closes the others. Each panel on screen scales with
-- the screen about its own anchor (UI.scale), so phones get the same layout
-- at a size they can still read and tap.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI = {}

UI.Colors = {
	Panel = Color3.fromRGB(20, 30, 48),
	PanelLight = Color3.fromRGB(34, 48, 72),
	Card = Color3.fromRGB(40, 56, 84),
	Text = Color3.fromRGB(240, 246, 255),
	Muted = Color3.fromRGB(160, 178, 204),
	Ice = Color3.fromRGB(143, 216, 255),
	Warm = Color3.fromRGB(255, 179, 71),
	Ember = Color3.fromRGB(255, 122, 46),
	Good = Color3.fromRGB(110, 224, 140),
	Bad = Color3.fromRGB(255, 110, 110),
	Gold = Color3.fromRGB(242, 201, 76),
	Locked = Color3.fromRGB(90, 100, 118),
	Track = Color3.fromRGB(14, 22, 36),
}

UI.Title = Enum.Font.FredokaOne
UI.Body = Enum.Font.GothamBold

local player = Players.LocalPlayer
local windows: { [string]: { Frame: Frame, OnClose: (() -> ())? } } = {}
local scales: { UIScale } = {}
local listeners: { () -> () } = {}
-- How big panels are drawn for this screen (1 on a laptop).
UI.factor = 1

function UI.new(className: string, props: { [string]: any }?, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props or {} do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

function UI.corner(parent: Instance, radius: number?)
	UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

function UI.stroke(parent: Instance, color: Color3?, thickness: number?)
	UI.new("UIStroke", {
		Color = color or UI.Colors.Ice,
		Thickness = thickness or 1.5,
		Transparency = 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function UI.pad(parent: Instance, pixels: number)
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, pixels),
		PaddingRight = UDim.new(0, pixels),
		PaddingTop = UDim.new(0, pixels),
		PaddingBottom = UDim.new(0, pixels),
	}, parent)
end

function UI.list(parent: Instance, padding: number?, horizontal: boolean?): UIListLayout
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent)
end

-- A ScreenGui for some of the game's panels.
function UI.screen(name: string, order: number?): ScreenGui
	local gui = UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = order or 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

-- Makes a panel grow and shrink with the screen, about its anchor point.
function UI.scale(frame: GuiObject): UIScale
	local scale = UI.new("UIScale", { Scale = UI.factor }, frame)
	table.insert(scales, scale)
	return scale
end

-- Runs callback now and whenever the screen changes size, for panels that
-- sit relative to others.
function UI.onRescale(callback: () -> ())
	table.insert(listeners, callback)
	callback()
end

-- Whether this is a touch screen without a keyboard.
function UI.touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function UI.rescale()
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	UI.factor = math.clamp(height / 820, 0.55, 1.25)
	for _, uiScale in scales do
		uiScale.Scale = UI.factor
	end
	for _, listener in listeners do
		task.spawn(listener)
	end
end

function UI.panel(parent: Instance, props: { [string]: any }?): Frame
	local frame = UI.new("Frame", {
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
	}, parent)
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	UI.corner(frame)
	UI.stroke(frame)
	return frame
end

function UI.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local label = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = UI.Body,
		TextSize = 14,
		TextColor3 = UI.Colors.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18),
	}, parent)
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

function UI.button(parent: Instance, text: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local button = UI.new("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = UI.Colors.Warm,
		Text = text,
		Font = UI.Title,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(40, 24, 10),
		Size = UDim2.fromOffset(120, 34),
	}, parent)
	for key, value in props or {} do
		(button :: any)[key] = value
	end
	UI.corner(button, 8)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- A bar that fills from the left, with words over it. Returns the track,
-- the fill and the words.
function UI.bar(parent: Instance, color: Color3, props: { [string]: any }?): (Frame, Frame, TextLabel)
	local track = UI.new("Frame", {
		BackgroundColor3 = UI.Colors.Track,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 16),
	}, parent)
	for key, value in props or {} do
		(track :: any)[key] = value
	end
	UI.corner(track, 8)
	local fill = UI.new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, track)
	UI.corner(fill, 8)
	local words = UI.label(track, "", {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		TextStrokeTransparency = 0.5,
		ZIndex = 3,
	})
	return track, fill, words
end

function UI.setBar(fill: Frame, fraction: number)
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
end

-- A centred window with a title, a close button and a scrolling body.
-- Opening a window closes any other.
export type Window = {
	Frame: Frame,
	Body: ScrollingFrame,
	Title: TextLabel,
	Tabs: Frame,
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
}

function UI.window(gui: ScreenGui, name: string, title: string, size: Vector2, onClose: (() -> ())?): Window
	local frame = UI.panel(gui, {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		ZIndex = 10,
	})
	frame.BackgroundTransparency = 0.04
	local popScale = UI.scale(frame)
	local heading = UI.label(frame, title, {
		Font = UI.Title,
		TextSize = 24,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -70, 0, 30),
		TextColor3 = UI.Colors.Warm,
	})
	local tabs = UI.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 46),
		Size = UDim2.new(1, -28, 0, 0),
	}, frame)
	UI.list(tabs, 6, true)
	local body = UI.new("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 50),
		Size = UDim2.new(1, -28, 1, -64),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, frame)
	local window: Window
	local function close()
		frame.Visible = false
		if onClose then
			onClose()
		end
	end
	local closeButton = UI.button(frame, "X", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(36, 32),
		BackgroundColor3 = UI.Colors.Bad,
		TextColor3 = UI.Colors.Text,
	}, close)
	closeButton.Name = "Close"
	window = {
		Frame = frame,
		Body = body,
		Title = heading,
		Tabs = tabs,
		open = function()
			for other, entry in windows do
				if other ~= name and entry.Frame.Visible then
					entry.Frame.Visible = false
					if entry.OnClose then
						entry.OnClose()
					end
				end
			end
			frame.Visible = true
			popScale.Scale = UI.factor * 0.9
			TweenService:Create(popScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = UI.factor }):Play()
		end,
		close = close,
		isOpen = function()
			return frame.Visible
		end,
	}
	windows[name] = { Frame = frame, OnClose = onClose }
	return window
end

-- Leaves room for tabs above a window's body.
function UI.withTabs(window: Window)
	window.Tabs.Size = UDim2.new(1, -28, 0, 32)
	window.Body.Position = UDim2.fromOffset(14, 86)
	window.Body.Size = UDim2.new(1, -28, 1, -100)
end

function UI.closeAll()
	for _, entry in windows do
		if entry.Frame.Visible then
			entry.Frame.Visible = false
			if entry.OnClose then
				entry.OnClose()
			end
		end
	end
end

function UI.anyOpen(): boolean
	for _, entry in windows do
		if entry.Frame.Visible then
			return true
		end
	end
	return false
end

-- Removes every child of a container except its layout objects.
function UI.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

-- A row card for a menu: an icon, a title, a line of words and a button on
-- the right. Returns the card and its button.
function UI.card(
	parent: Instance,
	icon: string,
	title: string,
	blurb: string,
	action: string,
	order: number,
	height: number?
): (Frame, TextButton)
	local tall = height or 64
	local card = UI.new("Frame", {
		BackgroundColor3 = UI.Colors.Card,
		Size = UDim2.new(1, -8, 0, tall),
		LayoutOrder = order,
	}, parent)
	UI.corner(card, 8)
	UI.label(card, icon, {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(10, 10),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.SourceSans,
	})
	UI.label(card, title, {
		Font = UI.Title,
		TextSize = 17,
		Position = UDim2.fromOffset(62, 6),
		Size = UDim2.new(1, -200, 0, 22),
	})
	UI.label(card, blurb, {
		TextSize = 12,
		TextColor3 = UI.Colors.Muted,
		Position = UDim2.fromOffset(62, 28),
		Size = UDim2.new(1, -200, 0, tall - 32),
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local button = UI.button(card, action, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(124, 40),
		TextSize = 14,
		TextWrapped = true,
	})
	return card, button
end

function UI.mount()
	local function watch()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(UI.rescale)
		end
		UI.rescale()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()
end

return UI
