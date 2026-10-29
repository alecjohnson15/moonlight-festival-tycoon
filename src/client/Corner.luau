-- The corner of the screen for everything the game says in words: the
-- guide's goal, its notes and the path preview (client/Guide), Ghost
-- Catcher's round and result (client/Activity), the Moonlight Parade's thanks
-- (client/Parade) and new wardrobe items (client/Wardrobe). They stack as
-- small cards with small text, so the middle of the screen stays clear. On a
-- computer or console the stack sits in the bottom right corner; on a phone
-- or tablet, where the thumbstick and the jump button fill the bottom of the
-- screen, it sits in the top right. The goal is always the card nearest the
-- corner, and the others stack away from it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PANEL = Color3.fromRGB(26, 18, 40)
local TEXT = Color3.fromRGB(255, 244, 214)
local TRACK = Color3.fromRGB(50, 38, 70)
local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamBold
local TITLE_SIZE = 16
local BODY_SIZE = 13
local WIDTH = 240
local MARGIN = 10
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local Corner = {}

-- How far from the corner each card sits, nearest first.
Corner.Order = {
	Goal = 1,
	Path = 2,
	Note = 3,
	Activity = 4,
	Parade = 5,
	Wardrobe = 6,
}

local player = Players.LocalPlayer

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local gui = make("ScreenGui", { Name = "Corner", ResetOnSpawn = false })
local column = make("Frame", {
	Name = "Column",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -MARGIN, 1, -MARGIN),
	Size = UDim2.fromOffset(WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
make("UIListLayout", {
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, column)
local columnScale = make("UIScale", {}, column)

local cards: { [Frame]: number } = {}
local onTop = false
local lineOrder = 0

-- A card in the stack, hidden until shown. Its lines stack inside it, and it
-- grows to fit them.
function Corner.card(order: number, accent: Color3): (Frame, UIStroke)
	local card = make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		LayoutOrder = if onTop then order else -order,
		Visible = false,
	}, column)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, card)
	local stroke = make("UIStroke", {
		Color = accent,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, card)
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

-- A line of body text on a card, wrapping onto more lines when it must.
function Corner.line(card: Frame, props: { [string]: any }?): TextLabel
	lineOrder += 1
	local label = make("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = BODY,
		TextSize = BODY_SIZE,
		TextColor3 = TEXT,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = lineOrder,
	}, card)
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

-- A heading line on a card.
function Corner.title(card: Frame, props: { [string]: any }?): TextLabel
	local label = Corner.line(card, { Font = TITLE, TextSize = TITLE_SIZE })
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

-- Puts words on a line, and hides the line when there are none.
function Corner.set(label: TextLabel, text: string)
	label.Text = text
	label.Visible = text ~= ""
end

-- An empty strip across a card, for things side by side.
function Corner.row(card: Frame, height: number): Frame
	lineOrder += 1
	return make("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = lineOrder,
	}, card)
end

-- A bar on a card that fills from the left, with words over it.
function Corner.bar(card: Frame, color: Color3, height: number?): (Frame, Frame, TextLabel)
	lineOrder += 1
	local track = make("Frame", {
		Size = UDim2.new(1, 0, 0, height or 14),
		BackgroundColor3 = TRACK,
		LayoutOrder = lineOrder,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color }, track)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	local words = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = BODY,
		TextSize = 11,
		TextColor3 = TEXT,
		TextStrokeTransparency = 0.4,
		ZIndex = 2,
	}, track)
	return track, fill, words
end

-- Shows a card with a little bounce.
function Corner.pop(card: Frame)
	local scale = card:FindFirstChildOfClass("UIScale")
	card.Visible = true
	if scale then
		scale.Scale = 0.85
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end
end

-- Puts the stack in its corner, at a size to suit the screen: a touch screen
-- gets the top right, anything else the bottom right.
local function place()
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	columnScale.Scale = math.clamp(height / 900, 0.9, 1.25)
	local top = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if top == onTop then
		return
	end
	onTop = top
	column.AnchorPoint = Vector2.new(1, if top then 0 else 1)
	column.Position = if top then UDim2.new(1, -MARGIN, 0, MARGIN) else UDim2.new(1, -MARGIN, 1, -MARGIN)
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
