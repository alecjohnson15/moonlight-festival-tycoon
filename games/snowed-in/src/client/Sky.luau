-- The weather and the light: the sun crossing the sky through each day and
-- the moon through each night (shared/Cycle.clock), the blizzard's fog
-- closing in at night and pulling back as the hearth is built up, snow
-- falling around the camera, an aurora over the mountains at night, the
-- hearth's fire growing and shrinking with its flame and a ring on the
-- snow showing how far its warmth reaches, lanterns and windows that
-- flicker, the radio beacon blinking once the train is called, and the
-- rescue train itself pulling into the station at the end.
--
-- All of it is drawn on each client from the State attributes; the server
-- never moves the sun.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Map = require(Shared.Config.Map)
local Cycle = require(Shared.Cycle)
local Landmarks = require(Shared.World.Landmarks)

local State = ReplicatedStorage:WaitForChild("State") :: Configuration

local Sky = {}

local HEARTH = Vector3.new(Map.Hearth[1], 0, Map.Hearth[2])

local snow: Part
local snowEmitter: ParticleEmitter
local aurora: Part
local auroraBeams: { Beam } = {}
local warmRing: Part
local train: Model? = nil
local trainState = ""
local flickers: { [Light]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function progress(): (string, number)
	local phase = State:GetAttribute("Phase") or "Waiting"
	local night = State:GetAttribute("Night") or 0
	local ends = State:GetAttribute("PhaseEnds") or 0
	local length = Cycle.length(phase, night)
	if ends <= 0 or length == math.huge then
		return phase, 0
	end
	return phase, math.clamp(1 - (ends - now()) / length, 0, 1)
end

local function makeSnow()
	snow = Instance.new("Part")
	snow.Name = "Snowfall"
	snow.Anchored = true
	snow.CanCollide = false
	snow.CanQuery = false
	snow.CanTouch = false
	snow.Transparency = 1
	snow.Size = Vector3.new(160, 1, 160)
	snow.Parent = Workspace
	snowEmitter = Instance.new("ParticleEmitter")
	snowEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snowEmitter.Color = ColorSequence.new(Color3.fromRGB(245, 250, 255))
	snowEmitter.LightEmission = 0.3
	snowEmitter.Size = NumberSequence.new(0.35)
	snowEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.1),
		NumberSequenceKeypoint.new(0.9, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	snowEmitter.Lifetime = NumberRange.new(4, 6)
	snowEmitter.Speed = NumberRange.new(8, 12)
	snowEmitter.EmissionDirection = Enum.NormalId.Bottom
	snowEmitter.SpreadAngle = Vector2.new(25, 25)
	snowEmitter.Acceleration = Vector3.new(6, 0, 2)
	snowEmitter.Rate = 220
	snowEmitter.RotSpeed = NumberRange.new(-90, 90)
	snowEmitter.Parent = snow
end

local function makeAurora()
	aurora = Instance.new("Part")
	aurora.Name = "Aurora"
	aurora.Anchored = true
	aurora.CanCollide = false
	aurora.CanQuery = false
	aurora.CanTouch = false
	aurora.Transparency = 1
	aurora.Size = Vector3.one
	aurora.Position = Vector3.new(0, 240, -420)
	aurora.Parent = Workspace
	local colors = {
		{ Color3.fromRGB(80, 255, 170), Color3.fromRGB(120, 140, 255) },
		{ Color3.fromRGB(120, 255, 200), Color3.fromRGB(200, 120, 255) },
		{ Color3.fromRGB(90, 220, 255), Color3.fromRGB(110, 255, 160) },
	}
	for index, pair in colors do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-420 + index * 40, (index - 2) * 30, index * 25)
		a0.Parent = aurora
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(420 - index * 40, (2 - index) * 25, -index * 20)
		a1.Parent = aurora
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 90
		beam.Width1 = 70
		beam.CurveSize0 = 160 * (if index % 2 == 0 then 1 else -1)
		beam.CurveSize1 = -140 * (if index % 2 == 0 then 1 else -1)
		beam.Segments = 40
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(pair[1], pair[2])
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.75),
			NumberSequenceKeypoint.new(0.7, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Enabled = false
		beam.Parent = aurora
		table.insert(auroraBeams, beam)
	end
end

local function makeWarmRing()
	warmRing = Instance.new("Part")
	warmRing.Name = "WarmRing"
	warmRing.Anchored = true
	warmRing.CanCollide = false
	warmRing.CanQuery = false
	warmRing.CanTouch = false
	warmRing.Shape = Enum.PartType.Cylinder
	warmRing.Material = Enum.Material.Neon
	warmRing.Color = Color3.fromRGB(255, 170, 80)
	warmRing.Transparency = 0.88
	warmRing.CastShadow = false
	warmRing.Size = Vector3.new(0.15, 60, 60)
	warmRing.CFrame = CFrame.new(HEARTH.X, 0.12, HEARTH.Z) * CFrame.Angles(0, 0, math.pi / 2)
	warmRing.Parent = Workspace
end

-- The town's parts this draws on, found once (the town is built before
-- any player joins and never rebuilt).
local found: { [string]: Instance } = {}
local flameParts: { BasePart } = {}

local function find(name: string): Instance?
	local existing = found[name]
	if existing and existing.Parent then
		return existing
	end
	local town = Workspace:FindFirstChild("Town")
	local instance = town and town:FindFirstChild(name, true)
	if instance then
		found[name] = instance
		if name == "Hearth" then
			table.clear(flameParts)
			for _, part in instance:GetDescendants() do
				if part.Name == "Flame" and part:IsA("BasePart") then
					table.insert(flameParts, part)
				end
			end
		end
	end
	return instance
end

local function hearth(): Model?
	return find("Hearth") :: Model?
end

local function updateHearth(dt: number)
	local model = hearth()
	local flame = State:GetAttribute("Flame") or 0
	local max = State:GetAttribute("MaxFlame") or 100
	local fraction = math.clamp(flame / max, 0, 1)
	local radius = State:GetAttribute("HearthRadius") or 30
	if model then
		local fire = model:FindFirstChildWhichIsA("Fire", true)
		if fire then
			fire.Enabled = flame > 0
			fire.Size = lerp(fire.Size, 4 + fraction * 14, math.min(1, dt * 2))
			fire.Heat = 6 + fraction * 14
		end
		local glow = model:FindFirstChildWhichIsA("PointLight", true)
		if glow then
			glow.Range = math.min(60, radius * 1.2)
			-- The glow flickers (updateFlicker) around a brightness that
			-- follows the flame.
			flickers[glow] = 1 + fraction * 2.5
		end
		for _, part in flameParts do
			part.Transparency = if flame > 0 then 0.1 + (1 - fraction) * 0.5 else 1
		end
	end
	local size = radius * 2
	warmRing.Size = Vector3.new(
		0.15,
		lerp(warmRing.Size.Y, size, math.min(1, dt * 3)),
		lerp(warmRing.Size.Z, size, math.min(1, dt * 3))
	)
	warmRing.Transparency = if flame > 0 then 0.86 + math.sin(os.clock() * 2) * 0.03 else 1
end

local function updateBeacon()
	local beacon = find("Beacon")
	if not beacon or not beacon:IsA("BasePart") then
		return
	end
	local called = State:GetAttribute("Called") == true
	local fitted = State:GetAttribute("Parts") or 0
	if called then
		beacon.Material = Enum.Material.Neon
		beacon.Color = if os.clock() % 1 < 0.5 then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(120, 20, 20)
	elseif fitted > 0 then
		beacon.Material = Enum.Material.Neon
		beacon.Color = Color3.fromRGB(255, 200, 80):Lerp(Color3.fromRGB(90, 60, 30), 1 - fitted / #Map.Landmarks)
	else
		beacon.Material = Enum.Material.SmoothPlastic
		beacon.Color = Color3.fromRGB(90, 60, 50)
	end
end

local function updateTrain()
	local phase = State:GetAttribute("Phase")
	local stopX = Map.Station[1] + 14
	local y = 3
	if phase == "Rescue" and trainState ~= "Arriving" then
		trainState = "Arriving"
		if train then
			train:Destroy()
		end
		local model = Landmarks.train(Workspace)
		model:PivotTo(CFrame.new(stopX + 420, y, Map.TrackZ))
		train = model
		local value = Instance.new("NumberValue")
		value.Value = stopX + 420
		value.Changed:Connect(function(x)
			if model.Parent then
				model:PivotTo(CFrame.new(x, y, Map.TrackZ))
			end
		end)
		TweenService:Create(value, TweenInfo.new(9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = stopX })
			:Play()
	elseif phase == "Won" and trainState == "Arriving" and train then
		trainState = "Leaving"
		local model = train
		local value = Instance.new("NumberValue")
		value.Value = stopX
		value.Changed:Connect(function(x)
			if model.Parent then
				model:PivotTo(CFrame.new(x, y, Map.TrackZ))
			end
		end)
		task.delay(Balance.Phases.Results * 0.5, function()
			TweenService
				:Create(
					value,
					TweenInfo.new(9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Value = stopX - 460 }
				)
				:Play()
		end)
	elseif phase == "Intermission" or phase == "Lost" or phase == "Day" then
		if train then
			train:Destroy()
			train = nil
		end
		trainState = ""
	end
end

local function updateSky(dt: number)
	local phase, t = progress()
	local level = State:GetAttribute("HearthLevel") or 1
	local levels = Balance.Hearth.Levels
	local config = levels[math.clamp(level, 1, #levels)]
	local clock = Cycle.clock(phase :: any, t)
	-- Ease the clock, wrapping round midnight.
	local current = Lighting.ClockTime
	local difference = (clock - current + 12) % 24 - 12
	Lighting.ClockTime = (current + difference * math.min(1, dt * 2)) % 24

	local dark = phase == "Night" or phase == "Lost"
	local dusk = phase == "Dusk"
	local fog = if dark then config.FogNight elseif dusk then lerp(config.FogDay, config.FogNight, t) else config.FogDay
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = lerp(atmosphere.Density, fog, math.min(1, dt))
		atmosphere.Color = if dark then Color3.fromRGB(60, 80, 120) else Color3.fromRGB(200, 215, 235)
		atmosphere.Decay = if dark then Color3.fromRGB(40, 50, 90) else Color3.fromRGB(150, 170, 200)
	end
	local nightness = if dark then 1 elseif dusk then t elseif phase == "Dawn" then 1 - t else 0
	Lighting.Brightness = lerp(2.2, 0.6, nightness)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 180):Lerp(Color3.fromRGB(70, 85, 130), nightness)
	Lighting.Ambient = Color3.fromRGB(110, 115, 130):Lerp(Color3.fromRGB(55, 65, 100), nightness)
	local grade = Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect?
	if grade then
		grade.TintColor = Color3.fromRGB(255, 252, 248):Lerp(Color3.fromRGB(200, 215, 255), nightness)
		grade.Saturation = if phase == "Lost" then -0.5 else lerp(0.1, -0.05, nightness)
	end
	for _, beam in auroraBeams do
		beam.Enabled = nightness > 0.3
	end
	snowEmitter.Rate = lerp(160, 360, nightness)
	local camera = Workspace.CurrentCamera
	if camera then
		local eye = camera.CFrame.Position
		snow.Position = Vector3.new(eye.X, math.max(eye.Y, 0) + 45, eye.Z)
	end
end

local function updateFlicker()
	local time = os.clock()
	for light, base in flickers do
		if light.Parent then
			light.Brightness = base * (0.85 + math.noise(time * 3, base * 10) * 0.3)
		else
			flickers[light] = nil
		end
	end
end

local function watchFlicker(instance: Instance)
	if instance:IsA("Light") then
		flickers[instance] = instance.Brightness
	end
end

function Sky.start()
	makeSnow()
	makeAurora()
	makeWarmRing()
	for _, light in CollectionService:GetTagged("Flicker") do
		watchFlicker(light)
	end
	CollectionService:GetInstanceAddedSignal("Flicker"):Connect(watchFlicker)
	State:GetAttributeChangedSignal("Phase"):Connect(updateTrain)
	updateTrain()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		updateSky(dt)
		updateHearth(dt)
		elapsed += dt
		if elapsed > 0.1 then
			elapsed = 0
			updateFlicker()
			updateBeacon()
		end
	end)
end

return Sky
