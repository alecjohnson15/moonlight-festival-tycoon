-- Builds the map for each round far from the lobby and clears it after.
-- Each map module (Look/Maps) returns a model with the markers the round
-- needs: Spawns, Coins, Clues, Passages and Rooms. The map's lighting is
-- put on by each client while their camera is near it (client/Atmosphere),
-- so the lobby keeps its own sky.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Game = require(ReplicatedStorage.Shared.Config.Game)
local Maps = ReplicatedStorage.Shared.Look.Maps

local MapService = {}

-- Every map, in the order the vote offers them.
MapService.Modules = {
	require(Maps.Manor),
	require(Maps.Carnival),
}

MapService.Ids = {}
local byId = {}
for _, module in MapService.Modules do
	table.insert(MapService.Ids, module.Id)
	byId[module.Id] = module
end

local current: Model? = nil
local folder: Folder? = nil

function MapService.origin(): CFrame
	local at = Game.MapOrigin
	return CFrame.new(at[1], at[2], at[3])
end

function MapService.name(id: string): string
	local module = byId[id]
	return if module then module.Name else id
end

function MapService.blurb(id: string): string
	local module = byId[id]
	return if module then module.Blurb else ""
end

function MapService.current(): Model?
	return current
end

-- Builds the map and puts it in the world, replacing any other.
function MapService.load(id: string): Model
	MapService.unload()
	local module = byId[id] or MapService.Modules[1]
	local map = module.build(MapService.origin())
	map.Name = "Map"
	map:SetAttribute("MapId", module.Id)
	map.Parent = folder
	current = map
	Workspace:SetAttribute("MapId", module.Id)
	return map
end

function MapService.unload()
	if current then
		current:Destroy()
		current = nil
	end
	Workspace:SetAttribute("MapId", nil)
end

-- The map's markers in one of its folders.
function MapService.markers(name: string): { BasePart }
	local list = {}
	local found = current and current:FindFirstChild(name)
	if found then
		for _, marker in found:GetChildren() do
			if marker:IsA("BasePart") then
				table.insert(list, marker)
			end
		end
	end
	return list
end

-- The name of the room a position is in, or nil outside every room.
function MapService.roomAt(position: Vector3): string?
	for _, box in MapService.markers("Rooms") do
		local offset = box.CFrame:PointToObjectSpace(position)
		local half = box.Size / 2
		if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
			return box.Name
		end
	end
	return nil
end

function MapService.init()
	local holder = Instance.new("Folder")
	holder.Name = "Round"
	holder.Parent = Workspace
	folder = holder
end

return MapService
