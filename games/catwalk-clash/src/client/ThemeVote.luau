-- The theme vote and reveal. While the lobby votes, three theme cards sit
-- along the bottom of the screen with live vote counts; the weekly
-- spotlight theme (double rewards) wears a gold star. When the vote ends,
-- the winning theme is revealed in a big banner for a moment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Themes = require(Config.Themes)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local C = Ui.Colors
local make = Ui.make

local ThemeVote = {}

local remote: RemoteEvent
local gui: ScreenGui
local row: Frame
local banner: Frame
local bannerName: TextLabel
local bannerHint: TextLabel
local cards: { TextButton } = {}
local choice = 0
local shownRound = -1

local COLORS = { C.Pink, C.Aqua, C.Violet }

local function options(): { string }
	local text = State.round("Options")
	if type(text) ~= "string" or text == "" then
		return {}
	end
	return string.split(text, ",")
end

local function counts(): { number }
	local text = State.round("OptionVotes")
	local list = {}
	if type(text) == "string" and text ~= "" then
		for _, value in string.split(text, ",") do
			table.insert(list, tonumber(value) or 0)
		end
	end
	return list
end

local function refreshCounts()
	local list = counts()
	for index, card in cards do
		local votes = card:FindFirstChild("Votes") :: TextLabel?
		if votes then
			local count = list[index] or 0
			votes.Text = if count == 1 then "1 vote" else `{count} votes`
		end
		Ui.setChosen(card, index == choice, COLORS[index])
	end
end

local function build()
	for _, card in cards do
		card:Destroy()
	end
	cards = {}
	choice = 0
	local spotlight = State.round("Spotlight")
	for index, id in options() do
		local theme = Themes.get(id)
		if theme then
			local card = Ui.button(row, "", C.Panel2, function()
				choice = index
				remote:FireServer(index)
				Sounds.play("Vote")
				refreshCounts()
			end, { Size = UDim2.fromOffset(196, 92), LayoutOrder = index })
			Ui.stroke(card, COLORS[index], 2)
			Ui.label(card, {
				Text = theme.Name,
				Font = Ui.Fonts.Title,
				TextSize = 20,
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 0, 26),
			})
			Ui.label(card, {
				Text = theme.Hint,
				TextSize = 12,
				TextColor3 = C.Muted,
				Position = UDim2.fromOffset(8, 36),
				Size = UDim2.new(1, -16, 0, 28),
			})
			Ui.label(card, {
				Name = "Votes",
				Text = "0 votes",
				TextSize = 13,
				TextColor3 = COLORS[index],
				Position = UDim2.new(0, 8, 1, -24),
				Size = UDim2.new(1, -16, 0, 18),
			})
			if id == spotlight then
				local badge = Ui.label(card, {
					Text = "★ x2",
					Font = Ui.Fonts.Title,
					TextSize = 14,
					TextColor3 = C.Dark,
					BackgroundTransparency = 0,
					BackgroundColor3 = C.Gold,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 6, 0, -8),
					Size = UDim2.fromOffset(46, 22),
				})
				Ui.corner(badge, 11)
			end
			table.insert(cards, card)
		end
	end
	refreshCounts()
end

local function reveal()
	local theme = State.theme()
	if not theme then
		return
	end
	local spotlight = State.round("Spotlight") == theme.Id
	bannerName.Text = theme.Name
	bannerHint.Text = if spotlight then `★ Spotlight theme: double rewards! ★` else theme.Hint
	banner.Visible = true
	banner.BackgroundTransparency = 1
	Ui.pop(banner)
	TweenService:Create(banner, TweenInfo.new(0.3), { BackgroundTransparency = 0.1 }):Play()
	Sounds.play("Reveal")
	task.delay(4.2, function()
		banner.Visible = false
	end)
end

local function update(name: string)
	local phase = State.phase()
	if name == "Phase" then
		row.Visible = phase == "ThemeVote"
		if phase == "ThemeVote" and shownRound ~= State.round("Round") then
			shownRound = State.round("Round")
			build()
			Ui.pop(row)
		end
		if phase == "Reveal" then
			reveal()
		end
	elseif name == "Options" and phase == "ThemeVote" then
		build()
	elseif name == "OptionVotes" then
		refreshCounts()
	end
end

function ThemeVote.mount()
	remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ThemeVote") :: RemoteEvent
	gui = Ui.screen("ThemeVote", 4)
	row = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(620, 100),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	Ui.list(row, true, 10, Enum.HorizontalAlignment.Center)
	Ui.autoscale(row)

	banner = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(520, 150),
		BackgroundColor3 = C.Panel,
		Visible = false,
	}, gui)
	Ui.corner(banner, 22)
	Ui.stroke(banner, C.Gold, 3)
	Ui.label(banner, {
		Text = "THE THEME IS",
		Font = Ui.Fonts.Title,
		TextSize = 22,
		TextColor3 = C.Gold,
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 28),
	})
	bannerName = Ui.label(banner, {
		Font = Ui.Fonts.Title,
		TextSize = 46,
		Position = UDim2.fromOffset(10, 42),
		Size = UDim2.new(1, -20, 0, 56),
		TextScaled = true,
	})
	make("UIStroke", { Color = C.Pink, Thickness = 2.5 }, bannerName)
	bannerHint = Ui.label(banner, {
		TextSize = 16,
		TextColor3 = C.Aqua,
		Position = UDim2.fromOffset(10, 104),
		Size = UDim2.new(1, -20, 0, 34),
	})

	State.onRound(update)
	update("Phase")
end

return ThemeVote
