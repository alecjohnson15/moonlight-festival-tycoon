--!strict
-- Counts a matchup's votes. Designed against vote brigading from day one:
--   * the server decides who may vote: never the two walkers, only during
--     the vote window, and only after the outfits have been on show for a
--     moment (server/Services/ShowService);
--   * one ballot per player per matchup; changing your mind replaces it;
--   * a vote from a Roblox friend of either walker, or from a brand new
--     account, counts for less (Config/Game Voting);
--   * the judges always vote too, and count most when few people watch;
--   * nobody sees which way the votes are going until they close, so there
--     is no bandwagon to join.
-- Pure logic, tested in tests/Voting.spec.

export type Side = "A" | "B"

export type Ballot = { Side: Side, Weight: number }

export type Tally = {
	A: number,
	B: number,
	-- Unweighted counts, for showing "12 votes".
	VotesA: number,
	VotesB: number,
	JudgesA: number,
	JudgesB: number,
	Winner: Side,
	-- The winner's share of the weighted total, from 0.5 to 1.
	Share: number,
	-- How the winner was decided: "Votes", "Judges", "Score" or "Coin".
	DecidedBy: string,
}

export type Settings = {
	FriendWeight: number,
	NewAccountWeight: number,
	NewAccountDays: number,
	JudgeBase: number,
	JudgeFade: number,
	JudgeFloor: number,
}

local Voting = {}

-- How much one voter's ballot counts.
function Voting.weight(settings: Settings, isFriendOfWalker: boolean, accountAgeDays: number): number
	local weight = 1
	if isFriendOfWalker then
		weight *= settings.FriendWeight
	end
	if accountAgeDays < settings.NewAccountDays then
		weight *= settings.NewAccountWeight
	end
	return weight
end

-- How much each judge's vote counts, given how many players voted.
function Voting.judgeWeight(settings: Settings, audienceVotes: number): number
	return math.max(settings.JudgeFloor, settings.JudgeBase - settings.JudgeFade * audienceVotes)
end

-- Whether a ballot may be cast: the window is open, the voter isn't
-- walking, and the side is real.
function Voting.canVote(
	voterId: string,
	walkerA: string,
	walkerB: string,
	side: any,
	now: number,
	opensAt: number,
	closesAt: number
): (boolean, string?)
	if voterId == walkerA or voterId == walkerB then
		return false, "Walking"
	end
	if side ~= "A" and side ~= "B" then
		return false, "BadSide"
	end
	if now < opensAt then
		return false, "TooEarly"
	end
	if now > closesAt then
		return false, "Closed"
	end
	return true, nil
end

-- Counts the ballots and the judges' votes. Ties go to the judges' combined
-- score, then the higher Style Score, then a coin flip (coin is 0 or 1).
function Voting.tally(
	settings: Settings,
	ballots: { [any]: Ballot },
	judgeSides: { Side },
	judgeScores: { A: number, B: number },
	styleScores: { A: number, B: number },
	coin: number
): Tally
	local result = {
		A = 0,
		B = 0,
		VotesA = 0,
		VotesB = 0,
		JudgesA = 0,
		JudgesB = 0,
		Winner = "A" :: Side,
		Share = 0.5,
		DecidedBy = "Votes",
	}
	local audience = 0
	for _, ballot in ballots do
		audience += 1
		if ballot.Side == "A" then
			result.A += ballot.Weight
			result.VotesA += 1
		else
			result.B += ballot.Weight
			result.VotesB += 1
		end
	end

	local judgeWeight = Voting.judgeWeight(settings, audience)
	for _, side in judgeSides do
		if side == "A" then
			result.A += judgeWeight
			result.JudgesA += 1
		else
			result.B += judgeWeight
			result.JudgesB += 1
		end
	end

	-- Round away floating point noise so equal totals really tie.
	local a = math.round(result.A * 1000) / 1000
	local b = math.round(result.B * 1000) / 1000
	if a ~= b then
		result.Winner = if a > b then "A" else "B"
		result.DecidedBy = if audience > 0 then "Votes" else "Judges"
	elseif judgeScores.A ~= judgeScores.B then
		result.Winner = if judgeScores.A > judgeScores.B then "A" else "B"
		result.DecidedBy = "Judges"
	elseif styleScores.A ~= styleScores.B then
		result.Winner = if styleScores.A > styleScores.B then "A" else "B"
		result.DecidedBy = "Score"
	else
		result.Winner = if coin == 0 then "A" else "B"
		result.DecidedBy = "Coin"
	end

	local total = result.A + result.B
	if total > 0 then
		local winning = if result.Winner == "A" then result.A else result.B
		result.Share = winning / total
	end
	return result :: Tally
end

return Voting
