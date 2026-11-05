-- The rescue: four radio parts are frozen at the four landmarks
-- (Config/Map), each guarded by day. Players free a part with its
-- landmark's trial (saw the logs, melt the ice, light the lighthouse, pry
-- the crate), carry it back (a little slower while they do), and walk it up
-- to the radio by the tower, which fits it. Once all four are in, the radio
-- calls the rescue train, which comes at the dawn after the last night
-- (shared/Cycle).
--
-- The rules live in shared/Radio; this service only asks it and moves the
-- models to match. Each part's state is an attribute on
-- ReplicatedStorage.State ("Part_Generator" = "Frozen", "Loose", "Carried"
-- or "Fitted") and its model sits in Workspace.RadioParts, so clients can
-- mark them. "RadioHelp" on State is true while the team is behind and the
-- missing parts are marked for everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local Radio = require(ReplicatedStorage.Shared.Radio)
local Gear = require(ReplicatedStorage.Shared.World.Gear)
local Lib = script.Parent.Parent.Lib
local Analytics = require(Lib.Analytics)
local Celebrate = require(Lib.Celebrate)
local Net = require(Lib.Net)
local RunStats = require(Lib.RunStats)
local GameLoop = require(script.Parent.GameLoop)
local MonsterService = require(script.Parent.MonsterService)
local PlayerService = require(script.Parent.PlayerService)
local WorldService = require(script.Parent.WorldService)

local State = ReplicatedStorage.State :: Configuration

local ObjectiveService = {}

local FIT_RANGE = 14
-- Loose parts dropped further out than this are put back inside the
-- valley wall, where everyone can walk.
local SAFE_RADIUS = Map.WallRadius - 14

type View = {
	Home: CFrame,
	Model: Model?,
	Ice: BasePart?,
}

local radio = Radio.new()
local views: { [string]: View } = {}
local folder: Folder
local radioAt: Vector3

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish(part: Radio.Part)
	State:SetAttribute(`Part_{part.Id}`, part.State)
	local view = views[part.Id]
	if view.Model then
		view.Model:SetAttribute("State", part.State)
	end
	State:SetAttribute("Parts", Radio.fitted(radio))
end

local function publishHelp()
	State:SetAttribute("RadioHelp", GameLoop.isPlaying() and Radio.behind(GameLoop.night(), Radio.fitted(radio)))
end

local function clearModel(view: View)
	if view.Model then
		view.Model:Destroy()
		view.Model = nil
	end
	if view.Ice then
		view.Ice:Destroy()
		view.Ice = nil
	end
end

local pickUp: (Radio.Part, Player) -> ()

-- Leaves the part on the ground at a spot, with a prompt to pick it up.
local function showLoose(part: Radio.Part, at: CFrame)
	local view = views[part.Id]
	clearModel(view)
	local model = Gear.radioPart(folder, part.Id)
	model:PivotTo(at)
	model:SetAttribute("PartName", part.Landmark.PartName)
	view.Model = model
	publish(part)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Pick up the {part.Landmark.PartName}`
	prompt.ObjectText = "Carry it to the radio tower"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		pickUp(part, player)
	end)
end

local function trialText(part: Radio.Part): (string, string)
	local trial = Radio.trial(part)
	local turns = Radio.turns(trial)
	local action = if turns > 1 then `{trial.Action} ({part.Progress}/{turns})` else trial.Action
	local object = `The {part.Landmark.PartName} is frozen inside`
	if trial.Kind == "Bring" then
		object = `Uses {trial.Amount} {string.lower(trial.Resource :: string)} from your backpack`
	elseif trial.Kind == "Melt" then
		object = "Hold a torch or any fire tool"
	end
	return action, object
end

-- Freezes a part at its landmark, with a prompt for its trial.
local function showFrozen(part: Radio.Part)
	local view = views[part.Id]
	clearModel(view)
	local model = Gear.radioPart(folder, part.Id)
	model:PivotTo(view.Home * CFrame.new(0, 1.6, 0))
	model:SetAttribute("PartName", part.Landmark.PartName)
	model:SetAttribute("Hint", Radio.hint(part.Landmark))
	view.Model = model
	local ice = Gear.iceBlock(folder, view.Home * CFrame.new(0, 2.2, 0))
	ice.Size = Vector3.new(5, 4.6, 5)
	ice.Name = `Ice_{part.Id}`
	view.Ice = ice
	publish(part)
	local trial = Radio.trial(part)
	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = trial.Seconds or 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.ActionText, prompt.ObjectText = trialText(part)
	prompt.Parent = ice
	prompt.Triggered:Connect(function(player)
		if PlayerService.isFrozen(player) or not Net.near(player, ice.Position, 16) then
			return
		end
		local outcome = Radio.work(radio, part.Id, {
			Who = player,
			Tool = PlayerService.equipped(player),
			Pack = PlayerService.pack(player),
		}, GameLoop.isPlaying())
		if not outcome.Ok then
			Net.notice(player, outcome.Reason or "Not yet.", "Bad")
			return
		end
		if outcome.Take then
			PlayerService.takeFromPack(player, outcome.Take)
		end
		if not outcome.Freed then
			prompt.ActionText, prompt.ObjectText = trialText(part)
			Net.fx("Trial", { Position = ice.Position, Part = part.Id, Progress = outcome.Progress })
			return
		end
		Net.fx("IceBreak", { Position = ice.Position, Landmark = part.Landmark.Id })
		showLoose(part, view.Home * CFrame.new(0, 1.6, 0))
		RunStats.add(player, "Freed", 1)
		Analytics.step(player, "FoundPart")
		Celebrate.milestone("FirstPart")
		Net.notice(nil, `{player.DisplayName} freed the {part.Landmark.PartName} at the {part.Landmark.Name}!`, "Good")
	end)
end

function pickUp(part: Radio.Part, player: Player)
	local view = views[part.Id]
	if PlayerService.isFrozen(player) or not view.Model then
		return
	end
	local root = Net.root(player)
	if not root or (root.Position - view.Model:GetPivot().Position).Magnitude > 16 then
		return
	end
	local ok, reason = Radio.pickUp(radio, part.Id, player, GameLoop.isPlaying())
	if not ok then
		if reason then
			Net.notice(player, reason, "Info")
		end
		return
	end
	clearModel(view)
	local model = Gear.radioPart(nil, part.Id)
	model:PivotTo(root.CFrame * CFrame.new(0, 0.6, 1.4))
	Gear.weld(model, model.PrimaryPart :: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model:SetAttribute("PartName", part.Landmark.PartName)
	model.Parent = folder
	view.Model = model
	publish(part)
	player:SetAttribute("Carrying", part.Id)
	PlayerService.refreshSpeed(player)
	Net.notice(player, `Carry the {part.Landmark.PartName} to the radio tower!`, "Good")
end

-- Where a dropped part comes to rest: where the carrier was, pulled back
-- inside the valley if they were outside it.
local function restingSpot(player: Player, part: Radio.Part): CFrame
	local root = Net.root(player)
	if not root then
		return views[part.Id].Home * CFrame.new(0, 1.6, 0)
	end
	local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
	local hearth = Vector3.new(Map.Hearth[1], 0, Map.Hearth[2])
	local offset = flat - hearth
	if offset.Magnitude > SAFE_RADIUS then
		flat = hearth + offset.Unit * SAFE_RADIUS
	end
	return CFrame.new(flat.X, 1.6, flat.Z)
end

local function drop(player: Player)
	local carried = Radio.carriedBy(radio, player)
	if not carried then
		return
	end
	local at = restingSpot(player, carried)
	local part = Radio.drop(radio, player, now()) :: Radio.Part
	player:SetAttribute("Carrying", "")
	PlayerService.refreshSpeed(player)
	showLoose(part, at)
	Net.notice(nil, `The {part.Landmark.PartName} was dropped in the snow. Go and get it!`, "Bad")
end

local function fit(player: Player)
	local part, complete = Radio.fit(radio, player, GameLoop.isPlaying())
	if not part then
		return
	end
	player:SetAttribute("Carrying", "")
	PlayerService.refreshSpeed(player)
	local view = views[part.Id]
	clearModel(view)
	local fitted = Radio.fitted(radio)
	local tower = WorldService.get().RadioTower
	local index = table.find(radio.Order, part.Id) or fitted
	local socket = tower:FindFirstChild(`Socket{index}`, true) :: Attachment?
	local model = Gear.radioPart(folder, part.Id)
	if socket then
		model:PivotTo(socket.WorldCFrame * CFrame.new(0, 0, 0.4))
	end
	view.Model = model
	publish(part)
	publishHelp()
	RunStats.team().Parts = fitted
	RunStats.add(player, "Fitted", 1)
	Analytics.step(player, "FittedPart")
	Celebrate.milestone("FirstFit")
	if fitted == #radio.Order - 1 then
		Celebrate.milestone("OneToGo")
	end
	Net.fx("Fitted", { Part = part.Id, Count = fitted })
	if complete then
		GameLoop.callTrain()
		Net.notice(nil, 'The radio crackles: "Rescue train on its way! Hold out until the last dawn!"', "Big")
		Net.fx("Called", {})
	else
		Net.notice(
			nil,
			`{player.DisplayName} fitted the {part.Landmark.PartName}! Radio: {fitted} of {#radio.Order}.`,
			"Big"
		)
	end
end

local function guardRemaining()
	MonsterService.clearGuards()
	local help = Radio.behind(GameLoop.night(), Radio.fitted(radio))
	for _, id in radio.Order do
		if radio.Parts[id].State == "Frozen" then
			MonsterService.guard(views[id].Home.Position, GameLoop.night(), if help then 1 else 0)
		end
	end
end

function ObjectiveService.reset()
	for _, carrier in Radio.reset(radio) do
		if typeof(carrier) == "Instance" and carrier:IsA("Player") then
			carrier:SetAttribute("Carrying", "")
			PlayerService.refreshSpeed(carrier)
		end
	end
	for _, id in radio.Order do
		showFrozen(radio.Parts[id])
	end
	State:SetAttribute("Parts", 0)
	State:SetAttribute("RadioHelp", false)
	MonsterService.clearGuards()
end

-- The rules object, for the tests' sake and for other services that ask.
function ObjectiveService.radio(): Radio.Radio
	return radio
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
		views[landmark.Part] = {
			Home = CFrame.new(spot.WorldPosition.X, 0, spot.WorldPosition.Z),
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
			local wasHelped = State:GetAttribute("RadioHelp") == true
			publishHelp()
			if State:GetAttribute("RadioHelp") == true and not wasHelped then
				Net.notice(
					nil,
					"The radio picks up a faint signal: the missing parts now glow through the storm.",
					"Big"
				)
			end
		elseif phase == "Won" or phase == "Lost" then
			State:SetAttribute("RadioHelp", false)
		end
	end)
end

function ObjectiveService.start()
	while true do
		task.wait(0.25)
		-- Carriers who reach the radio fit their part; carriers who are gone
		-- drop it.
		for _, id in radio.Order do
			local part = radio.Parts[id]
			local carrier = part.Carrier
			if part.State == "Carried" and carrier then
				if not carrier.Parent then
					drop(carrier)
				elseif Net.near(carrier, radioAt, FIT_RANGE) then
					fit(carrier)
				end
			end
		end
		-- Parts nobody has picked up for a while go home to their landmark.
		for _, part in Radio.stale(radio, now()) do
			Radio.sendHome(part)
			showLoose(part, views[part.Id].Home * CFrame.new(0, 1.6, 0))
			Net.notice(
				nil,
				`The {part.Landmark.PartName} slid back to the {part.Landmark.Name}. Go and get it!`,
				"Info"
			)
		end
	end
end

return ObjectiveService
