-- The PvP arena: a raised round stage past the bonfire where players fight
-- only if they choose to. Walking onto the stage makes a player a fighter, and
-- walking off makes them safe again. A fighter with no weapon is lent the
-- theme's bonker, which is taken back when they leave.
--
-- Fighters hit each other with any Tool carrying a Weapon attribute (see
-- Config/Weapons) and with that weapon's special move. Every hit is decided
-- here: a client only says it swung (the Tool's Activated) or used its special
-- (the ArenaAction remote), and the server checks the cooldown, finds who was
-- in reach, deals the damage and tells every client to draw it through the
-- ArenaEffect remote. A hit player's own client throws them, since it moves
-- their character. Nobody outside the stage can hit or be hit, and nothing
-- about a fight touches coins.
--
-- A player knocked down to no health isn't killed: they lie dizzy for a
-- moment and are put back outside the entrance, and whoever knocked them out
-- scores a KO, which is saved and shown on the leaderboard.
--
-- If the place has no Workspace.Arena with a Stage part, the stage and its
-- ramp are made here; WorldService then dresses them with the theme.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Arena = require(Shared.Config.Arena)
local Layout = require(Shared.Config.Layout)
local Theme = require(Shared.Config.Theme)
local Weapons = require(Shared.Config.Weapons)
local Combat = require(Shared.Combat)
local DataService = require(script.Parent.DataService)

local ArenaAction = ReplicatedStorage.Remotes.ArenaAction :: RemoteEvent
local ArenaEffect = ReplicatedStorage.Remotes.ArenaEffect :: RemoteEvent

local CHECK_SECONDS = 0.1
-- How high above the stage someone still counts as in the arena, so a jump or
-- a hit that throws them up doesn't take them out of it.
local CEILING = 30
-- The plaza's depth, as PlotService makes it, for places without a Plaza.
local PLAZA_DEPTH = 40

type Fighter = {
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	ShieldUntil: number,
	LastSwing: number,
	LastSpecial: number,
	KnockedOut: boolean,
	Streak: number,
}

local ArenaService = {}

local fighters: { [Player]: Fighter } = {}
local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local centre = Vector3.zero
local exitPoint = CFrame.identity
local bonker: Tool? = nil

local function weaponOf(id: any)
	return if type(id) == "string" then rawget(Weapons, id) else nil
end

local function isWeapon(instance: Instance): boolean
	return instance:IsA("Tool") and weaponOf(instance:GetAttribute("Weapon")) ~= nil
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Where the stage goes: Distance past the back edge of the plaza, on its
-- centre line.
local function stageCentre(): Vector3
	local plaza = Workspace:FindFirstChild("Plaza")
	if plaza and plaza:IsA("BasePart") then
		local back = plaza.Position.Z + plaza.Size.Z / 2
		return Vector3.new(plaza.Position.X, Arena.Height, back + Arena.Distance)
	end
	return Vector3.new(0, Arena.Height, Layout.PlotSize / 2 + PLAZA_DEPTH + Arena.Distance)
end

local function makeStage(): BasePart
	local model = Instance.new("Model")
	model.Name = "Arena"
	local at = stageCentre()
	local height = Arena.Height

	-- A round stage sunk a stud into the ground. Cylinders lie along X, so it
	-- is turned upright.
	local stage = Instance.new("Part")
	stage.Name = "Stage"
	stage.Anchored = true
	stage.Shape = Enum.PartType.Cylinder
	stage.Size = Vector3.new(height + 1, Arena.Radius * 2, Arena.Radius * 2)
	stage.CFrame = CFrame.new(at.X, (height - 1) / 2, at.Z) * CFrame.Angles(0, 0, math.pi / 2)
	stage.TopSurface = Enum.SurfaceType.Smooth
	stage.BottomSurface = Enum.SurfaceType.Smooth
	stage.Color = Color3.fromRGB(90, 86, 104)
	stage.Parent = model

	-- A ramp up to the entrance, which faces the plaza (-Z). A wedge's high
	-- edge is at its back, so it rises towards the stage, and it reaches a
	-- stud onto the stage so there is no seam to trip on.
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Anchored = true
	ramp.Size = Vector3.new(Arena.EntranceWidth, height, Arena.RampLength)
	ramp.CFrame = CFrame.new(at.X, height / 2, at.Z - Arena.Radius - Arena.RampLength / 2 + 1)
	ramp.TopSurface = Enum.SurfaceType.Smooth
	ramp.BottomSurface = Enum.SurfaceType.Smooth
	ramp.Color = stage.Color
	ramp.Parent = model

	model.PrimaryPart = stage
	model.Parent = Workspace
	return stage
end

local function stageTop(stage: BasePart): Vector3
	local height = if stage.Shape == Enum.PartType.Cylinder then stage.Size.X else stage.Size.Y
	return stage.Position + Vector3.new(0, height / 2, 0)
end

local function setKOs(player: Player, count: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(Theme.Strings.ArenaKOs)
	if value and value:IsA("IntValue") then
		value.Value = count
	end
end

-- A weapon the player already has, held or in their backpack.
local function weaponIn(player: Player, character: Model): Tool?
	for _, holder in { character, player:FindFirstChildOfClass("Backpack") } do
		if holder then
			for _, child in holder:GetChildren() do
				if isWeapon(child) then
					return child :: Tool
				end
			end
		end
	end
	return nil
end

-- The other fighters who can be hit right now.
local function targets(except: Player): { Combat.Fighter }
	local list = {}
	for player, fighter in fighters do
		if player ~= except and not fighter.KnockedOut and fighter.Humanoid.Health > 0 and fighter.Root.Parent then
			table.insert(list, { Id = player, Position = fighter.Root.Position })
		end
	end
	return list
end

local function enter(player: Player, character: Model, humanoid: Humanoid, root: BasePart)
	local now = os.clock()
	fighters[player] = {
		Character = character,
		Humanoid = humanoid,
		Root = root,
		ShieldUntil = now + Arena.ShieldSeconds,
		LastSwing = -math.huge,
		LastSpecial = -math.huge,
		KnockedOut = false,
		Streak = 0,
	}
	player:SetAttribute("InArena", true)
	humanoid.MaxHealth = Arena.Health
	humanoid.Health = Arena.Health

	local shield = Instance.new("ForceField")
	shield.Name = "ArenaShield"
	shield.Parent = character
	Debris:AddItem(shield, Arena.ShieldSeconds)

	local weapon = weaponIn(player, character)
	if not weapon and bonker then
		local loaner = bonker:Clone()
		loaner:SetAttribute("Loaner", true)
		loaner.Parent = player:FindFirstChildOfClass("Backpack")
		weapon = loaner
	end
	if weapon and weapon.Parent ~= character then
		humanoid:EquipTool(weapon)
	end
end

local function leave(player: Player)
	local fighter = fighters[player]
	if not fighter then
		return
	end
	fighters[player] = nil
	player:SetAttribute("InArena", nil)
	player:SetAttribute("KnockedOut", nil)
	player:SetAttribute("ArenaStreak", nil)
	for _, holder in { fighter.Character, player:FindFirstChildOfClass("Backpack") } do
		if holder then
			for _, child in holder:GetChildren() do
				if (child:IsA("Tool") and child:GetAttribute("Loaner")) or child.Name == "ArenaShield" then
					child:Destroy()
				end
			end
		end
	end
	if fighter.Humanoid.Health > 0 then
		fighter.Humanoid.Health = fighter.Humanoid.MaxHealth
	end
end

-- Scores a KO for the attacker: saved, on the leaderboard, and counted
-- towards their streak for this visit to the arena.
local function score(attacker: Player)
	local data = DataService.get(attacker)
	if data then
		data.Arena.KOs += 1
		setKOs(attacker, data.Arena.KOs)
	end
	local fighter = fighters[attacker]
	if fighter then
		fighter.Streak += 1
		attacker:SetAttribute("ArenaStreak", fighter.Streak)
	end
end

local function knockOut(attacker: Player, victim: Player, fighter: Fighter, velocity: Vector3, weaponId: string)
	fighter.KnockedOut = true
	victim:SetAttribute("KnockedOut", true)
	fighter.Humanoid.Health = 1
	-- Scored first, so the attacker's streak has arrived when they hear of it.
	score(attacker)
	local throw = Vector3.new(velocity.X * Arena.KnockoutThrow, Arena.KnockoutLift, velocity.Z * Arena.KnockoutThrow)
	ArenaEffect:FireAllClients("KnockOut", victim, attacker, weaponId, throw)

	task.delay(Arena.KnockedOutSeconds, function()
		-- Unless they left, reset or left the game while dizzy.
		if fighters[victim] ~= fighter then
			return
		end
		if fighter.Character.Parent and fighter.Humanoid.Health > 0 then
			fighter.Character:PivotTo(exitPoint)
			fighter.Humanoid.Health = fighter.Humanoid.MaxHealth
		end
		leave(victim)
	end)
end

-- Deals a hit, unless the victim is shielded or already knocked out.
local function hit(attacker: Player, victim: Player, damage: number, velocity: Vector3, weaponId: string)
	local fighter = fighters[victim]
	if not fighter or fighter.KnockedOut or os.clock() < fighter.ShieldUntil then
		return
	end
	local health = fighter.Humanoid.Health - damage
	if health > 0 then
		fighter.Humanoid.Health = health
		ArenaEffect:FireAllClients("Hit", victim, attacker, weaponId, velocity)
	else
		knockOut(attacker, victim, fighter, velocity, weaponId)
	end
end

local function swing(player: Player, tool: Tool)
	local fighter = fighters[player]
	local weaponId = tool:GetAttribute("Weapon")
	local weapon = weaponOf(weaponId)
	if not fighter or fighter.KnockedOut or not weapon or tool.Parent ~= fighter.Character then
		return
	end
	local now = os.clock()
	if not Combat.ready(now, fighter.LastSwing, weapon.Cooldown, Arena.CooldownSlack) then
		return
	end
	fighter.LastSwing = now
	local root = fighter.Root
	local facing = root.CFrame.LookVector
	local target = Combat.swingTarget(root.Position, facing, targets(player), weapon.Reach, weapon.Arc, Arena.HitHeight)
	if target then
		local velocity = Combat.knockback(root.Position, target.Position, facing, weapon.Knockback, Arena.Lift)
		hit(player, target.Id, weapon.Damage, velocity, weaponId)
	end
end

-- Runs the special move of the weapon the player holds. The player's own
-- client moves them for a leap or a charge, so this follows where they go;
-- a charge only counts as far as it could really reach.
local function special(player: Player)
	local fighter = fighters[player]
	local tool = fighter and fighter.Character:FindFirstChildOfClass("Tool")
	local weaponId = tool and tool:GetAttribute("Weapon")
	local weapon = weaponOf(weaponId)
	if not fighter or fighter.KnockedOut or not weapon then
		return
	end
	local move = weapon.Special
	local now = os.clock()
	if not Combat.ready(now, fighter.LastSpecial, move.Cooldown, Arena.CooldownSlack) then
		return
	end
	fighter.LastSpecial = now

	local root = fighter.Root
	local start, facing = root.Position, root.CFrame.LookVector
	local ahead = flat(facing).Unit
	ArenaEffect:FireAllClients("Special", player, weaponId, start, ahead)

	local struck: { [Player]: boolean } = {}
	local function strike(found: { Combat.Fighter }, from: Vector3?)
		for _, target in found do
			if not struck[target.Id] then
				struck[target.Id] = true
				local origin = from or target.Position - ahead
				local velocity = Combat.knockback(origin, target.Position, ahead, move.Knockback, Arena.Lift)
				hit(player, target.Id, move.Damage, velocity, weaponId)
			end
		end
	end
	local function still(): boolean
		return fighters[player] == fighter and not fighter.KnockedOut
	end

	if move.Kind == "Slam" then
		task.wait(move.Delay)
		if still() then
			local landing = root.Position
			strike(Combat.within(landing, targets(player), move.Radius, Arena.HitHeight + 4), landing)
			ArenaEffect:FireAllClients("Impact", player, weaponId, landing)
		end
	elseif move.Kind == "Spin" then
		for _ = 1, 3 do
			if not still() then
				break
			end
			strike(Combat.within(root.Position, targets(player), move.Radius, Arena.HitHeight), root.Position)
			task.wait(move.Seconds / 3)
		end
	elseif move.Kind == "Dash" then
		local last = start
		local deadline = now + move.Seconds + 0.15
		while still() and os.clock() < deadline do
			local here = root.Position
			if flat(here - start).Magnitude > move.Distance + 6 then
				break
			end
			strike(Combat.along(last, here, targets(player), move.Width, Arena.HitHeight), here)
			last = here
			task.wait(1 / 20)
		end
	elseif move.Kind == "Wave" then
		local from = start
		local travelled = 0
		local step = 1 / 20
		while travelled < move.Distance do
			local advance = math.min(move.Speed * step, move.Distance - travelled)
			local to = from + ahead * advance
			local first = Combat.along(from, to, targets(player), move.Width, Arena.HitHeight)[1]
			if first then
				strike({ first }, nil)
				ArenaEffect:FireAllClients("Impact", player, weaponId, first.Position)
				break
			end
			travelled += advance
			from = to
			task.wait(step)
		end
	end
end

-- Listens to swings of every weapon a player equips, once per Tool.
local function watchCharacter(player: Player, character: Model)
	local function hook(child: Instance)
		if child:IsA("Tool") and not hooked[child] then
			hooked[child] = true
			child.Activated:Connect(function()
				swing(player, child)
			end)
		end
	end
	for _, child in character:GetChildren() do
		hook(child)
	end
	character.ChildAdded:Connect(hook)
end

local function watchPlayer(player: Player)
	if player.Character then
		watchCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		leave(player)
		watchCharacter(player, character)
	end)
end

-- Makes fighters of everyone standing in the arena, and makes everyone else
-- safe. A knocked-out fighter stays one until they are put outside.
local function check()
	for _, player in Players:GetPlayers() do
		local fighter = fighters[player]
		if not (fighter and fighter.KnockedOut) then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local inside = humanoid ~= nil
				and root ~= nil
				and root:IsA("BasePart")
				and humanoid.Health > 0
				and Combat.isInside(centre, Arena.Radius - 1, CEILING, root.Position)
			if fighter and (not inside or fighter.Character ~= character) then
				leave(player)
				fighter = nil
			end
			if inside and not fighter then
				enter(player, character :: Model, humanoid :: Humanoid, root :: BasePart)
			end
		end
	end
end

function ArenaService.init()
	local folder = Workspace:FindFirstChild("Arena")
	local found = folder and folder:FindFirstChild("Stage")
	local stage = if found and found:IsA("BasePart") then found else makeStage()
	centre = stageTop(stage)
	-- Outside the entrance, facing back in.
	local outside = centre
		- Vector3.new(0, Arena.Height, Arena.Radius + Arena.RampLength + Arena.ExitDistance)
		+ Vector3.new(0, 3, 0)
	exitPoint = CFrame.lookAt(outside, Vector3.new(centre.X, outside.Y, centre.Z))

	bonker = Theme.Arena.bonker()

	DataService.onLoaded(function(player, data)
		local leaderstats = player:WaitForChild("leaderstats", 10)
		if leaderstats and player.Parent then
			local value = Instance.new("IntValue")
			value.Name = Theme.Strings.ArenaKOs
			value.Value = data.Arena.KOs
			value.Parent = leaderstats
		end
	end)

	ArenaAction.OnServerEvent:Connect(function(player, action)
		if action == "Special" then
			special(player)
		end
	end)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		fighters[player] = nil
	end)
end

function ArenaService.start()
	while true do
		check()
		task.wait(CHECK_SECONDS)
	end
end

return ArenaService
