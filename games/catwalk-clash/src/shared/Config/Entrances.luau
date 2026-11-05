--!strict
-- Runway entrances: the effect that plays as a walker steps out and strides
-- down their lane. Every viewer's client plays it (client/Effects), so it
-- costs the server nothing. Free ones come with the game; others cost
-- Sparkles, come with a pass (Pass) or with a Style Pass tier (Season).

export type Entrance = {
	Id: string,
	Name: string,
	Price: number,
	Pass: string?,
	Season: number?,
	Colors: { string },
	Style: string,
}

local Entrances: { Entrance } = {
	{ Id = "spotlight", Name = "Spotlight", Price = 0, Colors = { "Snow" }, Style = "Spotlight" },
	{ Id = "sparkle_trail", Name = "Sparkle Trail", Price = 0, Colors = { "Gold", "Snow" }, Style = "Trail" },
	{
		Id = "confetti_pop",
		Name = "Confetti Pop",
		Price = 0,
		Colors = { "Hot Pink", "Lemon", "Aqua", "Lime" },
		Style = "Confetti",
	},
	{ Id = "petal_shower", Name = "Petal Shower", Price = 300, Colors = { "Blush", "Snow" }, Style = "Shower" },
	{ Id = "snow_flurry", Name = "Snow Flurry", Price = 300, Colors = { "Snow", "Baby Blue" }, Style = "Shower" },
	{ Id = "bubble_parade", Name = "Bubble Parade", Price = 300, Colors = { "Aqua", "Baby Blue" }, Style = "Bubbles" },
	{ Id = "paparazzi", Name = "Paparazzi", Price = 400, Colors = { "Snow" }, Style = "Flashes" },
	{
		Id = "glitter_storm",
		Name = "Glitter Storm",
		Price = 500,
		Colors = { "Gold", "Hot Pink", "Violet" },
		Style = "Storm",
	},
	{ Id = "golden_carpet", Name = "Golden Carpet", Price = 0, Pass = "vip", Colors = { "Gold" }, Style = "Carpet" },
	{
		Id = "fireworks",
		Name = "Fireworks",
		Price = 0,
		Pass = "showstopper_entrances",
		Colors = { "Ruby", "Lemon", "Sky", "Lime" },
		Style = "Fireworks",
	},
	{
		Id = "starfall",
		Name = "Starfall",
		Price = 0,
		Pass = "showstopper_entrances",
		Colors = { "Snow", "Lemon" },
		Style = "Starfall",
	},
	{
		Id = "rainbow_road",
		Name = "Rainbow Road",
		Price = 0,
		Pass = "showstopper_entrances",
		Colors = { "Ruby", "Tangerine", "Lemon", "Lime", "Sky", "Violet" },
		Style = "Carpet",
	},
	{
		Id = "thunder_strut",
		Name = "Thunder Strut",
		Price = 0,
		Pass = "showstopper_entrances",
		Colors = { "Baby Blue", "Snow" },
		Style = "Thunder",
	},
	{
		Id = "neon_pulse",
		Name = "Neon Pulse",
		Price = 0,
		Pass = "showstopper_entrances",
		Colors = { "Hot Pink", "Aqua" },
		Style = "Pulse",
	},
	{
		Id = "crown_rain",
		Name = "Crown Rain",
		Price = 0,
		Season = 25,
		Colors = { "Gold", "Hot Pink" },
		Style = "Storm",
	},
}

local byId: { [string]: Entrance } = {}
for _, entrance in Entrances do
	byId[entrance.Id] = entrance
end

return {
	List = Entrances,
	Default = "spotlight",
	get = function(id: string): Entrance?
		return byId[id]
	end,
}
