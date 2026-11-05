--!strict
-- Works out which monsters a player's weapon hits, on flat ground, from
-- where the player stands and where they aimed. The server calls this with
-- the player's real position (never the client's word for it), so a
-- client can choose where to aim but not what it hits.

local EnemySim = require(script.Parent.EnemySim)
local Weapons = require(script.Parent.Config.Weapons)

export type Hit = { Id: number, Damage: number }

export type Result = {
	Hits: { Hit },
	-- Where the shot landed, for the effects.
	ImpactX: number,
	ImpactZ: number,
}

local Combat = {}

local function unit(dx: number, dz: number): (number, number)
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.001 then
		return 0, -1
	end
	return dx / length, dz / length
end

-- Every monster within range (plus its own size) and within the cone's
-- full angle, in degrees, around the aim direction.
local function inCone(
	world: EnemySim.World,
	x: number,
	z: number,
	dirX: number,
	dirZ: number,
	range: number,
	angle: number
): { EnemySim.Enemy }
	local found = {}
	local cosHalf = math.cos(math.rad(angle / 2))
	for _, enemy in world.Enemies do
		local dx, dz = enemy.X - x, enemy.Z - z
		local d = math.sqrt(dx * dx + dz * dz)
		if d <= range + enemy.Def.Radius then
			-- Monsters right on top of the player always count.
			if d < enemy.Def.Radius + 1.5 or (dx * dirX + dz * dirZ) / d >= cosHalf then
				table.insert(found, enemy)
			end
		end
	end
	return found
end

-- The first monster along the aim, and how far along it is.
local function firstAlong(
	world: EnemySim.World,
	x: number,
	z: number,
	dirX: number,
	dirZ: number,
	range: number,
	assist: number
): (EnemySim.Enemy?, number)
	local best, bestT = nil, math.huge
	for _, enemy in world.Enemies do
		local dx, dz = enemy.X - x, enemy.Z - z
		local t = dx * dirX + dz * dirZ
		if t >= -enemy.Def.Radius and t <= range + enemy.Def.Radius then
			local px, pz = dx - dirX * t, dz - dirZ * t
			local off = math.sqrt(px * px + pz * pz)
			if off <= enemy.Def.Radius + assist and t < bestT then
				best, bestT = enemy, t
			end
		end
	end
	return best, bestT
end

-- The hits from one use of a weapon by a player at (x, z) aiming at
-- (aimX, aimZ). damageScale is the player's bonus (the Ranger's 25%, the
-- volley's double).
function Combat.resolve(
	world: EnemySim.World,
	weaponId: string,
	x: number,
	z: number,
	aimX: number,
	aimZ: number,
	damageScale: number
): Result
	local weapon = Weapons.ById[weaponId]
	assert(weapon, `unknown weapon {weaponId}`)
	local dirX, dirZ = unit(aimX - x, aimZ - z)
	local damage = weapon.Damage * damageScale
	local hits: { Hit } = {}
	local impactX, impactZ = x + dirX * weapon.Range, z + dirZ * weapon.Range

	if weapon.Kind == "Melee" or weapon.Kind == "Cone" then
		for _, enemy in inCone(world, x, z, dirX, dirZ, weapon.Range, weapon.Angle or 90) do
			table.insert(hits, { Id = enemy.Id, Damage = damage })
		end
		impactX, impactZ = x + dirX * weapon.Range * 0.6, z + dirZ * weapon.Range * 0.6
	elseif weapon.Kind == "Shot" then
		local enemy, t = firstAlong(world, x, z, dirX, dirZ, weapon.Range, weapon.AimAssist or 0)
		if enemy then
			table.insert(hits, { Id = enemy.Id, Damage = damage })
			impactX, impactZ = x + dirX * t, z + dirZ * t
		end
	elseif weapon.Kind == "Blast" then
		local enemy, t = firstAlong(world, x, z, dirX, dirZ, weapon.Range, weapon.AimAssist or 0)
		if enemy then
			impactX, impactZ = x + dirX * t, z + dirZ * t
		else
			-- Nothing in the way: it lands where the player aimed, if that is
			-- in range.
			local aimDistance = math.sqrt((aimX - x) ^ 2 + (aimZ - z) ^ 2)
			local reach = math.min(aimDistance, weapon.Range)
			impactX, impactZ = x + dirX * reach, z + dirZ * reach
		end
		local radius = weapon.Radius or 0
		for _, other in world.Enemies do
			local dx, dz = other.X - impactX, other.Z - impactZ
			if math.sqrt(dx * dx + dz * dz) <= radius + other.Def.Radius then
				table.insert(hits, { Id = other.Id, Damage = damage })
			end
		end
	end

	return { Hits = hits, ImpactX = impactX, ImpactZ = impactZ }
end

return Combat
