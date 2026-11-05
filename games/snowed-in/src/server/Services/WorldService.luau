-- Builds Pinehollow (shared/World/Town) when the server starts and keeps
-- hold of the parts other services need: the hearth, the stations, the
-- radio tower, the cabins, the landmarks and the gatherable nodes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local Town = require(ReplicatedStorage.Shared.World.Town)

local WorldService = {}

WorldService.town = nil :: Town.Built?

-- The ground-level point at the middle of the hearth.
WorldService.hearth = Vector3.new(Map.Hearth[1], 0, Map.Hearth[2])

function WorldService.get(): Town.Built
	return WorldService.town :: Town.Built
end

-- A spot on the ground where a player can stand, near the hearth: used for
-- spawning and for waking up after freezing.
function WorldService.spawnPoint(): CFrame
	local angle = math.random() * math.pi * 2
	local radius = 10 + math.random() * 6
	local at = WorldService.hearth + Vector3.new(math.sin(angle) * radius, 3.5, math.cos(angle) * radius)
	return CFrame.lookAt(at, WorldService.hearth + Vector3.new(0, 3.5, 0))
end

function WorldService.init()
	WorldService.town = Town.build(Workspace)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(10, 1, 6)
	spawn.CFrame = CFrame.new(Map.Hearth[1], 0.5, Map.Hearth[2] + 14)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = Workspace
end

return WorldService
