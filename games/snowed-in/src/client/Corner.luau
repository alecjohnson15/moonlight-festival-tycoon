-- The corner of the screen for everything the game says in words: the
-- guide's next goal (client/Guide), the radio's progress, and short notes
-- from the server ("Dropped off 12 wood"). They stack as small cards with
-- small text, so the middle of the screen stays clear for the blizzard. On
-- a computer the stack sits in the bottom right corner; on a phone, where
-- the thumbstick and jump button fill the bottom, it sits in the top right
-- under the HUD's corner. The goal is always the card nearest the corner.
--
-- Big team news (nightfall, a yeti, the radio calling) is a banner across
-- the top instead, below the night counter, for a few seconds.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent.UI)

local TITLE_SIZE = 16
local BODY_SIZE = 13
local WIDTH = 250
local MARGIN = 10
local NOTE_SECONDS = 5
local MAX_NOTES = 3
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local Corner = {}

-- How far from the corner each card sits, nearest first.
Corner.Order = {
	Goal = 1,
	Radio = 2,
	Note = 3,
}

local KIND_COLORS = {
	Info = UI.Colors.Ice,
	Good = UI.Colors.Good,
	Bad = UI.Colors.Bad,
	Big = UI.Colors.Warm,
}

local player = Players.LocalPlayer

local gui = UI.new("ScreenGui", { Name = "Corner", ResetOnSpawn = false, DisplayOrder = 2 })
local column = UI.new("Frame", {
	Name = "Column",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -MARGIN, 1, -MARGIN),
	Size = UDim2.fromOffset(WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, gui)
UI.new("UIListLayout", {
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, column)
local columnScale = UI.new("UIScale", {}, column)

local banner = UI.new("TextLabel", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 96),
	Size = UDim2.fromOffset(520, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = UI.Colors.Panel,
	BackgroundTransparency = 0.2,
	Font = UI.Title,
	TextSize = 20,
	TextColor3 = UI.Colors.Warm,
	TextWrapped = true,
	TextStrokeTransparency = 0.6,
	Visible = false,
}, gui)
UI.corner(banner, 10)
UI.pad(banner, 8)
local bannerScale = UI.new("UIScale", {}, banner)

local cards: { [Frame]: number } = {}
local onTop = false
local lineOrder = 0
local notes: { Frame } = {}
local bannerToken = 0

-- A card in the stack, hidden until shown. Its lines stack inside it, and it
-- grows to fit them.
function Corner.card(order: number, accent: Color3): (Frame, UIStroke)
	local card = UI.new("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.15,
		LayoutOrder = if onTop then order else -order,
		Visible = false,
	}, column)
	UI.corner(card, 8)
	local stroke = UI.new("UIStroke", {
		Color = accent,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, card)
	UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, 9),
		PaddingRight = UDim.new(0, 9),
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 6),
	}, card)
	UI.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, card)
	UI.new("UIScale", {}, card)
	cards[card] = order
	return card, stroke
end

-- A line of body text on a card, wrapping onto more lines when it must.
function Corner.line(card: Frame, props: { [string]: any }?): TextLabel
	lineOrder += 1
	local label = UI.new("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = UI.Body,
		TextSize = BODY_SIZE,
		TextColor3 = UI.Colors.Text,
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
	local label = Corner.line(card, { Font = UI.Title, TextSize = TITLE_SIZE })
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
	return UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = lineOrder,
	}, card)
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

-- A short note that fades after a few seconds. Up to three show at once;
-- a fourth pushes the oldest out.
function Corner.note(text: string, kind: string?)
	local accent = KIND_COLORS[kind or "Info"] or UI.Colors.Ice
	local card = Corner.card(Corner.Order.Note, accent)
	Corner.line(
		card,
		{ Text = text, TextColor3 = if kind == "Bad" then Color3.fromRGB(255, 214, 214) else UI.Colors.Text }
	)
	Corner.pop(card)
	table.insert(notes, card)
	while #notes > MAX_NOTES do
		local oldest = table.remove(notes, 1) :: Frame
		cards[oldest] = nil
		oldest:Destroy()
	end
	task.delay(NOTE_SECONDS, function()
		local index = table.find(notes, card)
		if not index then
			return
		end
		table.remove(notes, index)
		cards[card] = nil
		local fade = TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		for _, child in card:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
		fade.Completed:Connect(function()
			card:Destroy()
		end)
		fade:Play()
	end)
end

-- A banner across the top for the whole team's news.
function Corner.banner(text: string, color: Color3?)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.TextColor3 = color or UI.Colors.Warm
	banner.Visible = true
	bannerScale.Scale = UI.factor * 0.7
	TweenService:Create(bannerScale, POP, { Scale = UI.factor }):Play()
	task.delay(4.5, function()
		if bannerToken == token then
			banner.Visible = false
		end
	end)
end

-- Puts the stack in its corner, at a size to suit the screen: a touch screen
-- gets the top right, anything else the bottom right.
local function place()
	local camera = Workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	local width = if camera then camera.ViewportSize.X else 1280
	columnScale.Scale = math.clamp(height / 900, 0.8, 1.2)
	bannerScale.Scale = UI.factor
	banner.Size = UDim2.fromOffset(math.min(520, (width - 40) / UI.factor), 0)
	-- Under the night counter and a boss's health bar.
	banner.Position = UDim2.new(0.5, 0, 0, 20 + 124 * UI.factor)
	local top = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	column.AnchorPoint = Vector2.new(1, if top then 0 else 1)
	-- On a phone, just left of the menu buttons down the right edge.
	column.Position = if top
		then UDim2.new(1, -MARGIN - 72 * UI.factor, 0, MARGIN)
		else UDim2.new(1, -MARGIN, 1, -MARGIN)
	if top == onTop then
		return
	end
	onTop = top
	for card, order in cards do
		card.LayoutOrder = if top then order else -order
	end
end

function Corner.mount()
	gui.Parent = player:WaitForChild("PlayerGui")
	UI.onRescale(place)
	UserInputService.LastInputTypeChanged:Connect(place)
end

return Corner
