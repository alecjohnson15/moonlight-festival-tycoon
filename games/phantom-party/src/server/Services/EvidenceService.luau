-- Leads: imperfect evidence from what really happened in the round, sent to
-- the players who saw or heard it (Config/Evidence, Rules/Evidence).
--
--   A tag: anyone close by with a clear view glimpses the tagger's mask
--   colour (usually right); anyone in earshot hears a scuffle in that room.
--   The Phantom then leaves faint glowing footprints for a few seconds, and
--   a guest who comes across them notes the room.
--   A thrown blade that hits nothing: those in earshot hear where it landed.
--   A torn clue page: scraps stay on the floor; witnesses glimpse a mask
--   colour, others hear it.
--   A blackout: when the lights come back, everyone standing learns about
--   where they were cut from (usually right).
--
-- Every lead is decided here from the server's own positions and sent only
-- to that player. A lead never carries a name, a user id or a role, and the
-- notebook is capped, so leads can't be farmed (they pay nothing anyway).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local EvidenceConfig = require(Shared.Config.Evidence)
local Combat = require(Shared.Config.Combat)
local Evidence = require(Shared.Rules.Evidence)
local Match = require(script.Parent.Parent.Lib.Match)
local CombatService = require(script.Parent.CombatService)
local MapService = require(script.Parent.MapService)

local RoundRemote = ReplicatedStorage.Remotes.Round :: RemoteEvent

type Participant = Match.Participant

local EvidenceService = {}

local books: { [any]: Evidence.Book } = {}
-- Phantoms leaving footprints, and until when.
local trails: { [Participant]: { Until: number, Id: number } } = {}
-- Fresh prints, for guests to come across.
local prints: { { Position: Vector3, Born: number, Trail: number } } = {}
-- Which trails each player has already noted.
local noted: { [any]: { [number]: boolean } } = {}
local folder: Folder? = nil
local trailCount = 0
local random = Random.new()

local function rand(): number
	return random:NextNumber()
end

local function roomAt(position: Vector3): string
	return MapService.roomAt(position) or "grounds"
end

local function chest(position: Vector3): Vector3
	return position + Vector3.new(0, 1.5, 0)
end

local function holder(): Folder?
	if folder and folder.Parent then
		return folder
	end
	local map = MapService.current()
	if not map then
		return nil
	end
	local made = Instance.new("Folder")
	made.Name = "Evidence"
	made.Parent = map
	folder = made
	return made
end

-- Writes a lead in a participant's notebook and tells their client.
local function note(participant: Participant, kind: string, room: string?, tone: string?)
	local player = participant.Player
	if not player then
		return
	end
	local book = books[participant.Key]
	if not book then
		book = Evidence.newBook()
		books[participant.Key] = book
	end
	local lead = Evidence.write(book, kind, room, tone, os.clock())
	if lead then
		RoundRemote:FireClient(player, {
			Kind = "Lead",
			Family = lead.Family,
			Text = lead.Text,
			Room = lead.Room,
			At = Workspace:GetServerTimeNow(),
			Lifetime = EvidenceConfig.Lifetime,
		})
		Match.fire("Lead", participant, lead.Family)
	end
end

-- Everyone standing who saw or heard something at position, done by actor,
-- leaving out the actor and anyone in except. Calls each(listener, sense).
local function witnesses(
	position: Vector3,
	actor: Participant?,
	except: Participant?,
	each: (Participant, string) -> ()
)
	local actorRoot = actor and Match.root(actor)
	for _, listener in Match.Participants do
		local root = Match.root(listener)
		if listener ~= actor and listener ~= except and listener.State == "Alive" and root then
			local toActor = if actorRoot then (actorRoot.Position - root.Position).Magnitude else nil
			local canSee = actorRoot ~= nil
				and toActor ~= nil
				and toActor <= EvidenceConfig.SeeRange
				and CombatService.clear(chest(root.Position), chest(actorRoot.Position))
			local sense = Evidence.sense(toActor, canSee, (position - root.Position).Magnitude)
			if sense then
				each(listener, sense)
			end
		end
	end
end

-- Footprints -----------------------------------------------------------

local function groundBelow(position: Vector3): Vector3?
	local map = MapService.current()
	if not map then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(position, Vector3.new(0, -8, 0), params)
	return hit and hit.Position
end

local function stepPrint(phantom: Participant, trail: { Until: number, Id: number })
	local root = Match.root(phantom)
	local parent = holder()
	if not root or not parent or rand() > EvidenceConfig.Footprints.Show then
		return
	end
	local jitter = EvidenceConfig.Footprints.Jitter
	local ground = groundBelow(root.Position + Vector3.new((rand() - 0.5) * 2 * jitter, 0, (rand() - 0.5) * 2 * jitter))
	if not ground then
		return
	end
	local heading = root.CFrame.LookVector
	local mark = Instance.new("Part")
	mark.Name = "Footprint"
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.Material = Enum.Material.Neon
	mark.Color = Color3.fromRGB(190, 150, 255)
	mark.Transparency = 0.35
	mark.Size = Vector3.new(0.7, 0.05, 1.1)
	mark.CFrame = CFrame.lookAt(ground + Vector3.new(0, 0.05, 0), ground + Vector3.new(heading.X, 0.05, heading.Z))
	mark:SetAttribute("Fade", EvidenceConfig.Footprints.Fade)
	mark:AddTag("Footprint")
	mark.Parent = parent
	Debris:AddItem(mark, EvidenceConfig.Footprints.Fade)
	table.insert(prints, { Position = ground, Born = os.clock(), Trail = trail.Id })
end

-- Guests who come across fresh prints note the room, once per trail.
local function checkPrints()
	local now = os.clock()
	local keep = {}
	for _, step in prints do
		if now - step.Born < EvidenceConfig.Footprints.Fade then
			table.insert(keep, step)
		end
	end
	prints = keep
	if #prints == 0 then
		return
	end
	for _, participant in Match.Participants do
		local root = Match.root(participant)
		if participant.Player and participant.State == "Alive" and participant.Role ~= "Phantom" and root then
			local seen = noted[participant.Key] or {}
			noted[participant.Key] = seen
			for _, step in prints do
				if not seen[step.Trail] and (step.Position - root.Position).Magnitude <= 8 then
					seen[step.Trail] = true
					note(participant, "Footprints", roomAt(step.Position), nil)
				end
			end
		end
	end
end

-- What happened --------------------------------------------------------

local function onDown(target: Participant, by: Participant?, how: string)
	if not by or by.Role ~= "Phantom" or (how ~= "Swing" and how ~= "Throw") then
		return
	end
	local root = Match.root(target)
	if not root then
		return
	end
	local room = roomAt(root.Position)
	local tone = Evidence.tone(by.Mask)
	witnesses(root.Position, by, target, function(listener, sense)
		if sense == "See" then
			note(listener, "SawTag", room, Evidence.glimpse(tone, rand))
		else
			note(listener, "HeardTag", room, nil)
		end
	end)
	if EvidenceConfig.Footprints.Enabled then
		trailCount += 1
		trails[by] = { Until = os.clock() + EvidenceConfig.Footprints.Seconds, Id = trailCount }
	end
end

local function onThrowLanded(thrower: Participant, position: Vector3, hit: boolean)
	if hit then
		return
	end
	local room = roomAt(position)
	witnesses(position, nil, thrower, function(listener)
		note(listener, "HeardThrow", room, nil)
	end)
end

local function scraps(position: Vector3)
	local parent = holder()
	if not parent then
		return
	end
	for index = 1, 4 do
		local scrap = Instance.new("Part")
		scrap.Name = "TornPage"
		scrap.Anchored = true
		scrap.CanCollide = false
		scrap.CanQuery = false
		scrap.CanTouch = false
		scrap.Color = Color3.fromRGB(255, 244, 214)
		scrap.Material = Enum.Material.SmoothPlastic
		scrap.Size = Vector3.new(0.5, 0.05, 0.6)
		local spot = position + Vector3.new(math.cos(index * 1.7) * 1.2, -1.9, math.sin(index * 1.7) * 1.2)
		scrap.CFrame = CFrame.new(spot) * CFrame.Angles(0, index * 1.3, 0)
		scrap.Parent = parent
		Debris:AddItem(scrap, EvidenceConfig.ScrapSeconds)
	end
end

local function onTorn(shadow: Participant, position: Vector3)
	scraps(position)
	local room = roomAt(position)
	local tone = Evidence.tone(shadow.Mask)
	witnesses(position, shadow, nil, function(listener, sense)
		if sense == "See" then
			note(listener, "SawTear", room, Evidence.glimpse(tone, rand))
		else
			note(listener, "HeardTear", room, nil)
		end
	end)
end

local function onBlackout(saboteur: Participant)
	if not EvidenceConfig.Blackout.Enabled then
		return
	end
	local root = Match.root(saboteur)
	if not root then
		return
	end
	local room = roomAt(root.Position)
	-- Sometimes the trace is wrong: another room of the map.
	if rand() >= EvidenceConfig.Blackout.Accuracy then
		local others = {}
		for _, box in MapService.markers("Rooms") do
			if box.Name ~= room then
				table.insert(others, box.Name)
			end
		end
		if #others > 0 then
			room = others[random:NextInteger(1, #others)]
		end
	end
	local playing = Match.PlayingSince
	task.delay(Combat.Blackout.Seconds, function()
		if Match.State ~= "Playing" or Match.PlayingSince ~= playing then
			return
		end
		for _, listener in Match.Participants do
			if listener ~= saboteur and listener.State == "Alive" then
				note(listener, "Lights", room, nil)
			end
		end
	end)
end

local function reset()
	books = {}
	trails = {}
	prints = {}
	noted = {}
	if folder then
		folder:Destroy()
		folder = nil
	end
end

function EvidenceService.init()
	if not EvidenceConfig.Enabled then
		return
	end
	Match.on("Down", onDown)
	Match.on("ThrowLanded", onThrowLanded)
	Match.on("Torn", onTorn)
	Match.on("Blackout", onBlackout)
	Match.on("State", function(state)
		if state == "Playing" or state == "Results" or state == "Waiting" then
			reset()
		end
	end)
end

function EvidenceService.start()
	if not EvidenceConfig.Enabled then
		return
	end
	local every = EvidenceConfig.Footprints.Every
	local nextStep = 0
	while true do
		task.wait(0.3)
		if Match.State == "Playing" then
			local now = os.clock()
			if now >= nextStep then
				nextStep = now + every
				for phantom, trail in trails do
					if now > trail.Until or phantom.State ~= "Alive" then
						trails[phantom] = nil
					else
						stepPrint(phantom, trail)
					end
				end
			end
			checkPrints()
		end
	end
end

return EvidenceService
