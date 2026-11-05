--!strict
-- The monsters' minds, as plain numbers on flat ground (X and Z). The server
-- steps this ten times a second and sends the positions to the clients,
-- which draw the monsters (client/Monsters), so no monster is a physics
-- object: hundreds of studs of walking cost a few additions, nothing gets
-- stuck on a fence post, and the tests can play whole nights in Lune.
--
-- Each step a monster picks a goal (the hearth, the nearest player it can
-- see, or the nearest building, by its kind's Prefers), walks at it, stops
-- at anything Solid in its way and hits that instead, and hits its goal when
-- it is close enough. Hits come back as events for the server to apply:
-- warmth off a player, health off a building, flame off the hearth.

local Enemies = require(script.Parent.Config.Enemies)
local Features = require(script.Parent.Config.Features)
local Structures = require(script.Parent.Config.Structures)

export type Enemy = {
	Id: number,
	Kind: string,
	Def: Enemies.Enemy,
	X: number,
	Z: number,
	Health: number,
	MaxHealth: number,
	Cooldown: number,
	-- Facing, in radians about Y (0 faces -Z).
	Heading: number,
	-- What the client should show: "Walk", "Attack" or "Idle", and for
	-- bosses "Windup" (a slam is coming) and "Tired" (out of breath).
	Action: "Walk" | "Attack" | "Idle" | "Windup" | "Tired",
	-- Seconds the Attack pose is held for.
	ActionTime: number,
	-- Guards stay within Leash of Home unless chasing.
	HomeX: number?,
	HomeZ: number?,
	Leash: number?,
	-- Seconds of slowness left (from the cold-resist-free Blaze Blower) and
	-- the speed multiplier while slowed.
	SlowTime: number,
	-- Bosses: seconds left winding up a slam and where it will land,
	-- seconds left out of breath, and how many roars it has done.
	Windup: number,
	WindX: number,
	WindZ: number,
	Tired: number,
	Roared: number,
}

export type Structure = {
	Id: number,
	Kind: string,
	X: number,
	Z: number,
	HalfW: number,
	HalfD: number,
	Solid: boolean,
	Health: number,
	MaxHealth: number,
	Cooldown: number,
}

export type Player = {
	X: number,
	Z: number,
	Frozen: boolean,
}

export type Obstacle = { X: number, Z: number, R: number }

export type World = {
	Enemies: { [number]: Enemy },
	Structures: { [number]: Structure },
	Players: { [any]: Player },
	Obstacles: { Obstacle },
	HearthX: number,
	HearthZ: number,
	-- The hearth's stone ring: monsters stop at its edge to hit it.
	HearthRadius: number,
	NextId: number,
}

export type Event = {
	Type: "Hit" | "Smash" | "Douse" | "Slam" | "Shoot" | "Down" | "Burn" | "Turret" | "Telegraph" | "Roar",
	Enemy: number?,
	Kind: string?,
	Player: any?,
	Structure: number?,
	Amount: number?,
	X: number?,
	Z: number?,
	ToX: number?,
	ToZ: number?,
	Radius: number?,
	By: any?,
}

local EnemySim = {}

-- How long a monster holds its attack pose.
local ATTACK_POSE = 0.4
-- How near a guard must be to home to stand still.
local HOME_SLACK = 3
-- How far a "Structures" monster looks for buildings to break.
local STRUCTURE_SIGHT = 40

function EnemySim.newWorld(hearthX: number, hearthZ: number, hearthRadius: number, obstacles: { Obstacle }?): World
	return {
		Enemies = {},
		Structures = {},
		Players = {},
		Obstacles = obstacles or {},
		HearthX = hearthX,
		HearthZ = hearthZ,
		HearthRadius = hearthRadius,
		NextId = 0,
	}
end

-- Adds a monster and returns it. health overrides its kind's health (for
-- bosses, whose health grows with the number of players).
function EnemySim.spawn(world: World, kind: string, x: number, z: number, health: number?): Enemy
	local def = Enemies.ById[kind]
	assert(def, `unknown monster {kind}`)
	-- Ids wrap at 65535 so they fit the snapshot's two bytes; there are
	-- never anywhere near that many alive.
	world.NextId = world.NextId % 65535 + 1
	while world.Enemies[world.NextId] do
		world.NextId = world.NextId % 65535 + 1
	end
	local maxHealth = health or def.Health
	local enemy: Enemy = {
		Id = world.NextId,
		Kind = kind,
		Def = def,
		X = x,
		Z = z,
		Health = maxHealth,
		MaxHealth = maxHealth,
		Cooldown = 0,
		Heading = math.atan2(-(world.HearthX - x), -(world.HearthZ - z)),
		Action = "Walk",
		ActionTime = 0,
		SlowTime = 0,
		Windup = 0,
		WindX = x,
		WindZ = z,
		Tired = 0,
		Roared = 0,
	}
	world.Enemies[enemy.Id] = enemy
	return enemy
end

-- Adds a monster that guards a spot: it waits there, chases players who
-- come near, and goes back when they get away.
function EnemySim.spawnGuard(world: World, kind: string, x: number, z: number, leash: number): Enemy
	local enemy = EnemySim.spawn(world, kind, x, z)
	enemy.HomeX = x
	enemy.HomeZ = z
	enemy.Leash = leash
	enemy.Action = "Idle"
	return enemy
end

-- The footprint of a structure of this kind turned this many quarter turns,
-- as half its width along X and half its depth along Z.
function EnemySim.footprint(kind: string, turns: number): (number, number)
	local def = Structures.ById[kind]
	local w, d = def.Width / 2, def.Depth / 2
	if turns % 2 == 1 then
		return d, w
	end
	return w, d
end

function EnemySim.addStructure(
	world: World,
	id: number,
	kind: string,
	x: number,
	z: number,
	turns: number,
	healthScale: number?
): Structure
	local def = Structures.ById[kind]
	local halfW, halfD = EnemySim.footprint(kind, turns)
	local health = def.Health * (healthScale or 1)
	local structure: Structure = {
		Id = id,
		Kind = kind,
		X = x,
		Z = z,
		HalfW = halfW,
		HalfD = halfD,
		Solid = def.Solid,
		Health = health,
		MaxHealth = health,
		Cooldown = 0,
	}
	world.Structures[id] = structure
	return structure
end

local function distance(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	return math.sqrt(dx * dx + dz * dz)
end

-- Distance from a point to the edge of a structure's footprint (0 inside).
function EnemySim.distanceToStructure(structure: Structure, x: number, z: number): number
	local dx = math.max(math.abs(x - structure.X) - structure.HalfW, 0)
	local dz = math.max(math.abs(z - structure.Z) - structure.HalfD, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function nearestPlayer(world: World, x: number, z: number, range: number): (any, Player?, number)
	local bestKey, best, bestDistance = nil, nil, range
	for key, player in world.Players do
		if not player.Frozen then
			local d = distance(x, z, player.X, player.Z)
			if d <= bestDistance then
				bestKey, best, bestDistance = key, player, d
			end
		end
	end
	return bestKey, best, bestDistance
end

local function nearestStructure(world: World, x: number, z: number, range: number): Structure?
	local best, bestDistance = nil, range
	for _, structure in world.Structures do
		local d = EnemySim.distanceToStructure(structure, x, z)
		if d <= bestDistance then
			best, bestDistance = structure, d
		end
	end
	return best
end

-- The solid structure a monster of this radius would stand inside at (x, z).
local function blockedBy(world: World, x: number, z: number, radius: number): Structure?
	for _, structure in world.Structures do
		if structure.Solid and EnemySim.distanceToStructure(structure, x, z) < radius then
			return structure
		end
	end
	return nil
end

local function face(enemy: Enemy, x: number, z: number)
	local dx, dz = x - enemy.X, z - enemy.Z
	if dx * dx + dz * dz > 0.0001 then
		enemy.Heading = math.atan2(-dx, -dz)
	end
end

local function strike(enemy: Enemy)
	enemy.Cooldown = enemy.Def.Rate
	enemy.Action = "Attack"
	enemy.ActionTime = ATTACK_POSE
end

-- Whether this monster uses the boss phases (wind-up, tired, roars).
local function phased(enemy: Enemy): boolean
	return Features.BossPhases and enemy.Def.Boss == true and enemy.Def.Windup ~= nil
end

-- A boss's slam hits every player and building within its radius of a
-- spot (and the hearth, if the spot is at the hearth's edge).
local function slamAt(world: World, enemy: Enemy, x: number, z: number, events: { Event }, douse: boolean)
	local def = enemy.Def
	local radius = def.Slam :: number
	table.insert(events, { Type = "Slam", Enemy = enemy.Id, X = x, Z = z, Radius = radius })
	for key, player in world.Players do
		if not player.Frozen and distance(x, z, player.X, player.Z) <= radius + def.Reach * 0.5 then
			table.insert(events, { Type = "Hit", Enemy = enemy.Id, Player = key, Amount = def.Hit })
		end
	end
	for _, structure in world.Structures do
		if EnemySim.distanceToStructure(structure, x, z) <= radius then
			table.insert(events, { Type = "Smash", Enemy = enemy.Id, Structure = structure.Id, Amount = def.Smash })
		end
	end
	if douse and distance(x, z, world.HearthX, world.HearthZ) <= world.HearthRadius + def.Reach + 1 then
		table.insert(events, { Type = "Douse", Enemy = enemy.Id, Amount = def.Douse })
	end
end

local function slam(world: World, enemy: Enemy, events: { Event })
	if phased(enemy) then
		-- Wind up first: the slam lands where the boss stands now, after
		-- Windup seconds, so players can see it coming and step out.
		enemy.Windup = enemy.Def.Windup :: number
		enemy.WindX, enemy.WindZ = enemy.X, enemy.Z
		enemy.Action = "Windup"
		table.insert(events, {
			Type = "Telegraph",
			Enemy = enemy.Id,
			X = enemy.X,
			Z = enemy.Z,
			Radius = enemy.Def.Slam,
			Amount = enemy.Windup,
		})
		return
	end
	slamAt(world, enemy, enemy.X, enemy.Z, events, false)
end

-- A boss's turn while it winds up, is out of breath or roars. Returns true
-- if that took its whole turn.
local function bossTurn(world: World, enemy: Enemy, dt: number, events: { Event }): boolean
	if not phased(enemy) then
		return false
	end
	local def = enemy.Def
	local roars = def.Roars or {}
	local next = roars[enemy.Roared + 1]
	if next and enemy.Health / enemy.MaxHealth <= next then
		enemy.Roared += 1
		table.insert(events, {
			Type = "Roar",
			Enemy = enemy.Id,
			Kind = def.Summon,
			X = enemy.X,
			Z = enemy.Z,
			Amount = def.SummonCount or 0,
		})
	end
	if enemy.Windup > 0 then
		enemy.Windup -= dt
		enemy.Action = "Windup"
		if enemy.Windup <= 0 then
			enemy.Windup = 0
			slamAt(world, enemy, enemy.WindX, enemy.WindZ, events, true)
			enemy.Tired = def.Tired or 0
			enemy.Action = "Tired"
			enemy.Cooldown = math.max(enemy.Cooldown, enemy.Tired)
		end
		return true
	end
	if enemy.Tired > 0 then
		enemy.Tired = math.max(0, enemy.Tired - dt)
		enemy.Action = if enemy.Tired > 0 then "Tired" else "Idle"
		return true
	end
	return false
end

local function hitPlayer(world: World, enemy: Enemy, key: any, player: Player, events: { Event })
	face(enemy, player.X, player.Z)
	strike(enemy)
	if enemy.Def.Slam then
		slam(world, enemy, events)
		return
	end
	local ranged = enemy.Def.Reach > 10
	if ranged then
		table.insert(events, {
			Type = "Shoot",
			Enemy = enemy.Id,
			X = enemy.X,
			Z = enemy.Z,
			ToX = player.X,
			ToZ = player.Z,
		})
	end
	table.insert(events, { Type = "Hit", Enemy = enemy.Id, Player = key, Amount = enemy.Def.Hit })
end

local function hitStructure(world: World, enemy: Enemy, structure: Structure, events: { Event })
	face(enemy, structure.X, structure.Z)
	strike(enemy)
	if enemy.Def.Slam then
		slam(world, enemy, events)
		return
	end
	table.insert(events, { Type = "Smash", Enemy = enemy.Id, Structure = structure.Id, Amount = enemy.Def.Smash })
end

local function hitHearth(world: World, enemy: Enemy, events: { Event })
	face(enemy, world.HearthX, world.HearthZ)
	strike(enemy)
	if enemy.Def.Slam then
		slam(world, enemy, events)
		if phased(enemy) then
			-- The douse lands with the slam.
			return
		end
	end
	table.insert(events, { Type = "Douse", Enemy = enemy.Id, Amount = enemy.Def.Douse })
end

-- Moves a monster toward (x, z), up to step studs. Returns the solid
-- structure that stopped it, if one did.
local function walk(world: World, enemy: Enemy, x: number, z: number, step: number): Structure?
	local dx, dz = x - enemy.X, z - enemy.Z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.001 then
		return nil
	end
	local move = math.min(step, length)
	local nx = enemy.X + dx / length * move
	local nz = enemy.Z + dz / length * move
	face(enemy, x, z)
	enemy.Action = "Walk"
	local def = enemy.Def
	if not def.Flying then
		local wall = blockedBy(world, nx, nz, def.Radius)
		if wall then
			return wall
		end
		-- Slide round the big things in town rather than through them.
		for _, obstacle in world.Obstacles do
			local ox, oz = nx - obstacle.X, nz - obstacle.Z
			local reach = obstacle.R + def.Radius
			local d = math.sqrt(ox * ox + oz * oz)
			if d < reach and d > 0.001 then
				nx = obstacle.X + ox / d * reach
				nz = obstacle.Z + oz / d * reach
			end
		end
	end
	enemy.X, enemy.Z = nx, nz
	return nil
end

local function think(world: World, enemy: Enemy, dt: number, events: { Event })
	local def = enemy.Def
	enemy.Cooldown -= dt
	enemy.SlowTime = math.max(0, enemy.SlowTime - dt)
	if enemy.ActionTime > 0 then
		enemy.ActionTime -= dt
	end
	if bossTurn(world, enemy, dt, events) then
		return
	end
	local ready = enemy.Cooldown <= 0
	local speed = def.Speed * (if enemy.SlowTime > 0 then 0.6 else 1)
	local step = speed * dt

	-- Anyone within reach gets hit first, whatever the monster was after.
	local key, player, playerDistance = nearestPlayer(world, enemy.X, enemy.Z, def.Sight)
	if player and playerDistance <= def.Reach + 1 then
		if ready then
			hitPlayer(world, enemy, key, player, events)
		elseif enemy.ActionTime <= 0 then
			enemy.Action = "Idle"
		end
		-- Ranged monsters keep their distance; the rest stand and swing.
		if def.Reach > 10 and playerDistance < def.Reach * 0.6 then
			local away = playerDistance > 0.001 and playerDistance or 1
			walk(
				world,
				enemy,
				enemy.X - (player.X - enemy.X) / away * 4,
				enemy.Z - (player.Z - enemy.Z) / away * 4,
				step
			)
			face(enemy, player.X, player.Z)
		end
		return
	end

	-- Guards.
	if enemy.HomeX and enemy.HomeZ and enemy.Leash then
		local homeX, homeZ = enemy.HomeX :: number, enemy.HomeZ :: number
		if player and distance(homeX, homeZ, player.X, player.Z) <= (enemy.Leash :: number) then
			walk(world, enemy, player.X, player.Z, step)
		elseif distance(enemy.X, enemy.Z, homeX, homeZ) > HOME_SLACK then
			walk(world, enemy, homeX, homeZ, step)
		elseif enemy.ActionTime <= 0 then
			enemy.Action = "Idle"
		end
		return
	end

	-- Pick a goal.
	local goalX, goalZ = world.HearthX, world.HearthZ
	local goalStructure: Structure? = nil
	if def.Prefers == "Players" and player then
		goalX, goalZ = player.X, player.Z
	elseif def.Prefers == "Structures" then
		goalStructure = nearestStructure(world, enemy.X, enemy.Z, STRUCTURE_SIGHT)
		if goalStructure then
			goalX, goalZ = goalStructure.X, goalStructure.Z
		end
	end

	-- Close enough to hit the goal?
	if goalStructure then
		if EnemySim.distanceToStructure(goalStructure, enemy.X, enemy.Z) <= def.Reach then
			if ready then
				hitStructure(world, enemy, goalStructure, events)
			end
			return
		end
	elseif not player or def.Prefers ~= "Players" then
		local toHearth = distance(enemy.X, enemy.Z, world.HearthX, world.HearthZ)
		if toHearth <= world.HearthRadius + def.Reach then
			if ready then
				hitHearth(world, enemy, events)
			end
			return
		end
	end

	local wall = walk(world, enemy, goalX, goalZ, step)
	if wall then
		face(enemy, wall.X, wall.Z)
		if ready then
			hitStructure(world, enemy, wall, events)
		elseif enemy.ActionTime <= 0 then
			enemy.Action = "Idle"
		end
	end
end

-- Pushes overlapping monsters apart, so a crowd spreads out instead of
-- stacking on one spot.
local function separate(world: World)
	local list = {}
	for _, enemy in world.Enemies do
		table.insert(list, enemy)
	end
	for i = 1, #list do
		local a = list[i]
		for j = i + 1, #list do
			local b = list[j]
			if a.Def.Flying == b.Def.Flying then
				local dx, dz = b.X - a.X, b.Z - a.Z
				local reach = (a.Def.Radius + b.Def.Radius) * 0.8
				local d2 = dx * dx + dz * dz
				if d2 < reach * reach then
					local d = math.sqrt(d2)
					if d < 0.001 then
						dx, dz, d = 1, 0, 1
					end
					local push = (reach - d) * 0.5
					a.X -= dx / d * push
					a.Z -= dz / d * push
					b.X += dx / d * push
					b.Z += dz / d * push
				end
			end
		end
	end
end

-- Damages a monster. When it runs out of health it is removed and a Down
-- event names who knocked it out. A boss out of breath takes double.
function EnemySim.damage(world: World, id: number, amount: number, by: any, events: { Event }): boolean
	local enemy = world.Enemies[id]
	if not enemy or amount <= 0 then
		return false
	end
	if enemy.Tired > 0 then
		amount *= 2
	end
	enemy.Health -= amount
	if enemy.Health <= 0 then
		world.Enemies[id] = nil
		table.insert(events, { Type = "Down", Enemy = id, Kind = enemy.Kind, X = enemy.X, Z = enemy.Z, By = by })
		return true
	end
	return false
end

-- Turrets shoot and traps burn. Turrets aim at the nearest monster in range.
local function defend(world: World, dt: number, events: { Event })
	for _, structure in world.Structures do
		local def = Structures.ById[structure.Kind]
		if def.Burn then
			for id, enemy in world.Enemies do
				if
					not enemy.Def.Flying
					and math.abs(enemy.X - structure.X) <= structure.HalfW
					and math.abs(enemy.Z - structure.Z) <= structure.HalfD
				then
					EnemySim.damage(world, id, def.Burn * dt, structure.Id, events)
				end
			end
		elseif def.Damage and def.Range and def.Cooldown then
			structure.Cooldown -= dt
			if structure.Cooldown <= 0 then
				local target, bestDistance = nil, def.Range
				for _, enemy in world.Enemies do
					local d = distance(structure.X, structure.Z, enemy.X, enemy.Z)
					if d <= bestDistance then
						target, bestDistance = enemy, d
					end
				end
				if target then
					structure.Cooldown = def.Cooldown
					table.insert(events, {
						Type = "Turret",
						Structure = structure.Id,
						X = structure.X,
						Z = structure.Z,
						ToX = target.X,
						ToZ = target.Z,
						Radius = def.Splash,
					})
					if def.Splash then
						local hitX, hitZ = target.X, target.Z
						for id, enemy in world.Enemies do
							if distance(hitX, hitZ, enemy.X, enemy.Z) <= def.Splash + enemy.Def.Radius then
								EnemySim.damage(world, id, def.Damage, structure.Id, events)
							end
						end
					else
						EnemySim.damage(world, target.Id, def.Damage, structure.Id, events)
					end
				end
			end
		end
	end
end

-- Moves the world on by dt seconds. Returns the events that happened, for
-- the server to apply (the sim never changes players, buildings' health or
-- the hearth itself; it only says what hit what).
function EnemySim.step(world: World, dt: number): { Event }
	local events: { Event } = {}
	for _, enemy in world.Enemies do
		think(world, enemy, dt, events)
	end
	separate(world)
	defend(world, dt, events)
	return events
end

function EnemySim.count(world: World): number
	local count = 0
	for _ in world.Enemies do
		count += 1
	end
	return count
end

-- Removes every monster (at dawn they melt back into the snow), except
-- guards when keepGuards is set. Returns the removed monsters.
function EnemySim.clear(world: World, keepGuards: boolean?): { Enemy }
	local removed = {}
	for id, enemy in world.Enemies do
		if not (keepGuards and enemy.Leash) then
			world.Enemies[id] = nil
			table.insert(removed, enemy)
		end
	end
	return removed
end

return EnemySim
