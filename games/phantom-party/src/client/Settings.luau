-- Help and settings: how to play (the roles and the keys), your saved
-- stats, and the switches: music on or off, and sitting out rounds to hang
-- out in the plaza.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Roles = require(Shared.Config.Roles)
local Format = require(Shared.Format)
local Hud = require(script.Parent.Hud)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Settings = {}

local ROLE_ORDER = { "Phantom", "Saboteur", "Guardian", "Medic", "Guest" }

local KEYS = {
	{ "1 or Q", "Draw or put away your blade or blaster" },
	{ "Click", "Tag with your blade, or zap with your blaster" },
	{ "E", "Throw your blade (Phantom), or use what's in front of you" },
	{ "F", "Cut the lights (Saboteur)" },
	{ "G", "Emotes" },
}

local STATS = {
	{ "Rounds", "Rounds played" },
	{ "Wins", "Wins" },
	{ "Survived", "Rounds survived" },
	{ "Takedowns", "Phantoms knocked out" },
	{ "Tags", "Tags as the Phantom" },
	{ "PhantomWins", "Wins as the Phantom" },
	{ "Revives", "Revives" },
	{ "Clues", "Clue pages found" },
	{ "CoinsEarned", "Coins earned" },
	{ "CratesOpened", "Crates opened" },
	{ "Trades", "Trades" },
}

local gui = Ui.screen("Settings", 3)
local panel, body = Ui.panel(gui, "Help & Settings", 560, 420)
local tab = "How to play"
local sittingOut = false
local content: Frame
local pick: (string) -> ()

local function scroller(parent: Instance): ScrollingFrame
	local frame = Ui.make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Ui.Colors.Accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, parent)
	Ui.list(frame, 6)
	return frame
end

local function howToPlay(holder: Frame)
	local list = scroller(holder)
	Ui.label(
		list,
		"Someone at the party is the Phantom. Guests survive, find clue pages and work out who it is. The Guardian knocks the Phantom out.",
		{
			Size = UDim2.new(1, -10, 0, 36),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		}
	)
	for index, roleId in ROLE_ORDER do
		local role = Roles.List[roleId]
		local color = Color3.fromHex(role.Color)
		local card = Ui.make("Frame", {
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Ui.Colors.Card,
			LayoutOrder = index,
		}, list)
		Ui.round(card, 8)
		Ui.stroke(card, color, 1.5)
		Ui.pad(card, 10, 6)
		Ui.list(card, 2)
		Ui.label(card, `{role.Name}  ·  {if role.Team == "Shadows" then "Shadows" else "Guests"}`, {
			Font = Ui.Title,
			TextSize = 16,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		})
		Ui.label(card, role.Goal, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
		})
		for moveIndex, move in role.Moves do
			Ui.label(card, `• {move}`, {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 11,
				TextColor3 = Ui.Colors.Dim,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2 + moveIndex,
			})
		end
	end
	Ui.label(list, "Keys", {
		Font = Ui.Title,
		TextSize = 16,
		TextColor3 = Ui.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 20,
	})
	for index, pair in KEYS do
		Ui.label(list, `{pair[1]}: {pair[2]}`, {
			Size = UDim2.new(1, -10, 0, 16),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 20 + index,
		})
	end
	Ui.label(list, "On a phone or tablet, the round buttons sit at the bottom right.", {
		Size = UDim2.new(1, -10, 0, 16),
		TextSize = 12,
		TextColor3 = Ui.Colors.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 40,
	})
end

local function stats(holder: Frame)
	local profile = State.Profile
	local saved = profile and profile.Stats or {}
	local grid = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, holder)
	Ui.make("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 46),
		CellPadding = UDim2.fromOffset(8, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for index, pair in STATS do
		local cell = Ui.make("Frame", { BackgroundColor3 = Ui.Colors.Card, LayoutOrder = index }, grid)
		Ui.round(cell, 8)
		Ui.label(cell, pair[2], {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 16),
			TextSize = 11,
			TextColor3 = Ui.Colors.Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.label(cell, Format.whole(saved[pair[1]] or 0), {
			Position = UDim2.fromOffset(10, 20),
			Size = UDim2.new(1, -20, 0, 22),
			Font = Ui.Title,
			TextSize = 20,
			TextColor3 = Ui.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
end

local function switch(parent: Instance, order: number, title: string, text: string, on: boolean, flip: () -> ())
	local row = Ui.make("Frame", {
		Size = UDim2.new(1, -10, 0, 58),
		BackgroundColor3 = Ui.Colors.Card,
		LayoutOrder = order,
	}, parent)
	Ui.round(row, 8)
	Ui.label(row, title, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -140, 0, 20),
		Font = Ui.Title,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Ui.label(row, text, {
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -140, 0, 26),
		TextSize = 11,
		TextColor3 = Ui.Colors.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local button = Ui.button(row, if on then "ON" else "OFF", if on then Ui.Colors.Good else Ui.Colors.Track, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(90, 34),
	})
	button.Activated:Connect(function()
		Sounds.play("Click")
		flip()
	end)
end

local function settings(holder: Frame)
	local list = scroller(holder)
	local profile = State.Profile
	local musicOn = not profile or not profile.Settings or profile.Settings.Music ~= false
	switch(list, 1, "Music", "The plaza and party music. Sound effects stay on.", musicOn, function()
		local value = not musicOn
		local result = State.request("Setting", "Music", value)
		if result.Ok and State.Profile then
			State.Profile.Settings = State.Profile.Settings or {}
			State.Profile.Settings.Music = value
			State.fire("Profile")
		end
		pick(tab)
	end)
	switch(
		list,
		2,
		"Sit out rounds",
		"Stay in the plaza while others play: shop, trade and hang out.",
		sittingOut,
		function()
			local result = State.request("SitOut", not sittingOut)
			if result.Ok then
				sittingOut = result.SittingOut == true
				State.SittingOut = sittingOut
			end
			pick(tab)
		end
	)
	Ui.label(list, "Your progress saves on its own. Trades save the moment they finish.", {
		Size = UDim2.new(1, -10, 0, 30),
		TextSize = 11,
		TextColor3 = Ui.Colors.Dim,
		LayoutOrder = 10,
	})
end

content, pick = Ui.tabs(body, { "How to play", "Your stats", "Settings" }, function(name)
	tab = name
	local holder = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, content)
	if name == "How to play" then
		howToPlay(holder)
	elseif name == "Your stats" then
		stats(holder)
	else
		settings(holder)
	end
end)

function Settings.open(which: string?)
	Ui.show(panel)
	pick(which or tab)
end

function Settings.start()
	Hud.onMenu("Settings", function()
		if Ui.isOpen(panel) then
			Ui.hide(panel)
		else
			Settings.open()
		end
	end)
	State.on("Profile", function()
		if Ui.isOpen(panel) and tab ~= "Settings" then
			pick(tab)
		end
	end)
end

return Settings
