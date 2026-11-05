--!strict
-- The colours and finishes players dress with. Looks store a colour as its
-- place in Colors (a number), or, for owners of the Color Studio pass, as a
-- "#RRGGBB" string; Palette.resolve turns either into a Color3.

export type Swatch = { Name: string, Color: Color3 }
export type Finish = { Name: string, Material: Enum.Material, Reflectance: number }

local Palette = {}

Palette.Colors = {
	{ Name = "Snow", Color = Color3.fromRGB(250, 250, 252) },
	{ Name = "Cloud", Color = Color3.fromRGB(220, 222, 232) },
	{ Name = "Silver", Color = Color3.fromRGB(168, 176, 192) },
	{ Name = "Slate", Color = Color3.fromRGB(96, 104, 124) },
	{ Name = "Ink", Color = Color3.fromRGB(38, 36, 52) },
	{ Name = "Black", Color = Color3.fromRGB(16, 16, 20) },
	{ Name = "Ruby", Color = Color3.fromRGB(206, 24, 58) },
	{ Name = "Cherry", Color = Color3.fromRGB(240, 70, 96) },
	{ Name = "Coral", Color = Color3.fromRGB(255, 122, 104) },
	{ Name = "Peach", Color = Color3.fromRGB(255, 186, 152) },
	{ Name = "Blush", Color = Color3.fromRGB(255, 198, 216) },
	{ Name = "Bubblegum", Color = Color3.fromRGB(255, 124, 192) },
	{ Name = "Hot Pink", Color = Color3.fromRGB(255, 36, 150) },
	{ Name = "Magenta", Color = Color3.fromRGB(210, 40, 200) },
	{ Name = "Lavender", Color = Color3.fromRGB(204, 176, 255) },
	{ Name = "Violet", Color = Color3.fromRGB(140, 80, 232) },
	{ Name = "Plum", Color = Color3.fromRGB(96, 40, 132) },
	{ Name = "Royal Blue", Color = Color3.fromRGB(48, 80, 222) },
	{ Name = "Sky", Color = Color3.fromRGB(108, 190, 255) },
	{ Name = "Baby Blue", Color = Color3.fromRGB(184, 222, 255) },
	{ Name = "Teal", Color = Color3.fromRGB(18, 168, 170) },
	{ Name = "Aqua", Color = Color3.fromRGB(92, 232, 222) },
	{ Name = "Mint", Color = Color3.fromRGB(164, 242, 204) },
	{ Name = "Emerald", Color = Color3.fromRGB(22, 160, 92) },
	{ Name = "Lime", Color = Color3.fromRGB(164, 232, 60) },
	{ Name = "Olive", Color = Color3.fromRGB(112, 122, 52) },
	{ Name = "Lemon", Color = Color3.fromRGB(255, 238, 92) },
	{ Name = "Sunflower", Color = Color3.fromRGB(255, 200, 40) },
	{ Name = "Tangerine", Color = Color3.fromRGB(255, 140, 40) },
	{ Name = "Rust", Color = Color3.fromRGB(178, 82, 42) },
	{ Name = "Cocoa", Color = Color3.fromRGB(108, 68, 44) },
	{ Name = "Caramel", Color = Color3.fromRGB(192, 132, 80) },
	{ Name = "Sand", Color = Color3.fromRGB(232, 206, 162) },
	{ Name = "Cream", Color = Color3.fromRGB(255, 246, 222) },
	{ Name = "Gold", Color = Color3.fromRGB(242, 192, 62) },
	{ Name = "Rose Gold", Color = Color3.fromRGB(232, 162, 142) },
} :: { Swatch }

-- Skin tones, from lightest to deepest, plus a few fantasy ones.
Palette.Skins = {
	{ Name = "Porcelain", Color = Color3.fromRGB(255, 226, 206) },
	{ Name = "Ivory", Color = Color3.fromRGB(246, 210, 182) },
	{ Name = "Honey", Color = Color3.fromRGB(232, 184, 140) },
	{ Name = "Golden", Color = Color3.fromRGB(214, 160, 112) },
	{ Name = "Tan", Color = Color3.fromRGB(190, 132, 90) },
	{ Name = "Bronze", Color = Color3.fromRGB(160, 104, 68) },
	{ Name = "Umber", Color = Color3.fromRGB(122, 78, 52) },
	{ Name = "Ebony", Color = Color3.fromRGB(86, 54, 38) },
	{ Name = "Classic", Color = Color3.fromRGB(245, 205, 48) },
	{ Name = "Mint Sprite", Color = Color3.fromRGB(170, 236, 200) },
	{ Name = "Moon Blue", Color = Color3.fromRGB(176, 200, 255) },
	{ Name = "Fairy Lilac", Color = Color3.fromRGB(214, 186, 255) },
} :: { Swatch }

Palette.Finishes = {
	{ Name = "Matte", Material = Enum.Material.Fabric, Reflectance = 0 },
	{ Name = "Satin", Material = Enum.Material.SmoothPlastic, Reflectance = 0 },
	{ Name = "Shiny", Material = Enum.Material.SmoothPlastic, Reflectance = 0.18 },
	{ Name = "Sequin", Material = Enum.Material.Foil, Reflectance = 0.1 },
	{ Name = "Glow", Material = Enum.Material.Neon, Reflectance = 0 },
	{ Name = "Metal", Material = Enum.Material.Metal, Reflectance = 0.1 },
	{ Name = "Glass", Material = Enum.Material.Glass, Reflectance = 0.1 },
	{ Name = "Frost", Material = Enum.Material.Ice, Reflectance = 0 },
} :: { Finish }

local colorIndex: { [string]: number } = {}
for index, swatch in Palette.Colors do
	colorIndex[swatch.Name] = index
end

local finishIndex: { [string]: Finish } = {}
for _, finish in Palette.Finishes do
	finishIndex[finish.Name] = finish
end

-- The place of a named colour in Colors, or nil.
function Palette.indexOf(name: string): number?
	return colorIndex[name]
end

function Palette.finish(name: string?): Finish
	return (name and finishIndex[name]) or Palette.Finishes[2]
end

function Palette.isFinish(name: any): boolean
	return type(name) == "string" and finishIndex[name] ~= nil
end

-- True for "#RRGGBB".
function Palette.isHex(value: any): boolean
	return type(value) == "string" and string.match(value, "^#%x%x%x%x%x%x$") ~= nil
end

function Palette.fromHex(value: string): Color3
	local r = tonumber(string.sub(value, 2, 3), 16) or 0
	local g = tonumber(string.sub(value, 4, 5), 16) or 0
	local b = tonumber(string.sub(value, 6, 7), 16) or 0
	return Color3.fromRGB(r, g, b)
end

function Palette.toHex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

-- A stored colour (palette number or hex) or a colour name as a Color3.
function Palette.resolve(value: any, fallback: Color3?): Color3
	if type(value) == "number" then
		local swatch = Palette.Colors[value]
		if swatch then
			return swatch.Color
		end
	elseif type(value) == "string" then
		if Palette.isHex(value) then
			return Palette.fromHex(value)
		end
		local index = colorIndex[value]
		if index then
			return Palette.Colors[index].Color
		end
	end
	return fallback or Palette.Colors[1].Color
end

function Palette.skin(index: any): Color3
	local swatch = if type(index) == "number" then Palette.Skins[index] else nil
	return (swatch or Palette.Skins[3]).Color
end

-- How far apart two colours look, from 0 (same) to about 1.7.
function Palette.distance(a: Color3, b: Color3): number
	local dr, dg, db = a.R - b.R, a.G - b.G, a.B - b.B
	return math.sqrt(dr * dr * 2 + dg * dg * 4 + db * db * 3) / 1.6
end

return Palette
