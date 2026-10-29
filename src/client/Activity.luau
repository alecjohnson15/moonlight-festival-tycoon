-- Ghost Catcher on this client (Config/Activity): the wisps of a round the
-- server started for this player, a timer and a count in the corner of the
-- screen while it runs, a burst and "+N" for every catch, and how the round
-- went at the end. It also writes
-- on every booth's Status board whether its next round is ready. The server
-- places the wisps and decides every catch; this only draws them.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Activity)
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Format)
local Corner = require(script.Parent.Corner)
local Sounds = require(script.Parent.Sounds)

local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Activity") :: RemoteEvent

local TEXT = Color3.fromRGB(255, 244, 214)
local GAIN = Color3.fromRGB(150, 255, 140)
local GOLD = Color3.fromRGB(255, 205, 90)
local FONT = Enum.Font.FredokaOne
local Strings = Theme.Strings
local GLOW = Theme.Activity.Color
-- How long a wisp takes to pop in and to shrink away.
local POP_SECONDS = 0.3
local RESULT_SECONDS = 4.5
local BOARD_STEP = 0.25

type Shown = { Model: Model, At: number, Base: CFrame, State: "Waiting" | "Out" | "Gone", Scale: number }

local Activity = {}

local player = Players.LocalPlayer
local round: { StartedAt: number, Wisps: { Shown }, Count: number, Total: number }? = nil
local resultUntil = 0

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local text = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = TEXT,
	}, parent)
	for key, value in props do
		(text :: any)[key] = value
	end
	return text
end

-- The card in the corner (client/Corner) while a round runs: how many are
-- caught so far, and the seconds left.
local panel = Corner.card(Corner.Order.Activity, GLOW)
Corner.title(panel, { TextColor3 = GLOW, Text = Strings.ActivityPlaying })
local row = Corner.row(panel, 18)
local countLabel = label(row, {
	Size = UDim2.fromScale(0.7, 1),
	Font = Enum.Font.GothamBold,
	TextScaled = false,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local timerLabel = label(row, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromScale(0.3, 1),
	TextScaled = false,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = GOLD,
})

-- How the round went, in the same place.
local result = Corner.card(Corner.Order.Activity, GLOW)
local resultTitle = Corner.title(result)
local resultEarned = Corner.line(result, { TextColor3 = GAIN, TextSize = 15 })
local resultBest = Corner.line(result, { TextColor3 = GOLD })

local function myPlot(): BasePart?
	local plots = Workspace:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			if plot:IsA("BasePart") and plot:GetAttribute("OwnerUserId") == player.UserId then
				return plot
			end
		end
	end
	return nil
end

local function clearRound()
	if round then
		for _, shown in round.Wisps do
			shown.Model:Destroy()
		end
	end
	round = nil
	panel.Visible = false
end

local function showCount()
	if round then
		countLabel.Text = Strings.ActivityCount:format(round.Count, round.Total)
	end
end

-- A burst of sparkles and "+N" rising where a wisp was caught.
local function burst(at: Vector3, reward: number)
	local spot = make("Part", {
		Name = "CatchBurst",
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(at),
	}, Workspace)
	local sparkles = make("ParticleEmitter", {
		Rate = 0,
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.5, 0),
		Color = ColorSequence.new(GLOW),
		LightEmission = 1,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
	}, spot)
	sparkles:Emit(24)
	local billboard = make("BillboardGui", {
		Size = UDim2.fromOffset(140, 40),
		StudsOffset = Vector3.new(0, 1.5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
	}, spot)
	local text = label(billboard, {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = GAIN,
		TextStrokeTransparency = 0.2,
		Text = `+{Format.whole(reward)}`,
	})
	local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, 4.5, 0) }):Play()
	TweenService:Create(text, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(spot, 1.2)
end

local function onStart(message)
	clearRound()
	local plot = myPlot()
	if not plot or type(message.Wisps) ~= "table" then
		return
	end
	local shown = {}
	for _, wisp in message.Wisps do
		table.insert(shown, {
			Model = Theme.Activity.wisp(),
			At = message.StartedAt + wisp.At,
			Base = plot.CFrame * CFrame.new(wisp.X, plot.Size.Y / 2 + Config.Height, wisp.Z),
			State = "Waiting",
			Scale = 1,
		})
	end
	round = { StartedAt = message.StartedAt, Wisps = shown, Count = 0, Total = #shown }
	resultUntil = 0
	result.Visible = false
	Corner.pop(panel)
	showCount()
	Sounds.play("RoundStart")
end

local function onCaught(message)
	local current = round
	if not current then
		return
	end
	local shown = current.Wisps[message.Index]
	if shown and shown.State ~= "Gone" then
		burst(shown.Model:GetPivot().Position, message.Reward or 0)
		shown.Model:Destroy()
		shown.State = "Gone"
	end
	current.Count += 1
	showCount()
	Sounds.play("Catch")
end

local function onEnd(message)
	clearRound()
	resultTitle.Text = if message.Perfect
		then Strings.ActivityPerfect
		else Strings.ActivityResult:format(message.Caught or 0, message.Total or 0)
	resultTitle.TextColor3 = if message.Perfect then GOLD else TEXT
	resultEarned.Text = Strings.ActivityEarned:format(Format.whole(message.Earned or 0))
	resultBest.Text = Strings.ActivityBest:format(message.Best or 0)
	Corner.pop(result)
	resultUntil = os.clock() + RESULT_SECONDS
	Sounds.play("RoundEnd")
end

-- Pops wisps in when their time comes, bobs and turns them while they wait,
-- and shrinks them away when their time is up.
local function drawWisps(now: number)
	local current = round
	if not current then
		return
	end
	for index, shown in current.Wisps do
		local age = now - shown.At
		if shown.State == "Waiting" and age >= 0 then
			shown.State = "Out"
			shown.Model.Parent = Workspace
		end
		if shown.State == "Out" then
			local left = Config.WispSeconds - age
			if left <= 0 then
				shown.Model:Destroy()
				shown.State = "Gone"
			else
				local scale = math.clamp(math.min(age, left) / POP_SECONDS, 0.05, 1)
				if scale ~= shown.Scale then
					shown.Model:ScaleTo(scale)
					shown.Scale = scale
				end
				local bob = math.sin(now * 3 + index) * 0.4
				shown.Model:PivotTo(shown.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, now * 1.5 + index, 0))
			end
		end
	end
	timerLabel.Text = `{math.max(0, math.ceil(current.StartedAt + Config.RoundSeconds - now))}`
end

-- Writes on each booth's Status board whether its next round is ready.
local function writeBoards(now: number)
	for _, booth in CollectionService:GetTagged("ActivityBooth") do
		local board = booth:FindFirstChild("Status", true)
		local surface = board and board:FindFirstChildWhichIsA("SurfaceGui")
		local text = surface and surface:FindFirstChildWhichIsA("TextLabel")
		if text then
			local readyAt = booth:GetAttribute("ReadyAt") or 0
			local wanted = if booth:GetAttribute("Playing")
				then Strings.ActivityPlaying
				elseif now < readyAt then Strings.ActivityWait:format(math.ceil(readyAt - now))
				else Strings.ActivityReady
			if text.Text ~= wanted then
				text.Text = wanted
			end
		end
	end
end

local sinceBoards = BOARD_STEP
local function onRenderStep(dt: number)
	local now = Workspace:GetServerTimeNow()
	drawWisps(now)
	sinceBoards += dt
	if sinceBoards >= BOARD_STEP then
		sinceBoards = 0
		writeBoards(now)
	end
	if result.Visible and os.clock() > resultUntil then
		result.Visible = false
	end
end

function Activity.start()
	Remote.OnClientEvent:Connect(function(message)
		if type(message) ~= "table" then
			return
		elseif message.Kind == "Start" then
			onStart(message)
		elseif message.Kind == "Caught" then
			onCaught(message)
		elseif message.Kind == "End" then
			onEnd(message)
		end
	end)
	RunService.RenderStepped:Connect(onRenderStep)
end

return Activity
