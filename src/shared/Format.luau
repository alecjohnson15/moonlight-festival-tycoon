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

return Format
