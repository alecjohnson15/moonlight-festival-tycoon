-- The show on this client: the runway camera, the matchup banner, the vote
-- buttons, the result with the judges' comment, the bracket card, and the
-- crowning. Walkers get their own view: the controls are handed to the show
-- while they strut, and the vote buttons say they're on the runway instead.
--
-- Votes are sent to the server (CastVote) and only count there; the split
-- is never sent until the votes close, so the buttons show the number of
-- votes but not who's ahead.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Layout = require(Config.Layout)
local GameConfig = require(Config.Game)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local Camera = require(script.Parent.Camera)
local Effects = require(script.Parent.Effects)
local Corner = require(script.Parent.Corner)
local Hud = require(script.Parent.Hud)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = Ui.Colors
local make = Ui.make

local Show = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local versus: Frame
local roundLabel: TextLabel
local nameA: TextLabel
local nameB: TextLabel
local rankA: TextLabel
local rankB: TextLabel
local panel: Frame
local status: TextLabel
local timerFill: Frame
local buttonA: TextButton
local buttonB: TextButton
local resultFrame: Frame
local resultTitle: TextLabel
local resultBarA: Frame
local resultCounts: TextLabel
local resultHow: TextLabel
local freeButton: TextButton
local crownBanner: Frame
local crownName: TextLabel
local crownSub: TextLabel
local bracketCard: Frame
local bracketLines: { TextLabel } = {}
local judgeCard: Frame
local judgeName: TextLabel
local judgeLine: TextLabel

local current: any = nil
local myVote: string? = nil
local freeLook = false
local controls: any = nil

local DECIDED = {
	Votes = "Decided by the crowd's votes and the judges",
	Judges = "The judges decided this one",
	Score = "A tie! Decided by Style Score",
	Coin = "A perfect tie! Decided by a coin toss",
}

local function getControls()
	if controls then
		return controls
	end
	local ok, module = pcall(function()
		local scripts = player:WaitForChild("PlayerScripts")
		return require(scripts:WaitForChild("PlayerModule") :: ModuleScript) :: any
	end)
	if ok and module then
		controls = module:GetControls()
	end
	return controls
end

local function setControls(enabled: boolean)
	local found = getControls()
	if found then
		if enabled then
			found:Enable()
		else
			found:Disable()
		end
	end
end

local function amWalker(): boolean
	return current ~= nil and (current.A.UserId == player.UserId or current.B.UserId == player.UserId)
end

local function showCamera(shot: string)
	if freeLook then
		Camera.clear("Show")
		return
	end
	local spec = (Layout.Cameras :: any)[shot]
	Camera.fixed("Show", Camera.Priority.Show, spec.From, spec.At, 0.06, 60)
end

local function setVoteButtons(open: boolean)
	local walker = amWalker()
	buttonA.Visible = not walker
	buttonB.Visible = not walker
	for side, button in { A = buttonA, B = buttonB } do
		local base = if side == "A" then C.Pink else C.Aqua
		if not open then
			button.BackgroundColor3 = C.Panel3
		elseif myVote and myVote ~= side then
			button.BackgroundColor3 = base:Lerp(C.Panel3, 0.6)
		else
			button.BackgroundColor3 = base
		end
		button.AutoButtonColor = open
	end
end

local function vote(side: string)
	local match = current
	if not match or amWalker() then
		return
	end
	local now = State.now()
	if now < match.OpensAt then
		Sounds.play("Deny")
		status.Text = "Votes open in a moment: look at both outfits!"
		return
	end
	if now > match.ClosesAt + GameConfig.Match.VoteGrace then
		return
	end
	myVote = side
	Remotes.CastVote:FireServer({ Id = match.Id, Side = side })
	Sounds.play("Vote")
	setVoteButtons(true)
	Ui.pop(if side == "A" then buttonA else buttonB)
end

local function onBracket(message)
	local rounds = message.Rounds or {}
	local names = message.Names or {}
	-- The round in progress: the first with a match still to walk.
	local roundIndex = #rounds
	for index, matches in rounds do
		local open = false
		for _, pair in matches do
			if pair[3] == "" and pair[1] ~= "" and pair[2] ~= "" then
				open = true
			end
		end
		if open then
			roundIndex = index
			break
		end
	end
	local matches = rounds[roundIndex] or {}
	local fromEnd = #rounds - roundIndex
	local title = if fromEnd == 0
		then "Final"
		elseif fromEnd == 1 then "Semifinals"
		elseif fromEnd == 2 then "Quarterfinals"
		else `Round {roundIndex}`
	bracketLines[1].Text = `Bracket: {title}`
	for index = 2, #bracketLines do
		local pair = matches[index - 1]
		local label = bracketLines[index]
		if pair and (pair[1] ~= "" or pair[2] ~= "") then
			local a = names[pair[1]] or "Bye"
			local b = names[pair[2]] or "Bye"
			if pair[3] ~= "" then
				if pair[3] == pair[1] then
					a = `✓ {a}`
				else
					b = `✓ {b}`
				end
			end
			label.Text = `{a}  vs  {b}`
			label.Visible = true
		else
			label.Visible = false
		end
	end
	Corner.pop(bracketCard)
end

local function onMatch(message)
	current = message
	myVote = nil
	judgeCard.Visible = false
	resultFrame.Visible = false
	roundLabel.Text = string.upper(message.Round)
	nameA.Text = message.A.Name
	nameB.Text = message.B.Name
	rankA.Text = if message.A.Rival then "Studio model" else `{message.A.Rank} · {message.A.Rating}`
	rankB.Text = if message.B.Rival then "Studio model" else `{message.B.Rank} · {message.B.Rating}`
	buttonA.Text = message.A.Name
	buttonB.Text = message.B.Name
	versus.Visible = true
	Ui.pop(versus)
	panel.Visible = true
	if amWalker() then
		status.Text = "You're on the runway! Strut your stuff!"
		Hud.setMenuVisible(false)
	else
		status.Text = "Get ready to vote!"
	end
	setVoteButtons(false)
	showCamera("Runway")
	Sounds.play("Whoosh")

	local walkIn = math.max(0, message.WalkAt - State.now())
	local walkFor = math.max(1, message.PoseAt - message.WalkAt)
	task.delay(walkIn, function()
		if current ~= message then
			return
		end
		for side, info in { A = message.A, B = message.B } do
			if info.Model then
				Effects.entrance(info.Model, info.Entrance, walkFor)
			end
			Effects.lane(side, true)
		end
		Effects.paparazzi(walkFor + 2)
		Sounds.play("Whoosh", 0.8)
	end)
	task.delay(math.max(0, message.OpensAt - State.now()), function()
		if current == message and not amWalker() then
			status.Text = "Vote for your favourite look!"
			setVoteButtons(true)
			Sounds.play("Tick", 1.3)
		end
	end)
	task.delay(math.max(0, message.PoseAt - State.now()), function()
		if current == message then
			showCamera("Pose")
			Effects.flash(Vector3.new(0, 10, -100))
			Sounds.play("Shutter")
		end
	end)
end

local function onVoteCount(message)
	if current and message.Id == current.Id then
		local count = message.Votes or 0
		if not amWalker() then
			status.Text = if count == 1 then "1 vote so far" else `{count} votes so far`
		else
			status.Text = `You're on the runway! {count} votes so far`
		end
	end
end

local function onResult(message)
	if not current or message.Id ~= current.Id then
		return
	end
	local match = current
	setVoteButtons(false)
	buttonA.Visible = false
	buttonB.Visible = false
	resultFrame.Visible = true
	local winnerName = if message.Winner == "A" then match.A.Name else match.B.Name
	resultTitle.Text = `{winnerName} wins!`
	resultTitle.TextColor3 = if message.Winner == "A" then C.Pink else C.Aqua
	local total = message.VotesA + message.VotesB
	local share = if total > 0 then message.VotesA / total else 0.5
	resultBarA.Size = UDim2.fromScale(0.5, 1)
	TweenService:Create(resultBarA, TweenInfo.new(0.8, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(share, 1) })
		:Play()
	resultCounts.Text =
		`{message.VotesA} votes · judges {message.JudgesA}   |   judges {message.JudgesB} · {message.VotesB} votes`
	resultHow.Text = DECIDED[message.DecidedBy] or ""
	status.Text = ""

	if message.Judge then
		judgeName.Text = message.Judge.Name
		judgeLine.Text = `"{message.Judge.Line}"`
		Corner.pop(judgeCard)
	end
	Sounds.play("VoteReveal")
	task.delay(0.4, function()
		Sounds.play("Cheer")
	end)
	Effects.cheer(3)
	Effects.lane("A", false)
	Effects.lane("B", false)

	local mySide = if match.A.UserId == player.UserId then "A" elseif match.B.UserId == player.UserId then "B" else nil
	if mySide then
		local change = if mySide == "A" then message.ChangeA else message.ChangeB
		local won = message.Winner == mySide
		local themeScore = if mySide == "A" then message.ThemeA else message.ThemeB
		Sounds.play(if won then "MatchWin" else "Deny")
		Corner.toast(
			if won then "You won the matchup!" else "So close!",
			`Style Score {if change >= 0 then "+" else ""}{change} · Theme score {themeScore}/100`,
			if won then C.Green else C.Violet,
			6
		)
	elseif myVote and myVote == message.Winner then
		Corner.toast("Good taste!", "You picked the winner.", C.Gold, 3)
	end
end

local function onYouWalk(message)
	setControls(false)
	Hud.setMenuVisible(false)
	if message.Step == "Walk" and message.Target then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:MoveTo(message.Target.Position)
		end
	end
end

local function onYouDone()
	setControls(true)
	Hud.setMenuVisible(true)
end

local function onCrown(message)
	current = nil
	panel.Visible = false
	versus.Visible = false
	judgeCard.Visible = false
	local first = message.First
	crownName.Text = if first then `👑 {first.Name}` else "👑"
	local names = {}
	if message.Second then
		table.insert(names, `2nd {message.Second.Name}`)
	end
	for _, third in message.Third or {} do
		table.insert(names, `3rd {third.Name}`)
	end
	crownSub.Text = table.concat(names, "   ·   ")
	crownBanner.Visible = true
	Ui.pop(crownBanner)
	local podium = Layout.Cameras.Podium
	if not freeLook then
		Camera.fixed("Crown", Camera.Priority.Crown, podium.From, podium.At, 0.05, 55)
	end
	Sounds.play("Crown")
	task.delay(0.3, function()
		Sounds.play("Cheer")
	end)
	Effects.cheer(8)
	for index = 0, 2 do
		task.delay(index * 0.9, function()
			Effects.confetti(Vector3.new(0, 18, -95))
		end)
	end
	Effects.paparazzi(6, 0.15)
end

local function onResults(message)
	local place = message.Place
	local text = if place == 1
		then "You won the crown! 👑"
		elseif place == 2 then "Runner-up! Amazing!"
		elseif place == 3 then "Third place! Great show!"
		else "Thanks for walking! Try again next round."
	Corner.toast(`You placed #{place}`, text, if place == 1 then C.Gold else C.Pink, 7)
end

local function clearShow()
	current = nil
	panel.Visible = false
	versus.Visible = false
	crownBanner.Visible = false
	judgeCard.Visible = false
	bracketCard.Visible = false
	Camera.clear("Show")
	Camera.clear("Crown")
	Effects.lane("A", false)
	Effects.lane("B", false)
	setControls(true)
	Hud.setMenuVisible(true)
end

local function build()
	gui = Ui.screen("Show", 4)

	versus = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(460, 74),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, gui)
	Ui.corner(versus, 16)
	Ui.stroke(versus, C.Gold, 2)
	Ui.autoscale(versus)
	roundLabel = Ui.label(versus, {
		Font = Ui.Fonts.Title,
		TextSize = 14,
		TextColor3 = C.Gold,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 16),
	})
	nameA = Ui.label(versus, {
		Font = Ui.Fonts.Title,
		TextSize = 22,
		TextColor3 = C.Pink,
		Position = UDim2.fromOffset(10, 20),
		Size = UDim2.new(0.5, -40, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	nameB = Ui.label(versus, {
		Font = Ui.Fonts.Title,
		TextSize = 22,
		TextColor3 = C.Aqua,
		Position = UDim2.new(0.5, 30, 0, 20),
		Size = UDim2.new(0.5, -40, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Ui.label(versus, {
		Text = "VS",
		Font = Ui.Fonts.Title,
		TextSize = 24,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.fromOffset(50, 28),
	})
	rankA = Ui.label(versus, {
		TextSize = 12,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(10, 48),
		Size = UDim2.new(0.5, -40, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	rankB = Ui.label(versus, {
		TextSize = 12,
		TextColor3 = C.Muted,
		Position = UDim2.new(0.5, 30, 0, 48),
		Size = UDim2.new(0.5, -40, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	panel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(460, 120),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, gui)
	Ui.corner(panel, 16)
	Ui.stroke(panel, C.Pink, 2)
	Ui.autoscale(panel)
	status = Ui.label(panel, {
		TextSize = 14,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -110, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	freeButton = Ui.button(panel, "Free look", C.Panel3, function()
		freeLook = not freeLook
		freeButton.Text = if freeLook then "Show cam" else "Free look"
		if freeLook then
			Camera.clear("Show")
			Camera.clear("Crown")
		else
			showCamera("Runway")
		end
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 5),
		Size = UDim2.fromOffset(90, 24),
		TextSize = 12,
	})
	local track = make("Frame", {
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = C.Panel3,
	}, panel)
	Ui.corner(track, 3)
	timerFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Gold }, track)
	Ui.corner(timerFill, 3)
	buttonA = Ui.button(panel, "", C.Pink, function()
		vote("A")
	end, {
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(0.5, -18, 0, 64),
		TextSize = 20,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	buttonB = Ui.button(panel, "", C.Aqua, function()
		vote("B")
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 44),
		Size = UDim2.new(0.5, -18, 0, 64),
		TextSize = 20,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	resultFrame = make("Frame", {
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 74),
		BackgroundTransparency = 1,
		Visible = false,
	}, panel)
	resultTitle = Ui.label(resultFrame, {
		Font = Ui.Fonts.Title,
		TextSize = 24,
		Size = UDim2.new(1, 0, 0, 28),
	})
	local bar = make("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = C.Aqua,
	}, resultFrame)
	Ui.corner(bar, 7)
	resultBarA = make("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C.Pink }, bar)
	Ui.corner(resultBarA, 7)
	resultCounts = Ui.label(resultFrame, {
		TextSize = 12,
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 14),
	})
	resultHow = Ui.label(resultFrame, {
		TextSize = 11,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 14),
	})

	crownBanner = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(480, 110),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.08,
		Visible = false,
	}, gui)
	Ui.corner(crownBanner, 20)
	Ui.stroke(crownBanner, C.Gold, 3)
	Ui.label(crownBanner, {
		Text = "TONIGHT'S STAR",
		Font = Ui.Fonts.Title,
		TextSize = 16,
		TextColor3 = C.Gold,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 20),
	})
	crownName = Ui.label(crownBanner, {
		Font = Ui.Fonts.Title,
		TextSize = 38,
		Position = UDim2.fromOffset(10, 26),
		Size = UDim2.new(1, -20, 0, 46),
		TextScaled = true,
	})
	make("UIStroke", { Color = C.Pink, Thickness = 2 }, crownName)
	crownSub = Ui.label(crownBanner, {
		TextSize = 14,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(10, 78),
		Size = UDim2.new(1, -20, 0, 22),
	})

	bracketCard = Corner.card(Corner.Order.Bracket, C.Violet)
	bracketLines = { Corner.title(bracketCard, { TextColor3 = C.Violet }) }
	for _ = 1, 8 do
		table.insert(bracketLines, Corner.line(bracketCard, { Visible = false }))
	end
	judgeCard = Corner.card(Corner.Order.Result, C.Gold)
	judgeName = Corner.title(judgeCard, { TextColor3 = C.Gold })
	judgeLine = Corner.line(judgeCard)
end

function Show.mount()
	build()
	Remotes.Show.OnClientEvent:Connect(function(message)
		if type(message) ~= "table" then
			return
		end
		local kind = message.Type
		if kind == "Bracket" then
			onBracket(message)
		elseif kind == "Match" then
			onMatch(message)
		elseif kind == "VoteCount" then
			onVoteCount(message)
		elseif kind == "Result" then
			onResult(message)
		elseif kind == "YouWalk" then
			onYouWalk(message)
		elseif kind == "YouDone" then
			onYouDone()
		elseif kind == "Crown" then
			onCrown(message)
		elseif kind == "Results" then
			onResults(message)
		end
	end)
	State.onRound(function(name)
		if name ~= "Phase" then
			return
		end
		local phase = State.phase()
		if phase ~= "Showtime" and phase ~= "Crowning" then
			clearShow()
		elseif phase == "Showtime" then
			Camera.clear("Crown")
		end
	end)
	RunService.RenderStepped:Connect(function()
		local match = current
		if match and panel.Visible then
			local now = State.now()
			local span = math.max(match.ClosesAt - match.WalkAt, 1)
			local left = math.clamp((match.ClosesAt - now) / span, 0, 1)
			timerFill.Size = UDim2.fromScale(left, 1)
		end
	end)
end

return Show
