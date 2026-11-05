-- Gathering: a prompt on every pine, boulder, coal seam, pile of junk,
-- fishing hole and frostberry bush. Holding it puts the node's yield in
-- the player's backpack; a node used up disappears and grows back later.
-- The stockpile's prompt empties a backpack into the team's stockpile, and
-- each dawn drops supply crates around town whose contents are written on
-- them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Assist = require(ReplicatedStorage.Shared.Assist)
local Stock = require(ReplicatedStorage.Shared.Stock)
local Props = require(ReplicatedStorage.Shared.World.Props)
local Lib = script.Parent.Parent.Lib
local Analytics = require(Lib.Analytics)
local Net = require(Lib.Net)
local RunStats = require(Lib.RunStats)
local GameLoop = require(script.Parent.GameLoop)
local PlayerService = require(script.Parent.PlayerService)
local TeamService = require(script.Parent.TeamService)
local WorldService = require(script.Parent.WorldService)

local GatherService = {}

type NodeState = {
	Model: Model,
	Def: Resources.Node,
	Home: Instance,
	Uses: number,
}

local nodes: { [Model]: NodeState } = {}
local lastGather: { [Player]: number } = {}
local crates: { [Model]: boolean } = {}
local usedSpots: { [number]: Model } = {}
local stash = ServerStorage:WaitForChild("Stash")

local function yieldFor(def: Resources.Node): number
	local amount = def.Yield
	if def.Upgrade and TeamService.hasUpgrade(def.Upgrade) then
		amount += 1
	end
	return amount
end

local function describe(state: NodeState, prompt: ProximityPrompt)
	local resource = Resources.ById[state.Def.Gives]
	prompt.ObjectText = `{state.Def.Name}: +{yieldFor(state.Def)} {resource.Name}`
end

local function regrow(state: NodeState)
	state.Uses = state.Def.Uses
	state.Model.Parent = state.Home
	local prompt = state.Model.PrimaryPart and state.Model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		describe(state, prompt)
	end
end

local function onGather(state: NodeState, player: Player)
	if not GameLoop.isPlaying() or PlayerService.isFrozen(player) or state.Model.Parent ~= state.Home then
		return
	end
	local root = Net.root(player)
	local hit = state.Model.PrimaryPart
	if not root or not hit or (root.Position - hit.Position).Magnitude > 16 then
		return
	end
	-- However the prompt was held, gathering can't go faster than the
	-- quickest role could hold it.
	local role = PlayerService.role(player)
	local quickest = state.Def.HoldSeconds
		* Assist.holdScale(role and role.GatherSpeed or 0, #Players:GetPlayers())
		* 0.8
	local time = os.clock()
	if time - (lastGather[player] or 0) < quickest then
		return
	end
	lastGather[player] = time
	if PlayerService.packFull(player) then
		Net.notice(player, "Your backpack is full. Drop it off at the stockpile!", "Bad")
		Net.fx("PackFull", {}, player)
		return
	end
	local moved = PlayerService.carry(player, { [state.Def.Gives] = yieldFor(state.Def) })
	local amount = moved[state.Def.Gives] or 0
	Analytics.step(player, "Gathered")
	state.Uses -= 1
	local depleted = state.Uses <= 0
	Net.fx("Gather", {
		Position = hit.Position,
		Node = state.Def.Id,
		Resource = state.Def.Gives,
		Amount = amount,
		Depleted = depleted,
		By = player.UserId,
		Model = if depleted then nil else state.Model,
	})
	if depleted then
		state.Model.Parent = stash
		task.delay(state.Def.RespawnSeconds, function()
			if state.Model.Parent == stash then
				regrow(state)
			end
		end)
	end
end

local function addPrompt(state: NodeState)
	local hit = state.Model.PrimaryPart
	if not hit then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Gather"
	prompt.ActionText = state.Def.Action
	prompt.HoldDuration = state.Def.HoldSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Gather", true)
	describe(state, prompt)
	prompt.Parent = hit
	prompt.Triggered:Connect(function(player)
		onGather(state, player)
	end)
end

-- Supply crates -------------------------------------------------------------

local function clearCrates()
	for crate in crates do
		crate:Destroy()
	end
	table.clear(crates)
	table.clear(usedSpots)
end

local function dropCrates()
	local spots = WorldService.get().Layout.Crates
	local folder = Workspace:FindFirstChild("Crates") or Instance.new("Folder")
	folder.Name = "Crates"
	folder.Parent = Workspace
	local free = {}
	for index in spots do
		if not usedSpots[index] then
			table.insert(free, index)
		end
	end
	local contents = Resources.Crate.Contents
	for _ = 1, Resources.Crate.Count do
		if #free == 0 then
			break
		end
		local index = table.remove(free, math.random(1, #free)) :: number
		local spot = spots[index]
		local crate = Props.crate(folder, CFrame.new(spot.X, 0, spot.Z) * CFrame.Angles(0, spot.Turn, 0))
		crate:AddTag("Crate")
		crates[crate] = true
		usedSpots[index] = crate
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open supply crate"
		prompt.ObjectText = `Holds {Stock.describe(contents)}`
		prompt.HoldDuration = Resources.Crate.HoldSeconds
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = crate.PrimaryPart
		prompt.Triggered:Connect(function(player)
			if
				not crates[crate]
				or PlayerService.isFrozen(player)
				or not Net.near(player, crate:GetPivot().Position, 16)
			then
				return
			end
			if PlayerService.packFull(player) then
				Net.notice(player, "Your backpack is full. Drop it off at the stockpile first!", "Bad")
				return
			end
			PlayerService.carry(player, contents)
			crates[crate] = nil
			usedSpots[index] = nil
			Net.fx("Crate", { Position = crate:GetPivot().Position, By = player.UserId })
			crate:Destroy()
		end)
	end
end

-- The stockpile -------------------------------------------------------------

local function onDeposit(player: Player)
	if not GameLoop.isPlaying() then
		return
	end
	local pack = PlayerService.unpack(player)
	local total = Stock.total(pack)
	if total == 0 then
		Net.notice(player, "Your backpack is empty. Gather things around town!", "Info")
		return
	end
	TeamService.add(pack)
	RunStats.team().Gathered += total
	RunStats.add(player, "Gathered", total)
	Analytics.step(player, "DroppedOff")
	Net.fx("Deposit", { By = player.UserId, Amount = total })
	Net.notice(player, `Dropped off {Stock.describe(pack)}.`, "Good")
end

function GatherService.reset()
	for _, state in nodes do
		regrow(state)
	end
	clearCrates()
end

function GatherService.init()
	local town = WorldService.get()
	for _, model in town.Nodes do
		local def = Resources.Nodes[model:GetAttribute("Node")]
		if def then
			local state = { Model = model, Def = def, Home = model.Parent :: Instance, Uses = def.Uses }
			nodes[model] = state
			addPrompt(state)
		end
	end

	local stockpile = town.Stockpile:FindFirstChild("Prompt") :: BasePart
	local deposit = Instance.new("ProximityPrompt")
	deposit.ActionText = "Drop off backpack"
	deposit.ObjectText = "Stockpile"
	deposit.HoldDuration = 0
	deposit.MaxActivationDistance = 12
	deposit.RequiresLineOfSight = false
	deposit.Parent = stockpile
	deposit.Triggered:Connect(onDeposit)

	TeamService.onUpgrade(function()
		for _, state in nodes do
			local prompt = state.Model.PrimaryPart and state.Model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				describe(state, prompt)
			end
		end
	end)

	GameLoop.onPhase(function(phase, night)
		if phase == "Intermission" then
			GatherService.reset()
		elseif phase == "Dawn" or (phase == "Day" and night == 0) then
			dropCrates()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastGather[player] = nil
	end)
end

return GatherService
