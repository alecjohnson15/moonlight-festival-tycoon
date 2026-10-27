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

return Format
