-- Candy coins and clue pages, scattered round the map each round.
--
-- Coins: anyone still standing picks them up by touching them, up to a cap
-- a round. They come back a while after they're taken, somewhere else.
--
-- Clue pages fill the Truth Bell, which the guests share (Rules/Bell). At
-- half full the bell chimes the room the Phantom is in at that moment; when
-- it's full it lights the Phantom up for everyone for a moment, then
-- empties. A bigger party needs more pages, and the bell rings at most
-- Rewards.Bell.MaxRings times a round. A Shadow who touches a page tears it
-- up instead, which leaves scraps and leads for anyone nearby
-- (EvidenceService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Rewards = require(Shared.Config.Rewards)
local Roles = require(Shared.Config.Roles)
local BellRules = require(Shared.Rules.Bell)
local Match = require(script.Parent.Parent.Lib.Match)
local MapService = require(script.Parent.MapService)

local Remotes = ReplicatedStorage.Remotes
local RoundRemote = Remotes.Round :: RemoteEvent
local Fx = Remotes.Fx :: RemoteEvent

-- Share of the coin spots that hold a coin at once, and how soon a taken
-- coin comes back somewhere free.
local COIN_SHARE = 0.55
local COIN_RESPAWN = { 8, 16 }
-- Pages out at once.
local PAGES = 5
local PAGE_RESPAWN = { 10, 20 }

local PickupService = {}

local folder: Folder? = nil
local bell: BellRules.Bell = BellRules.new(0)
local running = 0
-- The room the bell last chimed, while it's still on screen.
local hintRoom: string? = nil
local random = Random.new()

local function participantFor(part: BasePart): Match.Participant?
	local character = part:FindFirstAncestorOfClass("Model")
	return Match.byCharacter(character)
end

local function everyoneInRound(): { Player }
	local list = {}
	for _, participant in Match.Participants do
		if participant.Player then
			table.insert(list, participant.Player)
		end
	end
	return list
end

local function sendBell()
	local message = { Kind = "Bell", Value = bell.Value, Room = hintRoom, Spent = bell.Spent, Need = bell.Need }
	for _, player in Players:GetPlayers() do
		RoundRemote:FireClient(player, message)
	end
end

local function phantomRoom(): string?
	local phantom = Match.withRole("Phantom")
	local root = phantom and Match.root(phantom)
	if not phantom or not root or phantom.State == "Out" then
		return nil
	end
	return MapService.roomAt(root.Position) or "grounds"
end

-- What a page brought to the bell does.
local function ring(event: string?)
	local generation = running
	if event == "Ring" then
		local phantom = Match.withRole("Phantom")
		if phantom and phantom.Character and phantom.State ~= "Out" then
			for _, player in Players:GetPlayers() do
				Fx:FireClient(player, "Reveal", phantom.Character, Rewards.Bell.RevealSeconds)
			end
		end
		hintRoom = nil
		Match.fire("Rang")
	elseif event == "Hint" then
		hintRoom = phantomRoom()
		local shown = hintRoom
		if not Rewards.Bell.TrackRoom then
			-- A snapshot: it fades, and the Phantom may have moved on.
			task.delay(Rewards.Bell.HintSeconds, function()
				if running == generation and hintRoom == shown then
					hintRoom = nil
					sendBell()
				end
			end)
		end
	end
	sendBell()
end

local function freeSpot(markers: { BasePart }, kind: string): BasePart?
	local taken = {}
	for _, item in (folder :: Folder):GetChildren() do
		if item:GetAttribute("Kind") == kind then
			taken[item:GetAttribute("Spot")] = true
		end
	end
	local free = {}
	for index in markers do
		if not taken[index] then
			table.insert(free, index)
		end
	end
	if #free == 0 then
		return nil
	end
	local index = free[random:NextInteger(1, #free)]
	local marker = markers[index]
	marker:SetAttribute("Index", index)
	return marker
end

local function makeCoin(markers: { BasePart }, generation: number)
	local marker = freeSpot(markers, "Coin")
	if not marker or not folder then
		return
	end
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.35, 1.7, 1.7)
	coin.Color = Color3.fromRGB(255, 206, 84)
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CFrame = marker.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	coin:SetAttribute("Kind", "Coin")
	coin:SetAttribute("Spot", marker:GetAttribute("Index"))
	coin:AddTag("Pickup")
	local taken = false
	coin.Touched:Connect(function(part)
		if taken then
			return
		end
		local participant = participantFor(part)
		if not participant or participant.State ~= "Alive" or Match.State ~= "Playing" then
			return
		end
		if participant.Coins >= Rewards.Coins.Cap then
			return
		end
		taken = true
		participant.Coins += 1
		if participant.Player then
			Fx:FireClient(participant.Player, "Coin", coin.Position, participant.Coins, Rewards.Coins.Cap)
		end
		coin:Destroy()
		task.delay(random:NextNumber(COIN_RESPAWN[1], COIN_RESPAWN[2]), function()
			if running == generation and Match.State == "Playing" then
				makeCoin(markers, generation)
			end
		end)
	end)
	coin.Parent = folder
end

local function makePage(markers: { BasePart }, generation: number)
	local marker = freeSpot(markers, "Page")
	if not marker or not folder then
		return
	end
	local page = Instance.new("Part")
	page.Name = "CluePage"
	page.Size = Vector3.new(1.4, 0.1, 1.8)
	page.Color = Color3.fromRGB(255, 244, 214)
	page.Material = Enum.Material.SmoothPlastic
	page.Anchored = true
	page.CanCollide = false
	page.CanQuery = false
	page.CFrame = marker.CFrame * CFrame.Angles(math.rad(-25), random:NextNumber(0, math.pi * 2), 0)
	page:SetAttribute("Kind", "Page")
	page:SetAttribute("Spot", marker:GetAttribute("Index"))
	page:AddTag("Pickup")
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(180, 220, 255)
	glow.Range = 8
	glow.Brightness = 1.4
	glow.Parent = page
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(180, 220, 255)
	sparkle.Parent = page
	local taken = false
	page.Touched:Connect(function(part)
		if taken then
			return
		end
		local participant = participantFor(part)
		if not participant or participant.State ~= "Alive" or Match.State ~= "Playing" then
			return
		end
		taken = true
		local position = page.Position
		page:Destroy()
		if Roles.team(participant.Role) == "Shadows" then
			for _, player in everyoneInRound() do
				Fx:FireClient(player, "Torn", position)
			end
			Match.fire("Torn", participant, position)
		else
			participant.Clues += 1
			for _, player in everyoneInRound() do
				Fx:FireClient(player, "Page", position, participant.Player == player)
			end
			Match.fire("Page", participant, position)
			ring(BellRules.add(bell))
		end
		task.delay(random:NextNumber(PAGE_RESPAWN[1], PAGE_RESPAWN[2]), function()
			if running == generation and Match.State == "Playing" then
				makePage(markers, generation)
			end
		end)
	end)
	page.Parent = folder
end

-- Scatters coins and pages as the round starts playing.
function PickupService.begin()
	PickupService.finish()
	running += 1
	local guests = 0
	for _, participant in Match.Participants do
		if Roles.team(participant.Role) == "Guests" then
			guests += 1
		end
	end
	bell = BellRules.new(guests)
	hintRoom = nil
	local generation = running
	local holder = Instance.new("Folder")
	holder.Name = "Pickups"
	holder.Parent = MapService.current() or Workspace
	folder = holder
	local coins = MapService.markers("Coins")
	for _ = 1, math.floor(#coins * COIN_SHARE) do
		makeCoin(coins, generation)
	end
	local pages = MapService.markers("Clues")
	for _ = 1, math.min(PAGES, #pages) do
		makePage(pages, generation)
	end
	sendBell()
end

function PickupService.finish()
	running += 1
	if folder then
		folder:Destroy()
		folder = nil
	end
end

-- With TrackRoom on (the first version's rule), keep naming the Phantom's
-- room as they move while the bell is past half.
function PickupService.start()
	while true do
		task.wait(3)
		if Rewards.Bell.TrackRoom and Match.State == "Playing" and bell.Hinted then
			local room = phantomRoom()
			if room ~= hintRoom then
				hintRoom = room
				sendBell()
			end
		end
	end
end

function PickupService.init() end

return PickupService
