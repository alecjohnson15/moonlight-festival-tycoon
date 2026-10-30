--!strict
-- What the showcase build (showcase.project.json, run by Server.luau and
-- Client.luau) puts on the map for store screenshots, in
-- ReplicatedStorage.Shared.ShowcasePlan so both sides read it. The player's own plot is maxed out on the path of each
-- building that looks best, and three neighbours took the other paths, so
-- the festival looks busy and every path shows on one plot or another. Each
-- plot is a whole route through the tree (Config/Balance): one path per
-- building, every tier of it bought. Plain data and pure functions, so the
-- tests can check every plot is a real route that unlocks everything it
-- shows.

export type Festival = { Name: { number }, Palette: string, Decor: { [string]: string } }

export type Plot = {
	-- Where the plot is in the row, from 1 (Layout.plotX).
	Index: number,
	-- The name on a neighbour's gate. The player's gate shows their own.
	Owner: string?,
	-- The path taken on each building, by building id.
	Paths: { [string]: string },
	-- A word from each of the theme's name lists, by number, the palette,
	-- and the decoration in each of Layout.Decor's spots, by spot number.
	Festival: Festival,
}

type Upgrade = { Id: string, Building: string?, Path: string? }

local Plan = {}

-- Beside the courtyard, so the Moonlight Wheel and the plot fit in one shot.
Plan.Player = {
	Index = 4,
	Paths = {
		-- Ghoul Grub Bar: glowing grub and a skull on the roof.
		starter_stall = "vendor",
		-- Bumper Crop: the giant pumpkin.
		grower = "output",
		-- Enchanted Pies: rune circle, floating spellbook and crystal.
		kitchen = "value",
		-- Scream Maze: scares that pop up.
		attraction_1 = "ticket",
		-- Moon Beacon: beams of moonlight seen from the spawn.
		attraction_2 = "draw",
		-- Terror Train: the skull tunnel, a loop and braziers.
		attraction_3 = "ticket",
	},
	Festival = {
		-- The Midnight Pumpkin Carnival.
		Name = { 9, 2, 3 },
		Palette = "harvest",
		Decor = {
			["1"] = "skeleton_band",
			["2"] = "parade_float",
			["3"] = "ghost_statue",
			["4"] = "moon_fountain",
			["5"] = "lantern_arch",
			["6"] = "witch_cauldron",
		},
	},
} :: Plot

Plan.Neighbours = {
	-- Across the courtyard, in every shot of the Wheel.
	{
		Index = 3,
		Owner = "Luna",
		Paths = {
			starter_stall = "output",
			grower = "vendor",
			kitchen = "vendor",
			attraction_1 = "capacity",
			attraction_2 = "ticket",
			attraction_3 = "draw",
		},
		Festival = {
			-- The Howling Bat Bazaar.
			Name = { 1, 4, 6 },
			Palette = "classic",
			Decor = {
				["1"] = "lantern_arch",
				["2"] = "bat_topiary",
				["3"] = "graveyard_corner",
				["4"] = "pumpkin_pile",
				["5"] = "moon_fountain",
				["6"] = "skeleton_band",
			},
		},
	},
	{
		Index = 5,
		Owner = "Grimsby",
		Paths = {
			starter_stall = "markup",
			grower = "output",
			kitchen = "value",
			attraction_1 = "capacity",
			attraction_2 = "draw",
			attraction_3 = "seats",
		},
		Festival = {
			-- The Glowing Cauldron Market.
			Name = { 4, 5, 10 },
			Palette = "toxic",
			Decor = {
				["1"] = "witch_cauldron",
				["2"] = "ghost_statue",
				["3"] = "pumpkin_pile",
				["4"] = "graveyard_corner",
				["5"] = "bat_topiary",
				["6"] = "lantern_arch",
			},
		},
	},
	{
		Index = 2,
		Owner = "Pip",
		Paths = {
			starter_stall = "output",
			grower = "vendor",
			kitchen = "value",
			attraction_1 = "ticket",
			attraction_2 = "ticket",
			attraction_3 = "draw",
		},
		Festival = {
			-- The Grinning Skeleton Jamboree.
			Name = { 8, 9, 4 },
			Palette = "blood_moon",
			Decor = {
				["1"] = "parade_float",
				["2"] = "witch_cauldron",
				["3"] = "hay_corner",
				["4"] = "ghost_statue",
				["5"] = "skeleton_band",
				["6"] = "moon_fountain",
			},
		},
	},
} :: { Plot }

-- Every plot's trophies: perfect Ghost Catcher rounds, many Moonlight
-- Parades and arena knockouts, which also unlock every colour and
-- decoration (Config/Festival).
Plan.Activity = { Best = 12, Rounds = 140 }
Plan.Parade = { Joined = 24, Filled = 19, Lanterns = 310 }
Plan.KOs = 180

-- The player's coins, and what they've earned in all.
Plan.Coins = 1_250_000_000
Plan.LifetimeCoins = 1_480_000_000

-- What the player wears: the earned look, so the shots show what anyone can
-- get by playing. Every paid item can still be tried on in the wardrobe, as
-- in any Studio test.
Plan.Outfit = {
	Head = "pumpkin_head",
	Back = "witch_cape",
	Hand = "moon_saber",
	Pet = "pumpkling",
	Aura = "phantom_aura",
	Trail = "ember_trail",
}

-- The Moonlight Parade comes round soon after the server starts, and often.
Plan.ParadeFirstSeconds = 20
Plan.ParadeIntervalSeconds = 120

-- Every upgrade on a route: all of each building's own upgrades, and every
-- tier of the path it took.
function Plan.owned(paths: { [string]: string }, upgrades: { Upgrade }): { [string]: boolean }
	local owned = {}
	for _, upgrade in upgrades do
		if not upgrade.Path or paths[upgrade.Building :: string] == upgrade.Path then
			owned[upgrade.Id] = true
		end
	end
	return owned
end

-- Fills a save in place with a plot's route and festival, and everyone's
-- trophies and coins.
function Plan.fill(save: any, plot: Plot, upgrades: { Upgrade })
	save.Coins = Plan.Coins
	save.LifetimeCoins = Plan.LifetimeCoins
	save.Owned = Plan.owned(plot.Paths, upgrades)
	save.Equipped = table.clone(Plan.Outfit)
	save.Activity = table.clone(Plan.Activity)
	save.Parade = table.clone(Plan.Parade)
	save.Arena.KOs = Plan.KOs
	save.Festival = {
		Name = table.clone(plot.Festival.Name),
		Palette = plot.Festival.Palette,
		Decor = table.clone(plot.Festival.Decor),
	}
end

return Plan
