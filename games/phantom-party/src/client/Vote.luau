-- The map vote during the intermission: a small card per map along the
-- bottom of the screen, with how many votes each has. Tap one to vote;
-- tap another to change your mind.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local VoteRemote = Remotes:WaitForChild("Vote") :: RemoteEvent
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local NAMES = {
	manor = { "Hollowmere Manor", "Secret passages and a grand ballroom." },
	carnival = { "Starlight Carnival", "Neon lights, a mirror maze and a big top." },
}

local Vote = {}

local gui = Ui.screen("Vote", 2)
local row = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(0, 74),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
local layout = Ui.list(row, 8, true)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Ui.fitScale(row)

local mine: string? = nil

local function draw()
	for _, child in row:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local vote = State.Vote
	row.Visible = State.Round.State == "Intermission" and #vote.Choices > 0
	for index, mapId in vote.Choices do
		local info = NAMES[mapId] or { mapId, "" }
		local chosen = mine == mapId
		local button = Ui.make("TextButton", {
			Size = UDim2.fromOffset(170, 70),
			BackgroundColor3 = if chosen then Ui.Colors.CardHover else Ui.Colors.Panel,
			BackgroundTransparency = 0.08,
			AutoButtonColor = true,
			Text = "",
			LayoutOrder = index,
		}, row)
		Ui.round(button, 10)
		Ui.stroke(button, if chosen then Ui.Colors.Gold else Ui.Colors.Accent, if chosen then 2.5 else 1.5)
		Ui.label(button, info[1], {
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 20),
			Font = Ui.Title,
			TextSize = 16,
			TextColor3 = Ui.Colors.Gold,
		})
		Ui.label(button, info[2], {
			Position = UDim2.fromOffset(8, 24),
			Size = UDim2.new(1, -16, 0, 26),
			TextSize = 11,
			TextColor3 = Ui.Colors.Dim,
		})
		local count = vote.Counts[mapId] or 0
		Ui.label(button, if count == 1 then "1 vote" else `{count} votes`, {
			Position = UDim2.new(0, 8, 1, -20),
			Size = UDim2.new(1, -16, 0, 16),
			TextSize = 12,
			Font = Ui.Title,
		})
		button.Activated:Connect(function()
			mine = mapId
			Sounds.play("Vote")
			VoteRemote:FireServer(mapId)
			draw()
		end)
	end
end

function Vote.start()
	State.on("Vote", draw)
	State.on("Round", function()
		if State.Round.State ~= "Intermission" then
			mine = nil
		end
		draw()
	end)
end

return Vote
