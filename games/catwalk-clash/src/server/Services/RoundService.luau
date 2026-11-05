-- The show: one round after another, for everyone in the server.
--
--   Lobby      players hang out in Glow Plaza, try on looks, shop
--   ThemeVote  the lobby votes between three themes
--   Reveal     the winning theme is announced
--   Dressing   contestants dress in their backstage booths (and can press
--              Ready); rivals fill the bracket if the server is small
--   Showtime   the knockout bracket: two walkers at a time stride down
--              their lanes, pose, and the audience votes, alongside the
--              three judges; the winner moves on
--   Crowning   the top three take the podium and the champion is crowned
--
-- RoundState (a Configuration in ReplicatedStorage) holds the state as
-- attributes, which every client reads: Phase, EndsAt (server time), Round,
-- Theme, Spotlight, Options and OptionVotes (comma lists), Ready ("2/5"),
-- Step and Match. Everything else goes out on the Show remote as a table
-- with a Type: Bracket, Match, VoteCount, Result, Crown, Dressing, YouWalk,
-- YouDone and Results.
--
-- Fair voting: walkers can't vote in their own matchup; the vote split is
-- hidden until the votes close; votes open only once both outfits have
-- been on show; friends of a walker and brand-new accounts count half; and
-- the judges always vote too, so a few voters can't swing a quiet server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Game = require(Config.Game)
local Themes = require(Config.Themes)
local Layout = require(Config.Layout)
local People = require(Config.People)
local Bracket = require(Shared.Bracket)
local Voting = require(Shared.Voting)
local Judge = require(Shared.Judge)
local StyleScore = require(Shared.StyleScore)
local ThemePicker = require(Shared.ThemePicker)
local Look = require(Shared.Look)
local Pieces = require(Shared.Build.Pieces)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local DataService = require(script.Parent.DataService)
local ProfileService = require(script.Parent.ProfileService)
local LookService = require(script.Parent.LookService)
local RivalService = require(script.Parent.RivalService)
local WorldService = require(script.Parent.WorldService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local PlayerHooks = require(script.Parent.Parent.Lib.PlayerHooks)

local Remotes = ReplicatedStorage.Remotes
local Show = Remotes.Show :: RemoteEvent
local State = ReplicatedStorage.RoundState :: Configuration

local RoundService = {}

type Walker = {
	Id: string,
	Name: string,
	Player: Player?,
	Rival: RivalService.Rival?,
	Rating: number,
	Booth: number,
	Ready: boolean,
	Look: Look.Look,
	Summary: Look.Summary,
	Names: { string },
	Gone: boolean,
	Spot: CFrame?,
}

type CurrentMatch = {
	Id: number,
	A: Walker,
	B: Walker,
	OpensAt: number,
	ClosesAt: number,
	Ballots: { [number]: Voting.Ballot },
	Dirty: boolean,
}

local ROUND_ROBIN_THEMES = 16
local STAGE_GUARD_SECONDS = 0.5
local MATCH_SECONDS = Game.Match.Intro + Game.Match.Walk + Game.Match.Pose + Game.Match.VoteGrace + Game.Match.Result

local rng = Random.new()
local roundNumber = 0
local recentThemes: { string } = {}
local themeVotes: { [Player]: number } = {}
local walkers: { [string]: Walker } = {}
local walking: { [Player]: boolean } = {}
local current: CurrentMatch? = nil
local matchCounter = 0
local bracket: Bracket.Bracket? = nil
-- The current matchup as sent to clients, for players who join mid-show.
local matchMessage: { [string]: any }? = nil
local votesThisRound: { [Player]: number } = {}
local tasteThisRound: { [Player]: number } = {}
local posesSeen: { [Player]: { [string]: boolean } } = {}
local friends: { [number]: { [number]: boolean } } = {}
local voteLimiter = RateLimiter.new(Game.Cooldowns.Vote)
local themeLimiter = RateLimiter.new(0.3)
local readyLimiter = RateLimiter.new(0.3)
local crowns: { Instance } = {}
local theme = Themes.List[1]

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rngInt(n: number): number
	return rng:NextInteger(1, n)
end

local function rngNumber(): number
	return rng:NextNumber()
end

local function setPhase(phase: string, seconds: number)
	State:SetAttribute("Phase", phase)
	State:SetAttribute("EndsAt", now() + seconds)
end

local function setStep(step: string, endsAt: number)
	State:SetAttribute("Step", step)
	State:SetAttribute("StepEndsAt", endsAt)
end

-- Waits until a server time, or until check() returns true.
local function waitUntil(time: number, check: (() -> boolean)?)
	while now() < time do
		if check and check() then
			return
		end
		task.wait(0.2)
	end
end

local function playerId(player: Player): string
	return `P{player.UserId}`
end

local function modelOf(walker: Walker): Model?
	if walker.Rival then
		return walker.Rival.Model
	end
	local player = walker.Player
	return player and player.Character
end

local function rootOf(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Moves a player's character; anchored holds it still.
local function placeCharacter(character: Model?, cframe: CFrame, anchored: boolean)
	local root = rootOf(character)
	if not character or not root then
		return
	end
	root.Anchored = false
	character:PivotTo(cframe)
	root.Anchored = anchored
end

local function place(walker: Walker, cframe: CFrame, anchored: boolean)
	if walker.Rival then
		RivalService.place(walker.Rival, cframe, anchored)
	else
		placeCharacter(modelOf(walker), cframe, anchored)
	end
end

local function rankName(score: number): string
	return ProfileService.rankOf(score).Name
end

local function info(walker: Walker): { [string]: any }
	return {
		Id = walker.Id,
		Name = walker.Name,
		Rating = walker.Rating,
		Rank = rankName(walker.Rating),
		Rival = walker.Rival ~= nil,
		UserId = if walker.Player then walker.Player.UserId else 0,
		Model = modelOf(walker),
		Entrance = walker.Look.Entrance,
		Pose = walker.Look.Pose,
	}
end

local function screens(top: string?, main: string?, sub: string?)
	WorldService.screens(top, main, sub)
end

local function themeName(): string
	return theme.Name
end

local function isSpotlight(): boolean
	return State:GetAttribute("Spotlight") == theme.Id
end

local function multiplier(): number
	return if isSpotlight() then Game.Rewards.SpotlightMultiplier else 1
end

local function contestants(): { Walker }
	local list = {}
	for _, walker in walkers do
		table.insert(list, walker)
	end
	table.sort(list, function(a, b)
		return a.Booth < b.Booth
	end)
	return list
end

local function playerWalkers(): { Walker }
	local list = {}
	for _, walker in contestants() do
		if walker.Player and not walker.Gone then
			table.insert(list, walker)
		end
	end
	return list
end

-- Friendships between players in the server, checked once when they join.
local function checkFriends(player: Player)
	friends[player.UserId] = friends[player.UserId] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, result = pcall(player.IsFriendsWithAsync, player, other.UserId)
			if ok and result then
				friends[player.UserId][other.UserId] = true
				friends[other.UserId] = friends[other.UserId] or {}
				friends[other.UserId][player.UserId] = true
			end
		end
	end
end

local function areFriends(a: number, b: number): boolean
	local list = friends[a]
	return list ~= nil and list[b] == true
end

------------------------------------------------------------------------------
-- Lobby and theme vote

local function optionList(): { string }
	local text = State:GetAttribute("Options")
	if type(text) ~= "string" or text == "" then
		return {}
	end
	return string.split(text, ",")
end

local function updateOptionVotes()
	local counts = table.create(#optionList(), 0)
	for _, index in themeVotes do
		if counts[index] then
			counts[index] += 1
		end
	end
	for index, count in counts do
		counts[index] = tostring(count)
	end
	State:SetAttribute("OptionVotes", table.concat(counts, ","))
end

local function onThemeVote(player: Player, index: any)
	if State:GetAttribute("Phase") ~= "ThemeVote" or not themeLimiter:allow(player) then
		return
	end
	if type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #optionList() then
		themeVotes[player] = index
		updateOptionVotes()
	end
end

local function runLobby()
	roundNumber += 1
	State:SetAttribute("Round", roundNumber)
	State:SetAttribute("Theme", "")
	State:SetAttribute("Options", "")
	State:SetAttribute("Step", "")
	State:SetAttribute("Match", "")
	local time = os.time()
	State:SetAttribute("Spotlight", ThemePicker.spotlight(Themes.List, time))

	local lobbySeconds = Game.Round.Intermission - Game.Round.ThemeVote
	setPhase("Lobby", lobbySeconds)
	screens("CATWALK CLASH", "Next show soon!", "Try on looks while you wait")
	waitUntil(State:GetAttribute("EndsAt"))

	local options = ThemePicker.options(Themes.List, time, recentThemes, rngInt, 3)
	themeVotes = {}
	State:SetAttribute("Options", table.concat(options, ","))
	updateOptionVotes()
	setPhase("ThemeVote", Game.Round.ThemeVote)
	screens("VOTE FOR THE THEME", "Pick the next theme!", "Open the vote card")
	waitUntil(State:GetAttribute("EndsAt"))

	local winner = ThemePicker.winner(options, themeVotes, rngInt)
	table.insert(recentThemes, winner)
	while #recentThemes > ROUND_ROBIN_THEMES do
		table.remove(recentThemes, 1)
	end
	theme = Themes.get(winner) or Themes.List[1]
	State:SetAttribute("Theme", theme.Id)
	for _, player in Players:GetPlayers() do
		AnalyticsService.event(player, "ThemePlayed", if themeVotes[player] then 1 else 0, { theme.Id })
	end
end

------------------------------------------------------------------------------
-- Dressing

local function freeBooth(): number?
	local used = {}
	for _, walker in walkers do
		used[walker.Booth] = true
	end
	for index = 1, #Layout.Booths do
		if not used[index] then
			return index
		end
	end
	return nil
end

local function canEnter(player: Player): boolean
	local data = DataService.get(player)
	return data ~= nil and not data.Settings.WatchOnly and player.Character ~= nil and walkers[playerId(player)] == nil
end

local function enter(player: Player)
	local booth = freeBooth()
	if not booth then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local dressed = LookService.current(player)
	local look = if dressed then dressed.Look else Look.default()
	local walker: Walker = {
		Id = playerId(player),
		Name = player.DisplayName,
		Player = player,
		Rival = nil,
		Rating = data.StyleScore,
		Booth = booth,
		Ready = false,
		Look = look,
		Summary = Look.summary(look),
		Names = {},
		Gone = false,
		Spot = nil,
	}
	walkers[walker.Id] = walker
	placeCharacter(player.Character, Layout.Booths[booth], false)
	Show:FireClient(player, { Type = "Dressing", Booth = booth })
end

local function updateReady()
	local list = playerWalkers()
	local ready = 0
	for _, walker in list do
		if walker.Ready then
			ready += 1
		end
	end
	State:SetAttribute("Ready", `{ready}/{#list}`)
	return ready, #list
end

local function onReady(player: Player, isReady: any)
	if State:GetAttribute("Phase") ~= "Dressing" or not readyLimiter:allow(player) then
		return
	end
	local walker = walkers[playerId(player)]
	if walker then
		if isReady == true and not walker.Ready then
			local left = math.max(0, (State:GetAttribute("EndsAt") :: number) - now())
			AnalyticsService.event(player, "ReadyPressed", math.floor(left))
		end
		walker.Ready = isReady == true
		local ready, total = updateReady()
		if total > 0 and ready == total then
			local soon = now() + Game.Round.AllReady
			if (State:GetAttribute("EndsAt") :: number) > soon then
				State:SetAttribute("EndsAt", soon)
			end
		end
	end
end

local function addRivals()
	local needed = math.max(0, Game.Round.MinEntrants - #playerWalkers())
	for _, rivalInfo in RivalService.pick(needed, rng) do
		local booth = freeBooth()
		if not booth then
			break
		end
		local rival = RivalService.spawn(rivalInfo, theme, rng, Layout.Booths[booth])
		local walker: Walker = {
			Id = `R{rivalInfo.Id}`,
			Name = rivalInfo.Name,
			Player = nil,
			Rival = rival,
			Rating = rivalInfo.Rating,
			Booth = booth,
			Ready = true,
			Look = rival.Look,
			Summary = Look.summary(rival.Look),
			Names = {},
			Gone = false,
			Spot = nil,
		}
		walkers[walker.Id] = walker
	end
end

local function runDressing()
	setPhase("Reveal", Game.Round.Reveal)
	local spotlightText = if isSpotlight() then "SPOTLIGHT THEME: double rewards!" else theme.Hint
	screens("THE THEME IS", themeName(), spotlightText)
	waitUntil(State:GetAttribute("EndsAt"))

	walkers = {}
	for _, player in Players:GetPlayers() do
		if canEnter(player) then
			enter(player)
		end
	end
	updateReady()
	setPhase("Dressing", Game.Round.Dressing)
	screens(`THEME: {string.upper(themeName())}`, "Backstage: get dressed!", theme.Hint)
	addRivals()

	local lastSecond = -1
	waitUntil(State:GetAttribute("EndsAt") :: number, function()
		local endsAt = State:GetAttribute("EndsAt") :: number
		local left = endsAt - now()
		-- Late joiners enter while there's still time to dress.
		if left > Game.Round.LateJoinCutoff then
			for _, player in Players:GetPlayers() do
				if canEnter(player) then
					enter(player)
					updateReady()
				end
			end
		end
		local second = math.ceil(left)
		if second ~= lastSecond and second % 10 == 0 then
			lastSecond = second
			screens(nil, nil, `{second} seconds to dress`)
		end
		return now() >= endsAt
	end)
end

------------------------------------------------------------------------------
-- Showtime

local function audienceSpot(index: number): CFrame
	local spots = Layout.Audience
	local spot = spots[(index - 1) % #spots + 1]
	local lap = (index - 1) // #spots
	return spot * CFrame.new(0, 0, lap * 2.5)
end

local function seatEveryone()
	local index = 0
	for _, walker in contestants() do
		if not walker.Gone then
			index += 1
			walker.Spot = audienceSpot(index)
			place(walker, walker.Spot :: CFrame, walker.Rival ~= nil)
		end
	end
	for _, player in Players:GetPlayers() do
		if not walkers[playerId(player)] then
			index += 1
			placeCharacter(player.Character, audienceSpot(index), false)
		end
	end
end

local function lockLooks()
	for _, walker in playerWalkers() do
		LookService.setLocked(walker.Player :: Player, true)
	end
	for _, walker in playerWalkers() do
		local player = walker.Player :: Player
		LookService.settle(player, 2)
		local dressed = LookService.current(player)
		if dressed then
			walker.Look = dressed.Look
			walker.Summary = Look.summary(dressed.Look)
			walker.Names = LookService.catalogNames(player)
		end
		LookService.setLocked(player, true)
	end
end

local function sendBracket()
	if not bracket then
		return
	end
	local names = {}
	for id, walker in walkers do
		names[id] = walker.Name
	end
	Show:FireAllClients({ Type = "Bracket", Rounds = Bracket.summary(bracket), Names = names })
end

local function onCastVote(player: Player, request: any)
	local match = current
	if not match or type(request) ~= "table" or request.Id ~= match.Id or not voteLimiter:allow(player) then
		return
	end
	local ok = Voting.canVote(
		playerId(player),
		match.A.Id,
		match.B.Id,
		request.Side,
		now(),
		match.OpensAt,
		match.ClosesAt + Game.Match.VoteGrace
	)
	if not ok then
		return
	end
	-- Only a vote FOR a friend is suspect; voting against one is fine.
	local chosen = if request.Side == "A" then match.A else match.B
	local friendOfChosen = chosen.Player ~= nil and areFriends(player.UserId, chosen.Player.UserId)
	local first = match.Ballots[player.UserId] == nil
	match.Ballots[player.UserId] = Voting.ballot(Game.Voting, request.Side, friendOfChosen, player.AccountAge)
	match.Dirty = true
	if first then
		local data = DataService.get(player)
		if data then
			data.Stats.Votes += 1
		end
		ProfileService.record(player, "Vote", 1)
		local count = (votesThisRound[player] or 0) + 1
		votesThisRound[player] = count
		if count <= Game.Rewards.VoteCap then
			ProfileService.reward(player, Game.Rewards.Vote, multiplier())
		end
	end
end

-- Picks something a judge says about the result.
local function judgeLine(verdict: Judge.Verdict, winnerSide: string, share: number, themeScore: number)
	local best, bestJudge = -1, People.Judges[1]
	for index, side in verdict.Sides do
		if side == winnerSide then
			local judgeScore = rng:NextNumber()
			if judgeScore > best then
				best, bestJudge = judgeScore, People.Judges[index]
			end
		end
	end
	local lines = bestJudge.Lines.Win
	if share < 0.56 then
		lines = bestJudge.Lines.Close
	elseif themeScore >= Judge.NAILED then
		lines = bestJudge.Lines.Theme
	end
	return { Name = bestJudge.Name, Id = bestJudge.Id, Line = lines[rngInt(#lines)] }
end

-- Rewards, stats and Style Score for a player who walked.
local function settleWalker(
	walker: Walker,
	opponent: Walker,
	won: boolean,
	themeScore: number,
	roundName: string
): number
	local player = walker.Player
	local data = player and DataService.get(player)
	if not player or not data then
		return 0
	end
	local before = data.StyleScore
	local after =
		StyleScore.update(Game.StyleScore, before, opponent.Rating, won, data.Stats.Walks, opponent.Rival ~= nil)
	data.StyleScore = after
	walker.Rating = after
	data.Stats.Walks += 1

	local mult = multiplier()
	local rewards = Game.Rewards
	local sparkles = rewards.Walk.Sparkles
	local xp = rewards.Walk.Xp
	local themeShare = math.clamp(themeScore / Judge.MAX_THEME, 0, 1)
	sparkles += math.floor(rewards.ThemeBonus.Sparkles * themeShare)
	xp += math.floor(rewards.ThemeBonus.Xp * themeShare)
	if won then
		sparkles += rewards.MatchWin.Sparkles
		xp += rewards.MatchWin.Xp
		data.Stats.Wins += 1
	end
	local text = if won then "You won the matchup!" else "Great walk!"
	if mult > 1 then
		text ..= " (Spotlight x2)"
	end
	ProfileService.reward(player, { Sparkles = sparkles, Xp = xp }, mult, text)

	AnalyticsService.event(player, "MatchWalked", if won then 1 else 0, { roundName })
	ProfileService.record(player, "Walk", 1)
	if won then
		ProfileService.record(player, "MatchWin", 1)
	end
	if themeScore >= Judge.NAILED then
		data.Stats.Nailed += 1
		ProfileService.record(player, "ThemeMatch", 1)
	end
	if walker.Summary.Glows then
		ProfileService.record(player, "GlowWalk", 1)
	end
	if roundName == "Semifinal" then
		ProfileService.record(player, "ReachSemi", 1)
	end
	local seen = posesSeen[player] or {}
	posesSeen[player] = seen
	if not seen[walker.Look.Pose] then
		seen[walker.Look.Pose] = true
		ProfileService.record(player, "NewPose", 1)
	end

	local oldRank, newRank = rankName(before), rankName(after)
	if oldRank ~= newRank and after > before then
		ProfileService.notify(player, "RankUp", `Rank up! You're now a {newRank}!`, { Rank = newRank })
	end
	ProfileService.refresh(player)
	return after - before
end

local function startWalk(walker: Walker, lane: any)
	local target = lane.Pose
	if walker.Rival then
		RivalService.place(walker.Rival, lane.Start, false)
		RivalService.strut(walker.Rival, target, Game.Match.StrutSpeed, Game.Match.Walk)
		return
	end
	local player = walker.Player :: Player
	if not player.Parent then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	placeCharacter(character, lane.Start, false)
	if humanoid then
		humanoid.WalkSpeed = Game.Match.StrutSpeed
		humanoid:MoveTo(target.Position)
	end
	Show:FireClient(player, { Type = "YouWalk", Step = "Walk", Target = target, Speed = Game.Match.StrutSpeed })
end

local function strikePose(walker: Walker, lane: any)
	if walker.Rival then
		RivalService.halt(walker.Rival)
	end
	place(walker, lane.Pose, true)
	local model = modelOf(walker)
	if model then
		LookService.strike(model, walker.Look.Pose)
	end
end

local function stepDown(walker: Walker)
	local model = modelOf(walker)
	if model then
		LookService.relax(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid and walker.Player then
			humanoid.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed
		end
	end
	if walker.Spot then
		place(walker, walker.Spot, walker.Rival ~= nil)
	end
	local player = walker.Player
	if player then
		walking[player] = nil
		if player.Parent then
			Show:FireClient(player, { Type = "YouDone" })
		end
	end
end

local function runMatch(match: Bracket.Match)
	local b = bracket :: Bracket.Bracket
	local walkerA = walkers[match.A :: string]
	local walkerB = walkers[match.B :: string]
	local roundName = Bracket.roundName(b, match.Round)
	matchCounter += 1

	local start = now()
	local walkAt = start + Game.Match.Intro
	local poseAt = walkAt + Game.Match.Walk
	local closesAt = poseAt + Game.Match.Pose
	local resultAt = closesAt + Game.Match.VoteGrace
	local doneAt = resultAt + Game.Match.Result
	local match_: CurrentMatch = {
		Id = matchCounter,
		A = walkerA,
		B = walkerB,
		OpensAt = walkAt + Game.Match.VoteOpensAfter,
		ClosesAt = closesAt,
		Ballots = {},
		Dirty = false,
	}
	current = match_

	for _, pair in { { walkerA, Layout.Lanes.A }, { walkerB, Layout.Lanes.B } } do
		local walker = pair[1]
		place(walker, pair[2].Wait, true)
		if walker.Player and walker.Player.Parent then
			walking[walker.Player] = true
			Show:FireClient(walker.Player, { Type = "YouWalk", Step = "Wait" })
		end
	end
	State:SetAttribute("Match", roundName)
	setStep("Intro", walkAt)
	matchMessage = {
		Type = "Match",
		Id = match_.Id,
		Round = roundName,
		A = info(walkerA),
		B = info(walkerB),
		WalkAt = walkAt,
		OpensAt = match_.OpensAt,
		PoseAt = poseAt,
		ClosesAt = closesAt,
	}
	Show:FireAllClients(matchMessage)
	screens(string.upper(roundName), `{walkerA.Name}  vs  {walkerB.Name}`, `Theme: {themeName()}`)
	waitUntil(walkAt)

	setStep("Walk", poseAt)
	startWalk(walkerA, Layout.Lanes.A)
	startWalk(walkerB, Layout.Lanes.B)
	waitUntil(match_.OpensAt)
	screens(nil, nil, "VOTE NOW! Tap your favourite look")
	waitUntil(poseAt)

	setStep("Pose", closesAt)
	strikePose(walkerA, Layout.Lanes.A)
	strikePose(walkerB, Layout.Lanes.B)
	waitUntil(resultAt)

	-- The result: the judges score both looks, then every vote is counted.
	local verdict =
		Judge.verdict(People.Judges, theme, walkerA.Summary, walkerA.Names, walkerB.Summary, walkerB.Names, rngNumber)
	local tally = Voting.tally(
		Game.Voting,
		match_.Ballots,
		verdict.Sides :: any,
		verdict.Scores,
		{ A = walkerA.Rating, B = walkerB.Rating },
		rng:NextInteger(0, 1)
	)
	current = nil
	-- Someone who left mid-walk can't win.
	if walkerA.Gone ~= walkerB.Gone then
		tally.Winner = if walkerA.Gone then "B" else "A"
		tally.DecidedBy = "Walkover"
	end
	local winner = if tally.Winner == "A" then walkerA else walkerB
	local loser = if tally.Winner == "A" then walkerB else walkerA
	local winnerTheme = if tally.Winner == "A" then verdict.ThemeA else verdict.ThemeB

	-- Opponent ratings are read before either changes.
	local ratingA, ratingB = walkerA.Rating, walkerB.Rating
	local changeA = settleWalker(
		walkerA,
		{ Rating = ratingB, Rival = walkerB.Rival } :: any,
		winner == walkerA,
		verdict.ThemeA,
		roundName
	)
	local changeB = settleWalker(
		walkerB,
		{ Rating = ratingA, Rival = walkerA.Rival } :: any,
		winner == walkerB,
		verdict.ThemeB,
		roundName
	)

	for userId, ballot in match_.Ballots do
		local voter = Players:GetPlayerByUserId(userId)
		if voter and ballot.Side == tally.Winner then
			local count = (tasteThisRound[voter] or 0) + 1
			tasteThisRound[voter] = count
			local data = DataService.get(voter)
			if data then
				data.Stats.Taste += 1
			end
			ProfileService.record(voter, "Taste", 1)
			if count <= Game.Rewards.VoteCap then
				ProfileService.reward(voter, Game.Rewards.Taste, multiplier())
			end
		end
	end

	setStep("Result", doneAt)
	Show:FireAllClients({
		Type = "Result",
		Id = match_.Id,
		Winner = tally.Winner,
		WinnerName = winner.Name,
		VotesA = tally.VotesA,
		VotesB = tally.VotesB,
		JudgesA = tally.JudgesA,
		JudgesB = tally.JudgesB,
		Share = tally.Share,
		DecidedBy = tally.DecidedBy,
		ThemeA = math.floor(verdict.ThemeA),
		ThemeB = math.floor(verdict.ThemeB),
		ChangeA = changeA,
		ChangeB = changeB,
		Judge = judgeLine(verdict, tally.Winner, tally.Share, winnerTheme),
		FeedbackA = if Game.Show.JudgeFeedback then Judge.feedback(walkerA.Summary, theme, walkerA.Names) else nil,
		FeedbackB = if Game.Show.JudgeFeedback then Judge.feedback(walkerB.Summary, theme, walkerB.Names) else nil,
	})
	matchMessage = nil
	screens(nil, `{winner.Name} wins!`, `{loser.Name} was amazing too`)
	waitUntil(doneAt)

	stepDown(walkerA)
	stepDown(walkerB)
	Bracket.report(b, match, winner.Id)
end

-- Sends the live vote count (never the split) a few times a second.
local function broadcastVotes()
	local match = current
	if match and match.Dirty then
		match.Dirty = false
		local count = 0
		for _ in match.Ballots do
			count += 1
		end
		Show:FireAllClients({ Type = "VoteCount", Id = match.Id, Votes = count })
	end
end

-- Keeps the audience off the runway while the show is on.
local function guardStage()
	local stage = Layout.Stage
	local halfWidth = stage.Width / 2 + 5
	for _, player in Players:GetPlayers() do
		if not walking[player] then
			local root = rootOf(player.Character)
			if root then
				local position = root.Position
				local onStage = math.abs(position.X) < halfWidth
					and position.Z > stage.StartZ - 14
					and position.Z < stage.TEndZ + 0.5
					and position.Y > stage.Top
				if onStage then
					local walker = walkers[playerId(player)]
					placeCharacter(player.Character, (walker and walker.Spot) or audienceSpot(1), false)
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Crowning

local CROWN = {
	Id = "show_crown",
	Name = "Show Crown",
	Slot = "Head",
	Tags = {},
	Price = 0,
	Main = "Gold",
	Accent = "Ruby",
	Finish = "Metal",
	Shapes = {
		{ "Ring", n = 10, rad = 0.62, s = { 0.22, 0.5, 0.22 }, p = { 0, 0.55, 0 }, c = "Main" },
		{ "Ring", n = 10, rad = 0.62, s = { 0.16, 0.16, 0.16 }, p = { 0, 0.88, 0 }, c = "Accent", m = "Glass" },
		{ "Disc", rad = 0.66, h = 0.2, p = { 0, 0.35, 0 }, c = "Main" },
		{ "Ball", s = { 0.32, 0.32, 0.32 }, p = { 0, 0.5, -0.66 }, c = "Accent", m = "Glass" },
	},
	Effects = { { Kind = "Sparkle", Rate = 8 } },
	Light = { Color = "Main", Range = 8, Brightness = 1.2 },
}

local function crown(model: Model?)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local ok, built = pcall(Pieces.buildDefault, CROWN :: any)
	if ok and built then
		for _, accessory in built do
			accessory:SetAttribute("ShowCrown", true)
			humanoid:AddAccessory(accessory)
			table.insert(crowns, accessory)
		end
	end
end

local function placementOf(placements, id: string): number
	if placements.first == id then
		return 1
	elseif placements.second == id then
		return 2
	elseif table.find(placements.third, id) then
		return 3
	end
	return 4
end

local function runCrowning()
	local b = bracket :: Bracket.Bracket
	local placements = Bracket.placements(b)
	local first = placements.first and walkers[placements.first]
	local second = placements.second and walkers[placements.second]
	local thirds = {}
	for _, id in placements.third do
		local walker = walkers[id]
		if walker and not walker.Gone then
			table.insert(thirds, walker)
		end
	end

	local podium = Layout.Podium
	if first and not first.Gone then
		place(first, podium.First, true)
		crown(modelOf(first))
		local model = modelOf(first)
		if model then
			LookService.strike(model, first.Look.Pose)
		end
	end
	if second and not second.Gone then
		place(second, podium.Second, true)
	end
	for index, walker in thirds do
		place(walker, podium.Third * CFrame.new((index - 1) * 2.2, 0, 0), true)
	end

	setPhase("Crowning", Game.Round.Crowning)
	setStep("", 0)
	local champion = first and first.Name or "Nobody"
	Show:FireAllClients({
		Type = "Crown",
		First = if first then info(first) else nil,
		Second = if second and not second.Gone then info(second) else nil,
		Third = (function()
			local list = {}
			for _, walker in thirds do
				table.insert(list, info(walker))
			end
			return list
		end)(),
		Theme = theme.Id,
	})
	screens("TONIGHT'S STAR", `👑 {champion}`, `Winner of {themeName()}`)

	-- Rewards for everyone who walked.
	local mult = multiplier()
	for _, walker in contestants() do
		local player = walker.Player
		local data = player and DataService.get(player)
		if player and data and not walker.Gone then
			local place_ = placementOf(placements, walker.Id)
			data.Stats.Shows += 1
			if data.Stats.BestFinish == 0 or place_ < data.Stats.BestFinish then
				data.Stats.BestFinish = place_
			end
			ProfileService.record(player, "Round", 1)
			if place_ == 1 then
				data.Stats.Crowns += 1
				data.ThemeWins[theme.Id] = (data.ThemeWins[theme.Id] or 0) + 1
				ProfileService.record(player, "Crown", 1)
				ProfileService.reward(player, Game.Rewards.Crown, mult, `You won the crown for {themeName()}!`)
			elseif place_ == 2 then
				ProfileService.reward(player, Game.Rewards.RunnerUp, mult, "Runner-up! So close!")
			end
			ProfileService.refresh(player)
			Show:FireClient(player, { Type = "Results", Place = place_, Theme = theme.Id })
			AnalyticsService.event(player, "ShowFinished", place_, { theme.Id })
		end
	end

	if first and not first.Gone then
		WorldService.setChampion(first.Name, themeName(), modelOf(first))
	end
	waitUntil(State:GetAttribute("EndsAt"))
end

------------------------------------------------------------------------------
-- The round

local function cleanUp()
	current = nil
	bracket = nil
	matchMessage = nil
	for _, accessory in crowns do
		accessory:Destroy()
	end
	crowns = {}
	local ring = 0
	for _, walker in contestants() do
		if walker.Rival then
			RivalService.despawn(walker.Rival)
		elseif walker.Player then
			local player = walker.Player :: Player
			LookService.setLocked(player, false)
			walking[player] = nil
			local model = player.Character
			if model then
				LookService.relax(model)
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed
				end
			end
			if player.Parent then
				Show:FireClient(player, { Type = "YouDone" })
			end
		end
	end
	for _, player in Players:GetPlayers() do
		ring += 1
		placeCharacter(player.Character, Layout.LobbyRing[(ring - 1) % #Layout.LobbyRing + 1], false)
	end
	RivalService.clear()
	walkers = {}
	walking = {}
	votesThisRound = {}
	tasteThisRound = {}
	State:SetAttribute("Ready", "")
end

-- Everyone in the show on the runway at once, posing, so every look is
-- seen before anyone is knocked out (Game.Show.Lineup).
local function runLineup()
	local seconds = Game.Show.LineupSeconds
	local lineup = {}
	for index, walker in contestants() do
		if not walker.Gone and Layout.Lineup[index] then
			table.insert(lineup, { Walker = walker, Spot = Layout.Lineup[index] })
		end
	end
	local names = {}
	for _, entry in lineup do
		local walker = entry.Walker
		if walker.Player then
			walking[walker.Player] = true
		end
		place(walker, entry.Spot, true)
		local model = modelOf(walker)
		if model then
			LookService.strike(model, walker.Look.Pose)
		end
		table.insert(names, { Name = walker.Name, Rival = walker.Rival ~= nil })
	end
	local endsAt = now() + seconds
	setStep("Lineup", endsAt)
	Show:FireAllClients({ Type = "Lineup", Entrants = names, EndsAt = endsAt })
	screens("TONIGHT'S LINEUP", themeName(), `{#lineup} looks walk tonight`)
	waitUntil(endsAt)
	for _, entry in lineup do
		local walker = entry.Walker
		local model = modelOf(walker)
		if model then
			LookService.relax(model)
		end
		if walker.Spot then
			place(walker, walker.Spot, walker.Rival ~= nil)
		end
		if walker.Player then
			walking[walker.Player] = nil
		end
	end
end

local function runShow()
	lockLooks()
	local entrants = {}
	for _, walker in contestants() do
		if not walker.Gone then
			table.insert(entrants, { Id = walker.Id, Rating = walker.Rating })
		end
	end
	if #entrants < 2 then
		return false
	end
	bracket = Bracket.new(Bracket.seeded(entrants, Game.Show.Seeding, rngNumber))
	local remaining = Bracket.walkedCount(bracket :: Bracket.Bracket)
	local lineupSeconds = if Game.Show.Lineup then Game.Show.LineupSeconds else 0
	setPhase("Showtime", remaining * MATCH_SECONDS + lineupSeconds)
	seatEveryone()
	sendBracket()
	screens("SHOWTIME", themeName(), "Vote for your favourite looks!")
	if Game.Show.Lineup then
		runLineup()
	end

	local guarding = true
	task.spawn(function()
		while guarding do
			guardStage()
			broadcastVotes()
			task.wait(STAGE_GUARD_SECONDS / 2)
		end
	end)

	while true do
		local match = Bracket.nextMatch(bracket :: Bracket.Bracket)
		if not match then
			break
		end
		runMatch(match)
		sendBracket()
		remaining = math.max(remaining - 1, 1)
		State:SetAttribute("EndsAt", now() + remaining * MATCH_SECONDS)
	end
	guarding = false
	return true
end

local function hasPlayers(): boolean
	for _, player in Players:GetPlayers() do
		if DataService.get(player) then
			return true
		end
	end
	return false
end

local function runRound()
	while not hasPlayers() do
		State:SetAttribute("Phase", "Waiting")
		task.wait(1)
	end
	runLobby()
	runDressing()
	if #playerWalkers() == 0 then
		-- Everyone is watching or left: no show this time.
		cleanUp()
		return
	end
	if runShow() then
		runCrowning()
	end
	cleanUp()
end

------------------------------------------------------------------------------

local function onPlayerRemoving(player: Player)
	local walker = walkers[playerId(player)]
	if walker then
		walker.Gone = true
		if bracket then
			Bracket.withdraw(bracket, walker.Id)
		end
	end
	themeVotes[player] = nil
	walking[player] = nil
	votesThisRound[player] = nil
	tasteThisRound[player] = nil
	posesSeen[player] = nil
	friends[player.UserId] = nil
	for _, list in friends do
		list[player.UserId] = nil
	end
	for _, limiter in { voteLimiter, themeLimiter, readyLimiter } do
		limiter:forget(player)
	end
	if State:GetAttribute("Phase") == "ThemeVote" then
		updateOptionVotes()
	end
	if State:GetAttribute("Phase") == "Dressing" then
		updateReady()
	end
end

-- Catches a player who joins mid-show up on the bracket and the matchup
-- on stage, so they can vote straight away.
local function syncLateJoiner(player: Player)
	if State:GetAttribute("Phase") ~= "Showtime" or not bracket then
		return
	end
	local names = {}
	for id, walker in walkers do
		names[id] = walker.Name
	end
	Show:FireClient(player, { Type = "Bracket", Rounds = Bracket.summary(bracket), Names = names })
	if matchMessage then
		Show:FireClient(player, matchMessage)
	end
	AnalyticsService.event(player, "JoinedMidShow", 1)
end

-- Puts a respawned character back where the show needs them.
local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.5)
	if player.Character ~= character then
		return
	end
	local phase = State:GetAttribute("Phase")
	local walker = walkers[playerId(player)]
	if phase == "Dressing" and walker then
		placeCharacter(character, Layout.Booths[walker.Booth], false)
	elseif phase == "Showtime" then
		placeCharacter(character, (walker and walker.Spot) or audienceSpot(#Players:GetPlayers()), false)
	end
end

function RoundService.init()
	State:SetAttribute("Phase", "Waiting")
	State:SetAttribute("EndsAt", 0)
	State:SetAttribute("Round", 0)
	State:SetAttribute("Theme", "")
	State:SetAttribute("Spotlight", ThemePicker.spotlight(Themes.List, os.time()))
	Remotes.ThemeVote.OnServerEvent:Connect(onThemeVote)
	Remotes.Ready.OnServerEvent:Connect(onReady)
	Remotes.CastVote.OnServerEvent:Connect(onCastVote)
	PlayerHooks.eachPlayer(checkFriends)
	Players.PlayerAdded:Connect(function(player)
		-- Give the client a moment to hook up its remotes.
		task.delay(3, function()
			if player.Parent then
				syncLateJoiner(player)
			end
		end)
	end)
	PlayerHooks.eachCharacter(onCharacterAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function RoundService.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(runRound)
			if not ok then
				warn(`Round failed: {err}`)
				pcall(cleanUp)
				task.wait(3)
			end
		end
	end)
end

return RoundService
