-- Watching a round. When you're out, or sitting in the plaza while others
-- play, a small bar at the bottom lets you follow anyone still standing,
-- flipping between them with the arrows. Watching never shows anyone's
-- role: you see what a guest beside them would see.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Corner = require(script.Parent.Corner)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local Spectate = {}

local gui = Ui.screen("Spectate", 2)
local bar = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(360, 46),
	BackgroundColor3 = Ui.Colors.Panel,
	BackgroundTransparency = 0.1,
	Visible = false,
}, gui)
Ui.round(bar, 12)
Ui.stroke(bar, Ui.Colors.Accent, 2)
Ui.fitScale(bar)
local previous = Ui.button(bar, "<", Ui.Colors.Card, {
	Position = UDim2.fromOffset(6, 6),
	Size = UDim2.fromOffset(34, 34),
	TextSize = 18,
})
local nameLabel = Ui.label(bar, "", {
	Position = UDim2.fromOffset(46, 4),
	Size = UDim2.new(1, -190, 0, 22),
	Font = Ui.Title,
	TextSize = 16,
})
local hint = Ui.label(bar, "", {
	Position = UDim2.fromOffset(46, 25),
	Size = UDim2.new(1, -190, 0, 14),
	TextSize = 10,
	TextColor3 = Ui.Colors.Dim,
})
local nextButton = Ui.button(bar, ">", Ui.Colors.Card, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -96, 0, 6),
	Size = UDim2.fromOffset(34, 34),
	TextSize = 18,
})
local stop = Ui.button(bar, "Stop", Ui.Colors.Bad, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -6, 0, 6),
	Size = UDim2.fromOffset(84, 34),
})

-- The button to start watching, shown in the plaza during a round.
local watchButton = Ui.button(gui, "Watch the party", Ui.Colors.Accent, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(180, 40),
	Visible = false,
})
Ui.fitScale(watchButton)

local watching: Player? = nil
local active = false

-- Everyone still standing in the round.
local function standing(): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if
			other ~= player
			and character
			and character:GetAttribute("Pid") ~= nil
			and character:GetAttribute("Out") ~= true
		then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local function myHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function follow(other: Player?)
	watching = other
	local camera = Workspace.CurrentCamera
	local humanoid = other and other.Character and other.Character:FindFirstChildOfClass("Humanoid")
	if camera and humanoid then
		camera.CameraSubject = humanoid
		nameLabel.Text = other and other.DisplayName or ""
		local dazed = other and other.Character and other.Character:GetAttribute("Dazed") == true
		hint.Text = if dazed then "Dazed! Waiting for a Medic..." else "Still at the party"
	end
end

local function step(direction: number)
	local list = standing()
	if #list == 0 then
		return
	end
	local index = watching and table.find(list, watching) or 0
	index = ((index - 1 + direction) % #list) + 1
	follow(list[index])
	Sounds.play("Click")
end

function Spectate.stop()
	if not active then
		return
	end
	active = false
	watching = nil
	bar.Visible = false
	local camera = Workspace.CurrentCamera
	local humanoid = myHumanoid()
	if camera and humanoid then
		camera.CameraSubject = humanoid
	end
end

function Spectate.begin()
	if #standing() == 0 then
		Corner.note("Nobody to watch", "The round has nobody left standing.", Ui.Colors.Dim, 3)
		return
	end
	active = true
	bar.Visible = true
	watchButton.Visible = false
	step(1)
end

-- Whether watching makes sense now: a round is on and you're not in it.
local function canWatch(): boolean
	local round = State.Round
	if round.State ~= "Playing" then
		return false
	end
	return not round.InRound or State.Me == "Out"
end

local function refresh()
	local can = canWatch()
	if not can then
		Spectate.stop()
	end
	watchButton.Visible = can and not active
end

function Spectate.start()
	previous.Activated:Connect(function()
		step(-1)
	end)
	nextButton.Activated:Connect(function()
		step(1)
	end)
	stop.Activated:Connect(Spectate.stop)
	watchButton.Activated:Connect(Spectate.begin)
	State.on("Round", refresh)
	State.on("Me", refresh)
	player.CharacterAdded:Connect(function()
		-- A new body in the plaza; keep watching if a round is still on.
		task.defer(function()
			if active and watching then
				follow(watching)
			end
			refresh()
		end)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not active then
			return
		end
		if input.KeyCode == Enum.KeyCode.Left then
			step(-1)
		elseif input.KeyCode == Enum.KeyCode.Right then
			step(1)
		end
	end)
	-- Move on when the one you're watching is out or leaves.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if active then
				local character = watching and watching.Character
				if
					not watching
					or not watching.Parent
					or not character
					or character:GetAttribute("Pid") == nil
					or character:GetAttribute("Out") == true
				then
					if #standing() == 0 then
						Spectate.stop()
					else
						step(1)
					end
				else
					follow(watching)
				end
			end
		end
	end)
end

return Spectate
