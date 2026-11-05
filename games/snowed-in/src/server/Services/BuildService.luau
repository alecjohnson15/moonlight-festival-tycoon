-- Building: walls, lanterns, traps, campfires and turrets around the hearth
-- (Config/Structures). The client shows a preview and asks; the server
-- checks the spot (shared/Grid), the role, the hearth level and the
-- stockpile, then builds it, puts it in the monster world so monsters stop
-- at it and turrets shoot from it, and gives it a Repair prompt. Monsters'
-- hits come back here through damage().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Structures = require(ReplicatedStorage.Shared.Config.Structures)
local EnemySim = require(ReplicatedStorage.Shared.EnemySim)
local Grid = require(ReplicatedStorage.Shared.Grid)
local Stock = require(ReplicatedStorage.Shared.Stock)
local Buildings = require(ReplicatedStorage.Shared.World.Buildings)
local Town = require(ReplicatedStorage.Shared.World.Town)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local Lib = script.Parent.Parent.Lib
local Heat = require(Lib.Heat)
local Net = require(Lib.Net)
local RateLimiter = require(Lib.RateLimiter)
local RunStats = require(Lib.RunStats)
local Sim = require(Lib.Sim)
local GameLoop = require(script.Parent.GameLoop)
local PlayerService = require(script.Parent.PlayerService)
local TeamService = require(script.Parent.TeamService)

local BuildService = {}

-- Most built things that may carry a light, so a base of lanterns doesn't
-- cost phones their frame rate.
local MAX_LIGHTS = 14
-- How far from the spot the builder may stand.
local REACH = 48

type Built = {
	Id: number,
	Kind: string,
	Model: Model,
	Rect: Grid.Rect,
}

local built: { [number]: Built } = {}
local nextId = 0
local folder: Folder
local buildLimiter = RateLimiter.new(0.3)
local repairLimiter = RateLimiter.new(0.5)

local function healthScale(): number
	return if TeamService.hasUpgrade("IronBraces") then 1.5 else 1
end

local function rules(): Grid.Rules
	local rects = {}
	for _, entry in built do
		table.insert(rects, entry.Rect)
	end
	return { HearthX = Map.Hearth[1], HearthZ = Map.Hearth[2], Keep = Town.layout().Keep, Built = rects }
end

local function lights(): number
	local count = 0
	for _, entry in built do
		if entry.Model:FindFirstChildWhichIsA("PointLight", true) then
			count += 1
		end
	end
	return count
end

-- What this player pays for a structure.
function BuildService.cost(player: Player, kind: string): Stock.Counts
	local def = Structures.ById[kind]
	local role = PlayerService.role(player)
	if role and role.BuildDiscount then
		return Stock.discount(def.Cost, role.BuildDiscount)
	end
	return def.Cost
end

local function publish(entry: Built)
	local structure = Sim.Structures[entry.Id]
	if structure then
		entry.Model:SetAttribute("Health", math.max(0, math.floor(structure.Health)))
		entry.Model:SetAttribute("MaxHealth", math.floor(structure.MaxHealth))
	end
end

local function remove(id: number, broken: boolean)
	local entry = built[id]
	if not entry then
		return
	end
	built[id] = nil
	Sim.Structures[id] = nil
	Heat.set(id, nil)
	if broken then
		Net.fx("Broken", { Position = entry.Model:GetPivot().Position, Kind = entry.Kind })
	end
	entry.Model:Destroy()
	Workspace:SetAttribute("Structures", #rules().Built)
end

-- A monster's hit on a structure.
function BuildService.damage(id: number, amount: number)
	local structure = Sim.Structures[id]
	local entry = built[id]
	if not structure or not entry then
		return
	end
	structure.Health -= amount
	if structure.Health <= 0 then
		remove(id, true)
	else
		publish(entry)
	end
end

-- Heals a structure by a share of its health. Returns true if it needed it.
local function heal(id: number, share: number): boolean
	local structure = Sim.Structures[id]
	local entry = built[id]
	if not structure or not entry or structure.Health >= structure.MaxHealth then
		return false
	end
	structure.Health = math.min(structure.MaxHealth, structure.Health + structure.MaxHealth * share)
	publish(entry)
	return true
end

-- Heals every structure within radius of a point by a share of its health,
-- for free (the Builder's Quick Fix). Returns how many it healed.
function BuildService.repairNear(position: Vector3, radius: number, share: number): number
	local count = 0
	for id, entry in built do
		local at = entry.Model:GetPivot().Position
		if (Vector3.new(at.X, 0, at.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude <= radius then
			if heal(id, share) then
				count += 1
				Net.fx("Repair", { Position = at })
			end
		end
	end
	return count
end

local function addRepairPrompt(entry: Built)
	local root = entry.Model.PrimaryPart
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Repair"
	prompt.ActionText = "Repair"
	prompt.ObjectText = `{Structures.ById[entry.Kind].Name}: {Stock.describe(Structures.RepairCost)}`
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Enabled = false
	prompt.Parent = root
	-- Only damaged things offer a repair.
	entry.Model:GetAttributeChangedSignal("Health"):Connect(function()
		local health = entry.Model:GetAttribute("Health") or 0
		local max = entry.Model:GetAttribute("MaxHealth") or 1
		prompt.Enabled = health < max
	end)
	prompt.Triggered:Connect(function(player)
		if not repairLimiter:allow(player) or PlayerService.isFrozen(player) then
			return
		end
		local structure = Sim.Structures[entry.Id]
		if not structure or structure.Health >= structure.MaxHealth then
			return
		end
		if not TeamService.spend(Structures.RepairCost) then
			Net.notice(player, "The stockpile needs wood to repair.", "Bad")
			return
		end
		local role = PlayerService.role(player)
		heal(entry.Id, Structures.RepairShare * (1 + (role and role.RepairBonus or 0)))
		Net.fx("Repair", { Position = entry.Model:GetPivot().Position })
	end)
end

local function onBuild(player: Player, kind: unknown, x: unknown, z: unknown, turns: unknown)
	if typeof(kind) ~= "string" or typeof(x) ~= "number" or typeof(z) ~= "number" or typeof(turns) ~= "number" then
		return
	end
	if x ~= x or z ~= z or turns ~= turns or not buildLimiter:allow(player) then
		return
	end
	local def = Structures.ById[kind]
	if not def or not GameLoop.isPlaying() or PlayerService.isFrozen(player) then
		return
	end
	if def.Role and player:GetAttribute("Role") ~= def.Role then
		Net.notice(player, `Only the {def.Role} can build that.`, "Bad")
		return
	end
	if TeamService.level() < def.Needs then
		Net.notice(player, `Build up the hearth to level {def.Needs} first.`, "Bad")
		return
	end
	local rect = Grid.place(kind, x, z, turns)
	if not Net.near(player, Vector3.new(rect.X, 0, rect.Z), REACH) then
		Net.notice(player, "Walk closer to build there.", "Bad")
		return
	end
	local ok, reason = Grid.check(rect, rules())
	if not ok then
		Net.notice(player, reason or "You can't build there.", "Bad")
		return
	end
	local cost = BuildService.cost(player, kind)
	if not TeamService.spend(cost) then
		local missing = Stock.missing(TeamService.stock(), cost)
		Net.notice(player, `Need {Stock.describe(missing or {})} more in the stockpile.`, "Bad")
		return
	end

	nextId += 1
	local id = nextId
	local turn = Grid.turns(turns)
	local at = CFrame.new(rect.X, 0, rect.Z) * CFrame.Angles(0, turn * math.pi / 2, 0)
	local model = Buildings[kind](folder, at)
	model:SetAttribute("StructureId", id)
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Turns", turn)
	if lights() >= MAX_LIGHTS then
		for _, light in model:GetDescendants() do
			if light:IsA("PointLight") then
				light:Destroy()
			end
		end
	end
	local entry = { Id = id, Kind = kind, Model = model, Rect = rect }
	built[id] = entry
	EnemySim.addStructure(Sim, id, kind, rect.X, rect.Z, turn, healthScale())
	if def.Warmth then
		Heat.set(id, { X = rect.X, Z = rect.Z, R = def.Warmth })
	end
	publish(entry)
	addRepairPrompt(entry)
	RunStats.team().Built += 1
	Workspace:SetAttribute("Structures", #rules().Built)
	Net.fx("Built", { Position = at.Position, Kind = kind, By = player.UserId })
end

function BuildService.clear()
	for id in built do
		remove(id, false)
	end
	Heat.clear()
	nextId = 0
end

function BuildService.init()
	folder = Instance.new("Folder")
	folder.Name = "Built"
	folder.Parent = Workspace
	Net.remote("Build").OnServerEvent:Connect(onBuild)
	TeamService.onUpgrade(function(id)
		if id == "IronBraces" then
			for _, structure in Sim.Structures do
				structure.MaxHealth *= 1.5
				structure.Health *= 1.5
			end
			for _, entry in built do
				publish(entry)
			end
		end
	end)
	GameLoop.onPhase(function(phase)
		if phase == "Intermission" then
			BuildService.clear()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		buildLimiter:forget(player)
		repairLimiter:forget(player)
	end)
end

return BuildService
