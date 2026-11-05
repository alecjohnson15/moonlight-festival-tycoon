-- The corner of the screen for everything the game says in words: rewards,
-- challenge news, the bracket, your result, tips. They stack as small cards
-- with small text, so the middle of the screen stays clear for the runway.
-- On a computer the stack sits in the bottom right; on a phone or tablet,
-- where the thumbstick and jump button fill the bottom, it sits top right.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Ui = require(script.Parent.Ui)

local TITLE_SIZE = 16
local BODY_SIZE = 13
local WIDTH = 250
local MARGIN = 10
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local Corner = {}

-- How far from the corner each card sits, nearest first.
Corner.Order = {
	Tip = 1,
	Bracket = 2,
	Result = 3,
	Notice = 4,
}

local player = Players.LocalPlayer
local make = Ui.make

local gui = make("ScreenGui", { Name = "Corner", ResetOnSpawn = false, DisplayOrder = 3 })
local column = make("Frame", {
	Name = "Column",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -MARGIN, 1, -MARGIN),
	Size = UDim2.fromOffset(WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, column)
local columnScale = make("UIScale", {}, column)

local cards: { [Frame]: number } = {}
local onTop = false
local lineOrder = 0

-- A card in the stack, hidden until shown.
function Corner.card(order: number, accent: Color3): (Frame, UIStroke)
	local card = make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.12,
		LayoutOrder = if onTop then order else -order,
		Visible = false,
	}, column)
	Ui.corner(card, 8)
	local stroke = Ui.stroke(card, accent, 1.5)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 9),
		PaddingRight = UDim.new(0, 9),
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 6),
	}, card)
	make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, card)
	make("UIScale", {}, card)
	cards[card] = order
	return card, stroke
end

-- A line of body text on a card.
function Corner.line(card: Frame, props: { [string]: any }?): TextLabel
	lineOrder += 1
	local label = Ui.label(card, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = BODY_SIZE,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = lineOrder,
	})
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

function Corner.title(card: Frame, props: { [string]: any }?): TextLabel
	local label = Corner.line(card, { Font = Ui.Fonts.Title, TextSize = TITLE_SIZE })
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

function Corner.set(label: TextLabel, text: string)
	label.Text = text
	label.Visible = text ~= ""
end

-- A bar on a card that fills from the left, with words over it.
function Corner.bar(card: Frame, color: Color3, height: number?): (Frame, Frame, TextLabel)
	lineOrder += 1
	local track = make("Frame", {
		Size = UDim2.new(1, 0, 0, height or 14),
		BackgroundColor3 = Ui.Colors.Panel3,
		LayoutOrder = lineOrder,
	}, card)
	Ui.corner(track, 7)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color }, track)
	Ui.corner(fill, 7)
	local words = Ui.label(track, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 11,
		TextStrokeTransparency = 0.4,
		ZIndex = 2,
	})
	return track, fill, words
end

function Corner.pop(card: Frame)
	local scale = card:FindFirstChildOfClass("UIScale")
	card.Visible = true
	if scale then
		scale.Scale = 0.85
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end
end

-- A card that shows a message for a few seconds then goes, for news.
function Corner.toast(title: string, text: string, accent: Color3, seconds: number?)
	local card = Corner.card(Corner.Order.Notice, accent)
	Corner.title(card, { Text = title, TextColor3 = accent })
	if text ~= "" then
		Corner.line(card, { Text = text })
	end
	Corner.pop(card)
	task.delay(seconds or 4.5, function()
		cards[card] = nil
		card:Destroy()
	end)
end

local function place()
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	columnScale.Scale = math.clamp(height / 900, 0.85, 1.25)
	local top = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if top == onTop then
		return
	end
	onTop = top
	column.AnchorPoint = Vector2.new(1, if top then 0 else 1)
	column.Position = if top then UDim2.new(1, -MARGIN, 0, MARGIN + 56) else UDim2.new(1, -MARGIN, 1, -MARGIN)
	for card, order in cards do
		card.LayoutOrder = if top then order else -order
	end
end

function Corner.mount()
	gui.Parent = player:WaitForChild("PlayerGui")
	local watched: Camera? = nil
	local function watch()
		local camera = Workspace.CurrentCamera
		if camera and camera ~= watched then
			watched = camera
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
		end
		place()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()
end

return Corner
