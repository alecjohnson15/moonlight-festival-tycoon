-- The colours of Pinehollow: fresh snow, blue ice, dark pines, warm wood
-- and firelight. Everything in shared/World paints from here, so the whole
-- town can be re-coloured in one place.

local Kit = require(script.Parent.Parent.Kit)

return Kit.palette({
	Snow = "#F4F8FC",
	SnowShade = "#DCE6F0",
	Packed = "#C9D6E3",
	Ice = "#A9D8F5",
	IceDeep = "#6FB4E0",
	IceGlow = "#8FE3FF",
	Pine = "#1F4D3A",
	PineLight = "#2E6B4F",
	Bark = "#5B3A29",
	Log = "#8B5A3C",
	Plank = "#B07A4A",
	PlankDark = "#7A5235",
	Stone = "#8C949E",
	StoneDark = "#5E6670",
	Coal = "#2B2D33",
	Metal = "#6C7A89",
	MetalDark = "#3C4651",
	Rust = "#8E5B3A",
	RoofRed = "#9E3B33",
	RoofTeal = "#2F6F73",
	RoofBlue = "#3E5C8A",
	Warm = "#FFB347",
	Ember = "#FF7A2E",
	Flame = "#FFD166",
	Berry = "#7E6CF0",
	Leaf = "#3F7D5A",
	Rope = "#C8A06A",
	Cloth = "#C94C4C",
	Gold = "#F2C94C",
	White = "#FFFFFF",
	Black = "#1B1D22",
	Frost = "#BFEFFF",
	FrostEye = "#5CF2FF",
	Aurora = { "#5CF2B0", "#7C5CFF", "#4FC3FF" },
	Paint = { "#9E3B33", "#2F6F73", "#3E5C8A", "#7A5235", "#5B6B3A", "#8A4F7D" },
})
