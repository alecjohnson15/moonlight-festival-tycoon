-- The monsters. Each night's wave (shared/Waves) comes out of the blizzard
-- at the edge of the valley; by day a few guards wait at each landmark
-- that still has its radio part. The server steps the monster world
-- (shared/EnemySim) ten times a second, applies what it reports (warmth
-- off players, health off buildings, flame off the hearth) and sends every
-- client a compact snapshot to draw from (shared/Codec). Players' weapons
-- aim into the same world here (shared/Combat).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Enemies = require(ReplicatedStorage.Shared.Config.Enemies)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Codec = require(ReplicatedStorage.Shared.Codec)
local Combat = require(ReplicatedStorage.Shared.Combat)
local EnemySim = require(ReplicatedStorage.Shared.EnemySim)
local Waves = require(ReplicatedStorage.Shared.Waves)
local Lib = script.Parent.Parent.Lib
local Net = require(Lib.Net)
local RunStats = require(Lib.RunStats)
local Sim = require(Lib.Sim)
local BuildService = require(script.Parent.BuildService)
local GameLoop = require(script.Parent.GameLoop)
local PlayerService = require(script.Parent.PlayerService)
local TeamService = require(script.Parent.TeamService)
local WorldService = require(script.Parent.WorldService)

local MonsterService = {}

local TICK = 0.1

local pending: { Waves.Spawn } = {}
local spawnPoints: { Vector3 } = {}
local lastShot: { [Player]: { [string]: number } } = {}
local random = Random.new()
local snapshot: RemoteEvent

local function roll(): number
	return random:NextNumber()
end

local function credit(by: any): Player?
	if typeof(by) == "Instance" and by:IsA("Player") then
		return by
	end
	return nil
end

-- Applies what the sim reported.
local function apply(events: { EnemySim.Event })
	local downs = {}
	for _, event in events do
		local kind = event.Type
		if kind == "Hit" then
			PlayerService.chill(event.Player, event.Amount :: number)
		elseif kind == "Smash" then
			BuildService.damage(event.Structure :: number, event.Amount :: number)
		elseif kind == "Douse" then
			TeamService.douse(event.Amount :: number)
			Net.fx("Douse", { Enemy = event.Enemy })
		elseif kind == "Slam" then
			Net.fx("Slam", { X = event.X, Z = event.Z, Radius = event.Radius })
		elseif kind == "Shoot" then
			Net.fx("IceShard", { X = event.X, Z = event.Z, ToX = event.ToX, ToZ = event.ToZ })
		elseif kind == "Turret" then
			Net.fx("Turret", { Structure = event.Structure, ToX = event.ToX, ToZ = event.ToZ, Splash = event.Radius })
		elseif kind == "Down" then
			table.insert(downs, { Enemy = event.Enemy, Kind = event.Kind, X = event.X, Z = event.Z })
			local player = credit(event.By)
			if player then
				RunStats.knockout(player)
			end
			local def = Enemies.ById[event.Kind :: string]
			if def and def.Boss then
				if event.Kind == "Yeti" then
					RunStats.team().BeatYeti = true
				end
				Net.notice(nil, `{def.Name} ran off into the blizzard!`, "Big")
				Net.fx("BossDown", { X = event.X, Z = event.Z })
			end
		end
	end
	if #downs > 0 then
		Net.fx("Down", { List = downs })
	end
end

local function spawnAt(kind: string, point: number)
	local at = spawnPoints[point] or spawnPoints[1]
	local jitter = Vector3.new(random:NextNumber(-12, 12), 0, random:NextNumber(-12, 12))
	local def = Enemies.ById[kind]
	local health = if def.Boss then Waves.bossHealth(kind, #Players:GetPlayers()) else nil
	local enemy = EnemySim.spawn(Sim, kind, at.X + jitter.X, at.Z + jitter.Z, health)
	if def.Boss then
		Net.notice(nil, `{def.Name} is coming! Everyone to the hearth!`, "Big")
		Net.fx("Boss", { Kind = kind, Id = enemy.Id })
	end
end

local function planNight(night: number)
	local count = math.max(1, #Players:GetPlayers())
	local list = Waves.compose(night, count, roll)
	pending = Waves.schedule(list, Waves.boss(night), Balance.Phases.Night, roll)
end

-- Spawns a landmark's guards at a spot (ObjectiveService calls this each
-- morning for the landmarks whose radio part is still there).
function MonsterService.guard(position: Vector3, night: number)
	local count = Balance.Waves.GuardsPerLandmark + math.floor(night / 3)
	for index = 1, count do
		local angle = index / count * math.pi * 2
		local kind = if index == 1 and night >= 3
			then "SnowBrute"
			elseif index % 2 == 0 and night >= 2 then "SnowHound"
			else "Frostling"
		EnemySim.spawnGuard(Sim, kind, position.X + math.cos(angle) * 9, position.Z + math.sin(angle) * 9, 34)
	end
end

-- Sends every guard home to the blizzard (before the morning's new ones).
function MonsterService.clearGuards()
	for id, enemy in Sim.Enemies do
		if enemy.Leash then
			Sim.Enemies[id] = nil
		end
	end
end

local function melt(keepGuards: boolean)
	local removed = EnemySim.clear(Sim, keepGuards)
	if #removed > 0 then
		local list = {}
		for _, enemy in removed do
			table.insert(list, { Enemy = enemy.Id, Kind = enemy.Kind, X = enemy.X, Z = enemy.Z })
		end
		Net.fx("Melt", { List = list })
	end
end

local function onFire(player: Player, weaponId: unknown, aim: unknown)
	if typeof(weaponId) ~= "string" or typeof(aim) ~= "Vector3" then
		return
	end
	local weapon = Weapons.ById[weaponId]
	if not weapon or PlayerService.equipped(player) ~= weaponId or PlayerService.isFrozen(player) then
		return
	end
	local root = Net.root(player)
	if not root then
		return
	end
	local shots = lastShot[player] or {}
	lastShot[player] = shots
	local time = os.clock()
	if time - (shots[weaponId] or 0) < weapon.Cooldown * 0.85 then
		return
	end
	shots[weaponId] = time
	local origin = root.Position
	local result = Combat.resolve(Sim, weaponId, origin.X, origin.Z, aim.X, aim.Z, 1)
	local events = {}
	if #result.Hits > 0 then
		local scale = PlayerService.damageScale(player)
		for _, hit in result.Hits do
			EnemySim.damage(Sim, hit.Id, hit.Damage * scale, player, events)
		end
	end
	Net.fx("Shot", {
		By = player.UserId,
		Weapon = weaponId,
		From = origin,
		ImpactX = result.ImpactX,
		ImpactZ = result.ImpactZ,
		Hits = #result.Hits,
	})
	apply(events)
end

local lastSent = -1

local function sendSnapshot()
	local count = EnemySim.count(Sim)
	if count == 0 and lastSent == 0 then
		return
	end
	lastSent = count
	local entries = {}
	for _, enemy in Sim.Enemies do
		table.insert(entries, {
			Id = enemy.Id,
			Kind = enemy.Kind,
			Action = enemy.Action,
			X = enemy.X,
			Z = enemy.Z,
			Health = enemy.Health / enemy.MaxHealth,
			Heading = enemy.Heading,
		})
	end
	snapshot:FireAllClients(Codec.encode(entries))
end

local function updatePlayers()
	table.clear(Sim.Players)
	for _, player in Players:GetPlayers() do
		local root = Net.root(player)
		if root then
			Sim.Players[player] = {
				X = root.Position.X,
				Z = root.Position.Z,
				Frozen = PlayerService.isFrozen(player),
			}
		end
	end
end

function MonsterService.count(): number
	return EnemySim.count(Sim)
end

function MonsterService.init()
	snapshot = Net.remote("Snapshot")
	for _, spot in WorldService.get().Layout.Spawns do
		table.insert(spawnPoints, Vector3.new(spot.X, 0, spot.Z))
	end
	Net.remote("Fire").OnServerEvent:Connect(onFire)
	GameLoop.onPhase(function(phase, night)
		if phase == "Night" then
			planNight(night)
		elseif phase == "Dawn" then
			table.clear(pending)
			melt(true)
		elseif phase == "Intermission" or phase == "Won" or phase == "Lost" or phase == "Waiting" then
			table.clear(pending)
			melt(false)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
	end)
end

function MonsterService.start()
	local sinceSnapshot = 0
	while true do
		local dt = task.wait(TICK)
		dt = math.min(dt, 0.25)
		if GameLoop.isPlaying() then
			if GameLoop.isNight() and #pending > 0 then
				local elapsed = GameLoop.elapsed()
				while #pending > 0 and pending[1].At <= elapsed and EnemySim.count(Sim) < Balance.Waves.MaxAlive do
					local spawn = table.remove(pending, 1) :: Waves.Spawn
					spawnAt(spawn.Kind, spawn.Point)
				end
			end
			updatePlayers()
			apply(EnemySim.step(Sim, dt))
		end
		sinceSnapshot += dt
		if sinceSnapshot >= 0.099 then
			sinceSnapshot = 0
			sendSnapshot()
		end
	end
end

return MonsterService
