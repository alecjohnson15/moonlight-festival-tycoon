-- The two moments that take the middle of the screen, briefly:
--   - the role reveal as a round begins: your role, your goal, what you can
--     do and, for the Shadows, who's on your side;
--   - the results: who won, the moment that decided it, who was who, the
--     party star, what you earned and any mastery goals you met (only you
--     see those).
-- Both are cards of a fixed, modest size that close on their own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Roles = require(Shared.Config.Roles)
local Corner = require(script.Parent.Corner)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local RoleCard = {}

local gui = Ui.screen("RoleCard", 4)

local function card(width: number, height: number, accent: Color3): Frame
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.04,
	}, gui)
	Ui.round(frame, 14)
	Ui.stroke(frame, accent, 3)
	local scale = Ui.fitScale(frame)
	local target = scale.Scale
	scale.Scale = target * 0.6
	Ui.pop(scale, target, 0.35)
	return frame
end

local current: Frame? = nil

local function close()
	if current then
		current:Destroy()
		current = nil
	end
end

local function reveal(message)
	close()
	local role = Roles.List[message.Role]
	if not role then
		return
	end
	local color = Color3.fromHex(role.Color)
	local frame = card(400, 262, color)
	current = frame
	local heading = "YOUR ROLE"
	if message.Practice then
		heading = "PRACTICE ROUND"
	elseif message.Ruleset == "Duel" then
		heading = "DUEL: YOUR ROLE"
	end
	Ui.label(frame, heading, {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 13,
		TextColor3 = Ui.Colors.Dim,
	})
	Ui.label(frame, string.upper(role.Name), {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 46),
		Font = Ui.Title,
		TextSize = 42,
		TextColor3 = color,
		TextStrokeTransparency = 0.5,
	})
	Ui.label(frame, role.Goal, {
		Position = UDim2.fromOffset(20, 78),
		Size = UDim2.new(1, -40, 0, 40),
		TextSize = 15,
	})
	local moves = Ui.make("Frame", {
		Position = UDim2.fromOffset(24, 124),
		Size = UDim2.new(1, -48, 0, 90),
		BackgroundTransparency = 1,
	}, frame)
	Ui.list(moves, 3)
	for index, move in role.Moves do
		Ui.label(moves, `• {move}`, {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 13,
			TextColor3 = Ui.Colors.Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = index,
		})
	end
	local footer = ""
	if #message.Allies > 0 then
		local names = {}
		for _, ally in message.Allies do
			table.insert(names, `{ally.Name} ({ally.Role})`)
		end
		footer = `On your side: {table.concat(names, ", ")}`
	elseif message.Practice then
		footer = "Practice: stand-ins don't talk or hide, and it pays nothing. Real rounds start when someone joins."
	elseif message.Ruleset == "Duel" then
		footer = "Just two of you, so you both know who's who. Find each other first!"
	end
	if footer ~= "" then
		Ui.label(frame, footer, {
			Position = UDim2.new(0, 20, 1, -40),
			Size = UDim2.new(1, -40, 0, 32),
			TextSize = 12,
			TextWrapped = true,
			TextColor3 = color,
		})
	end
	Sounds.play(if role.Team == "Shadows" then "RevealShadow" else "RevealGuest")
	task.delay(6, function()
		if current == frame then
			close()
		end
	end)
end

local REASONS = {
	PhantomOut = "The Phantom was knocked out!",
	PhantomLeft = "The Phantom left the party.",
	AllTagged = "Every guest was tagged.",
	GuestsLeft = "Every guest left the party.",
	Time = "The guests made it to dawn.",
}

local function results(message)
	close()
	local guestsWon = message.Winner == "Guests"
	local color = if guestsWon
		then Color3.fromHex(Roles.List.Guardian.Color)
		else Color3.fromHex(Roles.List.Phantom.Color)
	local recap = if typeof(message.Recap) == "table" then message.Recap else {}
	local star = recap.Star
	local frame = card(420, if star then 328 else 304, color)
	current = frame
	Ui.label(frame, if guestsWon then "THE GUESTS WIN!" else "THE PHANTOM WINS!", {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 36),
		Font = Ui.Title,
		TextSize = 30,
		TextColor3 = color,
		TextStrokeTransparency = 0.5,
	})
	local decisive = if typeof(recap.Decisive) == "string" and recap.Decisive ~= ""
		then recap.Decisive
		else REASONS[message.Reason] or ""
	Ui.label(frame, decisive, {
		Position = UDim2.fromOffset(16, 46),
		Size = UDim2.new(1, -32, 0, 22),
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = Ui.Colors.Text,
	})
	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 0, 140),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
	}, frame)
	Ui.list(list, 2)
	for index, entry in message.Reveal do
		local role = Roles.List[entry.Role]
		local tags = {}
		if entry.Hero then
			table.insert(tags, "Hero")
		end
		if entry.Takedown then
			table.insert(tags, "caught the Phantom")
		end
		if entry.Tags > 0 then
			table.insert(tags, `{entry.Tags} tagged`)
		end
		if entry.Revives > 0 then
			table.insert(tags, `{entry.Revives} revived`)
		end
		if entry.State ~= "Alive" then
			table.insert(tags, "out")
		end
		local row = Ui.make("Frame", {
			Size = UDim2.new(1, -6, 0, 20),
			BackgroundTransparency = 1,
			LayoutOrder = index,
		}, list)
		Ui.label(row, entry.Name, {
			Size = UDim2.fromScale(0.45, 1),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Ui.label(row, if role then role.Name else entry.Role, {
			Position = UDim2.fromScale(0.45, 0),
			Size = UDim2.fromScale(0.22, 1),
			TextSize = 13,
			Font = Ui.Title,
			TextColor3 = if entry.Hero
				then Color3.fromHex(Roles.HERO_COLOR)
				elseif role then Color3.fromHex(role.Color)
				else Ui.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.label(row, table.concat(tags, ", "), {
			Position = UDim2.fromScale(0.67, 0),
			Size = UDim2.fromScale(0.33, 1),
			TextSize = 11,
			TextColor3 = Ui.Colors.Dim,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	if star then
		local role = Roles.List[star.Role]
		local starLabel = Ui.label(frame, `PARTY STAR: {star.Name} ({if role then role.Name else star.Role})`, {
			Position = UDim2.fromOffset(16, 218),
			Size = UDim2.new(1, -32, 0, 16),
			Font = Ui.Title,
			TextSize = 14,
			TextColor3 = Ui.Colors.Gold,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		starLabel.Name = "Star"
		Ui.label(frame, star.Why, {
			Position = UDim2.fromOffset(16, 234),
			Size = UDim2.new(1, -32, 0, 14),
			TextSize = 11,
			TextColor3 = Ui.Colors.Dim,
		})
	end
	local pay = Ui.label(frame, "", {
		Name = "Pay",
		Position = UDim2.new(0, 16, 1, -80),
		Size = UDim2.new(1, -32, 0, 70),
		TextSize = 13,
		TextColor3 = Ui.Colors.Gold,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	pay.Text = if State.Round.InRound then "Adding up your rewards..." else "Join the next party to earn coins and XP!"
	Sounds.play(if guestsWon then "GuestsWin" else "PhantomWins")
	task.delay(10, function()
		if current == frame then
			close()
		end
	end)
end

local function paid(message)
	local frame = current
	local label = frame and frame:FindFirstChild("Pay") :: TextLabel?
	local lines = {}
	for _, line in message.Lines do
		local parts = {}
		if line.Coins > 0 then
			table.insert(parts, `+{line.Coins} coins`)
		end
		if line.Xp > 0 then
			table.insert(parts, `+{line.Xp} XP`)
		end
		table.insert(lines, if #parts > 0 then `{line.Label}: {table.concat(parts, ", ")}` else line.Label)
	end
	local text = `{table.concat(lines, "\n")}`
	if label then
		label.Text = `+{message.Coins} coins   +{message.Xp} XP`
		label.TextSize = 18
		label.Font = Ui.Title
	end
	if message.Coins > 0 or message.Xp > 0 then
		Corner.note("Round rewards", text, Ui.Colors.Gold, 8)
	end
	-- Mastery goals met: only this player is told.
	if typeof(message.Mastery) == "table" then
		for _, goal in message.Mastery do
			local times = if goal.Count == 1 then "first time!" else `{goal.Count} times`
			Corner.note(`Mastery: {goal.Name}`, `{goal.Text} ({times})`, Color3.fromRGB(190, 150, 255), 8)
		end
	end
end

function RoleCard.start()
	State.on("Role", function(message)
		if typeof(message) == "table" then
			reveal(message)
		end
	end)
	State.on("Results", results)
	State.on("Pay", paid)
end

return RoleCard
