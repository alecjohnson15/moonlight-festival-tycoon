-- The corner of the screen for everything the game says in words: notices,
-- level ups, trade requests, the Truth Bell's news. They stack as small
-- cards with small text, so the middle of the screen stays clear. On a
-- computer the stack sits in the bottom right; on a phone or tablet, where
-- the thumbstick and jump button fill the bottom, it sits in the top right.

local Workspace = game:GetService("Workspace")

local Ui = require(script.Parent.Ui)

local WIDTH = 250
local MARGIN = 10
local NOTE_SECONDS = 5
local MAX_NOTES = 4

local Corner = {}

local gui = Ui.screen("Corner", 5)
local column = Ui.make("Frame", {
	Name = "Column",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -MARGIN, 1, -MARGIN),
	Size = UDim2.fromOffset(WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
local layout = Ui.list(column, 5)
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
local columnScale = Ui.make("UIScale", {}, column)

local order = 0
local notes: { Frame } = {}

-- A card in the stack. Lines go inside it, and it grows to fit them.
function Corner.card(accent: Color3): Frame
	order += 1
	local card = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.12,
		LayoutOrder = order,
	}, column)
	Ui.round(card, 8)
	Ui.stroke(card, accent, 1.5)
	Ui.pad(card, 9, 6)
	Ui.list(card, 3)
	return card
end

function Corner.title(card: Frame, text: string, color: Color3?): TextLabel
	return Ui.label(card, text, {
		Font = Ui.Title,
		TextSize = 16,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color or Ui.Colors.Gold,
		LayoutOrder = 1,
	})
end

function Corner.line(card: Frame, text: string, layoutOrder: number?): TextLabel
	return Ui.label(card, text, {
		TextSize = 13,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = layoutOrder or 2,
	})
end

local function pop(card: Frame)
	local scale = Ui.make("UIScale", { Scale = 0.85 }, card)
	Ui.pop(scale, 1)
end

-- A note that shows for a few seconds and goes.
function Corner.note(title: string, text: string?, accent: Color3?, seconds: number?): Frame
	local card = Corner.card(accent or Ui.Colors.Accent)
	Corner.title(card, title, accent)
	if text and text ~= "" then
		Corner.line(card, text)
	end
	pop(card)
	table.insert(notes, card)
	while #notes > MAX_NOTES do
		local oldest = table.remove(notes, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(seconds or NOTE_SECONDS, function()
		local index = table.find(notes, card)
		if index then
			table.remove(notes, index)
		end
		card:Destroy()
	end)
	return card
end

-- A note with two buttons, such as a trade request. Calls answer(true or
-- false), or nothing if it times out.
function Corner.ask(title: string, text: string, yes: string, no: string, seconds: number, answer: (boolean) -> ())
	local card = Corner.card(Ui.Colors.Gold)
	Corner.title(card, title)
	Corner.line(card, text)
	local row = Ui.make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 3 }, card)
	Ui.list(row, 6, true)
	local done = false
	local function finish(value: boolean?)
		if done then
			return
		end
		done = true
		card:Destroy()
		if value ~= nil then
			answer(value)
		end
	end
	Ui.button(row, yes, Ui.Colors.Good, { Size = UDim2.fromOffset(100, 28), TextSize = 14 }).Activated
		:Connect(function()
			finish(true)
		end)
	Ui.button(row, no, Ui.Colors.Bad, { Size = UDim2.fromOffset(100, 28), TextSize = 14 }).Activated:Connect(function()
		finish(false)
	end)
	pop(card)
	task.delay(seconds, function()
		finish(nil)
	end)
end

local onTop = false
local function place()
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	columnScale.Scale = math.clamp(height / 900, 0.8, 1.2)
	local top = Ui.isTouch()
	if top == onTop then
		return
	end
	onTop = top
	column.AnchorPoint = Vector2.new(1, if top then 0 else 1)
	column.Position = if top then UDim2.new(1, -MARGIN, 0, MARGIN + 36) else UDim2.new(1, -MARGIN, 1, -MARGIN)
	layout.VerticalAlignment = if top then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
end

function Corner.start()
	place()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
end

return Corner
