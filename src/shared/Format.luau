--!strict
-- Number formatting shared by the HUD and the labels on plots.

local Format = {}

-- Whole numbers as they are and anything else to one decimal place, so rates
-- read "4" and "2.5" rather than "4.0" and "2.4999".
function Format.rate(value: number): string
	local rounded = math.floor(value * 10 + 0.5) / 10
	if rounded == math.floor(rounded) then
		return string.format("%d", rounded)
	end
	return string.format("%.1f", rounded)
end

-- A whole number with commas between thousands, such as "12,345".
function Format.whole(value: number): string
	local digits = string.format("%d", math.floor(math.abs(value) + 0.5))
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	grouped = string.gsub(grouped, "^,", "")
	return if value < 0 then `-{grouped}` else grouped
end

local SUFFIXES = { "K", "M", "B", "T" }

-- A price or big amount kept short for labels: whole numbers with commas up
-- to 9,999, then three figures at most with K, M, B or T, such as "97K",
-- "1.4M" or "130M".
function Format.short(value: number): string
	local size = math.abs(value)
	if size < 10_000 then
		return Format.whole(value)
	end
	local index, shown = 0, size
	-- Rounds first, so 999,950 reads "1M" rather than "1000K".
	while shown >= 1000 and index < #SUFFIXES do
		size /= 1000
		index += 1
		local scale = if size >= 10 then 1 else 10
		shown = math.floor(size * scale + 0.5) / scale
	end
	local text = string.gsub(string.format("%.1f", shown), "%.0$", "")
	return `{if value < 0 then "-" else ""}{text}{SUFFIXES[index]}`
end

return Format
