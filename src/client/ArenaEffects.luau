-- Draws the arena's fights on this client: sparks where a hit lands, dizzy
-- stars over a knocked-out player, and every special move's effects, from a
-- pumpkin-orange shockwave to lightning raining down around the thunder
-- hammer. Each weapon's special has a Flair in the theme (Theme.Arena) that
-- picks what is drawn, in the weapon's own two colours. Everything here is
-- made on this client only, changes nothing and cleans itself up.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Config.Theme)
local Weapons = require(Shared.Config.Weapons)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local UP = Vector3.new(0, 1, 0)

local ArenaEffects = {}

local random = Random.new()
local folder: Folder? = nil
local shakeUntil, shakeStrength = 0, 0

type Look = { Name: string, Color: Color3, Accent: Color3, Flair: string }

local looks: { [string]: Look } = {}
for id, spec in Theme.Arena.Specials do
	looks[id] = {
		Name = spec.Name,
		Color = Color3.fromHex(spec.Color),
		Accent = Color3.fromHex(spec.Accent),
		Flair = spec.Flair,
	}
end

function ArenaEffects.look(weaponId: string): Look
	return looks[weaponId] or looks.bonker
end

local function container(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "ArenaEffects"
		made.Parent = Workspace
		folder = made
	end
	return folder :: Folder
end

-- A glowing part that can't be bumped, touched or clicked.
local function glow(cframe: CFrame, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Parent = container()
	return part
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

local function fadeAway(part: BasePart, seconds: number, goal: { [string]: any }?)
	local final = goal or {}
	final.Transparency = 1
	tween(part, seconds, final)
	Debris:AddItem(part, seconds + 0.1)
end

local function sound(name: string, at: Vector3)
	local spec = Theme.Arena.Sounds[name]
	if not spec or spec.Id == "" then
		return
	end
	local holder = glow(CFrame.new(at), Vector3.one, Color3.new(), nil)
	holder.Transparency = 1
	local played = Instance.new("Sound")
	played.SoundId = spec.Id
	played.Volume = spec.Volume
	played.RollOffMaxDistance = 150
	played.Parent = holder
	played:Play()
	Debris:AddItem(holder, 4)
end

-- A burst of glowing sparks, or of smoke.
local function burst(at: Vector3, color: Color3, count: number, speed: number, smoky: boolean?)
	local holder = glow(CFrame.new(at), Vector3.one, color)
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.4, if smoky then 1.4 else 0.8)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, if smoky then 2 else -20, 0)
	emitter.Color = ColorSequence.new(color)
	if smoky then
		emitter.Texture = SMOKE
		emitter.Size = NumberSequence.new(1.5, 4)
		emitter.Transparency = NumberSequence.new(0.4, 1)
	else
		emitter.Size = NumberSequence.new(0.6, 0)
		emitter.LightEmission = 1
	end
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, 2)
end

-- A brief flash of light.
local function flash(at: Vector3, color: Color3, range: number, brightness: number, seconds: number)
	local holder = glow(CFrame.new(at), Vector3.one, color)
	holder.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = holder
	tween(light, seconds, { Brightness = 0 })
	Debris:AddItem(holder, seconds + 0.1)
end

-- A ring of light spreading out over the ground from centre to radius.
local function ring(centre: Vector3, color: Color3, radius: number, seconds: number)
	local pieces = 20
	for i = 1, pieces do
		local angle = i / pieces * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local along = out:Cross(UP)
		local length = 2 * math.pi * radius / pieces
		local piece = glow(CFrame.lookAt(centre + out, centre + out + along), Vector3.new(0.7, 0.35, 0.4), color)
		fadeAway(piece, seconds, {
			CFrame = CFrame.lookAt(centre + out * radius, centre + out * radius + along),
			Size = Vector3.new(0.7, 0.35, length * 1.15),
		})
	end
end

-- A jagged bolt of lightning from a to b.
local function bolt(a: Vector3, b: Vector3, color: Color3, width: number)
	local points = { a }
	for i = 1, 5 do
		local jitter = Vector3.new(random:NextNumber(-2, 2), 0, random:NextNumber(-2, 2))
		table.insert(points, a:Lerp(b, i / 6) + jitter)
	end
	table.insert(points, b)
	for i = 1, #points - 1 do
		local from, to = points[i], points[i + 1]
		local piece =
			glow(CFrame.lookAt((from + to) / 2, to), Vector3.new(width, width, (to - from).Magnitude + width), color)
		fadeAway(piece, 0.35)
	end
end

-- A pillar of light or water rising out of the ground and fading.
local function column(base: Vector3, color: Color3, height: number, width: number, seconds: number)
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local piece = glow(CFrame.new(base) * upright, Vector3.new(0.5, width, width), color, Enum.PartType.Cylinder)
	piece.Transparency = 0.2
	fadeAway(piece, seconds, {
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * upright,
		Size = Vector3.new(height, width * 0.4, width * 0.4),
	})
end

-- Runs step(t) every frame for seconds, with t going from 0 to 1, then done.
local function animate(seconds: number, step: (number) -> (), done: (() -> ())?)
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - started) / seconds)
		step(t)
		if t >= 1 then
			connection:Disconnect()
			if done then
				done()
			end
		end
	end)
end

-- Glowing sparks streaming off a character for seconds.
local function trail(character: Model, color: Color3, seconds: number, smoky: boolean?)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 80
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Color = ColorSequence.new(color)
	if smoky then
		emitter.Texture = SMOKE
		emitter.Size = NumberSequence.new(1.2, 2.5)
		emitter.Transparency = NumberSequence.new(0.3, 1)
	else
		emitter.Size = NumberSequence.new(0.8, 0)
		emitter.LightEmission = 1
	end
	emitter.Parent = root
	task.delay(seconds, function()
		emitter.Enabled = false
	end)
	Debris:AddItem(emitter, seconds + 1)
end

-- Things orbiting a character, spreading out from them to radius.
local function orbit(character: Model, count: number, radius: number, seconds: number, make: (CFrame) -> BasePart)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local parts = {}
	for i = 1, count do
		parts[i] = make(root.CFrame)
	end
	animate(seconds, function(t)
		local spread = 1.5 + (radius - 1.5) * t
		for i, part in parts do
			local angle = i / count * math.pi * 2 + t * math.pi * 6
			part.CFrame =
				CFrame.new(root.Position + Vector3.new(math.cos(angle) * spread, 0.5, math.sin(angle) * spread))
		end
	end, function()
		for _, part in parts do
			fadeAway(part, 0.25)
		end
	end)
end

-- A crescent of light, made of short pieces curving round in front of frame.
local function crescent(frame: CFrame, color: Color3, size: number, transparency: number): Model
	local model = Instance.new("Model")
	model.Name = "Crescent"
	local pieces = 8
	for i = 0, pieces - 1 do
		local a = math.rad(-75 + 150 * i / pieces)
		local b = math.rad(-75 + 150 * (i + 1) / pieces)
		-- Thickest in the middle, tapering to points at the tips.
		local thickness = size * 0.22 * math.cos((a + b) / 2)
		local from = (frame * CFrame.new(math.sin(a) * size, 0, -math.cos(a) * size * 0.5)).Position
		local to = (frame * CFrame.new(math.sin(b) * size, 0, -math.cos(b) * size * 0.5)).Position
		local piece =
			glow(CFrame.lookAt((from + to) / 2, to), Vector3.new(thickness, 0.4, (to - from).Magnitude + 0.2), color)
		piece.Transparency = transparency
		piece.Parent = model
	end
	model.WorldPivot = frame
	model.Parent = container()
	return model
end

-- Sends a crescent flying from start along ahead, for the Wave specials.
local function wave(start: Vector3, ahead: Vector3, look: Look, distance: number, speed: number, ghostly: boolean)
	local size = if ghostly then 4 else 3
	local frame = CFrame.lookAt(start, start + ahead)
	local model = crescent(frame, look.Color, size, if ghostly then 0.35 else 0)
	local inner = crescent(frame * CFrame.new(0, 0, 0.6), look.Accent, size * 0.7, if ghostly then 0.5 else 0.2)
	inner.Parent = model
	model.WorldPivot = frame
	local seconds = distance / speed
	local lastWisp = 0
	animate(seconds, function(t)
		local at = frame * CFrame.new(0, 0, -distance * t)
		model:PivotTo(at)
		if ghostly and t - lastWisp > 0.08 then
			lastWisp = t
			burst(at.Position, look.Accent, 4, 3, true)
		end
	end, function()
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				fadeAway(part, 0.2)
			end
		end
		Debris:AddItem(model, 0.4)
	end)
end

-- Three claw marks slashed into the air in front of frame.
local function clawMarks(frame: CFrame, color: Color3)
	for i = -1, 1 do
		local piece =
			glow(frame * CFrame.new(i * 0.8, 2.5, -3) * CFrame.Angles(0, 0, 0.5), Vector3.new(0.25, 4, 0.1), color)
		fadeAway(piece, 0.4, { Size = Vector3.new(0.05, 5, 0.1) })
	end
end

-- Shakes this player's camera for a moment.
function ArenaEffects.shake(strength: number, seconds: number)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
	shakeStrength = math.max(shakeStrength, strength)
end

-- A hit landing on someone.
function ArenaEffects.hit(at: Vector3, weaponId: string)
	local look = ArenaEffects.look(weaponId)
	burst(at, look.Color, 14, 14)
	burst(at, Color3.new(1, 1, 0.8), 6, 8)
	sound("Bonk", at)
end

-- Stars circling over a knocked-out player's head.
function ArenaEffects.knockOut(character: Model, weaponId: string, seconds: number)
	local look = ArenaEffects.look(weaponId)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	burst(head.Position, look.Color, 30, 22)
	burst(head.Position, look.Accent, 10, 6, true)
	ring(head.Position - Vector3.new(0, 3, 0), look.Color, 8, 0.5)
	flash(head.Position, look.Color, 16, 4, 0.5)
	sound("KnockOut", head.Position)
	local stars = {}
	for i = 1, 3 do
		stars[i] = glow(head.CFrame, Vector3.new(0.45, 0.45, 0.45), Color3.fromRGB(255, 230, 90), Enum.PartType.Ball)
	end
	animate(seconds, function(t)
		if not head.Parent then
			return
		end
		for i, star in stars do
			local angle = i / 3 * math.pi * 2 + t * math.pi * 8
			star.CFrame = CFrame.new(head.Position + Vector3.new(math.cos(angle) * 1.4, 1.3, math.sin(angle) * 1.4))
		end
	end, function()
		for _, star in stars do
			fadeAway(star, 0.2)
		end
	end)
end

-- The start of a special move by character, who stood at start facing ahead.
function ArenaEffects.special(character: Model, weaponId: string, start: Vector3, ahead: Vector3)
	local weapon = rawget(Weapons, weaponId)
	if not weapon then
		return
	end
	local move = weapon.Special
	local look = ArenaEffects.look(weaponId)
	local flair = look.Flair
	sound("Special", start)

	if move.Kind == "Slam" then
		trail(character, look.Color, move.Delay)
		if flair == "Lightning" then
			-- Lightning strikes the hammer as it's raised.
			bolt(
				start + Vector3.new(random:NextNumber(-6, 6), 70, random:NextNumber(-6, 6)),
				start + Vector3.new(0, 4, 0),
				look.Accent,
				0.6
			)
			flash(start, look.Color, 30, 6, 0.4)
			sound("Thunder", start)
		end
	elseif move.Kind == "Dash" then
		trail(character, look.Color, move.Seconds, flair == "Water")
		trail(character, look.Accent, move.Seconds)
		if flair == "Water" then
			burst(start, look.Accent, 20, 12, true)
		end
		if flair == "Claws" then
			task.delay(move.Seconds, function()
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					clawMarks(root.CFrame, look.Color)
				end
			end)
		elseif flair == "Water" then
			task.delay(move.Seconds, function()
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local ground = root.Position - Vector3.new(0, 3, 0)
					for i = 0, 2 do
						local angle = i / 3 * math.pi * 2
						column(
							ground + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4),
							look.Color,
							14,
							3,
							0.8
						)
					end
					ring(ground, look.Accent, 10, 0.6)
				end
			end)
		end
	elseif move.Kind == "Spin" then
		local ground = start - Vector3.new(0, 3, 0)
		if flair == "Foxfire" then
			orbit(character, 8, move.Radius, move.Seconds, function(at)
				local orb = glow(at, Vector3.new(1.2, 1.2, 1.2), look.Color, Enum.PartType.Ball)
				local fire = Instance.new("Fire")
				fire.Color = look.Color
				fire.SecondaryColor = look.Accent
				fire.Size = 3
				fire.Heat = 6
				fire.Parent = orb
				return orb
			end)
		else
			orbit(character, 6, move.Radius, move.Seconds, function(at)
				local wisp = glow(at, Vector3.new(1, 1.4, 1), look.Color, Enum.PartType.Ball)
				wisp.Transparency = 0.25
				return wisp
			end)
			trail(character, look.Accent, move.Seconds, true)
		end
		for pulse = 0, 2 do
			task.delay(move.Seconds * pulse / 3, function()
				ring(ground, if pulse % 2 == 0 then look.Color else look.Accent, move.Radius, 0.45)
			end)
		end
		flash(start, look.Color, 24, 3, move.Seconds)
	elseif move.Kind == "Wave" then
		wave(start, ahead, look, move.Distance, move.Speed, flair == "Ghosts")
		if flair == "Ghosts" then
			trail(character, look.Accent, 0.4, true)
		end
	end
end

-- Where a special move lands: a slam hitting the ground, or a wave hitting
-- someone.
function ArenaEffects.impact(weaponId: string, at: Vector3)
	local weapon = rawget(Weapons, weaponId)
	if not weapon then
		return
	end
	local move = weapon.Special
	local look = ArenaEffects.look(weaponId)
	if move.Kind ~= "Slam" then
		burst(at, look.Color, 24, 18)
		ring(at - Vector3.new(0, 2.5, 0), look.Accent, 5, 0.35)
		return
	end

	local ground = at - Vector3.new(0, 3, 0)
	ring(ground, look.Color, move.Radius, 0.5)
	burst(ground, look.Color, 30, 24)
	if look.Flair == "Dust" or look.Flair == "Pumpkin" then
		burst(ground, look.Accent, 12, 10, true)
	end
	if look.Flair == "Lightning" then
		-- Thunderfall: bolts rain down all around, a pillar of light, a second
		-- ring and a flash that lights the whole arena.
		for i = 0, 5 do
			local angle = i / 6 * math.pi * 2 + random:NextNumber(-0.3, 0.3)
			local distance = random:NextNumber(3, move.Radius)
			local strike = ground + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			task.delay(i * 0.05, function()
				bolt(
					strike + Vector3.new(random:NextNumber(-4, 4), 60, random:NextNumber(-4, 4)),
					strike,
					look.Accent,
					0.5
				)
				burst(strike, look.Color, 8, 12)
			end)
		end
		bolt(ground + Vector3.new(0, 80, 0), ground, Color3.new(1, 1, 1), 1)
		column(ground, look.Color, 40, 6, 0.6)
		task.delay(0.12, function()
			ring(ground, look.Accent, move.Radius * 1.3, 0.6)
		end)
		flash(ground + Vector3.new(0, 6, 0), look.Color, 60, 8, 0.7)
		sound("Thunder", ground)
		ArenaEffects.shake(0.6, 0.5)
	else
		flash(ground + Vector3.new(0, 3, 0), look.Color, 24, 3, 0.4)
		ArenaEffects.shake(0.25, 0.25)
	end
end

function ArenaEffects.start()
	RunService:BindToRenderStep("ArenaShake", Enum.RenderPriority.Camera.Value + 1, function()
		local left = shakeUntil - os.clock()
		if left <= 0 then
			shakeStrength = 0
			return
		end
		local camera = Workspace.CurrentCamera
		local amount = shakeStrength * math.min(1, left * 4)
		camera.CFrame *= CFrame.Angles(
			math.rad(random:NextNumber(-1, 1) * amount),
			math.rad(random:NextNumber(-1, 1) * amount),
			0
		)
	end)
end

return ArenaEffects
