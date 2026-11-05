-- The show's sparkle, played on each client so it costs the server
-- nothing: runway entrances (Config/Entrances), photographers' flashes,
-- lane lights, cheering fans, confetti for the crowning, and pose previews
-- in the wardrobe. The Effects setting turns the particles down to a
-- minimum for players who want a calmer screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Entrances = require(Config.Entrances)
local Poses = require(Config.Poses)
local Palette = require(Config.Palette)
local Layout = require(Config.Layout)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local Effects = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SQUARE = "rbxasset://textures/particles/explosion01_core_main.dds"

local enabled = true
local fanBoost = 0
local folder: Folder

local function getFolder(): Folder
	if not folder or not folder.Parent then
		folder = Instance.new("Folder")
		folder.Name = "ClientEffects"
		folder.Parent = Workspace
	end
	return folder
end

local function sequence(colors: { string }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(Palette.resolve(colors[1]))
	end
	local keys = {}
	for index, name in colors do
		table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), Palette.resolve(name)))
	end
	return ColorSequence.new(keys)
end

local function attachment(parent: Instance, position: Vector3): Attachment
	local at = Instance.new("Attachment")
	at.Name = "EntranceFx"
	at.Position = position
	at.Parent = parent
	return at
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = SPARKLE
	particles.LightEmission = 0.8
	particles.Rate = 20
	particles.Lifetime = NumberRange.new(0.8, 1.4)
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	for key, value in props do
		(particles :: any)[key] = value
	end
	if not enabled then
		particles.Rate = math.min(particles.Rate, 4)
	end
	particles.Parent = parent
	return particles
end

-- A light flash at a point, with a camera shutter.
function Effects.flash(position: Vector3, color: Color3?)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Position = position
	local light = Instance.new("PointLight")
	light.Color = color or Color3.new(1, 1, 1)
	light.Brightness = 8
	light.Range = 14
	light.Shadows = false
	light.Parent = part
	part.Parent = getFolder()
	TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 0 }):Play()
	task.delay(0.3, function()
		part:Destroy()
	end)
end

-- Photographers' flashes along the runway for a while.
function Effects.paparazzi(seconds: number, rate: number?)
	task.spawn(function()
		local stop = os.clock() + seconds
		while os.clock() < stop do
			local spot = Layout.Flashes[math.random(1, #Layout.Flashes)]
			Effects.flash(spot)
			if math.random() < 0.5 then
				Sounds.play("Shutter", 0.9 + math.random() * 0.3)
			end
			task.wait((rate or 0.35) * (0.6 + math.random() * 0.8))
		end
	end)
end

local STYLES: { [string]: (Model, BasePart, any, number) -> () } = {}

STYLES.Spotlight = function(_model, root, entrance, _seconds)
	local at = attachment(root, Vector3.new(0, 10, 0))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 38
	light.Range = 18
	light.Brightness = 7
	light.Color = Palette.resolve(entrance.Colors[1])
	light.Parent = at
end

STYLES.Trail = function(_model, root, entrance, _seconds)
	local a0 = attachment(root, Vector3.new(0, 0.9, 0.3))
	local a1 = attachment(root, Vector3.new(0, -2.4, 0.3))
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = sequence(entrance.Colors)
	trail.LightEmission = 0.8
	trail.Lifetime = 1.2
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.FaceCamera = true
	trail.Parent = root
	emitter(a1, { Color = sequence(entrance.Colors), Rate = 24, Speed = NumberRange.new(0.2, 1) })
end

STYLES.Confetti = function(_model, root, entrance, _seconds)
	local at = attachment(root, Vector3.new(0, 3, 0))
	local particles = emitter(at, {
		Texture = SQUARE,
		Color = sequence(entrance.Colors),
		Rate = 30,
		Speed = NumberRange.new(4, 8),
		Acceleration = Vector3.new(0, -12, 0),
		Lifetime = NumberRange.new(1.2, 2),
		RotSpeed = NumberRange.new(-200, 200),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 0.3,
		Size = NumberSequence.new(0.25),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(50, 50),
	})
	particles:Emit(if enabled then 60 else 10)
end

STYLES.Shower = function(_model, root, entrance, _seconds)
	local at = attachment(root, Vector3.new(0, 6, 0))
	emitter(at, {
		Color = sequence(entrance.Colors),
		Rate = 26,
		Speed = NumberRange.new(0.5, 1),
		Acceleration = Vector3.new(0, -3, 0),
		Lifetime = NumberRange.new(2, 3),
		RotSpeed = NumberRange.new(-90, 90),
		Size = NumberSequence.new(0.35),
		LightEmission = 0.4,
	})
end

STYLES.Bubbles = function(_model, root, entrance, _seconds)
	local at = attachment(root, Vector3.new(0, -1, 0))
	emitter(at, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = sequence(entrance.Colors),
		Rate = 14,
		Speed = NumberRange.new(1, 2),
		Acceleration = Vector3.new(0, 2, 0),
		Lifetime = NumberRange.new(1.5, 2.5),
		Transparency = NumberSequence.new(0.4),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 0.9),
		}),
	})
end

STYLES.Flashes = function(_model, root, _entrance, seconds)
	task.spawn(function()
		local stop = os.clock() + seconds
		while os.clock() < stop and root.Parent do
			Effects.flash(root.Position + Vector3.new(math.random(-6, 6), math.random(2, 5), math.random(2, 6)))
			Sounds.play("Shutter", 1 + math.random() * 0.2)
			task.wait(0.18 + math.random() * 0.2)
		end
	end)
end

STYLES.Carpet = function(_model, root, entrance, seconds)
	local start = root.Position - Vector3.new(0, 2.9, 0)
	local carpet = Instance.new("Part")
	carpet.Anchored = true
	carpet.CanCollide = false
	carpet.CanQuery = false
	carpet.Material = Enum.Material.Neon
	carpet.Color = Palette.resolve(entrance.Colors[1])
	carpet.Size = Vector3.new(4, 0.1, 0.1)
	carpet.CFrame = CFrame.new(start)
	carpet.Parent = getFolder()
	local edge = carpet:Clone()
	edge.Color = Palette.resolve(entrance.Colors[2] or entrance.Colors[1])
	edge.Size = Vector3.new(4.6, 0.08, 0.1)
	edge.Parent = getFolder()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not root.Parent then
			connection:Disconnect()
			return
		end
		local here = Vector3.new(start.X, start.Y, root.Position.Z + 3)
		local length = math.max((here - start).Magnitude, 0.1)
		local middle = (start + here) / 2
		carpet.Size = Vector3.new(4, 0.1, length)
		carpet.CFrame = CFrame.new(middle + Vector3.new(0, 0.02, 0))
		edge.Size = Vector3.new(4.6, 0.08, length)
		edge.CFrame = CFrame.new(middle)
	end)
	task.delay(seconds + 2, function()
		connection:Disconnect()
		TweenService:Create(carpet, TweenInfo.new(1), { Transparency = 1 }):Play()
		TweenService:Create(edge, TweenInfo.new(1), { Transparency = 1 }):Play()
		task.wait(1.1)
		carpet:Destroy()
		edge:Destroy()
	end)
	emitter(attachment(root, Vector3.new(0, -2.6, 0)), {
		Color = sequence(entrance.Colors),
		Rate = 18,
		Speed = NumberRange.new(0.5, 1.5),
	})
end

STYLES.Fireworks = function(_model, root, entrance, seconds)
	local at = attachment(root, Vector3.new(0, 8, 0))
	local burst = emitter(at, {
		Color = sequence(entrance.Colors),
		Rate = 0,
		Speed = NumberRange.new(10, 16),
		Drag = 4,
		Acceleration = Vector3.new(0, -4, 0),
		Lifetime = NumberRange.new(0.8, 1.4),
		LightEmission = 1,
	})
	task.spawn(function()
		local stop = os.clock() + seconds
		while os.clock() < stop and at.Parent do
			burst:Emit(if enabled then 50 else 8)
			Effects.flash(at.WorldPosition, Palette.resolve(entrance.Colors[math.random(1, #entrance.Colors)]))
			Sounds.play("Whoosh", 1.6)
			task.wait(1.1)
		end
	end)
end

STYLES.Starfall = function(_model, root, entrance, _seconds)
	local at = attachment(root, Vector3.new(0, 9, 0))
	emitter(at, {
		Color = sequence(entrance.Colors),
		Rate = 30,
		Speed = NumberRange.new(6, 9),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(30, 30),
		Lifetime = NumberRange.new(0.8, 1.2),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(1, 0),
		}),
		LightEmission = 1,
	})
end

STYLES.Storm = function(_model, root, entrance, _seconds)
	local at = attachment(root, Vector3.new(0, 1, 0))
	emitter(at, {
		Color = sequence(entrance.Colors),
		Rate = 60,
		Speed = NumberRange.new(2, 5),
		RotSpeed = NumberRange.new(-300, 300),
		Lifetime = NumberRange.new(1, 1.6),
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.55),
			NumberSequenceKeypoint.new(1, 0),
		}),
	})
end

STYLES.Thunder = function(_model, root, entrance, seconds)
	STYLES.Storm(_model, root, { Colors = entrance.Colors }, seconds)
	task.spawn(function()
		local stop = os.clock() + seconds
		while os.clock() < stop and root.Parent do
			Effects.flash(root.Position + Vector3.new(0, 7, 0), Palette.resolve(entrance.Colors[1]))
			task.wait(0.07)
			Effects.flash(root.Position + Vector3.new(0, 7, 0), Palette.resolve(entrance.Colors[1]))
			task.wait(0.9 + math.random() * 0.6)
		end
	end)
end

STYLES.Pulse = function(_model, root, entrance, seconds)
	task.spawn(function()
		local stop = os.clock() + seconds
		local index = 0
		while os.clock() < stop and root.Parent do
			index += 1
			local ring = Instance.new("Part")
			ring.Shape = Enum.PartType.Cylinder
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.Material = Enum.Material.Neon
			ring.Color = Palette.resolve(entrance.Colors[(index - 1) % #entrance.Colors + 1])
			ring.Size = Vector3.new(0.1, 1, 1)
			ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
			ring.Transparency = 0.2
			ring.Parent = getFolder()
			TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
				Size = Vector3.new(0.1, 9, 9),
				Transparency = 1,
			}):Play()
			task.delay(0.85, function()
				ring:Destroy()
			end)
			task.wait(0.45)
		end
	end)
	emitter(attachment(root, Vector3.new(0, 0, 0)), {
		Color = sequence(entrance.Colors),
		Rate = 16,
	})
end

-- Plays an entrance on a walker for seconds.
function Effects.entrance(model: Model, entranceId: string, seconds: number)
	local entrance = Entrances.get(entranceId) or Entrances.get(Entrances.Default)
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not entrance or not root then
		return
	end
	local style = STYLES[entrance.Style] or STYLES.Spotlight
	local ok, err = pcall(style, model, root, entrance, seconds)
	if not ok then
		warn(`Entrance {entranceId} failed: {err}`)
	end
	task.delay(seconds, function()
		for _, child in root:GetChildren() do
			if child.Name == "EntranceFx" then
				for _, inner in child:GetChildren() do
					if inner:IsA("ParticleEmitter") then
						inner.Enabled = false
					elseif inner:IsA("Light") then
						TweenService:Create(inner, TweenInfo.new(0.6), { Brightness = 0 }):Play()
					end
				end
				task.delay(2.5, function()
					child:Destroy()
				end)
			elseif child:IsA("Trail") then
				child.Enabled = false
				task.delay(1.5, function()
					child:Destroy()
				end)
			end
		end
	end)
end

-- Turns the joints for a pose on this client only, for a preview.
function Effects.previewPose(character: Model, poseId: string)
	local pose = Poses.get(poseId)
	if not pose then
		return
	end
	local motors = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
		end
	end
	local restored = {}
	local info = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for name, turn in pose.Joints do
		local motor = motors[name]
		if motor then
			restored[motor] = motor.C0
			local goal = motor.C0 * CFrame.Angles(math.rad(turn[1]), math.rad(turn[2]), math.rad(turn[3]))
			TweenService:Create(motor, info, { C0 = goal }):Play()
		end
	end
	task.delay(2.4, function()
		for motor, c0 in restored do
			TweenService:Create(motor, TweenInfo.new(0.3), { C0 = c0 }):Play()
		end
	end)
end

-- Lights a lane's edges while its walker strides.
function Effects.lane(side: string, on: boolean)
	local hall = Workspace:FindFirstChild("CatwalkClash")
	local runway = hall and hall:FindFirstChild("Runway")
	if not runway then
		return
	end
	for _, strip in runway:GetChildren() do
		if strip:IsA("BasePart") and strip.Name == `Lane{side}` then
			local goal = if on then 0 else 0.55
			TweenService:Create(strip, TweenInfo.new(0.4), { Transparency = goal }):Play()
		end
	end
end

-- Makes the fans go wild for a moment.
function Effects.cheer(seconds: number)
	fanBoost = math.max(fanBoost, os.clock() + seconds)
end

-- A burst of confetti at a point.
function Effects.confetti(position: Vector3, colors: { string }?)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Position = position
	part.Parent = getFolder()
	local particles = emitter(part, {
		Texture = SQUARE,
		Color = sequence(colors or { "Hot Pink", "Gold", "Aqua", "Lime", "Violet" }),
		Rate = 0,
		Speed = NumberRange.new(10, 20),
		Acceleration = Vector3.new(0, -14, 0),
		Drag = 1.5,
		Lifetime = NumberRange.new(2.5, 3.5),
		RotSpeed = NumberRange.new(-200, 200),
		Rotation = NumberRange.new(0, 360),
		Size = NumberSequence.new(0.35),
		LightEmission = 0.3,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(60, 60),
	})
	particles:Emit(if enabled then 160 else 20)
	task.delay(4, function()
		part:Destroy()
	end)
end

type Fan = { Seed: number, Parts: { [BasePart]: CFrame } }

local function animateFans()
	local hall = Workspace:WaitForChild("CatwalkClash", 30)
	local runway = hall and hall:WaitForChild("Runway", 30)
	local fans = runway and runway:WaitForChild("Fans", 30)
	if not fans then
		return
	end
	local list: { Fan } = {}
	for index, fan in fans:GetChildren() do
		local entry: Fan = { Seed = index * 0.7, Parts = {} }
		for _, part in fan:GetChildren() do
			if part:IsA("BasePart") then
				entry.Parts[part] = part.CFrame
			end
		end
		table.insert(list, entry)
	end
	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		local phase = State.phase()
		if phase ~= "Showtime" and phase ~= "Crowning" then
			return
		end
		clock += dt
		local excited = os.clock() < fanBoost
		local speed = if excited then 9 else 3
		for _, fan in list do
			local hop = if excited then math.abs(math.sin(clock * 8 + fan.Seed)) * 0.6 else 0
			local lift = Vector3.new(0, hop, 0)
			for part, cframe in fan.Parts do
				if part.Name == "Glowstick" then
					local offset = part:GetAttribute("Sway") or 0
					local angle = math.sin(clock * speed + offset) * (if excited then 0.6 else 0.3)
					part.CFrame = (cframe + lift)
						* CFrame.new(0, -0.8, 0)
						* CFrame.Angles(0, 0, angle)
						* CFrame.new(0, 0.8, 0)
				else
					part.CFrame = cframe + lift
				end
			end
		end
	end)
end

function Effects.start()
	State.onProfile(function(profile)
		local settings = profile.Settings or {}
		enabled = settings.Effects ~= false
	end)
	task.spawn(animateFans)
end

return Effects
