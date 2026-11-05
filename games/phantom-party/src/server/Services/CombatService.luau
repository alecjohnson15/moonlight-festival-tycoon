-- Everything a role can do in a round, decided by the server: the
-- Phantom's blade (held and thrown), the Guardian's blaster, the Saboteur's
-- blackout and the Medic's revive. Clients only say what they're trying;
-- the server checks the role, the state, the cooldown and where everyone
-- really is before anything happens.
--
-- Roles stay secret. Role tools wait in ServerStorage, never in a backpack,
-- and go into the character's hand only while drawn, when everyone can see
-- them anyway. Nothing about a role is put where another client can read
-- it; each player hears only about their own kit.
--
-- A tagged guest is Dazed: down on the floor for a few seconds, when a
-- Medic can still bring them back, and then Out. A Shadow who is zapped is
-- Out at once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.Combat)
local Game = require(Shared.Config.Game)
local Roles = require(Shared.Config.Roles)
local Gear = require(Shared.Look.Gear)
local CombatRules = require(Shared.Rules.Combat)
local Round = require(Shared.Rules.Round)
local Match = require(script.Parent.Parent.Lib.Match)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local MapService = require(script.Parent.MapService)
local ProfileService = require(script.Parent.ProfileService)

local Remotes = ReplicatedStorage.Remotes
local Action = Remotes.Action :: RemoteEvent
local RoundRemote = Remotes.Round :: RemoteEvent
local Fx = Remotes.Fx :: RemoteEvent

type Participant = Match.Participant

type Kit = {
	Blade: Tool?,
	Blaster: Tool?,
	Drawn: Tool?,
	DrawnAt: number,
	LastSwing: number?,
	LastThrow: number?,
	Throwing: boolean,
	LastShot: number?,
	Blackouts: number,
	LastBlackout: number?,
	Revives: number,
}

local CombatService = {}

local kits: { [any]: Kit } = {}
local storage: Folder? = nil
local dropped: Model? = nil
local actionLimiter = RateLimiter.new(0.08)
local throwCount = 0

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function kitOf(participant: Participant): Kit
	local kit = kits[participant.Key]
	if not kit then
		kit = {
			Blade = nil,
			Blaster = nil,
			Drawn = nil,
			DrawnAt = 0,
			LastSwing = nil,
			LastThrow = nil,
			Throwing = false,
			LastShot = nil,
			Blackouts = 0,
			LastBlackout = nil,
			Revives = 0,
		}
		kits[participant.Key] = kit
	end
	return kit
end

local function humanoidOf(participant: Participant): Humanoid?
	local character = participant.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function outfitOf(participant: Participant): { [string]: string }
	if participant.Player then
		return ProfileService.outfit(participant.Player)
	end
	return {}
end

-- Clients in the round, and those watching it from the lobby.
local function everyone(): { Player }
	return Players:GetPlayers()
end

local function fxAll(...: any)
	for _, player in everyone() do
		Fx:FireClient(player, ...)
	end
end

-- Whether a player still standing in the round is within range of a spot.
-- Everyone else (the plaza, the tagged, the out) can't tell the living
-- anything, so they may see every effect.
local function within(player: Player, position: Vector3, range: number): boolean
	local participant = Match.get(player)
	if not participant or participant.State ~= "Alive" or not Match.live() then
		return true
	end
	local root = Match.root(participant)
	return root ~= nil and (root.Position - position).Magnitude <= range
end

-- An effect that happens where the Phantom is, sent only to clients that
-- could see or hear it, so a far-off client can't learn where (and so who)
-- the Phantom is. except is left out (the one doing it draws it already).
local function fxNear(position: Vector3, range: number, except: Player?, ...: any)
	for _, player in everyone() do
		if player ~= except and within(player, position, range) then
			Fx:FireClient(player, ...)
		end
	end
end

-- Whether nothing solid in the map stands between two points.
local function clear(from: Vector3, to: Vector3): boolean
	if not CombatConfig.LineOfSight then
		return true
	end
	local map = MapService.current()
	if not map then
		return true
	end
	local offset = to - from
	if offset.Magnitude < 1e-3 then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.RespectCanCollide = true
	return Workspace:Raycast(from, offset, params) == nil
end

CombatService.clear = clear

-- Chest height: where sight lines and shots start.
local function chest(position: Vector3): Vector3
	return position + Vector3.new(0, 1.5, 0)
end

-- Tells an attacker how their move went: Tagged, Missed, Caught (the
-- Phantom), Shadow (the Saboteur) or Innocent.
local function feedback(participant: Participant, move: string, result: string)
	if participant.Player then
		RoundRemote:FireClient(participant.Player, { Kind = "Hit", Move = move, Result = result })
	end
end

-- Tells a player what their kit can do right now.
local function sendKit(participant: Participant)
	local player = participant.Player
	if not player then
		return
	end
	local kit = kitOf(participant)
	local now = os.clock()
	local function readyAt(last: number?, seconds: number): number
		if not last then
			return 0
		end
		return serverNow() + math.max(0, last + seconds - now)
	end
	local graceLeft = math.max(0, Match.PlayingSince + Game.Seconds.Grace - now)
	RoundRemote:FireClient(player, {
		Kind = "Kit",
		Blade = kit.Blade ~= nil,
		Blaster = kit.Blaster ~= nil,
		Drawn = if kit.Drawn == nil then nil elseif kit.Drawn == kit.Blade then "Blade" else "Blaster",
		Throwing = kit.Throwing,
		BladeFrom = if Match.State == "Playing" then serverNow() + graceLeft else 0,
		ThrowReady = readyAt(kit.LastThrow, CombatConfig.Throw.Cooldown),
		ShotReady = readyAt(kit.LastShot, CombatConfig.Blaster.Cooldown),
		Blackouts = kit.Blackouts,
		BlackoutReady = math.max(
			readyAt(kit.LastBlackout, CombatConfig.Blackout.Cooldown),
			serverNow() + math.max(0, Match.PlayingSince + CombatConfig.Blackout.NotBefore - now)
		),
		Revives = kit.Revives,
	})
end

function CombatService.sendKit(participant: Participant)
	sendKit(participant)
end

-- Speeds -------------------------------------------------------------

function CombatService.walkSpeed(participant: Participant): number
	if participant.Role == "Phantom" then
		return Game.Movement.PhantomSpeed
	elseif participant.Role == "Guardian" or participant.Hero then
		return Game.Movement.GuardianSpeed
	end
	return Game.Movement.WalkSpeed
end

function CombatService.setMoving(participant: Participant, moving: boolean)
	local humanoid = humanoidOf(participant)
	if not humanoid then
		return
	end
	if participant.Player == nil then
		humanoid.WalkSpeed = if moving then 9 else 0
		return
	end
	humanoid.WalkSpeed = if moving then CombatService.walkSpeed(participant) else 0
	humanoid.JumpHeight = if moving then Game.Movement.JumpHeight else 0
end

-- Tools ----------------------------------------------------------------

local function holster(participant: Participant)
	local kit = kitOf(participant)
	if kit.Drawn then
		kit.Drawn.Parent = storage
		kit.Drawn = nil
	end
end

local function draw(participant: Participant, tool: Tool)
	local kit = kitOf(participant)
	local character = participant.Character
	if not character or kit.Drawn == tool then
		return
	end
	holster(participant)
	tool.Parent = character
	kit.Drawn = tool
	kit.DrawnAt = os.clock()
	if tool == kit.Blade then
		-- The telegraph: guests close by hear a blade come out.
		local root = Match.root(participant)
		if root then
			for _, other in Match.Participants do
				local otherRoot = Match.root(other)
				if
					other ~= participant
					and other.Player
					and other.State == "Alive"
					and otherRoot
					and (otherRoot.Position - root.Position).Magnitude <= CombatConfig.DrawWarnRange
				then
					Fx:FireClient(other.Player, "Draw", root.Position)
				end
			end
		end
		Match.fire("Drawn", participant)
	end
end

local function giveBlaster(participant: Participant)
	local kit = kitOf(participant)
	if kit.Blaster then
		return
	end
	local skin = outfitOf(participant).Blaster or "blaster_moonbeam"
	local tool = Gear.blaster(skin)
	tool.Parent = storage
	kit.Blaster = tool
end

-- Hands out the kit for each role as a round starts playing.
function CombatService.begin()
	kits = {}
	for _, participant in Match.Participants do
		local kit = kitOf(participant)
		if participant.Role == "Phantom" then
			local tool = Gear.blade(outfitOf(participant).Blade or "blade_shadow")
			tool.Parent = storage
			kit.Blade = tool
		elseif participant.Role == "Guardian" then
			giveBlaster(participant)
		elseif participant.Role == "Saboteur" then
			kit.Blackouts = CombatConfig.Blackout.Charges
		elseif participant.Role == "Medic" then
			local count = 0
			for _ in Match.Participants do
				count += 1
			end
			kit.Revives = CombatConfig.Revive.Charges + (if count >= CombatConfig.Revive.ExtraChargeAt then 1 else 0)
		end
		sendKit(participant)
	end
end

-- Takes every tool back and clears the floor, as a round ends.
function CombatService.finish()
	for key, kit in kits do
		for _, tool in { kit.Blade, kit.Blaster } do
			if tool then
				tool:Destroy()
			end
		end
		kits[key] = nil
	end
	if dropped then
		dropped:Destroy()
		dropped = nil
	end
end

-- The dropped blaster -------------------------------------------------

local function groundBelow(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local map = MapService.current()
	params.FilterDescendantsInstances = if map then { map } else {}
	local hit = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position else position - Vector3.new(0, 3, 0)
end

local function dropBlaster(participant: Participant)
	local kit = kitOf(participant)
	local tool = kit.Blaster
	local root = Match.root(participant)
	if not tool or not root then
		return
	end
	local skin = tool:GetAttribute("Skin") or "blaster_moonbeam"
	tool:Destroy()
	kit.Blaster = nil
	kit.Drawn = nil
	if dropped then
		dropped:Destroy()
	end
	local spot = groundBelow(root.Position)
	local model = Gear.blasterModel(skin)
	model.Name = "DroppedBlaster"
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	local base = CFrame.new(spot + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = base * part.CFrame
		end
	end
	model.WorldPivot = base
	local glow = Instance.new("Part")
	glow.Name = "Beacon"
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Material = Enum.Material.Neon
	glow.Color = Color3.fromRGB(127, 224, 255)
	glow.Transparency = 0.6
	glow.Size = Vector3.new(0.4, 14, 0.4)
	glow.CFrame = CFrame.new(spot + Vector3.new(0, 7, 0))
	glow.Parent = model
	local light = Instance.new("PointLight")
	light.Color = glow.Color
	light.Range = 14
	light.Brightness = 2
	light.Parent = glow
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = "Moonbeam Blaster"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("GuestsOnly", true)
	prompt.Parent = glow
	model:SetAttribute("DroppedBy", participant.UserId)
	model:SetAttribute("DroppedAt", os.clock())
	model.Parent = MapService.current()
	model:AddTag("DroppedBlaster")
	dropped = model
	prompt.Triggered:Connect(function(player)
		local picker = Match.get(player)
		if not picker or Match.State ~= "Playing" or not Round.canPickUp(picker.Role, picker.State) then
			return
		end
		if os.clock() - (model:GetAttribute("DroppedAt") or 0) < CombatConfig.Blaster.PickupDelay then
			return
		end
		if dropped ~= model then
			return
		end
		dropped = nil
		model:Destroy()
		if picker.Role ~= "Guardian" then
			picker.Hero = true
		end
		giveBlaster(picker)
		draw(picker, kitOf(picker).Blaster :: Tool)
		CombatService.setMoving(picker, true)
		sendKit(picker)
		fxAll("Notice", "Someone picked up the blaster!")
	end)
	fxAll("Notice", "The blaster has been dropped! Any guest can pick it up.")
end

-- Knockdowns -----------------------------------------------------------

local function setDazed(participant: Participant, dazed: boolean)
	local character = participant.Character
	local humanoid = humanoidOf(participant)
	if character then
		character:SetAttribute("Dazed", if dazed then true else nil)
	end
	if humanoid then
		humanoid.PlatformStand = dazed
		if dazed then
			humanoid.WalkSpeed = 0
			humanoid.JumpHeight = 0
		end
	end
end

local function goOut(participant: Participant)
	if participant.State == "Out" then
		return
	end
	participant.State = "Out"
	local tagger = participant.TaggedBy
	if tagger and tagger.Role == "Phantom" then
		tagger.Tags += 1
	end
	local character = participant.Character
	if character then
		character:SetAttribute("Dazed", nil)
		character:SetAttribute("Out", true)
	end
	holster(participant)
	Match.fire("Out", participant)
end

-- Knocks a participant down: Dazed for a guest, Out for a Shadow. how is
-- "Swing", "Throw", "Zap" or "Misfire".
function CombatService.knockDown(target: Participant, by: Participant?, how: string)
	-- Nothing lands once the round is decided: a shot or a blade still in
	-- the air when the clock stops does nothing.
	if target.State ~= "Alive" or Match.State ~= "Playing" then
		return
	end
	holster(target)
	if kitOf(target).Blaster then
		dropBlaster(target)
	end
	local root = Match.root(target)
	if root then
		local effect = if by then outfitOf(by).Effect else nil
		fxNear(root.Position, CombatConfig.FxRange, nil, "Burst", root.Position, effect or "fx_poof", how)
	end
	if Roles.team(target.Role) == "Shadows" then
		target.State = "Dazed"
		setDazed(target, true)
		Match.fire("Down", target, by, how)
		goOut(target)
		return
	end
	target.State = "Dazed"
	target.DazedAt = os.clock()
	target.TaggedBy = by
	target.LastHow = how
	setDazed(target, true)
	Match.fire("Down", target, by, how)
	if target.Player then
		RoundRemote:FireClient(target.Player, { Kind = "You", State = "Dazed", Seconds = Game.Seconds.Daze, How = how })
	end
	local dazedAt = target.DazedAt
	task.delay(Game.Seconds.Daze, function()
		if target.State == "Dazed" and target.DazedAt == dazedAt and Match.live() then
			goOut(target)
		end
	end)
end

-- A participant who left the game (left) or fell out of the world mid-round:
-- out, and any blaster they held drops where they were.
function CombatService.leave(participant: Participant, left: boolean?)
	if participant.State == "Out" then
		return
	end
	participant.Left = left == true
	if kitOf(participant).Blaster and Match.root(participant) then
		dropBlaster(participant)
	end
	goOut(participant)
end

function CombatService.revive(target: Participant, medic: Participant)
	target.State = "Alive"
	target.DazedAt = nil
	target.ShieldUntil = os.clock() + Game.Seconds.ReviveShield
	setDazed(target, false)
	CombatService.setMoving(target, true)
	medic.Revives += 1
	local root = Match.root(target)
	if root then
		fxAll("Revive", root.Position)
	end
	Match.fire("Revived", target, medic)
	if target.Player then
		local tagger = target.TaggedBy
		local line = "Back on your feet! Stay with the others."
		if tagger and target.LastHow == "Swing" then
			line = `Back on your feet! You saw who tagged you: {tagger.Name}. Tell the others, quietly.`
		elseif target.LastHow == "Throw" then
			line = "Back on your feet! A thrown blade got you, from somewhere you couldn't see."
		end
		RoundRemote:FireClient(target.Player, { Kind = "You", State = "Alive", Text = line })
	end
	target.TaggedBy = nil
end

-- Actions ----------------------------------------------------------------

-- The characters a hit can land on, besides the map.
local function hitFilter(except: Participant?): RaycastParams
	local list: { Instance } = {}
	local map = MapService.current()
	if map then
		table.insert(list, map)
	end
	for _, participant in Match.Participants do
		if participant ~= except and participant.Character and participant.State ~= "Out" then
			table.insert(list, participant.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = list
	return params
end

local function participantHit(part: Instance?): Participant?
	local model = part and part:FindFirstAncestorOfClass("Model")
	while model do
		local found = Match.byCharacter(model)
		if found then
			return found
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function canBeTagged(target: Participant): boolean
	return target.State == "Alive" and target.ShieldUntil <= os.clock()
end

local function swing(participant: Participant, facing: unknown)
	local kit = kitOf(participant)
	local now = os.clock()
	if participant.Role ~= "Phantom" or kit.Drawn ~= kit.Blade or kit.Blade == nil or kit.Throwing then
		return
	end
	if now - kit.DrawnAt < CombatConfig.Blade.DrawSeconds then
		return
	end
	if not CombatRules.ready(now, kit.LastSwing, CombatConfig.Blade.Cooldown, CombatConfig.CooldownSlack) then
		return
	end
	local root = Match.root(participant)
	local direction = typeof(facing) == "Vector3" and CombatRules.aim(facing :: Vector3)
	if not root or not direction then
		return
	end
	kit.LastSwing = now
	local slash = Instance.new("StringValue")
	slash.Name = "toolanim"
	slash.Value = "Slash"
	slash.Parent = kit.Blade
	task.delay(0.5, function()
		slash:Destroy()
	end)
	-- Who swung is never sent: only where, to those near enough to hear it.
	fxNear(root.Position, CombatConfig.FxRange, participant.Player, "Swing", root.Position)
	local targets = {}
	for _, other in Match.Participants do
		local otherRoot = Match.root(other)
		if other ~= participant and otherRoot and canBeTagged(other) and Round.canTag(participant.Role, other.Role) then
			table.insert(targets, { Id = other, Position = otherRoot.Position })
		end
	end
	local hit = CombatRules.swingTarget(
		root.Position,
		direction,
		targets,
		CombatConfig.Blade.Reach,
		CombatConfig.Blade.Arc,
		CombatConfig.Blade.Height,
		function(from, to)
			return clear(chest(from), chest(to))
		end
	)
	if hit then
		local target = hit.Id :: Participant
		CombatService.knockDown(target, participant, "Swing")
		feedback(participant, "Swing", "Tagged")
	else
		feedback(participant, "Swing", "Missed")
	end
end

local function throw(participant: Participant, origin: unknown, aim: unknown)
	local kit = kitOf(participant)
	local now = os.clock()
	if participant.Role ~= "Phantom" or not kit.Blade or kit.Drawn ~= kit.Blade or kit.Throwing then
		return
	end
	if not CombatRules.ready(now, kit.LastThrow, CombatConfig.Throw.Cooldown, CombatConfig.CooldownSlack) then
		return
	end
	local root = Match.root(participant)
	local direction = typeof(aim) == "Vector3" and CombatRules.aim(aim :: Vector3)
	if not root or not direction or typeof(origin) ~= "Vector3" then
		return
	end
	if not CombatRules.near(origin :: Vector3, root.Position, CombatConfig.OriginSlack) then
		return
	end
	kit.LastThrow = now
	kit.Throwing = true
	local blade = kit.Blade
	holster(participant)
	sendKit(participant)
	throwCount += 1
	local id = throwCount
	local config = CombatConfig.Throw
	-- The blade leaves just in front of the Phantom, unless that spot is
	-- through a wall they're hugging: then it leaves from their chest.
	local held = root.Position + Vector3.new(0, 1, 0)
	local start = held + direction * 2
	if not clear(held, start) then
		start = held
	end
	-- Each client sees the flight from the point it comes into their view.
	local viewers: { Player } = {}
	local flight = { Done = false }
	local skin = blade:GetAttribute("Skin")
	for _, player in everyone() do
		local viewer = Match.get(player)
		local viewerRoot = viewer and Match.root(viewer)
		local from: number? = 0
		if viewer and viewer.State == "Alive" then
			from = if viewerRoot
				then CombatRules.pathStart(start, direction, config.Range, viewerRoot.Position, CombatConfig.FxRange)
				else nil
		end
		if from then
			local shown = start + direction * from
			task.delay(from / config.Speed, function()
				-- Landed before it came into view: nothing to see.
				if player.Parent and (from == 0 or not flight.Done) then
					table.insert(viewers, player)
					Fx:FireClient(player, "Throw", id, shown, direction, config.Speed, config.Range - from, skin)
				end
			end)
		end
	end
	task.spawn(function()
		local params = hitFilter(participant)
		local position = start
		local travelled = 0
		local landed = start + direction * config.Range
		local tagged = false
		-- A Phantom knocked out mid-throw loses the blade in the air.
		while travelled < config.Range and Match.State == "Playing" and participant.State == "Alive" do
			local dt = task.wait(config.Step)
			local length = math.min(config.Speed * dt, config.Range - travelled)
			local result = Workspace:Spherecast(position, config.Radius, direction * length, params)
			if result then
				landed = result.Position
				local target = participantHit(result.Instance)
				if
					target
					and participant.State == "Alive"
					and canBeTagged(target)
					and Round.canTag(participant.Role, target.Role)
				then
					CombatService.knockDown(target, participant, "Throw")
					tagged = target.State ~= "Alive"
				end
				break
			end
			position += direction * length
			travelled += length
		end
		flight.Done = true
		feedback(participant, "Throw", if tagged then "Tagged" else "Missed")
		Match.fire("ThrowLanded", participant, landed, tagged)
		for _, player in viewers do
			if player.Parent then
				Fx:FireClient(player, "ThrowEnd", id, landed)
			end
		end
		task.wait(0.35)
		kit.Throwing = false
		if participant.State == "Alive" and kit.Blade == blade and Match.State == "Playing" then
			draw(participant, blade)
		end
		sendKit(participant)
	end)
end

local function fire(participant: Participant, origin: unknown, aim: unknown)
	local kit = kitOf(participant)
	local now = os.clock()
	if not kit.Blaster or kit.Drawn ~= kit.Blaster then
		return
	end
	if not CombatRules.ready(now, kit.LastShot, CombatConfig.Blaster.Cooldown, CombatConfig.CooldownSlack) then
		return
	end
	local root = Match.root(participant)
	local direction = typeof(aim) == "Vector3" and CombatRules.aim(aim :: Vector3)
	if not root or not direction or typeof(origin) ~= "Vector3" then
		return
	end
	if not CombatRules.near(origin :: Vector3, root.Position, CombatConfig.OriginSlack) then
		return
	end
	kit.LastShot = now
	local config = CombatConfig.Blaster
	-- Believe the client's muzzle only if nothing solid is between it and
	-- the shooter's chest.
	local start = CombatRules.origin(origin, chest(root.Position), CombatConfig.OriginSlack, clear)
	local result = Workspace:Spherecast(start, config.Radius, direction * config.Range, hitFilter(participant))
	local landed = if result then result.Position else start + direction * config.Range
	local tip = kit.Blaster:FindFirstChild("Tip", true)
	local from = if tip and tip:IsA("BasePart") then tip.Position else start
	fxAll("Beam", from, landed, kit.Blaster:GetAttribute("Skin"))
	sendKit(participant)
	local target = result and participantHit(result.Instance)
	if not target or target.State ~= "Alive" then
		feedback(participant, "Zap", "Missed")
		Match.fire("Shot", participant, "Missed")
		return
	end
	local zap = Round.zap(target.Role)
	if target.Role == "Phantom" then
		participant.Takedown = true
	end
	local outcome = if target.Role == "Phantom"
		then "Caught"
		elseif Roles.team(target.Role) == "Shadows" then "Shadow"
		else "Innocent"
	feedback(participant, "Zap", outcome)
	Match.fire("Shot", participant, outcome)
	CombatService.knockDown(target, participant, "Zap")
	if zap.Shooter then
		participant.Misfired = true
		CombatService.knockDown(participant, nil, "Misfire")
		if participant.Player then
			RoundRemote:FireClient(
				participant.Player,
				{ Kind = "You", State = "Dazed", Seconds = Game.Seconds.Daze, Text = `{target.Name} was innocent!` }
			)
		end
	end
end

local function blackout(participant: Participant)
	local kit = kitOf(participant)
	local now = os.clock()
	if participant.Role ~= "Saboteur" or kit.Blackouts <= 0 then
		return
	end
	if now - Match.PlayingSince < CombatConfig.Blackout.NotBefore then
		return
	end
	if not CombatRules.ready(now, kit.LastBlackout, CombatConfig.Blackout.Cooldown, 0) then
		return
	end
	kit.Blackouts -= 1
	kit.LastBlackout = now
	participant.BlackoutsUsed += 1
	sendKit(participant)
	Match.fire("Blackout", participant)
	for _, other in Match.Participants do
		if other.Player then
			Fx:FireClient(other.Player, "Blackout", CombatConfig.Blackout.Seconds, other.Role == "Phantom")
		end
	end
	for _, player in Players:GetPlayers() do
		if not Match.get(player) then
			Fx:FireClient(player, "Blackout", CombatConfig.Blackout.Seconds, false)
		end
	end
end

local function revive(medic: Participant, targetId: unknown)
	local kit = kitOf(medic)
	if medic.Role ~= "Medic" or kit.Revives <= 0 or typeof(targetId) ~= "number" then
		return
	end
	local target = Match.byUserId(targetId :: number)
	if not target or not Round.canRevive(target.Role, target.State) then
		return
	end
	local a, b = Match.root(medic), Match.root(target)
	if not a or not b or (a.Position - b.Position).Magnitude > CombatConfig.Revive.Range + 2 then
		return
	end
	kit.Revives -= 1
	CombatService.revive(target, medic)
	sendKit(medic)
end

local function onAction(player: Player, action: unknown, ...: any)
	if typeof(action) ~= "string" or not actionLimiter:allow(player) then
		return
	end
	local participant = Match.get(player)
	if not participant or participant.State ~= "Alive" or Match.State ~= "Playing" then
		return
	end
	local kit = kitOf(participant)
	if action == "Draw" then
		local tool = kit.Blade or kit.Blaster
		if kit.Blade and os.clock() < Match.PlayingSince + Game.Seconds.Grace then
			return
		end
		if tool and not kit.Throwing then
			draw(participant, tool)
		end
		sendKit(participant)
	elseif action == "Holster" then
		holster(participant)
		sendKit(participant)
	elseif action == "Swing" then
		swing(participant, ...)
	elseif action == "Throw" then
		throw(participant, ...)
	elseif action == "Fire" then
		fire(participant, ...)
	elseif action == "Blackout" then
		blackout(participant)
	elseif action == "Revive" then
		revive(participant, ...)
	end
end

function CombatService.init()
	local folder = Instance.new("Folder")
	folder.Name = "RoleTools"
	folder.Parent = ServerStorage
	storage = folder
	Action.OnServerEvent:Connect(onAction)
	Players.PlayerRemoving:Connect(function(player)
		actionLimiter:forget(player)
	end)
end

return CombatService
