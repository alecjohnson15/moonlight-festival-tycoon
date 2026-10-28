-- The wardrobe: a button on the left of the screen that opens a panel of
-- every cosmetic, one tab per line, each on a card with a turning preview.
-- Earned items say what to build to unlock them; paid ones say what they cost
-- and exactly what they are. When something new unlocks, a note pops up and,
-- if that slot was empty, the server has already put it on.
--
-- The button only appears once the player has earned their first item, so
-- progress comes before any shop. Everything shown comes from the player's
-- Wardrobe and Wear attributes; the client only asks to wear or buy.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Cosmetics = require(Shared.Config.Cosmetics)
local Theme = require(Shared.Config.Theme)
local Wardrobe = require(Shared.Wardrobe)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipCosmetic = Remotes:WaitForChild("EquipCosmetic") :: RemoteEvent
local RequestPurchase = Remotes:WaitForChild("RequestPurchase") :: RemoteEvent

local GOLD = Color3.fromRGB(255, 205, 90)
local PANEL = Color3.fromRGB(26, 18, 40)
local CARD = Color3.fromRGB(40, 28, 60)
local TEXT = Color3.fromRGB(255, 244, 214)
local DIM = Color3.fromRGB(170, 160, 190)
local WEAR = Color3.fromRGB(90, 200, 120)
local LOCKED = Color3.fromRGB(80, 74, 96)
local FONT = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamBold
local LINE_COLORS = {
	Earned = Color3.fromRGB(80, 220, 200),
	Deluxe = Color3.fromRGB(180, 120, 255),
	Brainrot = Color3.fromRGB(255, 130, 190),
	Legendary = GOLD,
}
local TOAST_SECONDS = 4
local Strings = Theme.Strings

local WardrobeUi = {}

local player = Players.LocalPlayer
local catalogById = {}
for _, item in Catalog do
	catalogById[item.Id] = item
end

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

local gui = make("ScreenGui", { Name = "Wardrobe", ResetOnSpawn = false })

-- The button that opens it.
local openButton = make("TextButton", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.5, 0),
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
	Text = "✦",
})
label(openButton, {
	Position = UDim2.new(0, 4, 1, -22),
	Size = UDim2.new(1, -8, 0, 16),
	Text = Strings.WardrobeButton,
})
local badge = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -4, 0, 4),
	Size = UDim2.fromOffset(18, 18),
	BackgroundColor3 = Color3.fromRGB(255, 70, 90),
	Visible = false,
}, openButton)
round(badge, UDim.new(1, 0))
local buttonScale = make("UIScale", {}, openButton)

-- The note that pops up when something unlocks.
local toast = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 104),
	Size = UDim2.fromOffset(380, 60),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.05,
	Visible = false,
}, gui)
round(toast)
outline(toast, GOLD, 2.5)
local toastTitle = label(toast, {
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -24, 0, 26),
	Font = FONT,
	TextColor3 = GOLD,
})
local toastText = label(toast, {
	Position = UDim2.fromOffset(12, 34),
	Size = UDim2.new(1, -24, 0, 18),
})
local toastScale = make("UIScale", {}, toast)

-- The panel.
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
make("UISizeConstraint", { MaxSize = Vector2.new(780, 520) }, panel)
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
	Text = Strings.WardrobeTitle,
})
local closeButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = Color3.fromRGB(150, 40, 60),
	Font = FONT,
	TextScaled = true,
	TextColor3 = TEXT,
	Text = "X",
}, panel)
round(closeButton, UDim.new(1, 0))

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

local grid = make("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 92),
	Size = UDim2.new(1, -20, 1, -146),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = GOLD,
}, panel)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(150, 204),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, grid)
make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, grid)

label(panel, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 18, 1, -8),
	Size = UDim2.new(1, -36, 0, 40),
	TextColor3 = DIM,
	Font = Enum.Font.Gotham,
	Text = if RunService:IsStudio() then `{Strings.WardrobeNote}\n{Strings.WardrobeStudio}` else Strings.WardrobeNote,
})

type Card = {
	Cosmetic: Wardrobe.Cosmetic,
	Frame: Frame,
	Button: TextButton,
	Detail: TextLabel,
	Viewport: ViewportFrame?,
	Model: Model?,
	Centre: Vector3?,
}

local cards: { Card } = {}
local tabButtons: { [string]: TextButton } = {}
local currentLine = "Earned"
local have: { [string]: boolean } = {}
local prices: { [string]: number } = {}
local seenOnce = false

local function nameOf(id: string): string
	local entry = Theme.Upgrades[id]
	return if entry then entry.DisplayName else id
end

-- How to earn a free item, in words.
local function requirement(cosmetic: Wardrobe.Cosmetic): string
	local unlock = cosmetic.Unlock or {}
	if unlock.Owns then
		return Strings.WardrobeOwns:format(nameOf(unlock.Owns))
	elseif unlock.OwnsAll then
		local names = {}
		for _, id in unlock.OwnsAll do
			table.insert(names, nameOf(id))
		end
		return Strings.WardrobeOwnsAll:format(table.concat(names, ", "))
	elseif unlock.OwnedCount then
		return Strings.WardrobeCount:format(unlock.OwnedCount)
	elseif unlock.Building then
		local building = nameOf(unlock.Building)
		if not unlock.Path then
			if unlock.Tier == 1 then
				return Strings.WardrobePick:format(building)
			elseif unlock.Tier then
				return Strings.WardrobeTier:format(unlock.Tier, building)
			end
			return Strings.WardrobeFinish:format(building)
		end
		local paths = Theme.Paths[unlock.Building]
		local path = paths and paths[unlock.Path]
		local pathName = if path then path.DisplayName else unlock.Path
		if unlock.Tier then
			return Strings.WardrobePathTier:format(unlock.Tier, pathName, building)
		end
		return Strings.WardrobePath:format(pathName, building)
	end
	return ""
end

-- A turning 3D preview of the item, or a swatch of its colour for auras and
-- trails, which a viewport can't show.
local function preview(card: Card, parent: Frame, color: Color3)
	local slot = card.Cosmetic.Slot
	local entry = Theme.Wearables[card.Cosmetic.Id]
	if slot == "Aura" or slot == "Trail" or not entry then
		local swatch = make("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 96),
			BackgroundColor3 = color,
		}, parent)
		round(swatch, UDim.new(0, 10))
		make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(color, Color3.fromRGB(20, 14, 30)),
		}, swatch)
		label(swatch, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(60, 60),
			Font = FONT,
			Text = if slot == "Trail" then "≋" else "✺",
		})
		return
	end

	local viewport = make("ViewportFrame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 96),
		BackgroundColor3 = Color3.fromRGB(16, 11, 26),
		Ambient = Color3.fromRGB(170, 160, 190),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-0.5, -0.8, 1),
	}, parent)
	round(viewport, UDim.new(0, 10))
	local model = entry.Build()
	model.WorldPivot = CFrame.new()
	model.Parent = viewport
	local box, size = model:GetBoundingBox()
	local camera = make("Camera", { FieldOfView = 35 }, viewport)
	local reach = math.max(size.X, size.Y, size.Z)
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0.55, 0.3, -1).Unit * (reach * 1.9 + 0.5), box.Position)
	viewport.CurrentCamera = camera
	card.Viewport = viewport
	card.Model = model
	card.Centre = box.Position
end

local function onCardPressed(card: Card)
	local cosmetic = card.Cosmetic
	local wearing = player:GetAttribute(`Wear{cosmetic.Slot}`) == cosmetic.Id
	if wearing then
		EquipCosmetic:FireServer(cosmetic.Slot, nil)
	elseif have[cosmetic.Id] then
		EquipCosmetic:FireServer(cosmetic.Slot, cosmetic.Id)
	elseif cosmetic.Premium then
		local item = catalogById[cosmetic.Id]
		if item and (item.PassId or item.ProductId or 0) ~= 0 then
			RequestPurchase:FireServer(cosmetic.Id)
		end
	end
end

local function makeCard(cosmetic: Wardrobe.Cosmetic, order: number): Card
	local names = Theme.Cosmetics[cosmetic.Id]
	local color = Color3.fromHex(names.Color)
	local lineColor = LINE_COLORS[cosmetic.Line] or GOLD

	local frame = make("Frame", {
		BackgroundColor3 = CARD,
		LayoutOrder = order,
		Visible = false,
	}, grid)
	round(frame)
	outline(frame, lineColor, 2)

	local card: Card = {
		Cosmetic = cosmetic,
		Frame = frame,
		Button = nil :: any,
		Detail = nil :: any,
	}
	preview(card, frame, color)

	if cosmetic.Line == "Legendary" then
		local tag = label(frame, {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(78, 16),
			BackgroundTransparency = 0,
			BackgroundColor3 = GOLD,
			TextColor3 = PANEL,
			Text = Strings.WardrobeArenaEdge,
		})
		round(tag, UDim.new(0, 6))
	end
	label(frame, {
		Position = UDim2.new(1, -60, 0, 86),
		Size = UDim2.fromOffset(50, 14),
		TextColor3 = DIM,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = Theme.CosmeticSlots[cosmetic.Slot] or cosmetic.Slot,
	})
	label(frame, {
		Position = UDim2.fromOffset(8, 108),
		Size = UDim2.new(1, -16, 0, 22),
		Font = FONT,
		Text = names.DisplayName,
	})
	card.Detail = label(frame, {
		Position = UDim2.fromOffset(8, 132),
		Size = UDim2.new(1, -16, 0, 30),
		Font = Enum.Font.Gotham,
		TextColor3 = DIM,
		Text = names.Blurb,
	})
	card.Button = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 28),
		BackgroundColor3 = WEAR,
		Font = FONT,
		TextScaled = true,
		TextColor3 = TEXT,
		Text = "",
	}, frame)
	round(card.Button, UDim.new(0, 8))
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, card.Button)
	card.Button.Activated:Connect(function()
		onCardPressed(card)
	end)
	return card
end

local function priceText(cosmetic: Wardrobe.Cosmetic): (string, boolean)
	local item = catalogById[cosmetic.Id]
	local id = item and (item.PassId or item.ProductId) or 0
	if id == 0 then
		return Strings.WardrobeSoon, false
	end
	local price = prices[cosmetic.Id]
	return if price then Strings.WardrobePrice:format(tostring(price)) else Strings.WardrobeBuy, true
end

local function refreshCard(card: Card)
	local cosmetic = card.Cosmetic
	local owned = have[cosmetic.Id] == true
	local wearing = player:GetAttribute(`Wear{cosmetic.Slot}`) == cosmetic.Id
	local button = card.Button
	local names = Theme.Cosmetics[cosmetic.Id]

	if wearing then
		button.Text = `{Strings.WardrobeWearing} ✓`
		button.BackgroundColor3 = GOLD
		button.TextColor3 = PANEL
		button.AutoButtonColor = true
	elseif owned then
		button.Text = Strings.WardrobeWear
		button.BackgroundColor3 = WEAR
		button.TextColor3 = TEXT
		button.AutoButtonColor = true
	elseif cosmetic.Premium then
		local text, buyable = priceText(cosmetic)
		button.Text = text
		button.BackgroundColor3 = if buyable then Color3.fromRGB(60, 160, 90) else LOCKED
		button.TextColor3 = TEXT
		button.AutoButtonColor = buyable
	else
		button.Text = Strings.WardrobeLocked
		button.BackgroundColor3 = LOCKED
		button.TextColor3 = DIM
		button.AutoButtonColor = false
	end

	card.Detail.Text = if not owned and not cosmetic.Premium then requirement(cosmetic) else names.Blurb
	if card.Viewport then
		card.Viewport.ImageColor3 = if owned or cosmetic.Premium
			then Color3.new(1, 1, 1)
			else Color3.fromRGB(90, 85, 105)
	end
end

local function refreshAll()
	for _, card in cards do
		refreshCard(card)
	end
end

local function showLine(line: string)
	currentLine = line
	for name, button in tabButtons do
		local selected = name == line
		button.BackgroundColor3 = if selected then LINE_COLORS[name] or GOLD else CARD
		button.TextColor3 = if selected then PANEL else TEXT
	end
	for _, card in cards do
		card.Frame.Visible = card.Cosmetic.Line == line
	end
	grid.CanvasPosition = Vector2.zero
end

local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		badge.Visible = false
		showLine(currentLine)
		refreshAll()
	end
end

local toastQueue: { string } = {}
local toastBusy = false

local function nextToast()
	local id = table.remove(toastQueue, 1)
	if not id then
		toastBusy = false
		return
	end
	toastBusy = true
	local cosmetic = Wardrobe.find(Cosmetics, id)
	toastTitle.Text = Strings.WardrobeUnlocked:format(Theme.Cosmetics[id].DisplayName)
	local wearing = cosmetic and player:GetAttribute(`Wear{cosmetic.Slot}`) == id
	toastText.Text = if wearing then Strings.WardrobeNowWearing else Strings.WardrobeOpenToWear
	toast.Visible = true
	toastScale.Scale = 0.6
	TweenService:Create(toastScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	task.delay(TOAST_SECONDS, function()
		toast.Visible = false
		nextToast()
	end)
end

local function onWardrobeChanged()
	local now = Wardrobe.decode(player:GetAttribute("Wardrobe"))
	local fresh = Wardrobe.newlyOwned(Cosmetics, have, now)
	have = now
	openButton.Visible = next(have) ~= nil
	if seenOnce and #fresh > 0 then
		badge.Visible = not panel.Visible
		for _, id in fresh do
			table.insert(toastQueue, id)
		end
		-- Wait a moment for the server's auto-equip, so the note can say so.
		if not toastBusy then
			toastBusy = true
			task.delay(0.3, nextToast)
		end
		TweenService
			:Create(buttonScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 2, true), {
				Scale = 1.2,
			})
			:Play()
	end
	seenOnce = player:GetAttribute("Wardrobe") ~= nil
	refreshAll()
end

local function loadPrices()
	for _, cosmetic in Cosmetics do
		local item = catalogById[cosmetic.Id]
		if item and item.Kind == "GamePass" and item.PassId ~= 0 then
			task.spawn(function()
				local ok, info =
					pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.PassId, Enum.InfoType.GamePass)
				if ok and info and info.PriceInRobux then
					prices[cosmetic.Id] = info.PriceInRobux
					refreshAll()
				end
			end)
		end
	end
end

local function onRenderStep()
	if not panel.Visible then
		return
	end
	local now = os.clock()
	for index, card in cards do
		local model, centre = card.Model, card.Centre
		if model and centre and card.Frame.Visible then
			local angle = math.sin(now * 0.9 + index) * 0.6
			model:PivotTo(CFrame.new(centre) * CFrame.Angles(0, angle, 0) * CFrame.new(-centre))
		end
	end
end

function WardrobeUi.mount()
	for index, line in Wardrobe.LINES do
		local button = make("TextButton", {
			Size = UDim2.new(1 / #Wardrobe.LINES, -6, 1, 0),
			LayoutOrder = index,
			BackgroundColor3 = CARD,
			Font = FONT,
			TextScaled = true,
			TextColor3 = TEXT,
			Text = Theme.CosmeticLines[line] or line,
		}, tabs)
		round(button, UDim.new(0, 10))
		make("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, button)
		button.Activated:Connect(function()
			showLine(line)
		end)
		tabButtons[line] = button
	end
	for index, cosmetic in Cosmetics do
		table.insert(cards, makeCard(cosmetic, index))
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	openButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	player:GetAttributeChangedSignal("Wardrobe"):Connect(onWardrobeChanged)
	for _, slot in Wardrobe.SLOTS do
		player:GetAttributeChangedSignal(`Wear{slot}`):Connect(refreshAll)
	end
	onWardrobeChanged()
	showLine(currentLine)
	loadPrices()
	RunService.RenderStepped:Connect(onRenderStep)
end

return WardrobeUi
