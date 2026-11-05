-- Runs the rounds, one after another:
--
--   Waiting       until enough players are in the lobby.
--   Intermission  a countdown while everyone votes for the next map.
--   Reveal        players stand still in the map while their role shows.
--   Playing       the round itself, until one team wins or time runs out.
--   Results       who was who, who won and what everyone earned.
--
-- Roles are dealt by Rules/Deal with tickets, so everyone gets their turn.
-- Each player is told only their own role (the Shadows also learn each
-- other). In Studio a lone tester gets a practice round against dummies
-- instead, taking each role in turn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Game = require(Shared.Config.Game)
local Roles = require(Shared.Config.Roles)
local Deal = require(Shared.Rules.Deal)
local Progress = require(Shared.Rules.Progress)
local Round = require(Shared.Rules.Round)
local Vote = require(Shared.Rules.Vote)
local Lib = script.Parent.Parent.Lib
local Dummy = require(Lib.Dummy)
local Match = require(Lib.Match)
local RateLimiter = require(Lib.RateLimiter)
local AnalyticsService = require(script.Parent.AnalyticsService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local LobbyService = require(script.Parent.LobbyService)
local MapService = require(script.Parent.MapService)
local OutfitService = require(script.Parent.OutfitService)
local PickupService = require(script.Parent.PickupService)
local ProfileService = require(script.Parent.ProfileService)

local Remotes = ReplicatedStorage.Remotes
local RoundRemote = Remotes.Round :: RemoteEvent
local VoteRemote = Remotes.Vote :: RemoteEvent

local TICK = 0.25
-- How long after going out a player is sent back to the lobby.
local OUT_SECONDS = 2.5
local PRACTICE_DUMMIES = 5

local RoundService = {}

local tickets: { [number]: Deal.Tickets } = {}
local sittingOut: { [Player]: boolean } = {}
local votes: { [Player]: string } = {}
local choices: { string } = {}
local lastMap: string? = nil
local practiceTurn = 0
local voteLimiter = RateLimiter.new(0.3)
local random = Random.new()

local function rand(): number
	return random:NextNumber()
end

local function broadcast(message: { [string]: any })
	for _, player in Players:GetPlayers() do
		RoundRemote:FireClient(player, message)
	end
end

local function sendState(player: Player?)
	local message = {
		Kind = "State",
		State = Match.State,
		EndsAt = Match.EndsAtServer,
		Map = Match.MapId,
		MapName = if Match.MapId then MapService.name(Match.MapId) else nil,
		Practice = Match.Practice,
		InRound = false,
	}
	if player then
		message.InRound = Match.get(player) ~= nil
		RoundRemote:FireClient(player, message)
		return
	end
	for _, each in Players:GetPlayers() do
		message.InRound = Match.get(each) ~= nil
		RoundRemote:FireClient(each, table.clone(message))
	end
end

local function setState(state: string, seconds: number?)
	Match.setState(state, seconds, Workspace:GetServerTimeNow())
	sendState(nil)
end

-- Players ready for the next round: loaded, standing, and not sitting out.
local function eligible(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if DataService.get(player) and humanoid and humanoid.Health > 0 and not sittingOut[player] then
			table.insert(list, player)
		end
	end
	return list
end

local function practiceAllowed(): boolean
	return RunService:IsStudio()
end

local function enough(count: number): boolean
	return count >= Game.MinPlayers or (count == 1 and practiceAllowed())
end

-- Waiting ----------------------------------------------------------------

local function waitForPlayers()
	setState("Waiting")
	while true do
		local count = #eligible()
		if enough(count) then
			return
		end
		LobbyService.setBoard(`Waiting for party guests\n{count} of {Game.MinPlayers}`)
		task.wait(1)
	end
end

-- Intermission and the vote ---------------------------------------------

local function sendVote()
	broadcast({ Kind = "Vote", Choices = choices, Counts = Vote.counts(choices, votes), EndsAt = Match.EndsAtServer })
end

local function intermission(): (boolean, string?)
	votes = {}
	choices = Vote.choices(MapService.Ids, Game.VoteChoices, lastMap, rand)
	setState("Intermission", Game.Seconds.Intermission)
	sendVote()
	while os.clock() < Match.EndsAt do
		if not enough(#eligible()) then
			return false, nil
		end
		local left = math.ceil(Match.EndsAt - os.clock())
		local names = {}
		for _, id in choices do
			table.insert(names, MapService.name(id))
		end
		LobbyService.setBoard(`Vote for the next party!\n{table.concat(names, "  ·  ")}\n{Format.clock(left)}`)
		task.wait(0.5)
	end
	local winner = Vote.winner(choices, votes, rand)
	lastMap = winner
	return true, winner
end

local function onVote(player: Player, mapId: unknown)
	if Match.State ~= "Intermission" or typeof(mapId) ~= "string" or not voteLimiter:allow(player) then
		return
	end
	if not table.find(choices, mapId) then
		return
	end
	votes[player] = mapId :: string
	sendVote()
end

-- Dealing ------------------------------------------------------------------

-- Roles for a live round: by tickets, so everyone gets their turn.
local function dealLive(players: { Player }): { [Player]: string }
	local ids = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	local byId = Deal.deal(ids, tickets, rand)
	Deal.afterDeal(tickets, byId)
	local roles = {}
	for _, player in players do
		roles[player] = byId[player.UserId] or "Guest"
	end
	return roles
end

local function shuffled(list: { BasePart }): { BasePart }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = random:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- Puts everyone in the round, in the map, frozen, and tells each their role.
local function setUp(players: { Player }, mapId: string): boolean
	Match.reset()
	local map = MapService.load(mapId)
	Match.Map = map
	Match.MapId = mapId
	local spawns = shuffled(MapService.markers("Spawns"))
	if #spawns == 0 then
		warn(`Map {mapId} has no spawns`)
		return false
	end
	local practice = #players == 1 and practiceAllowed()
	Match.Practice = practice

	local roles: { [any]: string } = {}
	if practice then
		practiceTurn += 1
		local order = Game.Practice.Order
		local mine = order[(practiceTurn - 1) % #order + 1]
		roles[players[1]] = mine
	else
		roles = dealLive(players)
	end

	local index = 0
	local function nextSpawn(): CFrame
		index += 1
		return spawns[(index - 1) % #spawns + 1].CFrame
	end
	for _, player in players do
		local character = player.Character
		if character then
			Match.add(player, {
				Player = player,
				UserId = player.UserId,
				Name = player.DisplayName,
				Character = character,
				Role = roles[player],
			})
			character:PivotTo(nextSpawn())
		end
	end

	if practice then
		-- Dummies take the special roles the tester doesn't have, and the
		-- rest are guests.
		local left = {}
		for _, roleId in Roles.DEAL_ORDER do
			if roleId ~= roles[players[1]] then
				table.insert(left, roleId)
			end
		end
		for i = 1, PRACTICE_DUMMIES do
			local model = Dummy.new(i, nextSpawn())
			model.Parent = map
			local roleId = left[i] or "Guest"
			Match.add(model, { Player = nil, UserId = -i, Name = model.Name, Character = model, Role = roleId })
			OutfitService.dress(model, {
				Mask = ({ "mask_cat", "mask_fox", "mask_moon", "mask_jester", "mask_ghost" })[i] or "mask_domino",
				Trail = "trail_none",
			})
		end
	end

	-- Everyone's names (not roles), so clients can show who's in.
	local guests = {}
	for _, participant in Match.Participants do
		table.insert(guests, { UserId = participant.UserId, Name = participant.Name })
	end
	for _, participant in Match.Participants do
		CombatService.setMoving(participant, false)
		local player = participant.Player
		if player then
			local allies = {}
			if Roles.team(participant.Role) == "Shadows" then
				for _, other in Match.Participants do
					if other ~= participant and Roles.team(other.Role) == "Shadows" then
						table.insert(allies, { Name = other.Name, Role = other.Role })
					end
				end
			end
			RoundRemote:FireClient(player, {
				Kind = "Role",
				Role = participant.Role,
				Allies = allies,
				Map = mapId,
				MapName = MapService.name(mapId),
				Practice = practice,
				Guests = guests,
			})
		end
	end
	AnalyticsService.roleDealt(players)
	return true
end

-- Playing --------------------------------------------------------------

local function sendCensus()
	local census = Round.census(Match.entries())
	local total = 0
	for _ in Match.Participants do
		total += 1
	end
	broadcast({ Kind = "Census", Alive = census.Alive, Dazed = census.Dazed, Out = census.Out, Total = total })
	return census
end

local function play(): (string, string)
	local count = 0
	for _ in Match.Participants do
		count += 1
	end
	local length = if Match.Practice then Game.Practice.Round else Round.length(count)
	Match.PlayingSince = os.clock()
	setState("Playing", length)
	for _, participant in Match.Participants do
		CombatService.setMoving(participant, true)
		if participant.Player == nil and participant.Character then
			Dummy.wander(participant.Character, MapService.markers("Spawns"), function()
				return Match.State == "Playing" and participant.State == "Alive"
			end)
		end
	end
	CombatService.begin()
	PickupService.begin()
	local finalSent = false
	local lastCensus = 0
	local mapName = MapService.name(Match.MapId or "")
	while true do
		task.wait(TICK)
		local timeLeft = Match.EndsAt - os.clock()
		local hasShadow = false
		for _, participant in Match.Participants do
			if participant.Role == "Phantom" then
				hasShadow = true
			end
		end
		local winner, reason = Round.outcome(Match.entries(), timeLeft, not hasShadow)
		if winner then
			return winner, reason :: string
		end
		if not finalSent and timeLeft <= Game.Seconds.Final then
			finalSent = true
			broadcast({ Kind = "Final" })
		end
		if os.clock() - lastCensus >= 1 then
			lastCensus = os.clock()
			local census = sendCensus()
			LobbyService.setBoard(
				`Party in progress at {mapName}\n{Format.clock(math.max(0, math.ceil(timeLeft)))} left · {census.Alive} standing`
			)
		end
	end
end

-- Results --------------------------------------------------------------

local function results(winner: string, reason: string)
	setState("Results", Game.Seconds.Results)
	CombatService.finish()
	PickupService.finish()
	-- Guests still dazed when the Phantom wins count as tagged.
	for _, participant in Match.Participants do
		if participant.State == "Dazed" and participant.TaggedBy and participant.TaggedBy.Role == "Phantom" then
			participant.TaggedBy.Tags += 1
		end
	end
	local reveal = {}
	for _, participant in Match.Participants do
		table.insert(reveal, {
			UserId = participant.UserId,
			Name = participant.Name,
			Role = participant.Role,
			State = participant.State,
			Hero = participant.Hero,
			Takedown = participant.Takedown,
			Tags = participant.Tags,
			Revives = participant.Revives,
			Clues = participant.Clues,
		})
	end
	table.sort(reveal, function(a, b)
		local order = { Phantom = 1, Saboteur = 2, Guardian = 3, Medic = 4, Guest = 5 }
		if order[a.Role] ~= order[b.Role] then
			return order[a.Role] < order[b.Role]
		end
		return a.Name < b.Name
	end)
	broadcast({
		Kind = "Results",
		Winner = winner,
		Reason = reason,
		Map = Match.MapId,
		Practice = Match.Practice,
		Reveal = reveal,
	})
	LobbyService.setBoard(if winner == "Guests" then "The guests win!" else "The Phantom wins!")

	for _, participant in Match.Participants do
		local player = participant.Player
		if player and player.Parent then
			local won = Roles.team(participant.Role) == winner
			local survived = participant.State == "Alive"
			local pay = Progress.pay({
				Won = won,
				Survived = survived,
				Tags = participant.Tags,
				Takedown = participant.Takedown,
				Revives = participant.Revives,
				Clues = participant.Clues,
				Coins = participant.Coins,
			})
			if Match.Practice then
				-- Practice pays nothing, so it can't be farmed.
				pay = { Coins = 0, Xp = 0, Lines = { { Label = "Practice round", Coins = 0, Xp = 0 } } }
			end
			ProfileService.award(player, pay, {
				Role = participant.Role,
				Won = won and not Match.Practice,
				Survived = survived and not Match.Practice,
				Tags = if Match.Practice then 0 else participant.Tags,
				Takedown = participant.Takedown and not Match.Practice,
				Revives = if Match.Practice then 0 else participant.Revives,
				Clues = if Match.Practice then 0 else participant.Clues,
			})
			RoundRemote:FireClient(
				player,
				{ Kind = "Pay", Coins = pay.Coins, Xp = pay.Xp, Lines = pay.Lines, Won = won }
			)
			AnalyticsService.roundPlayed(player, participant.Role, won, Match.Practice)
		end
	end
	task.wait(Game.Seconds.Results)
end

local function cleanUp()
	for _, participant in Match.Participants do
		local player = participant.Player
		if player and player.Parent and player.Character == participant.Character then
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
	MapService.unload()
	Match.reset()
end

-- Players leaving, falling or going out mid-round ---------------------------

local function onOut(participant: Match.Participant)
	local player = participant.Player
	if player then
		RoundRemote:FireClient(player, { Kind = "You", State = "Out" })
	end
	task.delay(OUT_SECONDS, function()
		if not Match.live() or Match.get(participant.Key) ~= participant then
			return
		end
		if player and player.Parent then
			player:LoadCharacter()
		elseif participant.Character and participant.Player == nil then
			participant.Character:Destroy()
		end
	end)
end

local function forfeit(participant: Match.Participant)
	if participant.State == "Out" or not Match.live() then
		return
	end
	CombatService.leave(participant)
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		local participant = Match.get(player)
		if participant and participant.Character == character then
			forfeit(participant)
		end
	end)
end

function RoundService.init()
	VoteRemote.OnServerEvent:Connect(onVote)
	Match.on("Out", onOut)
	ProfileService.handle("SitOut", function(player, value)
		if typeof(value) ~= "boolean" then
			return { Ok = false }
		end
		sittingOut[player] = value or nil
		return { Ok = true, SittingOut = value }
	end)
	ProfileService.handle("RoundState", function(player)
		sendState(player)
		if Match.State == "Intermission" then
			RoundRemote:FireClient(
				player,
				{ Kind = "Vote", Choices = choices, Counts = Vote.counts(choices, votes), EndsAt = Match.EndsAtServer }
			)
		end
		return { Ok = true }
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(watchCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local participant = Match.get(player)
		if participant then
			forfeit(participant)
		end
		votes[player] = nil
		sittingOut[player] = nil
		tickets[player.UserId] = nil
		voteLimiter:forget(player)
	end)
end

function RoundService.start()
	while true do
		waitForPlayers()
		local ok, mapId = intermission()
		if ok and mapId then
			local players = eligible()
			if enough(#players) and setUp(players, mapId) then
				setState("Reveal", Game.Seconds.Reveal)
				LobbyService.setBoard(`Party starting at {MapService.name(mapId)}...`)
				task.wait(Game.Seconds.Reveal)
				local winner, reason = play()
				results(winner, reason)
			end
			cleanUp()
		end
	end
end

return RoundService
