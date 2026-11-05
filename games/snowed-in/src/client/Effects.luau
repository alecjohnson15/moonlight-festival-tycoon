-- Plays what the server reports (the "Fx" remote) as things to see and
-- hear: wood chips and "+2 Wood" when a pine is chopped, a whoosh as the
-- hearth is fed, sparks off a hit, a puff of snow as a monster is knocked
-- back into the blizzard, a shockwave from a yeti's slam, and the stings
-- for nightfall, dawn, the radio and the train. Everything here is for show:
-- the server already decided what happened.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Map = require(Shared.Config.Map)
local Resources = require(Shared.Config.Resources)
local Weapons = require(Shared.Config.Weapons)
local MonsterView = require(script.Parent.MonsterView)
local Sounds = require(script.Parent.Sounds)
local UI = require(script.Parent.UI)

local State = ReplicatedStorage:WaitForChild("State") :: Configuration

local Effects = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local SNOW_COLOR = Color3.fromRGB(240, 248, 255)
local EMBER_COLOR = Color3.fromRGB(255, 150, 60)
local ICE_COLOR = Color3.fromRGB(150, 220, 255)

local player = Players.LocalPlayer
local HEARTH = Vector3.new(Map.Hearth[1], 0, Map.Hearth[2])
local RADIO = Vector3.new(Map.RadioTower[1], 0, Map.RadioTower[2])

local shake = 0
local bossOut = false

-- A burst of particles at a spot.
function Effects.burst(position: Vector3, color: Color3, count: number, options: { [string]: any }?)
	local opts = options or {}
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = opts.Texture or SMOKE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = opts.Glow or 0.2
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, opts.Size or 1.2),
		NumberSequenceKeypoint.new(1, (opts.Size or 1.2) * 0.2),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.4, opts.Life or 0.9)
	emitter.Speed = NumberRange.new(opts.Speed or 8, (opts.Speed or 8) * 1.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, opts.Gravity or -20, 0)
	emitter.Drag = 2
	emitter.Rate = 0
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Parent = holder
	emitter:Emit(count)
	task.delay((opts.Life or 0.9) + 0.6, function()
		holder:Destroy()
	end)
end

-- Words that float up from a spot and fade, such as "+2 Wood".
function Effects.float(position: Vector3, text: string, color: Color3?)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position + Vector3.new(0, 4, 0)
	holder.Parent = Workspace
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(140, 36)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Parent = holder
	local label = UI.label(board, text, {
		Size = UDim2.fromScale(1, 1),
		Font = UI.Title,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color or UI.Colors.Text,
		TextStrokeTransparency = 0.3,
	})
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(holder, info, { Position = holder.Position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.3, function()
		holder:Destroy()
	end)
end

-- A ring that spreads across the snow: slams, cocoa, heat packs.
function Effects.ring(position: Vector3, radius: number, color: Color3, seconds: number?)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position.X, 0.3, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = Workspace
	local info = TweenInfo.new(seconds or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
	task.delay((seconds or 0.6) + 0.1, function()
		ring:Destroy()
	end)
end

-- A glowing ball that flies from one spot to another, then bursts.
function Effects.bolt(from: Vector3, to: Vector3, color: Color3, size: number?, seconds: number?, onArrive: (() -> ())?)
	local ball = Instance.new("Part")
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Size = Vector3.one * (size or 1)
	ball.Position = from
	ball.Parent = Workspace
	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, (size or 1) * 0.3, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -(size or 1) * 0.3, 0)
	a1.Parent = ball
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Lifetime = 0.2
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = ball
	local distance = (to - from).Magnitude
	local time = seconds or math.clamp(distance / 120, 0.08, 0.5)
	local tween = TweenService:Create(ball, TweenInfo.new(time, Enum.EasingStyle.Linear), { Position = to })
	tween.Completed:Connect(function()
		ball:Destroy()
		if onArrive then
			onArrive()
		end
	end)
	tween:Play()
end

-- Shakes the camera a little (more when bigger).
function Effects.shake(amount: number)
	shake = math.max(shake, amount)
end

local function playerRoot(userId: number): BasePart?
	local other = Players:GetPlayerByUserId(userId)
	local character = other and other.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function ground(x: number, z: number, y: number?): Vector3
	return Vector3.new(x, y or 2, z)
end

-- A weapon going off, drawn the moment the player fires (and for other
-- players when the server reports it).
function Effects.shot(weaponId: string, from: Vector3, to: Vector3)
	local weapon = Weapons.ById[weaponId]
	if not weapon then
		return
	end
	local color = Color3.fromHex(weapon.Color)
	Sounds.at(weapon.Sound, from, 140)
	local start = from + Vector3.new(0, 1.2, 0)
	local finish = Vector3.new(to.X, 2, to.Z)
	if weapon.Kind == "Melee" then
		local look = (finish - start) * Vector3.new(1, 0, 1)
		local direction = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
		Effects.burst(
			start + direction * 4,
			EMBER_COLOR,
			10,
			{ Texture = FIRE, Size = 1.4, Speed = 6, Gravity = 4, Glow = 1 }
		)
	elseif weapon.Kind == "Shot" then
		Effects.bolt(start, finish, color, 0.8)
	elseif weapon.Kind == "Blast" then
		Effects.bolt(start, finish, color, if weaponId == "SunstoneCannon" then 2.2 else 1.2, nil, function()
			Effects.burst(finish, color, 24, { Texture = FIRE, Size = 2.4, Speed = 14, Gravity = 6, Glow = 1 })
			Effects.ring(finish, weapon.Radius or 8, color, 0.4)
		end)
	elseif weapon.Kind == "Cone" then
		local look = (finish - start) * Vector3.new(1, 0, 1)
		local direction = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
		for index = 1, 4 do
			task.delay(index * 0.03, function()
				Effects.burst(
					start + direction * (index * weapon.Range / 4),
					EMBER_COLOR,
					8,
					{ Texture = FIRE, Size = 2 + index * 0.5, Speed = 4, Gravity = 3, Glow = 1, Life = 0.5 }
				)
			end)
		end
	end
end

local handlers: { [string]: (data: any) -> () } = {}

handlers.Gather = function(data)
	local node = Resources.Nodes[data.Node]
	if node then
		Sounds.at(node.Sound, data.Position, 90)
	end
	local resource = Resources.ById[data.Resource]
	local color = if resource then Color3.fromHex(resource.Color) else SNOW_COLOR
	Effects.burst(data.Position + Vector3.new(0, 2, 0), color, 8, { Size = 0.8, Speed = 10 })
	Effects.burst(data.Position + Vector3.new(0, 1, 0), SNOW_COLOR, 6, { Size = 1.4, Speed = 4 })
	if data.By == player.UserId and resource and (data.Amount or 0) > 0 then
		Effects.float(data.Position, `+{data.Amount} {resource.Icon}`, color)
	end
	local model = data.Model
	if typeof(model) == "Instance" and model:IsA("Model") and model.Parent then
		-- A little wobble on whatever was hit.
		local pivot = model:GetPivot()
		model:PivotTo(pivot * CFrame.Angles(0.05, 0, 0.05))
		task.delay(0.08, function()
			if model.Parent then
				model:PivotTo(pivot)
			end
		end)
	end
	if data.Depleted then
		Effects.burst(data.Position + Vector3.new(0, 2, 0), SNOW_COLOR, 18, { Size = 2.4, Speed = 8 })
	end
end

handlers.PackFull = function()
	Sounds.play("PackFull")
end

handlers.Crate = function(data)
	Sounds.at("Crate", data.Position, 100)
	Effects.burst(data.Position + Vector3.new(0, 2, 0), UI.Colors.Gold, 20, { Texture = SPARKLE, Glow = 1, Speed = 12 })
end

handlers.Deposit = function(data)
	local at = Vector3.new(Map.Stockpile[1], 2, Map.Stockpile[2])
	if data.By == player.UserId then
		Sounds.play("Deposit")
		Effects.float(at, `+{data.Amount} to stockpile`, UI.Colors.Good)
	end
	Effects.burst(at, SNOW_COLOR, 10, { Size = 1.2, Speed = 6 })
end

handlers.Feed = function()
	Sounds.at("Feed", HEARTH, 160)
	Effects.burst(
		HEARTH + Vector3.new(0, 5, 0),
		EMBER_COLOR,
		30,
		{ Texture = FIRE, Size = 3, Speed = 16, Gravity = 10, Glow = 1 }
	)
end

handlers.HearthUp = function()
	Sounds.play("HearthUp")
	Effects.burst(
		HEARTH + Vector3.new(0, 6, 0),
		UI.Colors.Gold,
		60,
		{ Texture = SPARKLE, Size = 2, Speed = 26, Glow = 1, Life = 1.6 }
	)
	Effects.ring(HEARTH, State:GetAttribute("HearthRadius") or 30, UI.Colors.Warm, 1.2)
	Effects.shake(0.3)
end

handlers.Built = function(data)
	Sounds.at("Build", data.Position, 120)
	Effects.burst(data.Position + Vector3.new(0, 1, 0), SNOW_COLOR, 16, { Size = 2, Speed = 7 })
end

handlers.Broken = function(data)
	Sounds.at("Broken", data.Position, 150)
	Effects.burst(data.Position + Vector3.new(0, 2, 0), Color3.fromRGB(150, 110, 70), 20, { Size = 1, Speed = 14 })
	Effects.burst(data.Position + Vector3.new(0, 1, 0), SNOW_COLOR, 14, { Size = 2.4, Speed = 6 })
end

handlers.Repair = function(data)
	Sounds.at("Repair", data.Position, 100)
	Effects.burst(
		data.Position + Vector3.new(0, 3, 0),
		UI.Colors.Good,
		12,
		{ Texture = SPARKLE, Glow = 1, Speed = 6, Gravity = 4 }
	)
end

handlers.Crafted = function(data)
	Sounds.at("Craft", data.Position, 120)
	Effects.burst(data.Position + Vector3.new(0, 4, 0), UI.Colors.Gold, 24, { Texture = SPARKLE, Glow = 1, Speed = 12 })
end

handlers.Cooked = function(data)
	Sounds.at("Cook", data.Position, 100)
	Effects.burst(
		data.Position + Vector3.new(0, 4, 0),
		Color3.new(1, 1, 1),
		16,
		{ Size = 3, Speed = 4, Gravity = 6, Life = 1.6 }
	)
end

handlers.Eat = function(data)
	local root = playerRoot(data.Player)
	if data.Player == player.UserId then
		Sounds.play("Eat")
	end
	if root then
		Effects.burst(
			root.Position + Vector3.new(0, 2.5, 0),
			UI.Colors.Warm,
			12,
			{ Texture = SPARKLE, Glow = 1, Speed = 5, Gravity = 4 }
		)
	end
end

handlers.Shot = function(data)
	local impact = ground(data.ImpactX, data.ImpactZ)
	if data.By ~= player.UserId then
		Effects.shot(data.Weapon, data.From, impact)
	end
	if (data.Hits or 0) > 0 then
		local weapon = Weapons.ById[data.Weapon]
		local delay = if weapon and weapon.Kind ~= "Melee" then 0.12 else 0
		task.delay(delay, function()
			Sounds.at("Hit", impact, 100)
			Effects.burst(impact, ICE_COLOR, 10, { Texture = SPARKLE, Size = 1.2, Speed = 12, Glow = 1 })
		end)
	end
end

handlers.Douse = function(data)
	local at = MonsterView.position(data.Enemy) or HEARTH
	Effects.burst(Vector3.new(at.X, 3, at.Z), SNOW_COLOR, 12, { Size = 1.6, Speed = 10 })
	Effects.burst(
		HEARTH + Vector3.new(0, 4, 0),
		Color3.fromRGB(180, 190, 200),
		8,
		{ Size = 3, Speed = 3, Gravity = 6, Life = 1.4 }
	)
end

handlers.Slam = function(data)
	local at = ground(data.X, data.Z, 0.5)
	Sounds.at("Slam", at, 220)
	Effects.ring(at, data.Radius or 10, ICE_COLOR, 0.5)
	Effects.burst(at + Vector3.new(0, 1, 0), SNOW_COLOR, 30, { Size = 3, Speed = 18 })
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - at).Magnitude < 80 then
		Effects.shake(0.6)
	end
end

handlers.IceShard = function(data)
	Effects.bolt(ground(data.X, data.Z, 7), ground(data.ToX, data.ToZ, 3), ICE_COLOR, 0.7, 0.35, function()
		Effects.burst(ground(data.ToX, data.ToZ, 3), ICE_COLOR, 8, { Texture = SPARKLE, Glow = 1, Speed = 8 })
	end)
end

handlers.Turret = function(data)
	local built = Workspace:FindFirstChild("Built")
	local from: Vector3? = nil
	if built then
		for _, model in built:GetChildren() do
			if model:GetAttribute("StructureId") == data.Structure then
				local muzzle = model:FindFirstChild("Muzzle", true) :: BasePart?
				from = if muzzle then muzzle.Position else model:GetPivot().Position + Vector3.new(0, 6, 0)
				break
			end
		end
	end
	if not from then
		return
	end
	Sounds.at("Sling", from, 90, 1.3)
	local target = ground(data.ToX, data.ToZ, 2)
	Effects.bolt(from, target, EMBER_COLOR, if data.Splash then 1.4 else 0.8, nil, function()
		Effects.burst(
			target,
			EMBER_COLOR,
			if data.Splash then 18 else 8,
			{ Texture = FIRE, Glow = 1, Speed = 10, Gravity = 4 }
		)
	end)
end

local function poof(x: number, z: number, big: boolean)
	local at = ground(x, z, 2)
	Effects.burst(
		at,
		SNOW_COLOR,
		if big then 60 else 16,
		{ Size = if big then 5 else 2.2, Speed = if big then 20 else 9 }
	)
	Effects.burst(at, ICE_COLOR, if big then 30 else 6, { Texture = SPARKLE, Glow = 1, Speed = 12 })
end

handlers.Down = function(data)
	for _, down in data.List or {} do
		poof(down.X, down.Z, false)
		Sounds.at("Poof", ground(down.X, down.Z), 120)
	end
end

handlers.Melt = function(data)
	for index, down in data.List or {} do
		task.delay(index * 0.02, function()
			poof(down.X, down.Z, false)
		end)
	end
end

handlers.Boss = function()
	Sounds.play("Roar")
	Effects.shake(0.8)
	bossOut = true
end

handlers.BossDown = function(data)
	poof(data.X, data.Z, true)
	Sounds.play("Poof", 0.7)
	Effects.shake(0.5)
	bossOut = false
end

handlers.Chilled = function()
	Sounds.play("Hit", 0.8)
	Effects.shake(0.15)
end

handlers.Freeze = function(data)
	Sounds.at("Freeze", data.Position, 160)
	Effects.burst(data.Position, ICE_COLOR, 24, { Texture = SPARKLE, Glow = 1, Speed = 10 })
end

handlers.Thaw = function(data)
	Sounds.at("Thaw", data.Position, 160)
	Effects.burst(data.Position, UI.Colors.Warm, 24, { Texture = SPARKLE, Glow = 1, Speed = 10, Gravity = 6 })
end

handlers.IceBreak = function(data)
	Sounds.at("IceBreak", data.Position, 160)
	Effects.burst(data.Position, ICE_COLOR, 30, { Size = 1.2, Speed = 18 })
end

handlers.Fitted = function()
	Sounds.play("RadioFit")
	Effects.burst(
		RADIO + Vector3.new(0, 30, 0),
		UI.Colors.Gold,
		40,
		{ Texture = SPARKLE, Glow = 1, Speed = 20, Life = 1.4 }
	)
end

handlers.Called = function()
	task.delay(0.8, function()
		Sounds.play("Called")
	end)
end

handlers.Flare = function(data)
	Sounds.at("Ability", data.Position, 160)
	local up = data.Position + Vector3.new(0, 60, 0)
	Effects.bolt(data.Position + Vector3.new(0, 3, 0), up, Color3.fromRGB(255, 90, 90), 1.4, 0.7, function()
		Effects.burst(
			up,
			Color3.fromRGB(255, 120, 120),
			50,
			{ Texture = SPARKLE, Size = 3, Speed = 30, Glow = 1, Life = 2 }
		)
	end)
end

handlers.Cocoa = function(data)
	Sounds.at("Ability", data.Position, 120)
	Effects.ring(data.Position, data.Radius or 20, Color3.fromRGB(160, 100, 60), 0.8)
	Effects.burst(
		data.Position + Vector3.new(0, 3, 0),
		Color3.new(1, 1, 1),
		20,
		{ Size = 2.4, Speed = 6, Gravity = 6, Life = 1.4 }
	)
end

handlers.Volley = function(data)
	local root = playerRoot(data.Player)
	if root then
		Sounds.at("Ability", root.Position, 120)
		Effects.burst(root.Position, Color3.fromRGB(124, 224, 124), 24, { Texture = SPARKLE, Glow = 1, Speed = 12 })
	end
end

handlers.HeatPack = function(data)
	Sounds.at("Ability", data.Position, 120)
	Effects.ring(data.Position, data.Radius or 20, UI.Colors.Warm, 0.8)
end

handlers.Unlock = function()
	Sounds.play("Unlock")
end

local function onPhase()
	local phase = State:GetAttribute("Phase")
	if phase == "Night" then
		Sounds.play("NightHorn")
	elseif phase == "Dawn" then
		Sounds.play("DawnChime")
		bossOut = false
	elseif phase == "Rescue" then
		Sounds.play("TrainHorn")
	elseif phase == "Won" then
		Sounds.play("Win")
	elseif phase == "Lost" then
		Sounds.play("Lose")
	elseif phase == "Intermission" then
		bossOut = false
	end
end

local function music()
	local phase = State:GetAttribute("Phase")
	if bossOut and phase == "Night" then
		Sounds.music("MusicBoss")
	elseif phase == "Night" or phase == "Dusk" or phase == "Lost" then
		Sounds.music("MusicNight")
	else
		Sounds.music("MusicDay")
	end
end

function Effects.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, data)
		local handler = handlers[kind]
		if handler and type(data) == "table" then
			local ok, problem = pcall(handler, data)
			if not ok then
				warn(`Effect {kind} failed: {problem}`)
			end
		end
	end)
	State:GetAttributeChangedSignal("Phase"):Connect(onPhase)
	RunService:BindToRenderStep("SnowedInShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shake <= 0 then
			return
		end
		local camera = Workspace.CurrentCamera
		if camera then
			local offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake
			camera.CFrame *= CFrame.new(offset)
		end
		shake = math.max(0, shake - dt * 1.5)
	end)
	task.spawn(function()
		while true do
			music()
			task.wait(1)
		end
	end)
end

return Effects
