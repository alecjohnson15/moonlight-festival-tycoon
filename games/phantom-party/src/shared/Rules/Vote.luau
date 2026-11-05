--!strict
-- Map voting in the lobby: which maps are offered, and which one wins.

local Vote = {}

-- Up to count maps to offer, avoiding the last one played when there are
-- enough others. random() gives a number from 0 up to 1.
function Vote.choices(maps: { string }, count: number, last: string?, random: () -> number): { string }
	local pool = {}
	for _, map in maps do
		if map ~= last or #maps <= count then
			table.insert(pool, map)
		end
	end
	local chosen = {}
	while #chosen < count and #pool > 0 do
		local index = math.min(#pool, math.floor(random() * #pool) + 1)
		table.insert(chosen, table.remove(pool, index))
	end
	return chosen
end

-- The map with the most votes; a tie (or no votes) is settled at random
-- among the leaders.
function Vote.winner(choices: { string }, votes: { [any]: string }, random: () -> number): string
	local tally = {}
	for _, map in choices do
		tally[map] = 0
	end
	for _, map in votes do
		if tally[map] then
			tally[map] += 1
		end
	end
	local best = -1
	local leaders = {}
	for _, map in choices do
		if tally[map] > best then
			best = tally[map]
			leaders = { map }
		elseif tally[map] == best then
			table.insert(leaders, map)
		end
	end
	return leaders[math.min(#leaders, math.floor(random() * #leaders) + 1)]
end

-- Each offered map's vote count.
function Vote.counts(choices: { string }, votes: { [any]: string }): { [string]: number }
	local tally = {}
	for _, map in choices do
		tally[map] = 0
	end
	for _, map in votes do
		if tally[map] then
			tally[map] += 1
		end
	end
	return tally
end

return Vote
