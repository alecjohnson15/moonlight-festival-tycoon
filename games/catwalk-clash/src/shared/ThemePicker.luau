--!strict
-- Chooses the themes the lobby votes between. Seasonal themes only turn up
-- inside their windows (Config/Themes), the week's spotlight theme is always
-- offered (it pays double), and recent themes rest for a while so rounds
-- don't repeat. Pure logic, tested in tests/ThemePicker.spec.

export type Theme = {
	Id: string,
	Window: { From: { number }, To: { number } }?,
}

local ThemePicker = {}

-- How many recent themes are kept out of the vote.
ThemePicker.REST = 8

function ThemePicker.day(time: number): number
	return time // 86400
end

-- Weeks start on Monday (1 January 1970 was a Thursday).
function ThemePicker.week(time: number): number
	return (ThemePicker.day(time) + 3) // 7
end

-- Whether month/day falls inside a window, which may wrap past New Year.
function ThemePicker.inWindow(window: { From: { number }, To: { number } }, month: number, day: number): boolean
	local value = month * 100 + day
	local from = window.From[1] * 100 + window.From[2]
	local to = window.To[1] * 100 + window.To[2]
	if from <= to then
		return value >= from and value <= to
	end
	return value >= from or value <= to
end

-- The themes that may be played at this time, and which of those are
-- seasonal.
function ThemePicker.available(themes: { Theme }, time: number): ({ Theme }, { Theme })
	local date = os.date("!*t", time) :: { [string]: number }
	local list, seasonal = {}, {}
	for _, theme in themes do
		if theme.Window == nil then
			table.insert(list, theme)
		elseif ThemePicker.inWindow(theme.Window, date.month, date.day) then
			table.insert(list, theme)
			table.insert(seasonal, theme)
		end
	end
	return list, seasonal
end

-- This week's spotlight theme: a seasonal one while any are in season,
-- otherwise one of the year-round themes, in turn.
function ThemePicker.spotlight(themes: { Theme }, time: number): string
	local list, seasonal = ThemePicker.available(themes, time)
	-- Out of season, list holds only the year-round themes.
	local pool = if #seasonal > 0 then seasonal else list
	local week = ThemePicker.week(time)
	return pool[week % #pool + 1].Id
end

-- count theme ids to vote between. recent holds the latest themes played,
-- newest last; rng(n) returns a whole number from 1 to n.
function ThemePicker.options(
	themes: { Theme },
	time: number,
	recent: { string },
	rng: (number) -> number,
	count: number
): { string }
	local list, seasonal = ThemePicker.available(themes, time)
	local spotlight = ThemePicker.spotlight(themes, time)
	local resting: { [string]: boolean } = {}
	for index = math.max(1, #recent - ThemePicker.REST + 1), #recent do
		resting[recent[index]] = true
	end

	local chosen: { string } = {}
	local taken: { [string]: boolean } = {}
	local function take(id: string)
		if not taken[id] and #chosen < count then
			taken[id] = true
			table.insert(chosen, id)
		end
	end

	-- The spotlight rests only for the two rounds after it was played.
	local justPlayed = recent[#recent] == spotlight or recent[#recent - 1] == spotlight
	if not justPlayed then
		take(spotlight)
	end
	-- In season, one seasonal theme is always on offer.
	if #seasonal > 0 then
		local fresh = {}
		for _, theme in seasonal do
			if not resting[theme.Id] and not taken[theme.Id] then
				table.insert(fresh, theme.Id)
			end
		end
		if #fresh > 0 then
			take(fresh[rng(#fresh)])
		end
	end

	local pool = {}
	for _, theme in list do
		if not resting[theme.Id] and not taken[theme.Id] then
			table.insert(pool, theme.Id)
		end
	end
	while #chosen < count and #pool > 0 do
		take(table.remove(pool, rng(#pool)) :: string)
	end
	-- Very few themes left: let resting ones back in.
	for _, theme in list do
		take(theme.Id)
	end
	return chosen
end

-- The winning option: the most votes, with ties broken by rng(n).
function ThemePicker.winner(options: { string }, votes: { [any]: number }, rng: (number) -> number): string
	local counts = table.create(#options, 0)
	for _, choice in votes do
		if counts[choice] then
			counts[choice] += 1
		end
	end
	local best, tied = -1, {}
	for index, total in counts do
		if total > best then
			best, tied = total, { index }
		elseif total == best then
			table.insert(tied, index)
		end
	end
	return options[tied[rng(#tied)]]
end

return ThemePicker
