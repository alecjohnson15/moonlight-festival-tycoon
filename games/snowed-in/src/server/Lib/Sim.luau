-- The one monster world (shared/EnemySim) for this server. BuildService adds
-- the team's buildings to it, MonsterService steps it and fills in the
-- players, and the weapons aim into it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemySim = require(ReplicatedStorage.Shared.EnemySim)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local Town = require(ReplicatedStorage.Shared.World.Town)

local obstacles = {}
for _, circle in Town.layout().Obstacles do
	table.insert(obstacles, { X = circle.X, Z = circle.Z, R = circle.R + Map.ObstacleMargin })
end

return EnemySim.newWorld(Map.Hearth[1], Map.Hearth[2], 5.5, obstacles)
