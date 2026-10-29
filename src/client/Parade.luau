-- The Moonlight Parade on this client (Config/Parade): the floats and
-- marching ghosts going round the Moonlight Wheel, the lanterns they let go,
-- a burst and "+N" for every lantern this player catches, confetti and a
-- cheer when the server's meter fills, and how the parade went at the end. It
-- also writes on the courtyard's sign when the next parade starts. The goal
-- card (Guide) shows the meter while it's on. The server picks where the
-- lanterns go and decides every catch; this only draws them.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Parade)
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Format)
local Parade = require(Shared.Parade)
local Corner = require(script.Parent.Corner)
local Sounds = require(script.Parent.Sounds)

local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Parade") :: RemoteEvent

local TEXT = Color3.fromRGB(255, 244, 214)
local GAIN = Color3.fromRGB(150, 255, 140)
local GOLD = Color3.fromRGB(255, 205, 90)
local FONT = Enum.Font.FredokaOne
local Strings = Theme.Strings
local Look = Theme.Parade
-- Ghosts marching in each gap between two floats.
local MARCHERS_PER_GAP = 2
local POP_SECONDS = 0.35
local CARD_SECONDS = 4.5
local SIGN_STEP = 0.25

type Shown = { Model: Model?, At: number, Base: CFrame, State: "Waiting" | "Out" | "Gone", Scale: number }

type Running = {
	StartedAt: number,
	Centre: CFrame,
	Route: Parade.Route,
	Floats: { Model },
	Marchers: { Model },
	Lanterns: { Shown },
}

local ParadeClient = {}

local player = Players.LocalPlayer
local running: Running? = nil
local cardUntil = 0

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

-- A card in the corner (client/Corner) when the meter fills, and with how
-- the parade went.
local card = Corner.card(Corner.Order.Parade, Look.LanternColor)
local cardTitle = Corner.title(card)
local cardLine = Corner.line(card)
local cardLast = Corner.line(card, { Font = FONT, TextSize = 15 })

local function showCard(title: string, line: string, last: string, color: Color3, lastColor: Color3)
	cardTitle.Text = title
	cardTitle.TextColor3 = color
	Corner.set(cardLine, line)
	Corner.set(cardLast, last)
	cardLast.TextColor3 = lastColor
	Corner.pop(card)
	cardUntil = os.clock() + CARD_SECONDS
end

-- The loop the server published, if there is one.
local function route(): (CFrame?, Parade.Route)
	local centre = Workspace:GetAttribute("ParadeCentre")
	local loop = {
		RadiusX = Workspace:GetAttribute("ParadeRadiusX") or 20,
		RadiusZ = Workspace:GetAttribute("ParadeRadiusZ") or 20,
	}
	return if typeof(centre) == "CFrame" then centre else nil, loop
end

-- Where on the loop angle is, and the way along it.
local function onLoop(current: Running, angle: number, offset: number, y: number): CFrame
	local x, height, z = Parade.point(current.Route, angle, offset, y)
	local at = current.Centre * Vector3.new(x, height, z)
	local along = current.Centre:VectorToWorldSpace(
		Vector3.new(-math.sin(angle) * current.Route.RadiusX, 0, math.cos(angle) * current.Route.RadiusZ)
	)
	return CFrame.lookAt(at, at + along.Unit)
end

local function clear()
	local current = running
	running = nil
	Sounds.stopLoop("ParadeMarch")
	if not current then
		return
	end
	for _, model in current.Floats do
		model:Destroy()
	end
	for _, model in current.Marchers do
		model:Destroy()
	end
	for _, shown in current.Lanterns do
		if shown.Model then
			shown.Model:Destroy()
		end
	end
end

-- An invisible spot to hang effects on, gone after seconds.
local function spot(at: Vector3, seconds: number): Part
	local part = make("Part", {
		Name = "ParadeEffect",
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(at),
	}, Workspace)
	Debris:AddItem(part, seconds)
	return part
end

-- A burst of sparkles where a lantern was caught, with "+N" rising from it
-- if this player caught it.
local function burst(at: Vector3, reward: number?)
	local part = spot(at, 1.2)
	local sparkles = make("ParticleEmitter", {
		Rate = 0,
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.5, 0),
		Color = ColorSequence.new(Look.LanternColor),
		LightEmission = 1,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
	}, part)
	sparkles:Emit(if reward then 24 else 10)
	if not reward then
		return
	end
	local billboard = make("BillboardGui", {
		Size = UDim2.fromOffset(140, 40),
		StudsOffset = Vector3.new(0, 1.5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
	}, part)
	local text = label(billboard, {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = GAIN,
		TextStrokeTransparency = 0.2,
		Text = `+{Format.whole(reward)}`,
	})
	local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, 4.5, 0) }):Play()
	TweenService:Create(text, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

-- Confetti all round the loop when the meter fills.
local function confetti()
	local centre, loop = route()
	if not centre then
		return
	end
	local count = 8
	for i = 1, count do
		local x, y, z = Parade.point(loop, i / count * math.pi * 2, 0, 9)
		local part = spot(centre * Vector3.new(x, y, z), 4)
		for _, color in Look.Confetti do
			local emitter = make("ParticleEmitter", {
				Rate = 0,
				Lifetime = NumberRange.new(2, 3.5),
				Speed = NumberRange.new(10, 18),
				SpreadAngle = Vector2.new(40, 40),
				EmissionDirection = Enum.NormalId.Top,
				Acceleration = Vector3.new(0, -14, 0),
				Drag = 1.5,
				Size = NumberSequence.new(0.35),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-200, 200),
				Color = ColorSequence.new(color),
				LightEmission = 0.4,
			}, part)
			emitter:Emit(6)
		end
	end
end

local function onStart(message)
	clear()
	local centre, loop = route()
	if not centre or type(message.Lanterns) ~= "table" or type(message.StartedAt) ~= "number" then
		return
	end
	local current: Running = {
		StartedAt = message.StartedAt,
		Centre = centre,
		Route = loop,
		Floats = {},
		Marchers = {},
		Lanterns = {},
	}
	for index = 1, Config.Floats do
		local model = Look.float(index)
		model.Parent = Workspace
		table.insert(current.Floats, model)
		for _ = 1, MARCHERS_PER_GAP do
			local marcher = Look.marcher()
			marcher.Parent = Workspace
			table.insert(current.Marchers, marcher)
		end
	end
	local caught = {}
	if type(message.Caught) == "table" then
		for _, index in message.Caught do
			caught[index] = true
		end
	end
	for index, lantern in message.Lanterns do
		local x, y, z = Parade.point(loop, lantern.Angle, lantern.Offset, Config.Height)
		table.insert(current.Lanterns, {
			Model = nil,
			At = message.StartedAt + lantern.At,
			Base = centre * CFrame.new(x, y, z),
			State = if caught[index] then "Gone" else "Waiting",
			Scale = 1,
		})
	end
	running = current
	card.Visible = false
	Sounds.play("ParadeStart")
	Sounds.startLoop("ParadeMarch")
end

local function onCaught(message)
	local current = running
	local shown = current and current.Lanterns[message.Index]
	if not shown or shown.State == "Gone" then
		return
	end
	local mine = message.UserId == player.UserId
	if shown.Model then
		burst(shown.Model:GetPivot().Position, if mine then message.Reward or 0 else nil)
		shown.Model:Destroy()
		shown.Model = nil
	end
	shown.State = "Gone"
	if mine then
		Sounds.play("ParadeCatch")
	end
end

local function onFilled()
	confetti()
	Sounds.play("ParadeCheer")
	showCard(Strings.ParadeFilled, Strings.ParadeFilledHint, "", GOLD, TEXT)
end

-- How the parade went for this player, if they caught a lantern.
local function onThanks(message)
	local bonus = message.Bonus or 0
	local caught = Strings.ParadeCaught:format(message.Caught or 0)
	if message.Filled and bonus > 0 then
		showCard(Strings.ParadeFilled, caught, Strings.ParadeEarned:format(Format.whole(bonus)), GOLD, GAIN)
	else
		local minutes = math.ceil(Config.IntervalSeconds / 60)
		showCard(Strings.ParadeName, caught, Strings.ParadeOver:format(minutes), TEXT, TEXT)
	end
end

-- Moves the floats and marchers round the loop, pops lanterns in when their
-- time comes, bobs them while they wait and shrinks them away when it's up.
local function draw(now: number)
	local current = running
	if not current then
		return
	end
	local t = now - current.StartedAt
	local gap = math.pi * 2 / Config.Floats
	for index, model in current.Floats do
		local angle = Parade.floatAngle(Config, t, index)
		model:PivotTo(onLoop(current, angle, 0, 0) * CFrame.Angles(0, 0, math.sin(now * 2 + index) * 0.03))
	end
	for index, model in current.Marchers do
		local float = math.ceil(index / MARCHERS_PER_GAP)
		local place = (index - 1) % MARCHERS_PER_GAP + 1
		local angle = Parade.floatAngle(Config, t, float) - gap * place / (MARCHERS_PER_GAP + 1)
		local hop = math.abs(math.sin(now * 5 + index)) * 0.5
		model:PivotTo(onLoop(current, angle, 0, hop))
	end
	for index, shown in current.Lanterns do
		local age = now - shown.At
		if shown.State == "Waiting" and age >= 0 then
			shown.State = "Out"
			local model = Look.lantern()
			model.Parent = Workspace
			shown.Model = model
		end
		local model = shown.Model
		if shown.State == "Out" and model then
			local left = Config.LanternSeconds - age
			if left <= 0 then
				model:Destroy()
				shown.Model = nil
				shown.State = "Gone"
			else
				local scale = math.clamp(math.min(age, left) / POP_SECONDS, 0.05, 1)
				if scale ~= shown.Scale then
					model:ScaleTo(scale)
					shown.Scale = scale
				end
				local bob = math.sin(now * 2.5 + index) * 0.35 + age * 0.08
				model:PivotTo(shown.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, now + index, 0))
			end
		end
	end
end

-- Writes on the courtyard's sign when the next parade starts.
local function writeSign(now: number)
	for _, courtyard in CollectionService:GetTagged("ParadeRoute") do
		local sign = courtyard:FindFirstChild("ParadeSign", true)
		local surface = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
		local text = surface and surface:FindFirstChildWhichIsA("TextLabel")
		if text then
			local wanted = Strings.ParadeSignNow
			if not Workspace:GetAttribute("ParadeLive") then
				local left = math.max(0, math.ceil((Workspace:GetAttribute("ParadeAt") or now) - now))
				wanted = Strings.ParadeSign:format(string.format("%d:%02d", left // 60, left % 60))
			end
			if text.Text ~= wanted then
				text.Text = wanted
			end
		end
	end
end

local sinceSign = SIGN_STEP
local function onRenderStep(dt: number)
	local now = Workspace:GetServerTimeNow()
	draw(now)
	sinceSign += dt
	if sinceSign >= SIGN_STEP then
		sinceSign = 0
		writeSign(now)
	end
	if card.Visible and os.clock() > cardUntil then
		card.Visible = false
	end
end

function ParadeClient.start()
	Remote.OnClientEvent:Connect(function(message)
		if type(message) ~= "table" then
			return
		elseif message.Kind == "Start" then
			onStart(message)
		elseif message.Kind == "Caught" then
			onCaught(message)
		elseif message.Kind == "Filled" then
			onFilled()
		elseif message.Kind == "End" then
			clear()
		elseif message.Kind == "Thanks" then
			onThanks(message)
		end
	end)
	RunService.RenderStepped:Connect(onRenderStep)
	-- Joining while a parade is on: ask for what's out.
	if Workspace:GetAttribute("ParadeLive") then
		Remote:FireServer({ Kind = "Sync" })
	end
end

return ParadeClient
