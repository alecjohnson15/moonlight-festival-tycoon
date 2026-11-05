-- The wardrobe: where every look is made. It docks on the left so the
-- character stays in view on a turntable (drag to spin, scroll or the zoom
-- button to get closer). Five tabs:
--
--   Studio    the game's own pieces by slot, with a theme-fit mark, and the
--             paint panel: main and accent colours and a finish
--   Catalog   search Roblox's catalog of UGC accessories and layered
--             clothing, try anything on free, favourite it, or buy it
--   Body      skin, body type, and the painted top, bottoms, shoes, gloves
--   Poses     the pose struck at the end of the runway
--   Walk-ins  the entrance effect that plays on the runway
--
-- Changes are sent to the server (SetLook) a moment after the last tap; the
-- server checks them and dresses the character. During dressing, the Ready
-- button tells the show you're done. Above the tabs' content, Undo and Redo
-- step through this session's changes, and Theme look dresses you in a
-- starting outfit for the theme from what you own (shared/Stylist).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AvatarEditorService = game:GetService("AvatarEditorService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Wardrobe = require(Config.Wardrobe)
local Palette = require(Config.Palette)
local Poses = require(Config.Poses)
local Entrances = require(Config.Entrances)
local Catalog = require(Config.Catalog)
local GameConfig = require(Config.Game)
local Look = require(Shared.Look)
local Stylist = require(Shared.Stylist)
local Pieces = require(Shared.Build.Pieces)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local Camera = require(script.Parent.Camera)
local Effects = require(script.Parent.Effects)
local Corner = require(script.Parent.Corner)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = Ui.Colors
local make = Ui.make

local WardrobeUi = {}

local SEND_DELAY = 0.25
local SYNC_AFTER = 0.8
local HISTORY = 40

local player = Players.LocalPlayer
local window: Ui.Window
local content: Frame
local bottomBar: Frame
local readyButton: TextButton
local working: Look.Look = Look.default()
-- Undo history: committed is the look as of the last finished change.
local committed: Look.Look = Look.default()
local undoStack: { Look.Look } = {}
local redoStack: { Look.Look } = {}
local undoButton: TextButton
local redoButton: TextButton
local actionCallbacks: { (string) -> () } = {}
local lastEdit = 0
local sendQueued = false
local tab = "Studio"
local slot = "Hair"
local paintTarget = "Hair"
local paintChannel = "C"
local catalogCategory = "Hats"
local catalogKeyword = ""
local catalogPage = 1
local catalogResults: { any } = {}
local catalogMore = false
local isContestant = false
local isReady = false
local spin = math.rad(180)
local zoomed = false
local tabPicker: (string) -> ()
-- The colour slider being dragged, if any.
local slider: { Track: GuiObject, Set: (number) -> () }? = nil

local FINISHES = { "Matte", "Satin", "Shiny", "Sequin", "Glow", "Metal", "Glass", "Frost" }
local CATALOG_CATEGORIES = {
	"Hats",
	"Hair",
	"Face",
	"Neck",
	"Back",
	"Front",
	"Tops",
	"Jackets",
	"Bottoms",
	"Dresses",
	"Shoes",
	"Favorites",
	"Wearing",
}

local PASS_NAMES: { [string]: string } = {}
for _, item in Catalog do
	PASS_NAMES[item.Id] = item.Name
end

------------------------------------------------------------------------------
-- Sending the look

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

local function send()
	if sendQueued then
		return
	end
	sendQueued = true
	task.delay(SEND_DELAY, function()
		sendQueued = false
		Remotes.SetLook:FireServer(working)
	end)
end

local render: () -> ()

-- Tells listeners (the first-outfit guide in Tips) what the player just did:
-- "Equip", "Paint", "ThemeLook", "Undo" or "Ready".
local function action(name: string)
	for _, callback in actionCallbacks do
		task.spawn(callback, name)
	end
end

-- Takes a look from the server as the new starting point for undo.
local function rebase(look: Look.Look)
	working = deepCopy(look)
	committed = deepCopy(look)
end

local function updateHistoryButtons()
	if undoButton then
		undoButton.TextTransparency = if #undoStack > 0 then 0 else 0.6
		redoButton.TextTransparency = if #redoStack > 0 then 0 else 0.6
	end
end

local function edited()
	if not Look.same(committed, working) then
		table.insert(undoStack, committed)
		if #undoStack > HISTORY then
			table.remove(undoStack, 1)
		end
		redoStack = {}
		committed = deepCopy(working)
	end
	updateHistoryButtons()
	lastEdit = os.clock()
	send()
	render()
end

-- Steps back (or forward) through this session's changes.
local function travel(from: { Look.Look }, to: { Look.Look })
	local look = table.remove(from)
	if not look then
		Sounds.play("Deny")
		return
	end
	table.insert(to, deepCopy(working))
	working = deepCopy(look)
	committed = deepCopy(look)
	updateHistoryButtons()
	lastEdit = os.clock()
	Sounds.play("Click")
	send()
	render()
end

-- A starting outfit for this round's theme from the pieces you own.
local function themeLook()
	local theme = State.theme()
	if not theme or State.phase() == "Lobby" or State.phase() == "ThemeVote" or State.phase() == "Waiting" then
		Sounds.play("Deny")
		Corner.toast("Theme look", "Wait for the theme to be revealed, then try again.", C.Violet, 3)
		return
	end
	working = Stylist.suggest(
		theme,
		function(piece)
			return State.owns("Piece", piece.Id)
		end,
		working,
		function()
			return math.random()
		end
	)
	Sounds.play("Sparkle")
	edited()
	action("ThemeLook")
end

local function themeTags(): { [string]: boolean }
	local set = {}
	local theme = State.theme()
	if theme then
		for _, tag in theme.Tags do
			set[tag] = true
		end
	end
	return set
end

local function fitsTheme(piece: Wardrobe.Piece, tags: { [string]: boolean }): boolean
	for _, tag in piece.Tags do
		if tags[tag] then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Pictures of pieces

local previews: { [string]: Model } = {}

local function preview(parent: GuiObject, piece: Wardrobe.Piece, choice: Look.PieceChoice?)
	local viewport = make("ViewportFrame", {
		Size = UDim2.new(1, -8, 1, -30),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 190, 220),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
	}, parent)
	local main = if choice then Palette.resolve(choice.C) else Palette.resolve(piece.Main)
	local accent = if choice then Palette.resolve(choice.A) else Palette.resolve(piece.Accent)
	local finish = if choice and choice.F then choice.F else piece.Finish
	local key = `{piece.Id}|{main}|{accent}|{finish}`
	local model = previews[key]
	if not model then
		local ok, built = pcall(Pieces.preview, piece, main, accent, finish)
		if not ok then
			return
		end
		model = built
		previews[key] = model
	end
	local copy = model:Clone()
	copy.Parent = viewport
	local cframe, size = copy:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z) * 0.75 + 0.2
	local camera = make("Camera", {
		FieldOfView = 40,
		CFrame = CFrame.lookAt(
			cframe.Position + Vector3.new(radius * 0.9, radius * 0.7, -radius * 2.2),
			cframe.Position
		),
	}, viewport)
	viewport.CurrentCamera = camera
end

------------------------------------------------------------------------------
-- Building blocks

local function section(title: string, order: number): Frame
	local frame = make("Frame", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, content)
	Ui.list(frame, false, 4)
	Ui.label(frame, {
		Text = title,
		Font = Ui.Fonts.Title,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Pink,
		LayoutOrder = 0,
	})
	return frame
end

local function flow(parent: Instance, order: number, height: number?): Frame
	local row = make("Frame", {
		Size = UDim2.new(1, 0, 0, height or 0),
		AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	local layout = Ui.list(row, true, 6)
	layout.Wraps = true
	return row
end

local function chips(parent: Instance, order: number, names: { string }, chosen: string?, onPick: (string) -> ())
	local row = flow(parent, order)
	for index, name in names do
		local chip = Ui.chip(row, name, function()
			onPick(name)
		end)
		chip.LayoutOrder = index
		Ui.setChosen(chip, name == chosen)
	end
	return row
end

local function swatch(parent: Instance, color: Color3, chosen: boolean, onPick: () -> (), order: number?): TextButton
	local button = make("TextButton", {
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order or 0,
	}, parent)
	Ui.corner(button, 13)
	Ui.stroke(button, if chosen then C.Text else Color3.new(0, 0, 0), if chosen then 3 else 1)
	button.Activated:Connect(function()
		Sounds.play("Equip", 1.2)
		onPick()
	end)
	return button
end

local function badge(parent: Instance, text: string, color: Color3)
	local label = Ui.label(parent, {
		Text = text,
		TextSize = 11,
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -3, 0, 3),
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = C.Dark,
		ZIndex = 3,
	})
	Ui.corner(label, 8)
	make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, label)
end

-- What to do about something the player doesn't own yet.
local function lockedAction(kind: string, item: any)
	if item.Pass then
		Remotes.RequestPurchase:FireServer(item.Pass)
	elseif item.Season then
		Sounds.play("Deny")
		local Menus = require(script.Parent.Menus) :: any
		Menus.open("Pass")
	elseif item.Price > 0 then
		if State.sparkles() < item.Price then
			Sounds.play("Deny")
			Corner.toast(
				"Not enough Sparkles",
				`{item.Name} costs {Ui.sparkles(item.Price)}. Walk, vote and do challenges to earn more!`,
				C.Red
			)
			return
		end
		Remotes.ShopBuy:FireServer({ Kind = kind, Id = item.Id })
	end
end

local function lockText(item: any): (string, Color3)
	if item.Pass then
		return "Pass", C.Violet
	elseif item.Season then
		return `Tier {item.Season}`, C.Gold
	end
	return `✦{item.Price}`, C.Gold
end

------------------------------------------------------------------------------
-- The paint panel

local function paintFor(target: string): any
	if target == "Top" or target == "Bottom" or target == "Shoes" or target == "Gloves" then
		return (working :: any)[target]
	end
	return working.Pieces[target]
end

local function colorPicker(parent: Instance, order: number, current: any, allowNone: boolean, onPick: (any) -> ())
	local grid = flow(parent, order)
	local gridLayout = grid:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	gridLayout.Padding = UDim.new(0, 4)
	if allowNone then
		local none = swatch(grid, C.Panel3, current == 0, function()
			onPick(0)
		end, 0)
		Ui.label(none, { Text = "✕", Size = UDim2.fromScale(1, 1), TextSize = 12 })
	end
	for index, color in Palette.Colors do
		swatch(grid, color.Color, current == index, function()
			onPick(index)
		end, index)
	end
	-- Any colour at all, for Color Studio owners.
	local custom = make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order + 1,
	}, parent)
	Ui.list(custom, false, 4)
	if not State.hasPass("color_studio") then
		Ui.button(custom, "🎨 Any colour with Color Studio", C.Violet, function()
			Remotes.RequestPurchase:FireServer("color_studio")
		end, { Size = UDim2.new(1, 0, 0, 28), TextSize = 13 })
		return
	end
	local hue, light = 0, 0.5
	if Palette.isHex(current) then
		local h, s, v = Palette.fromHex(current):ToHSV()
		hue = h
		light = if s < 1 then 1 - s / 2 else v / 2
	end
	local function colorOf(h: number, l: number): Color3
		if l <= 0.5 then
			return Color3.fromHSV(h, 1, math.max(l * 2, 0.04))
		end
		return Color3.fromHSV(h, math.max(2 - l * 2, 0), 1)
	end
	local function bar(name: string, gradient: ColorSequence, onSet: (number) -> ())
		local track = make("TextButton", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundColor3 = Color3.new(1, 1, 1),
			AutoButtonColor = false,
			Text = "",
		}, custom)
		Ui.corner(track, 10)
		make("UIGradient", { Color = gradient }, track)
		local function set(x: number)
			local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			onSet(alpha)
		end
		track.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				slider = { Track = track, Set = set }
				set(input.Position.X)
			end
		end)
		return track
	end
	local keys = {}
	for step = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(step / 6, Color3.fromHSV(step / 6 % 1, 1, 1)))
	end
	bar("Hue", ColorSequence.new(keys), function(alpha)
		hue = alpha * 0.999
		onPick(Palette.toHex(colorOf(hue, light)))
	end)
	bar(
		"Light",
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromHSV(hue, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		}),
		function(alpha)
			light = alpha
			onPick(Palette.toHex(colorOf(hue, light)))
		end
	)
end

local function paintPanel(order: number, targets: { string })
	if not table.find(targets, paintTarget) then
		paintTarget = targets[1]
	end
	local paint = paintFor(paintTarget)
	local panel = section("Paint", order)
	if #targets > 1 then
		chips(panel, 1, targets, paintTarget, function(name)
			paintTarget = name
			render()
		end)
	end
	if not paint then
		Ui.label(panel, {
			Text = "Put something on to paint it.",
			TextColor3 = C.Muted,
			TextSize = 13,
			LayoutOrder = 2,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		return
	end
	local isPiece = working.Pieces[paintTarget] ~= nil
	if isPiece then
		chips(panel, 2, { "Main", "Accent" }, if paintChannel == "A" then "Accent" else "Main", function(name)
			paintChannel = if name == "Accent" then "A" else "C"
			render()
		end)
	else
		paintChannel = "C"
	end
	if paintTarget ~= "Gloves" then
		chips(panel, 3, FINISHES, paint.F, function(name)
			paint.F = name
			edited()
			action("Paint")
		end)
	end
	local allowNone = paintTarget == "Shoes" or paintTarget == "Gloves"
	colorPicker(panel, 4, paint[paintChannel], allowNone, function(value)
		paint[paintChannel] = value
		if type(value) == "string" then
			lastEdit = os.clock()
			send()
		else
			edited()
		end
		action("Paint")
	end)
end

------------------------------------------------------------------------------
-- Tabs

local function itemGrid(parent: Instance, order: number, cell: Vector2): Frame
	local grid = make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, parent)
	Ui.grid(grid, cell, 6)
	return grid
end

local function renderStudio()
	local slots = section("Pieces", 1)
	local names = {}
	local bySlotName = {}
	for _, slotId in Wardrobe.Slots do
		local name = Wardrobe.SlotNames[slotId]
		table.insert(names, name)
		bySlotName[name] = slotId
	end
	chips(slots, 1, names, Wardrobe.SlotNames[slot], function(name)
		slot = bySlotName[name]
		paintTarget = slot
		render()
	end)

	local tags = themeTags()
	local grid = itemGrid(slots, 2, Vector2.new(94, 116))
	local list = Wardrobe.inSlot(slot)
	table.sort(list, function(a, b)
		local ownA, ownB = State.owns("Piece", a.Id), State.owns("Piece", b.Id)
		if ownA ~= ownB then
			return ownA
		end
		local fitA, fitB = fitsTheme(a, tags), fitsTheme(b, tags)
		if fitA ~= fitB then
			return fitA
		end
		return a.Name < b.Name
	end)
	local wearing = working.Pieces[slot]
	for index, piece in list do
		local owned = State.owns("Piece", piece.Id)
		local worn = wearing ~= nil and wearing.Id == piece.Id
		local cell = Ui.button(grid, "", if worn then C.Pink else C.Panel2, function()
			if not owned then
				lockedAction("Piece", piece)
				return
			end
			if worn then
				working.Pieces[slot] = nil
				Sounds.play("Click")
			else
				working.Pieces[slot] = {
					Id = piece.Id,
					C = Palette.indexOf(piece.Main) or 1,
					A = Palette.indexOf(piece.Accent) or 1,
					F = piece.Finish,
				}
				Sounds.play("Equip")
				action("Equip")
			end
			paintTarget = slot
			edited()
		end, { LayoutOrder = index })
		preview(cell, piece, if worn then wearing else nil)
		Ui.label(cell, {
			Text = piece.Name,
			TextSize = 11,
			Position = UDim2.new(0, 4, 1, -28),
			Size = UDim2.new(1, -8, 0, 26),
			TextColor3 = if owned then C.Text else C.Muted,
		})
		if not owned then
			local text, color = lockText(piece)
			badge(cell, text, color)
		elseif fitsTheme(piece, tags) then
			badge(cell, "✓ theme", C.Aqua)
		end
	end
	paintPanel(3, { slot })
end

local function renderBody()
	local skin = section("Skin", 1)
	local row = flow(skin, 1)
	for index, tone in Palette.Skins do
		swatch(row, tone.Color, working.Skin == index, function()
			working.Skin = index
			edited()
		end, index)
	end
	local body = section("Body", 2)
	chips(body, 1, { "Classic", "Mine" }, working.Body, function(name)
		working.Body = name
		edited()
	end)
	Ui.label(body, {
		Text = "Classic is the same body for everyone. Mine uses your own avatar's body.",
		TextSize = 12,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 2,
	})
	local top = section("Top", 3)
	chips(top, 1, Look.TopStyles, working.Top.S, function(name)
		working.Top.S = name
		paintTarget = "Top"
		edited()
	end)
	local bottom = section("Bottoms", 4)
	chips(bottom, 1, Look.BottomStyles, working.Bottom.S, function(name)
		working.Bottom.S = name
		paintTarget = "Bottom"
		edited()
	end)
	paintPanel(5, { "Top", "Bottom", "Shoes", "Gloves" })
end

local function catalogCell(grid: Frame, entry: any, order: number)
	local wearing = table.find(working.Catalog, entry.Id) ~= nil
	local cell = Ui.button(grid, "", if wearing then C.Pink else C.Panel2, function()
		local index = table.find(working.Catalog, entry.Id)
		if index then
			table.remove(working.Catalog, index)
			Sounds.play("Click")
		elseif #working.Catalog >= GameConfig.Looks.MaxCatalogItems then
			Sounds.play("Deny")
			return
		else
			table.insert(working.Catalog, entry.Id)
			Sounds.play("Equip")
		end
		edited()
	end, { LayoutOrder = order })
	make("ImageLabel", {
		Size = UDim2.new(1, -10, 1, -36),
		Position = UDim2.fromOffset(5, 5),
		BackgroundTransparency = 1,
		Image = `rbxthumb://type=Asset&id={entry.Id}&w=150&h=150`,
		ScaleType = Enum.ScaleType.Fit,
	}, cell)
	Ui.label(cell, {
		Text = entry.Name or "",
		TextSize = 10,
		Position = UDim2.new(0, 4, 1, -30),
		Size = UDim2.new(1, -8, 0, 26),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local favorites = if State.Profile then State.Profile.Favorites else {}
	local favorite = table.find(favorites or {}, entry.Id) ~= nil
	local star = Ui.button(cell, if favorite then "★" else "☆", C.Dark, function()
		Remotes.Favorite:FireServer({ Id = entry.Id, On = not favorite })
	end, {
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(3, 3),
		TextSize = 14,
		TextColor3 = C.Gold,
		ZIndex = 3,
	})
	star.BackgroundTransparency = 0.3
	if wearing then
		local buy = Ui.button(cell, "Buy", C.Green, function()
			Remotes.CatalogBuy:FireServer(entry.Id)
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -3, 0, 3),
			Size = UDim2.fromOffset(38, 22),
			TextSize = 12,
			ZIndex = 3,
		})
		buy.BackgroundTransparency = 0.05
	end
end

local searching = false

local function search(page: number)
	if searching then
		return
	end
	searching = true
	catalogPage = page
	local request = { Category = catalogCategory, Keyword = catalogKeyword, Page = page, Sort = "Popular" }
	local ok, result = pcall(function()
		return Remotes.CatalogSearch:InvokeServer(request)
	end)
	if not ok or type(result) ~= "table" or result.Failed then
		-- The server couldn't search; try from here.
		local fallbackOk, pages = pcall(function()
			local params = CatalogSearchParams.new()
			params.SearchKeyword = catalogKeyword
			params.Limit = 30
			params.AssetTypes = { Enum.AvatarAssetType.Hat }
			return AvatarEditorService:SearchCatalogAsync(params)
		end)
		if fallbackOk and pages then
			local items = {}
			for _, entry in pages:GetCurrentPage() do
				if entry.ItemType == "Asset" then
					table.insert(items, { Id = entry.Id, Name = entry.Name })
				end
			end
			result = { Items = items, More = false }
		else
			result = { Items = {}, More = false }
		end
	end
	searching = false
	if result.Busy then
		return
	end
	if page == 1 then
		catalogResults = {}
	end
	for _, entry in result.Items or {} do
		table.insert(catalogResults, entry)
	end
	catalogMore = result.More == true
	render()
end

local function renderCatalog()
	local top = section("Roblox catalog: try anything on free", 1)
	local searchRow = make("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, top)
	local box = make("TextBox", {
		Size = UDim2.new(1, -86, 1, 0),
		BackgroundColor3 = C.Dark,
		Text = catalogKeyword,
		PlaceholderText = "Search hats, dresses, wings...",
		PlaceholderColor3 = C.Muted,
		TextColor3 = C.Text,
		Font = Ui.Fonts.Body,
		TextSize = 14,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, searchRow)
	Ui.corner(box, 8)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
	local function go()
		catalogKeyword = string.sub(box.Text, 1, 40)
		task.spawn(search, 1)
	end
	box.FocusLost:Connect(function(enter)
		if enter then
			go()
		end
	end)
	Ui.button(searchRow, "Search", C.Pink, go, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(80, 32),
		TextSize = 14,
	})
	chips(top, 2, CATALOG_CATEGORIES, catalogCategory, function(name)
		catalogCategory = name
		catalogResults = {}
		if name ~= "Favorites" and name ~= "Wearing" then
			task.spawn(search, 1)
		end
		render()
	end)
	Ui.label(top, {
		Text = `Wearing {#working.Catalog}/{GameConfig.Looks.MaxCatalogItems} catalog items. Buying one pays its creator.`,
		TextSize = 12,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
	})

	local grid = itemGrid(top, 4, Vector2.new(94, 120))
	local entries = catalogResults
	if catalogCategory == "Favorites" or catalogCategory == "Wearing" then
		entries = {}
		local ids = if catalogCategory == "Wearing"
			then working.Catalog
			else (if State.Profile then State.Profile.Favorites else {})
		for _, id in ids or {} do
			table.insert(entries, { Id = id, Name = "" })
		end
	end
	for index, entry in entries do
		catalogCell(grid, entry, index)
	end
	if #entries == 0 then
		Ui.label(top, {
			Text = if searching then "Searching..." else "Nothing here yet. Try a search!",
			TextColor3 = C.Muted,
			LayoutOrder = 5,
		})
	end
	if catalogMore and catalogCategory ~= "Favorites" and catalogCategory ~= "Wearing" then
		Ui.button(top, "More", C.Violet, function()
			task.spawn(search, catalogPage + 1)
		end, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 6, TextSize = 14 })
	end
end

local function renderChoices(kind: string, list: { any }, chosenId: string, onPick: (any) -> ())
	local frame = section(if kind == "Pose" then "Runway poses" else "Runway walk-ins", 1)
	local grid = itemGrid(frame, 1, Vector2.new(126, 64))
	for index, item in list do
		local owned = State.owns(kind, item.Id)
		local chosen = item.Id == chosenId
		local cell = Ui.button(grid, "", if chosen then C.Pink else C.Panel2, function()
			if not owned then
				lockedAction(kind, item)
				return
			end
			onPick(item)
		end, { LayoutOrder = index })
		Ui.label(cell, {
			Text = item.Name,
			TextSize = 13,
			Position = UDim2.fromOffset(6, 10),
			Size = UDim2.new(1, -12, 0, 32),
			TextColor3 = if owned then C.Text else C.Muted,
		})
		if not owned then
			local text, color = lockText(item)
			badge(cell, text, color)
		end
	end
end

local function renderPoses()
	renderChoices("Pose", Poses.List, working.Pose, function(pose)
		working.Pose = pose.Id
		edited()
		local character = player.Character
		if character then
			Effects.previewPose(character, pose.Id)
		end
	end)
end

local function renderEntrances()
	renderChoices("Entrance", Entrances.List, working.Entrance, function(entrance)
		working.Entrance = entrance.Id
		edited()
		local character = player.Character
		if character then
			Effects.entrance(character, entrance.Id, 3)
		end
	end)
end

render = function()
	if not window or not window.isOpen() then
		return
	end
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if tab == "Studio" then
		renderStudio()
	elseif tab == "Catalog" then
		renderCatalog()
	elseif tab == "Body" then
		renderBody()
	elseif tab == "Poses" then
		renderPoses()
	else
		renderEntrances()
	end
	readyButton.Visible = isContestant and State.phase() == "Dressing"
	readyButton.Text = if isReady then "READY ✓" else "I'M READY!"
	readyButton.BackgroundColor3 = if isReady then C.Green else C.Pink
end

------------------------------------------------------------------------------
-- The turntable camera

local function turntable(dt: number): CFrame
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return (workspace.CurrentCamera :: Camera).CFrame
	end
	if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		spin += dt * 0.08
	end
	local focus = root.Position + Vector3.new(0, if zoomed then 1.6 else 0.4, 0)
	local distance = if zoomed then 5 else 10.5
	local offset = Vector3.new(math.sin(spin), 0, math.cos(spin)) * distance
	local eye = focus + offset + Vector3.new(0, if zoomed then 0.4 else 1.6, 0)
	-- Look a little to the side so the character sits right of the panel.
	local look = CFrame.lookAt(eye, focus)
	return look * CFrame.new(-(if zoomed then 1.2 else 2.6), 0, 0)
end

function WardrobeUi.open(startTab: string?)
	if startTab then
		tab = startTab
	end
	window.open()
	if tabPicker then
		tabPicker(tab)
	end
end

-- Calls back with what the player does in the wardrobe (see action()).
function WardrobeUi.onAction(callback: (string) -> ())
	table.insert(actionCallbacks, callback)
end

function WardrobeUi.isOpen(): boolean
	return window ~= nil and window.isOpen()
end

function WardrobeUi.close()
	window.close()
end

function WardrobeUi.mount()
	window = Ui.window("Wardrobe", "Wardrobe", Vector2.new(440, 620), C.Pink, "Left")
	local body = window.Body
	tabPicker = Ui.tabs(body, { "Studio", "Catalog", "Body", "Poses", "Walk-ins" }, function(name)
		tab = name
		if
			name == "Catalog"
			and #catalogResults == 0
			and catalogCategory ~= "Favorites"
			and catalogCategory ~= "Wearing"
		then
			task.spawn(search, 1)
		end
		render()
	end)
	local tools = make("Frame", {
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
	}, body)
	Ui.list(tools, true, 6)
	undoButton = Ui.button(tools, "↶ Undo", C.Panel3, function()
		travel(undoStack, redoStack)
		action("Undo")
	end, { Size = UDim2.fromOffset(86, 30), TextSize = 14, LayoutOrder = 1 })
	redoButton = Ui.button(tools, "↷ Redo", C.Panel3, function()
		travel(redoStack, undoStack)
	end, { Size = UDim2.fromOffset(86, 30), TextSize = 14, LayoutOrder = 2 })
	Ui.button(tools, "✨ Theme look", C.Violet, themeLook, {
		Size = UDim2.fromOffset(140, 30),
		TextSize = 14,
		LayoutOrder = 3,
	})
	updateHistoryButtons()
	local scroller = Ui.scroller(body, {
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 1, -128),
	})
	content = make("Frame", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, scroller)
	Ui.list(content, false, 10)

	bottomBar = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
	}, body)
	Ui.list(bottomBar, true, 6)
	Ui.button(bottomBar, "Save outfit", C.Violet, function()
		Remotes.Looks:FireServer({ Action = "Save" })
	end, { Size = UDim2.fromOffset(112, 40), TextSize = 15, LayoutOrder = 1 })
	Ui.button(bottomBar, "Zoom", C.Panel3, function()
		zoomed = not zoomed
	end, { Size = UDim2.fromOffset(64, 40), TextSize = 15, LayoutOrder = 2 })
	Ui.button(bottomBar, "Reset", C.Panel3, function()
		local fresh = Look.default()
		fresh.Skin = working.Skin
		fresh.Body = working.Body
		working = fresh
		edited()
	end, { Size = UDim2.fromOffset(64, 40), TextSize = 15, LayoutOrder = 3 })
	readyButton = Ui.button(bottomBar, "I'M READY!", C.Pink, function()
		isReady = not isReady
		Remotes.Ready:FireServer(isReady)
		Sounds.play("Ready")
		if isReady then
			action("Ready")
		end
		render()
	end, { Size = UDim2.fromOffset(120, 40), TextSize = 16, LayoutOrder = 4, Visible = false })

	window.onOpen(function()
		if State.Profile and State.Profile.Current then
			rebase(State.Profile.Current)
		end
		Camera.set("Wardrobe", Camera.Priority.Wardrobe, turntable, 0.2, 50)
		render()
	end)
	window.onClose(function()
		Camera.clear("Wardrobe")
	end)

	-- Drag on the world (not the panel) to spin the turntable.
	local dragging: InputObject? = nil
	UserInputService.InputEnded:Connect(function(input)
		local isPress = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		if slider and isPress then
			slider = nil
			edited()
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		local isMove = input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		if slider and isMove then
			slider.Set(input.Position.X)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not window.isOpen() then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = input
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not window.isOpen() then
			return
		end
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == dragging) then
			spin -= input.Delta.X * 0.01
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			zoomed = input.Position.Z > 0
		end
	end)

	State.onProfile(function(profile)
		-- Take the server's version unless the player is mid-edit.
		if os.clock() - lastEdit > SYNC_AFTER and profile.Current then
			rebase(profile.Current)
		end
		render()
	end)
	State.onRound(function(name)
		if name == "Phase" then
			local phase = State.phase()
			if phase ~= "Dressing" then
				isReady = false
			end
			if phase == "Showtime" and isContestant then
				isContestant = false
				window.close()
			end
			render()
		elseif name == "Theme" then
			render()
		end
	end)
	Remotes.Show.OnClientEvent:Connect(function(message)
		if type(message) == "table" and message.Type == "Dressing" then
			isContestant = true
			isReady = false
			WardrobeUi.open("Studio")
		end
	end)
end

return WardrobeUi
