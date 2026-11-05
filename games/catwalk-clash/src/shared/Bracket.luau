--!strict
-- The knockout bracket for one show. Entrants are seeded (Bracket.seeded:
-- at random by default, or by Style Score), the bracket is padded to a
-- power of two, and the top seeds get the byes, so a show with n walkers
-- always takes n - 1 matchups. Matches are played one at
-- a time in order; a walker who leaves loses their next matchup by
-- walkover. Pure logic, so it is tested in tests/Bracket.spec.

export type Entrant = { Id: string, Seed: number }

export type Match = {
	Round: number,
	Index: number,
	A: string?,
	B: string?,
	Winner: string?,
	-- True when one side was a bye or a walkover, so nobody walked.
	Skipped: boolean,
}

export type Bracket = {
	Size: number,
	RoundCount: number,
	Rounds: { { Match } },
	Withdrawn: { [string]: boolean },
	Count: number,
}

local Bracket = {}

-- Seed positions for a bracket of size n (a power of two), top seed first,
-- arranged so seeds 1 and 2 can only meet in the final.
function Bracket.seedOrder(size: number): { number }
	local order = { 1 }
	local length = 1
	while length < size do
		length *= 2
		local nextOrder = {}
		for _, seed in order do
			table.insert(nextOrder, seed)
			table.insert(nextOrder, length + 1 - seed)
		end
		order = nextOrder
	end
	return order
end

-- Seeds for Bracket.new. "Random" (the default) shuffles everyone, so byes
-- and first opponents are luck of the draw; "Rating" seeds by Style Score,
-- which gives the byes to the highest scores and pits newcomers against the
-- top seeds first (tests/Bracket.spec simulates both). rng() returns a
-- number from 0 to 1.
function Bracket.seeded(list: { { Id: string, Rating: number } }, mode: string, rng: () -> number): { Entrant }
	local entrants = {}
	for _, item in list do
		local seed = if mode == "Rating" then item.Rating + rng() else rng()
		table.insert(entrants, { Id = item.Id, Seed = seed })
	end
	return entrants
end

local function nextPowerOfTwo(n: number): number
	local size = 1
	while size < n do
		size *= 2
	end
	return size
end

-- Builds a bracket. Higher Seed values are seeded first.
function Bracket.new(entrants: { Entrant }): Bracket
	assert(#entrants >= 2, "a bracket needs at least two entrants")
	local sorted = table.clone(entrants)
	table.sort(sorted, function(a, b)
		if a.Seed == b.Seed then
			return a.Id < b.Id
		end
		return a.Seed > b.Seed
	end)

	local size = nextPowerOfTwo(#sorted)
	local roundCount = math.round(math.log(size, 2))
	local order = Bracket.seedOrder(size)
	local bracket: Bracket = {
		Size = size,
		RoundCount = roundCount,
		Rounds = {},
		Withdrawn = {},
		Count = #sorted,
	}

	for round = 1, roundCount do
		local matches = {}
		for index = 1, size // 2 ^ round do
			table.insert(matches, { Round = round, Index = index, Skipped = false } :: Match)
		end
		bracket.Rounds[round] = matches
	end

	for index, match in bracket.Rounds[1] do
		local seedA = order[index * 2 - 1]
		local seedB = order[index * 2]
		match.A = if sorted[seedA] then sorted[seedA].Id else nil
		match.B = if sorted[seedB] then sorted[seedB].Id else nil
	end

	-- Byes: a lone entrant goes straight through.
	for _, match in bracket.Rounds[1] do
		if match.A == nil or match.B == nil then
			Bracket.report(bracket, match, (match.A or match.B) :: string, true)
		end
	end
	return bracket
end

-- Records the winner of a match and moves them into the next round.
function Bracket.report(bracket: Bracket, match: Match, winner: string, skipped: boolean?)
	assert(winner == match.A or winner == match.B, "the winner must be in the match")
	match.Winner = winner
	match.Skipped = skipped == true
	local nextRound = bracket.Rounds[match.Round + 1]
	if nextRound then
		local target = nextRound[(match.Index + 1) // 2]
		if match.Index % 2 == 1 then
			target.A = winner
		else
			target.B = winner
		end
	end
end

-- Marks an entrant as gone. Their next match is lost by walkover.
function Bracket.withdraw(bracket: Bracket, id: string)
	bracket.Withdrawn[id] = true
end

-- The next match to walk, or nil when the bracket is finished. Walkovers
-- are settled on the way.
function Bracket.nextMatch(bracket: Bracket): Match?
	for _, matches in bracket.Rounds do
		for _, match in matches do
			if match.Winner == nil and match.A ~= nil and match.B ~= nil then
				local aGone = bracket.Withdrawn[match.A :: string] == true
				local bGone = bracket.Withdrawn[match.B :: string] == true
				if aGone or bGone then
					local winner = if aGone and not bGone then match.B else match.A
					Bracket.report(bracket, match, winner :: string, true)
					return Bracket.nextMatch(bracket)
				end
				return match
			end
		end
	end
	return nil
end

function Bracket.final(bracket: Bracket): Match
	return bracket.Rounds[bracket.RoundCount][1]
end

-- The winner of the whole bracket, once it is finished.
function Bracket.champion(bracket: Bracket): string?
	return Bracket.final(bracket).Winner
end

-- How many matches will actually be walked, given no one leaves.
function Bracket.walkedCount(bracket: Bracket): number
	return bracket.Count - 1
end

local function loserOf(match: Match): string?
	if match.Winner == nil then
		return nil
	end
	return if match.Winner == match.A then match.B else match.A
end

-- First, second and the semifinal losers (third), once finished.
function Bracket.placements(bracket: Bracket): { first: string?, second: string?, third: { string } }
	local final = Bracket.final(bracket)
	local third = {}
	local semis = bracket.Rounds[bracket.RoundCount - 1]
	if semis then
		for _, match in semis do
			local loser = loserOf(match)
			if loser and not match.Skipped then
				table.insert(third, loser)
			end
		end
	end
	return { first = final.Winner, second = loserOf(final), third = third }
end

-- "Final", "Semifinal", "Quarterfinal" or "Round n".
function Bracket.roundName(bracket: Bracket, round: number): string
	local fromEnd = bracket.RoundCount - round
	if fromEnd == 0 then
		return "Final"
	elseif fromEnd == 1 then
		return "Semifinal"
	elseif fromEnd == 2 then
		return "Quarterfinal"
	end
	return `Round {round}`
end

-- The furthest round an entrant has been placed in.
function Bracket.furthestRound(bracket: Bracket, id: string): number
	local furthest = 0
	for round, matches in bracket.Rounds do
		for _, match in matches do
			if match.A == id or match.B == id then
				furthest = math.max(furthest, round)
			end
		end
	end
	return furthest
end

-- A compact copy for the clients' bracket card: each round's pairs.
function Bracket.summary(bracket: Bracket): { { { any } } }
	local rounds = {}
	for round, matches in bracket.Rounds do
		local list = {}
		for _, match in matches do
			table.insert(list, { match.A or "", match.B or "", match.Winner or "" })
		end
		rounds[round] = list
	end
	return rounds
end

return Bracket
