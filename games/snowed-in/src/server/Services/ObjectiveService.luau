-- The rescue: four radio parts are frozen in ice at the four landmarks
-- (Config/Map), each guarded by day. Players break the ice, carry a part
-- back (a little slower while they do), and walk it up to the radio by the
-- tower, which fits it. A carrier who freezes drops the part where they
-- stand. Once all four are in, the radio calls the rescue train, which
-- comes at the dawn after the last night (shared/Cycle).
--
-- Each part's state is an attribute on ReplicatedStorage.State
-- ("Part_Generator" = "Frozen", "Loose", "Carried" or "Fitted") and its
-- model sits in Workspace.RadioParts, so clients can mark them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local Gear = require(ReplicatedStorage.Shared.World.Gear)
local Lib = script.Parent.Parent.Lib
local Net = require(Lib.Net)
local RunStats = require(Lib.RunStats)
local GameLoop = require(script.Parent.GameLoop)
local MonsterService = require(script.Parent.MonsterService)
local PlayerService = require(script.Parent.PlayerService)
local WorldService = require(script.Parent.WorldService)

local State = ReplicatedStorage.State :: Configuration

local ObjectiveService = {}

local BREAK_SECONDS = 4
local FIT_RANGE = 14

type Part = {
	Id: string,
	Name: string,
	Landmark: Map.Landmark,
	Home: CFrame,
	Model: Model?,
	Ice: BasePart?,
	State: string,
	Carrier: Player?,
}

local parts: { [string]: Part } = {}
local folder: Folder
local radioAt: Vector3
local fitted = 0

local function setState(part: Part, state: string)
	part.State = state
	State:SetAttribute(`Part_{part.Id}`, state)
	if part.Model then
		part.Model:SetAttribute("State", state)
	end
end

local function clearModel(part: Part)
	if part.Model then
		part.Model:Destroy()
		part.Model = nil
	end
	if part.Ice then
		part.Ice:Destroy()
		part.Ice = nil
	end
end

local pickUp: (Part, Player) -> ()

-- Leaves the part on the ground at a spot, with a prompt to pick it up.
local function placeLoose(part: Part, at: CFrame)
	clearModel(part)
	local model = Gear.radioPart(folder, part.Id)
	model:PivotTo(at)
	model:SetAttribute("PartName", part.Name)
	part.Model = model
	setState(part, "Loose")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Pick up the {part.Name}`
	prompt.ObjectText = "Carry it to the radio tower"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		pickUp(part, player)
	end)
end

-- Freezes a part in a block of ice at its landmark, with a prompt to break
-- it out.
local function freezeAtHome(part: Part)
	clearModel(part)
	part.Carrier = nil
	local model = Gear.radioPart(folder, part.Id)
	model:PivotTo(part.Home * CFrame.new(0, 1.6, 0))
	model:SetAttribute("PartName", part.Name)
	part.Model = model
	local ice = Gear.iceBlock(folder, part.Home * CFrame.new(0, 2.2, 0))
	ice.Size = Vector3.new(5, 4.6, 5)
	ice.Name = `Ice_{part.Id}`
	part.Ice = ice
	setState(part, "Frozen")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Break the ice"
	prompt.ObjectText = `The {part.Name} is frozen inside`
	prompt.HoldDuration = BREAK_SECONDS
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = ice
	prompt.Triggered:Connect(function(player)
		if part.State ~= "Frozen" or PlayerService.isFrozen(player) or not GameLoop.isPlaying() then
			return
		end
		Net.fx("IceBreak", { Position = ice.Position })
		placeLoose(part, part.Home * CFrame.new(0, 1.6, 0))
		Net.notice(nil, `{player.DisplayName} found the {part.Name} at the {part.Landmark.Name}!`, "Good")
	end)
end

function pickUp(part: Part, player: Player)
	if part.State ~= "Loose" or not GameLoop.isPlaying() or PlayerService.isFrozen(player) then
		return
	end
	if (player:GetAttribute("Carrying") or "") ~= "" then
		Net.notice(player, "You can only carry one radio part at a time.", "Info")
		return
	end
	local root = Net.root(player)
	if not root or not part.Model or (root.Position - part.Model:GetPivot().Position).Magnitude > 16 then
		return
	end
	clearModel(part)
	local model = Gear.radioPart(nil, part.Id)
	model:PivotTo(root.CFrame * CFrame.new(0, 0.6, 1.4))
	Gear.weld(model, model.PrimaryPart :: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model:SetAttribute("PartName", part.Name)
	model.Parent = folder
	part.Model = model
	part.Carrier = player
	setState(part, "Carried")
	player:SetAttribute("Carrying", part.Id)
	PlayerService.refreshSpeed(player)
	Net.notice(player, `Carry the {part.Name} to the radio tower!`, "Good")
end

local function drop(player: Player)
	for _, part in parts do
		if part.Carrier == player and part.State == "Carried" then
			part.Carrier = nil
			player:SetAttribute("Carrying", "")
			PlayerService.refreshSpeed(player)
			local root = Net.root(player)
			local at = if root
				then CFrame.new(root.Position.X, 1.6, root.Position.Z)
				else part.Home * CFrame.new(0, 1.6, 0)
			placeLoose(part, at)
			Net.notice(nil, `The {part.Name} was dropped in the snow. Go and get it!`, "Bad")
		end
	end
end

local function fit(part: Part, player: Player)
	player:SetAttribute("Carrying", "")
	PlayerService.refreshSpeed(player)
	part.Carrier = nil
	clearModel(part)
	fitted += 1
	local radio = WorldService.get().RadioTower
	local index = table.find({ "Generator", "Battery", "Lamp", "Antenna" }, part.Id) or fitted
	local socket = radio:FindFirstChild(`Socket{index}`, true) :: Attachment?
	local model = Gear.radioPart(folder, part.Id)
	if socket then
		model:PivotTo(socket.WorldCFrame * CFrame.new(0, 0, 0.4))
	end
	part.Model = model
	setState(part, "Fitted")
	RunStats.team().Parts = fitted
	State:SetAttribute("Parts", fitted)
	Net.fx("Fitted", { Part = part.Id, Count = fitted })
	if fitted >= #Map.Landmarks then
		GameLoop.callTrain()
		Net.notice(nil, 'The radio crackles: "Rescue train on its way! Hold out until the last dawn!"', "Big")
		Net.fx("Called", {})
	else
		Net.notice(nil, `{player.DisplayName} fitted the {part.Name}! Radio: {fitted} of {#Map.Landmarks}.`, "Big")
	end
end

local function guardRemaining()
	MonsterService.clearGuards()
	for _, part in parts do
		if part.State == "Frozen" then
			MonsterService.guard(part.Home.Position, GameLoop.night())
		end
	end
end

function ObjectiveService.reset()
	fitted = 0
	State:SetAttribute("Parts", 0)
	for _, part in parts do
		if part.Carrier then
			part.Carrier:SetAttribute("Carrying", "")
		end
		freezeAtHome(part)
	end
	MonsterService.clearGuards()
end

function ObjectiveService.init()
	folder = Instance.new("Folder")
	folder.Name = "RadioParts"
	folder.Parent = Workspace
	local town = WorldService.get()
	radioAt = (town.RadioTower:FindFirstChild("Prompt") :: BasePart).Position
	for _, landmark in Map.Landmarks do
		local model = town.Landmarks[landmark.Id]
		local spot = model:FindFirstChild("PartSpot", true) :: Attachment
		parts[landmark.Part] = {
			Id = landmark.Part,
			Name = landmark.PartName,
			Landmark = landmark,
			Home = CFrame.new(spot.WorldPosition.X, 0, spot.WorldPosition.Z),
			State = "Frozen",
		}
	end
	ObjectiveService.reset()

	PlayerService.onFrozen(drop)
	Players.PlayerRemoving:Connect(drop)
	-- A carrier whose character goes (a reset, a fall) drops their part.
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			drop(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	GameLoop.onPhase(function(phase, night)
		if phase == "Intermission" then
			ObjectiveService.reset()
		elseif phase == "Day" then
			if night == 0 then
				ObjectiveService.reset()
			end
			guardRemaining()
		end
	end)
end

function ObjectiveService.start()
	-- Carriers who reach the radio fit their part.
	while true do
		task.wait(0.25)
		for _, part in parts do
			local carrier = part.Carrier
			if part.State == "Carried" and carrier then
				if not carrier.Parent then
					drop(carrier)
				elseif Net.near(carrier, radioAt, FIT_RANGE) then
					fit(part, carrier)
				end
			end
		end
	end
end

return ObjectiveService
