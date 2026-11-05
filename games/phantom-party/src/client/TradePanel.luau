-- The Trading Hall. Pick a player to ask; they get a small card to say yes
-- or no. In a trade each side puts up to eight copies on the table. When
-- both accept, a five second countdown runs, and any change to either offer
-- stops it, so nobody can swap something out at the last moment. The server
-- checks every copy again and moves them all at once, or none.
--
-- Only earned and bought-with-coins copies can be traded. Game pass items
-- and the defaults stay with their owner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Corner = require(script.Parent.Corner)
local Hud = require(script.Parent.Hud)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local TradeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Trade") :: RemoteEvent

local MAX_ITEMS = 8

local player = Players.LocalPlayer

local TradePanel = {}

local gui = Ui.screen("Trade", 3)
local panel, body, heading = Ui.panel(gui, "Trading Hall", 640, 430)

-- The open trade as the server last described it, or nil.
local session: { [string]: any }? = nil
-- When each player was asked, so the list can say "Asked".
local asked: { [number]: number } = {}
local countdown: TextLabel? = nil

local function clear()
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	countdown = nil
end

local function itemName(itemId: string?): string
	local item = itemId and Items.get(itemId)
	return item and item.Name or "?"
end

-- A small square showing one copy on the table.
local function slot(parent: Instance, entry: { Uid: string, Item: string? }?, order: number, onClick: (() -> ())?)
	local cell = Ui.make("TextButton", {
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = Ui.Colors.Card,
		AutoButtonColor = onClick ~= nil,
		Text = "",
		LayoutOrder = order,
	}, parent)
	Ui.round(cell, 8)
	if entry and entry.Item then
		local item = Items.get(entry.Item)
		Ui.picture(cell, entry.Item)
		Ui.stroke(cell, Ui.rarityColor(item and item.Rarity or "Common"), 2)
	else
		cell.BackgroundTransparency = 0.5
	end
	if onClick then
		cell.Activated:Connect(onClick)
	end
	return cell
end

-- The list of players to ask.
local function drawList()
	heading.Text = "Trading Hall"
	Ui.label(body, "Trade masks, blades, blasters, effects and trails with anyone here, between rounds.", {
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 13,
		TextColor3 = Ui.Colors.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Ui.Colors.Accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, body)
	Ui.list(list, 6)
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(others, other)
		end
	end
	table.sort(others, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	if #others == 0 then
		Ui.label(list, "Nobody else is here yet. Invite a friend!", {
			Size = UDim2.new(1, 0, 0, 40),
			TextColor3 = Ui.Colors.Dim,
		})
		return
	end
	for index, other in others do
		local row = Ui.make("Frame", {
			Size = UDim2.new(1, -10, 0, 48),
			BackgroundColor3 = Ui.Colors.Card,
			LayoutOrder = index,
		}, list)
		Ui.round(row, 8)
		local face = Ui.make("ImageLabel", {
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = Ui.Colors.Panel,
			Image = `rbxthumb://type=AvatarHeadShot&id={other.UserId}&w=48&h=48`,
		}, row)
		Ui.round(face, 20)
		Ui.label(row, other.DisplayName, {
			Position = UDim2.fromOffset(56, 6),
			Size = UDim2.new(1, -190, 0, 20),
			Font = Ui.Title,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local character = other.Character
		local inRound = character ~= nil and character:GetAttribute("Pid") ~= nil
		Ui.label(row, if inRound then "In a round" else "In the plaza", {
			Position = UDim2.fromOffset(56, 26),
			Size = UDim2.new(1, -190, 0, 14),
			TextSize = 11,
			TextColor3 = if inRound then Ui.Colors.Bad else Ui.Colors.Good,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local wasAsked = asked[other.UserId] and os.clock() - asked[other.UserId] < 20
		local button = Ui.button(
			row,
			if wasAsked then "Asked" else "Trade",
			if wasAsked or inRound then Ui.Colors.Track else Ui.Colors.Accent,
			{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(110, 32) }
		)
		button.Activated:Connect(function()
			if wasAsked then
				return
			end
			TradeRemote:FireServer("Request", other.UserId)
		end)
	end
end

local function offerIds(list: { { Uid: string, Item: string? } }): { string }
	local ids = {}
	for _, entry in list do
		table.insert(ids, entry.Uid)
	end
	return ids
end

-- The open trade: both offers, your tradeable copies and the buttons.
local function drawTrade(view: { [string]: any })
	heading.Text = `Trading with {view.With.Name}`
	local mine = view.Mine :: { { Uid: string, Item: string? } }
	local theirs = view.Theirs :: { { Uid: string, Item: string? } }
	local onTable: { [string]: boolean } = {}
	for _, entry in mine do
		onTable[entry.Uid] = true
	end

	local function side(title: string, list, x: number, accepted: boolean, removable: boolean)
		local frame = Ui.make("Frame", {
			Position = UDim2.new(x, if x > 0 then 5 else 0, 0, 0),
			Size = UDim2.new(0.5, -5, 0, 182),
			BackgroundColor3 = Ui.Colors.Card,
			BackgroundTransparency = 0.4,
		}, body)
		Ui.round(frame, 10)
		Ui.stroke(frame, if accepted then Ui.Colors.Good else Ui.Colors.Track, if accepted then 3 else 1.5)
		Ui.label(frame, title, {
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 0, 20),
			Font = Ui.Title,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.label(frame, if accepted then "ACCEPTED" else "", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 8),
			Size = UDim2.fromOffset(90, 16),
			TextSize = 12,
			TextColor3 = Ui.Colors.Good,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local slots = Ui.make("Frame", {
			Position = UDim2.fromOffset(10, 32),
			Size = UDim2.new(1, -20, 1, -40),
			BackgroundTransparency = 1,
		}, frame)
		Ui.make("UIGridLayout", {
			CellSize = UDim2.fromOffset(62, 62),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, slots)
		for index = 1, MAX_ITEMS do
			local entry = list[index]
			local click = nil
			if removable and entry then
				click = function()
					local ids = {}
					for _, other in mine do
						if other.Uid ~= entry.Uid then
							table.insert(ids, other.Uid)
						end
					end
					Sounds.play("Click")
					TradeRemote:FireServer("Offer", ids)
				end
			end
			slot(slots, entry, index, click)
		end
	end
	side("Your offer", mine, 0, view.MineAccepted, true)
	side(`{view.With.Name}'s offer`, theirs, 0.5, view.TheirsAccepted, false)

	-- Your copies that can go on the table.
	Ui.label(body, "Your tradeable items (tap to add or take back)", {
		Position = UDim2.fromOffset(0, 188),
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 12,
		TextColor3 = Ui.Colors.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local shelf = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 206),
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Ui.Colors.Accent,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
	}, body)
	Ui.list(shelf, 6, true)
	local copies = {}
	for uid, itemId in (State.Profile and State.Profile.Items) or {} do
		if Items.tradeable(itemId) then
			table.insert(copies, { Uid = uid, Item = itemId })
		end
	end
	table.sort(copies, function(a, b)
		local ra = Items.rank((Items.get(a.Item) :: any).Rarity)
		local rb = Items.rank((Items.get(b.Item) :: any).Rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.Uid < b.Uid
	end)
	if #copies == 0 then
		Ui.label(shelf, "Nothing to trade yet. Crates and the boutique give tradeable items.", {
			Size = UDim2.new(0, 560, 1, 0),
			TextSize = 12,
			TextColor3 = Ui.Colors.Dim,
		})
	end
	for index, copy in copies do
		local cell = slot(shelf, copy, index, function()
			local ids = offerIds(mine)
			if onTable[copy.Uid] then
				local index2 = table.find(ids, copy.Uid)
				if index2 then
					table.remove(ids, index2)
				end
			elseif #ids >= MAX_ITEMS then
				Sounds.play("Deny")
				Corner.note("Table's full", "Eight items at most in one trade.", Ui.Colors.Bad)
				return
			else
				table.insert(ids, copy.Uid)
			end
			Sounds.play("Click")
			TradeRemote:FireServer("Offer", ids)
		end)
		cell.Size = UDim2.fromOffset(72, 72)
		if onTable[copy.Uid] then
			Ui.make("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.5,
				ZIndex = 4,
			}, cell)
			Ui.label(cell, "ON TABLE", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -4),
				Size = UDim2.new(1, 0, 0, 12),
				TextSize = 10,
				TextColor3 = Ui.Colors.Gold,
				ZIndex = 5,
			})
		end
		cell.MouseEnter:Connect(function()
			heading.Text = itemName(copy.Item)
		end)
		cell.MouseLeave:Connect(function()
			heading.Text = `Trading with {view.With.Name}`
		end)
	end

	-- Status and buttons.
	local status = Ui.label(body, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -6),
		Size = UDim2.new(1, -300, 0, 36),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	if view.State == "Countdown" then
		status.TextColor3 = Ui.Colors.Gold
		countdown = status
	elseif view.State == "Settling" then
		status.Text = "Saving the swap for both of you..."
		status.TextColor3 = Ui.Colors.Gold
	elseif view.MineAccepted then
		status.Text = `Waiting for {view.With.Name} to accept...`
		status.TextColor3 = Ui.Colors.Dim
	elseif view.TheirsAccepted then
		status.Text = `{view.With.Name} accepted. Accept to start the countdown.`
		status.TextColor3 = Ui.Colors.Good
	else
		status.Text = "Both players accept, then a short countdown, then the swap."
		status.TextColor3 = Ui.Colors.Dim
	end
	local empty = #mine == 0 and #theirs == 0
	local accept = Ui.button(
		body,
		if view.MineAccepted then "Unaccept" else "Accept",
		if view.MineAccepted then Ui.Colors.Gold elseif empty then Ui.Colors.Track else Ui.Colors.Good,
		{ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -150, 1, -4), Size = UDim2.fromOffset(140, 40) }
	)
	accept.Activated:Connect(function()
		if view.MineAccepted then
			TradeRemote:FireServer("Unaccept")
		elseif not empty then
			Sounds.play("Click")
			TradeRemote:FireServer("Accept")
		else
			Sounds.play("Deny")
		end
	end)
	local cancel = Ui.button(body, "Cancel", Ui.Colors.Bad, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, -4),
		Size = UDim2.fromOffset(140, 40),
	})
	cancel.Activated:Connect(function()
		TradeRemote:FireServer("Cancel")
	end)
end

local function draw()
	clear()
	if session then
		drawTrade(session)
	else
		drawList()
	end
end

function TradePanel.open()
	Ui.show(panel)
	draw()
end

local function names(list: { string }): string
	if #list == 0 then
		return "nothing"
	end
	local out = {}
	for _, itemId in list do
		table.insert(out, itemName(itemId))
	end
	return table.concat(out, ", ")
end

function TradePanel.start()
	Hud.onMenu("Trade", function()
		if Ui.isOpen(panel) then
			Ui.hide(panel)
		else
			TradePanel.open()
		end
	end)

	TradeRemote.OnClientEvent:Connect(function(kind: string, payload: any)
		if kind == "Incoming" then
			Sounds.play("Page")
			Corner.ask(
				`{payload.Name} wants to trade`,
				"Open a trade with them?",
				"Trade",
				"No thanks",
				20,
				function(yes)
					TradeRemote:FireServer("Respond", payload.UserId, yes)
				end
			)
		elseif kind == "Sent" then
			asked[payload.UserId] = os.clock()
			Corner.note("Request sent", `Waiting for {payload.Name} to answer.`, Ui.Colors.Accent, 5)
			if Ui.isOpen(panel) and not session then
				draw()
			end
		elseif kind == "Open" then
			session = payload
			asked = {}
			Sounds.play("Click")
			TradePanel.open()
		elseif kind == "Update" then
			local before = session
			session = payload
			if before and payload.State == "Countdown" and before.State ~= "Countdown" then
				Sounds.play("Tick")
			end
			if Ui.isOpen(panel) then
				draw()
			end
		elseif kind == "Closed" then
			session = nil
			Corner.note("Trade closed", tostring(payload), Ui.Colors.Dim, 5)
			if Ui.isOpen(panel) then
				draw()
			end
		elseif kind == "Done" then
			session = nil
			Sounds.play("TradeDone")
			Corner.note(`Traded with {payload.With}!`, `You got {names(payload.Got)}.`, Ui.Colors.Good, 7)
			if Ui.isOpen(panel) then
				draw()
			end
		elseif kind == "Denied" then
			Sounds.play("Deny")
			Corner.note("Trade", tostring(payload), Ui.Colors.Bad, 5)
		end
	end)

	-- Profile changes (a new crate item) refresh the shelf.
	State.on("Profile", function()
		if Ui.isOpen(panel) and session then
			draw()
		end
	end)
	-- A trade can't stay open when a round pulls you in.
	State.on("Round", function()
		if State.Round.InRound and Ui.isOpen(panel) then
			Ui.hide(panel)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local view = session
		if countdown and view and view.State == "Countdown" and view.EndsAt then
			local left = math.max(0, math.ceil(State.left(view.EndsAt)))
			countdown.Text = `Swapping in {left}... any change stops it.`
		end
	end)
end

return TradePanel
