-- The festival board: where a player picks their festival's name, the
-- colours of its stall and booth, and what goes in each decoration spot
-- (Config/Festival). It opens from the board by Ghost Catcher's booth, or
-- from a button on the left of the screen once they have a plot. Locked
-- choices say how to unlock them.
--
-- Everything shown comes from the player's Festival* attributes, which the
-- server keeps up to date; the board only asks for a choice through the
-- Festival remote, and the server checks it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Festival)
local Layout = require(Shared.Config.Layout)
local Theme = require(Shared.Config.Theme)
local Festival = require(Shared.Festival)

local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Festival") :: RemoteEvent

local GOLD = Color3.fromRGB(255, 205, 90)
local PANEL = Color3.fromRGB(26, 18, 40)
local CARD = Color3.fromRGB(40, 28, 60)
local TEXT = Color3.fromRGB(255, 244, 214)
local DIM = Color3.fromRGB(170, 160, 190)
local CHOSEN = Color3.fromRGB(90, 200, 120)
local LOCKED = Color3.fromRGB(80, 74, 96)
local FONT = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamBold
local Strings = Theme.Strings

local FestivalBoard = {}

local player = Players.LocalPlayer

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
	return make("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = BODY,
		TextColor3 = TEXT,
		TextScaled = true,
		TextWrapped = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return make("TextLabel", defaults, parent)
end

local function button(parent: Instance, props: { [string]: any }): TextButton
	local defaults = {
		BackgroundColor3 = CARD,
		Font = FONT,
		TextScaled = true,
		TextColor3 = TEXT,
		AutoButtonColor = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local made = make("TextButton", defaults, parent)
	round(made, UDim.new(0, 10))
	return made
end

-- How to unlock a choice, in words.
local function requirement(choice: Festival.Choice): string
	local unlock = choice.Unlock
	if not unlock then
		return ""
	elseif unlock.Owns then
		return Strings.FestivalUnlockOwns:format(Theme.Upgrades[unlock.Owns].DisplayName)
	elseif unlock.Building then
		return Strings.FestivalUnlockPath:format(Theme.Upgrades[unlock.Building].DisplayName)
	elseif unlock.ActivityBest then
		return Strings.FestivalUnlockActivity:format(unlock.ActivityBest)
	elseif unlock.Parades then
		return if unlock.Parades == 1
			then Strings.FestivalUnlockParade
			else Strings.FestivalUnlockParades:format(unlock.Parades)
	end
	return ""
end

local gui = make("ScreenGui", { Name = "FestivalBoard", ResetOnSpawn = false })

-- The button on the left, under the wardrobe's.
local openButton = make("TextButton", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 80),
	Size = UDim2.fromOffset(68, 68),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.1,
	Text = "",
	AutoButtonColor = true,
	Visible = false,
}, gui)
round(openButton, UDim.new(0, 16))
outline(openButton, GOLD, 2.5)
label(openButton, {
	Position = UDim2.fromOffset(0, 4),
	Size = UDim2.new(1, 0, 0, 40),
	Font = FONT,
	TextColor3 = GOLD,
	Text = "⚑",
})
label(openButton, {
	Position = UDim2.new(0, 4, 1, -22),
	Size = UDim2.new(1, -8, 0, 16),
	Text = Strings.FestivalButton,
})
local badge = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -4, 0, 4),
	Size = UDim2.fromOffset(18, 18),
	BackgroundColor3 = Color3.fromRGB(255, 70, 90),
	Visible = false,
}, openButton)
round(badge, UDim.new(1, 0))

local panel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.92, 0.84),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.03,
	Visible = false,
}, gui)
round(panel, UDim.new(0, 18))
outline(panel, GOLD, 3)
make("UISizeConstraint", { MaxSize = Vector2.new(640, 500) }, panel)
make("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(60, 38, 92), Color3.fromRGB(22, 15, 34)),
}, panel)
label(panel, {
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(1, -90, 0, 34),
	Font = FONT,
	TextColor3 = GOLD,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = Strings.FestivalTitle,
})
local closeButton = button(panel, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = Color3.fromRGB(150, 40, 60),
	Text = "X",
})

local tabs = make("Frame", {
	Position = UDim2.fromOffset(14, 52),
	Size = UDim2.new(1, -28, 0, 32),
	BackgroundTransparency = 1,
}, panel)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabs)

local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local TAB_ORDER = { "Decor", "Colours", "Name" }
local TAB_NAMES = {
	Name = Strings.FestivalTabName,
	Colours = Strings.FestivalTabColours,
	Decor = Strings.FestivalTabDecor,
}
local currentTab = "Decor"

local function showTab(name: string)
	currentTab = name
	for tab, page in pages do
		page.Visible = tab == name
		tabButtons[tab].BackgroundColor3 = if tab == name then GOLD else CARD
		tabButtons[tab].TextColor3 = if tab == name then PANEL else TEXT
	end
end

for order, name in TAB_ORDER do
	local tab = button(tabs, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(150, 32),
		Text = TAB_NAMES[name],
	})
	tabButtons[name] = tab
	tab.Activated:Connect(function()
		showTab(name)
	end)
	pages[name] = make("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 92),
		Size = UDim2.new(1, -20, 1, -102),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = GOLD,
		Visible = false,
	}, panel)
	make("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, pages[name])
end

-- What the server says the player has and has chosen.
local function words(): { number }
	local list = {}
	for word in string.gmatch(player:GetAttribute("FestivalWords") or "", "%d+") do
		table.insert(list, tonumber(word) :: number)
	end
	return list
end

local function decorChosen(): { string }
	local list = {}
	for id in string.gmatch(player:GetAttribute("FestivalDecor") or "", "[^,]+") do
		table.insert(list, id)
	end
	return list
end

-- The name page: the festival's name, and a word from each list to step
-- through.
local namePage = pages.Name
local nameShown = label(namePage, {
	LayoutOrder = 0,
	Size = UDim2.new(1, -20, 0, 48),
	Font = FONT,
	TextColor3 = GOLD,
})
local wordLabels: { TextLabel } = {}

local function sendName(list: { number })
	Remote:FireServer({ Kind = "Name", Words = list })
end

for index, list in Theme.FestivalNames do
	local row = make("Frame", {
		LayoutOrder = index,
		Size = UDim2.new(1, -20, 0, 44),
		BackgroundColor3 = CARD,
	}, namePage)
	round(row)
	local word = label(row, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -120, 0, 30),
		Font = FONT,
	})
	wordLabels[index] = word
	for _, step in { -1, 1 } do
		local arrow = button(row, {
			AnchorPoint = Vector2.new(if step < 0 then 0 else 1, 0.5),
			Position = UDim2.new(if step < 0 then 0 else 1, if step < 0 then 6 else -6, 0.5, 0),
			Size = UDim2.fromOffset(44, 34),
			BackgroundColor3 = PANEL,
			TextColor3 = GOLD,
			Text = if step < 0 then "◀" else "▶",
		})
		arrow.Activated:Connect(function()
			local current = words()
			if #current == #Theme.FestivalNames then
				current[index] = (current[index] - 1 + step) % #list + 1
				sendName(current)
			end
		end)
	end
end
local shuffle = button(namePage, {
	LayoutOrder = #Theme.FestivalNames + 1,
	Size = UDim2.fromOffset(180, 38),
	BackgroundColor3 = GOLD,
	TextColor3 = PANEL,
	Text = Strings.FestivalShuffle,
})
shuffle.Activated:Connect(function()
	local random = Random.new()
	local list = {}
	for index, names in Theme.FestivalNames do
		list[index] = random:NextInteger(1, #names)
	end
	sendName(list)
end)

-- The colours page: a card for each palette.
type PaletteCard = { Choice: Festival.Choice, Frame: Frame, Status: TextLabel }
local paletteCards: { PaletteCard } = {}
local paletteGrid = make("Frame", {
	LayoutOrder = 1,
	Size = UDim2.new(1, -20, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
}, pages.Colours)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(180, 120),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, paletteGrid)
for order, choice in Config.Palettes do
	local themed = Theme.Palettes[choice.Id]
	local frame = make("Frame", { LayoutOrder = order, BackgroundColor3 = CARD }, paletteGrid)
	round(frame)
	local stroke = outline(frame, LOCKED, 2)
	stroke.Name = "Stroke"
	for stripe = 1, 4 do
		local swatch = make("Frame", {
			Position = UDim2.new((stripe - 1) / 4, 8 - (stripe - 1) * 4, 0, 8),
			Size = UDim2.new(0.25, -4, 0, 40),
			BackgroundColor3 = Color3.fromHex(themed.Colors[(stripe - 1) % 2 + 1]),
			BorderSizePixel = 0,
		}, frame)
		round(swatch, UDim.new(0, 6))
	end
	label(frame, {
		Position = UDim2.fromOffset(8, 52),
		Size = UDim2.new(1, -16, 0, 22),
		Font = FONT,
		Text = themed.DisplayName,
	})
	local status = label(frame, {
		Position = UDim2.fromOffset(8, 78),
		Size = UDim2.new(1, -16, 0, 34),
		TextColor3 = DIM,
	})
	local hit = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 2,
	}, frame)
	hit.Activated:Connect(function()
		Remote:FireServer({ Kind = "Palette", Id = choice.Id })
	end)
	table.insert(paletteCards, { Choice = choice, Frame = frame, Status = status })
end

-- The decorations page: each spot, with arrows to step through what's
-- unlocked, and below them what's still to unlock.
local decorRows: { TextLabel } = {}
local decorCount = label(pages.Decor, {
	LayoutOrder = 0,
	Size = UDim2.new(1, -20, 0, 24),
	TextColor3 = DIM,
})

local function unlockedDecor(): { string }
	local set = Festival.decode(player:GetAttribute("FestivalUnlocked"))
	local list = {}
	for _, choice in Config.Decor do
		if set[choice.Id] then
			table.insert(list, choice.Id)
		end
	end
	return list
end

for spot, spotName in Theme.DecorSpots do
	local row = make("Frame", {
		LayoutOrder = spot,
		Size = UDim2.new(1, -20, 0, 48),
		BackgroundColor3 = CARD,
	}, pages.Decor)
	round(row)
	label(row, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.32, -12, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = DIM,
		Text = spotName,
	})
	local piece = label(row, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.32, 50, 0.5, 0),
		Size = UDim2.new(0.68, -112, 0, 30),
		Font = FONT,
	})
	decorRows[spot] = piece
	for _, step in { -1, 1 } do
		local arrow = button(row, {
			AnchorPoint = Vector2.new(if step < 0 then 0 else 1, 0.5),
			Position = if step < 0 then UDim2.fromScale(0.32, 0.5) else UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(44, 36),
			BackgroundColor3 = PANEL,
			TextColor3 = GOLD,
			Text = if step < 0 then "◀" else "▶",
		})
		arrow.Activated:Connect(function()
			local options = unlockedDecor()
			local current = decorChosen()[spot]
			local at = table.find(options, current) or 1
			local id = options[(at - 1 + step) % #options + 1]
			if id and id ~= current then
				Remote:FireServer({ Kind = "Decor", Spot = spot, Id = id })
			end
		end)
	end
end
local lockedList = label(pages.Decor, {
	LayoutOrder = #Layout.Decor + 1,
	Size = UDim2.new(1, -20, 0, 90),
	TextColor3 = DIM,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Font = Enum.Font.Gotham,
})

local function refresh()
	nameShown.Text = player:GetAttribute("FestivalName") or ""
	local current = words()
	for index, word in wordLabels do
		local list = Theme.FestivalNames[index]
		word.Text = list[current[index] or 1] or ""
	end

	local palettes = Festival.decode(player:GetAttribute("FestivalPalettes"))
	local chosenPalette = player:GetAttribute("FestivalPalette")
	for _, card in paletteCards do
		local id = card.Choice.Id
		local stroke = card.Frame:FindFirstChild("Stroke") :: UIStroke
		if id == chosenPalette then
			card.Status.Text = Strings.FestivalChosen
			card.Status.TextColor3 = CHOSEN
			stroke.Color = CHOSEN
		elseif palettes[id] then
			card.Status.Text = Strings.FestivalPick
			card.Status.TextColor3 = GOLD
			stroke.Color = GOLD
		else
			card.Status.Text = requirement(card.Choice)
			card.Status.TextColor3 = DIM
			stroke.Color = LOCKED
		end
	end

	local chosen = decorChosen()
	for spot, piece in decorRows do
		local themed = Theme.Decor[chosen[spot] or ""]
		piece.Text = if themed then themed.DisplayName else ""
	end
	local unlocked = Festival.decode(player:GetAttribute("FestivalUnlocked"))
	local count, locked = 0, {}
	for _, choice in Config.Decor do
		if unlocked[choice.Id] then
			count += 1
		else
			table.insert(locked, `{Theme.Decor[choice.Id].DisplayName}: {requirement(choice)}`)
		end
	end
	decorCount.Text = Strings.FestivalCount:format(count, #Config.Decor)
	lockedList.Text = table.concat(locked, "\n")
	lockedList.Size = UDim2.new(1, -20, 0, math.max(1, #locked) * 20)
end

local function open()
	refresh()
	badge.Visible = false
	panel.Visible = true
	showTab(currentTab)
end

-- The board's prompt only shows on the player's own plot.
local function watchPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt.Name == "FestivalPrompt" then
		prompt.Enabled = prompt:GetAttribute("OwnerUserId") == player.UserId
	end
end

function FestivalBoard.mount()
	gui.Parent = player:WaitForChild("PlayerGui")
	openButton.Activated:Connect(function()
		if panel.Visible then
			panel.Visible = false
		else
			open()
		end
	end)
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)
	Remote.OnClientEvent:Connect(function(message)
		if type(message) == "table" and message.Kind == "Open" then
			open()
		end
	end)

	local plots = Workspace:WaitForChild("Plots")
	for _, descendant in plots:GetDescendants() do
		watchPrompt(descendant)
	end
	plots.DescendantAdded:Connect(watchPrompt)

	local function onHasPlot()
		openButton.Visible = player:GetAttribute("HasPlot") == true
	end
	onHasPlot()
	player:GetAttributeChangedSignal("HasPlot"):Connect(onHasPlot)
	for _, name in { "FestivalName", "FestivalWords", "FestivalPalette", "FestivalDecor", "FestivalPalettes" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if panel.Visible then
				refresh()
			end
		end)
	end
	local seenUnlocks = player:GetAttribute("FestivalUnlocked")
	player:GetAttributeChangedSignal("FestivalUnlocked"):Connect(function()
		local now = player:GetAttribute("FestivalUnlocked")
		-- A badge when something new arrives, not on the first publish.
		if seenUnlocks ~= nil and now ~= seenUnlocks and not panel.Visible then
			badge.Visible = true
		end
		seenUnlocks = now
		if panel.Visible then
			refresh()
		end
	end)
end

return FestivalBoard
