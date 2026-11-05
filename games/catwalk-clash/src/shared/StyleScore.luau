--!strict
-- The Style Score that follows a player from show to show: an Elo rating,
-- so beating a higher-rated walker earns more than beating a newcomer, plus
-- a small bonus for walking at all. The first ProtectedWalks walks can't
-- lose points. Ranks come from Config/Ranks.

local StyleScore = {}

export type Settings = {
	Start: number,
	Floor: number,
	NewK: number,
	K: number,
	NewUntilWalks: number,
	RivalScale: number,
	WalkBonus: number,
	ProtectedWalks: number?,
}

-- The chance the Elo model gives A of beating B.
function StyleScore.expected(ratingA: number, ratingB: number): number
	return 1 / (1 + 10 ^ ((ratingB - ratingA) / 400))
end

-- A player's new score after a matchup. won is true or false; walks is how
-- many matchups they had walked before this one; againstRival scales it down.
function StyleScore.update(
	settings: Settings,
	rating: number,
	opponent: number,
	won: boolean,
	walks: number,
	againstRival: boolean
): number
	local k = if walks < settings.NewUntilWalks then settings.NewK else settings.K
	if againstRival then
		k *= settings.RivalScale
	end
	local change = k * ((if won then 1 else 0) - StyleScore.expected(rating, opponent))
	-- A player's first few walks can only raise their score, so a new
	-- player's first losses never drop their rank.
	if walks < (settings.ProtectedWalks or 0) then
		change = math.max(change, 0)
	end
	local result = rating + change + settings.WalkBonus
	return math.max(settings.Floor, math.round(result))
end

-- The rank for a score: the highest whose MinScore it reaches.
function StyleScore.rank(ranks: { { Name: string, MinScore: number, Color: string } }, score: number)
	local best = ranks[1]
	for _, rank in ranks do
		if score >= rank.MinScore then
			best = rank
		end
	end
	return best
end

return StyleScore
