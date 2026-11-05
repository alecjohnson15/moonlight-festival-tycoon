--!strict
-- Everything the team makes from the stockpile.
--
-- Upgrades are made once per run at the workbench and help the whole team.
-- Weapons are made at the workbench too, one for the player who makes it.
-- Meals are cooked at the pot and go into the shared pantry; players take a
-- portion into their pocket and eat it when they are cold.
--
-- Needs is the hearth level the recipe waits for, so the tech opens up as
-- the team pushes the blizzard back. Role, when set, is the only role that
-- can make it.

export type Cost = { [string]: number }

export type Upgrade = {
	Id: string,
	Name: string,
	Blurb: string,
	Cost: Cost,
	Needs: number,
}

export type Weapon = {
	Id: string,
	Cost: Cost,
	Needs: number,
}

export type Meal = {
	Id: string,
	Name: string,
	Blurb: string,
	Cost: Cost,
	Portions: number,
	Warmth: number,
	-- Seconds of slower cold after eating, and how much slower (0.3 = 30%).
	ShieldSeconds: number?,
	Shield: number?,
	-- Seconds of quicker walking after eating, and the bonus speed.
	SpeedSeconds: number?,
	Speed: number?,
	Role: string?,
	Icon: string,
}

local Recipes = {}

Recipes.Upgrades = {
	{
		Id = "SharpAxes",
		Name = "Sharp Axes",
		Blurb = "+1 wood from every chop, for everyone.",
		Cost = { Wood = 15, Stone = 10 },
		Needs = 1,
	},
	{
		Id = "SturdyPicks",
		Name = "Sturdy Picks",
		Blurb = "+1 stone and coal from every swing, for everyone.",
		Cost = { Wood = 20, Stone = 15 },
		Needs = 1,
	},
	{
		Id = "SnowShovels",
		Name = "Snow Shovels",
		Blurb = "+1 scrap from every pile of buried junk.",
		Cost = { Wood = 20, Scrap = 8 },
		Needs = 2,
	},
	{
		Id = "BigPacks",
		Name = "Big Backpacks",
		Blurb = "Everyone carries 10 more things.",
		Cost = { Wood = 25, Scrap = 12 },
		Needs = 2,
	},
	{
		Id = "WoolCoats",
		Name = "Wool Coats",
		Blurb = "Everyone gets cold 25% slower.",
		Cost = { Wood = 20, Scrap = 15, Berries = 6 },
		Needs = 2,
	},
	{
		Id = "SignalFlares",
		Name = "Signal Flares",
		Blurb = "Radio parts and landmarks glow through the blizzard.",
		Cost = { Scrap = 15, Coal = 6 },
		Needs = 3,
	},
	{
		Id = "IronBraces",
		Name = "Iron Braces",
		Blurb = "Every wall and turret has 50% more health.",
		Cost = { Stone = 30, Scrap = 25, Coal = 8 },
		Needs = 3,
	},
} :: { Upgrade }

-- The weapon stats live in Config/Weapons; this is what each costs to make.
-- The Torch is free and everyone starts with it.
Recipes.Weapons = {
	{ Id = "EmberSling", Cost = { Wood = 12, Scrap = 8 }, Needs = 1 },
	{ Id = "FlarePistol", Cost = { Scrap = 20, Coal = 8 }, Needs = 2 },
	{ Id = "BlazeThrower", Cost = { Scrap = 30, Coal = 16, Stone = 10 }, Needs = 3 },
	{ Id = "SunstoneCannon", Cost = { Scrap = 40, Coal = 25, Stone = 20 }, Needs = 4 },
} :: { Weapon }

Recipes.Meals = {
	{
		Id = "RoastFish",
		Name = "Roast Fish",
		Blurb = "+25 warmth.",
		Cost = { Fish = 1, Wood = 1 },
		Portions = 1,
		Warmth = 25,
		Icon = "🐟",
	},
	{
		Id = "BerryTea",
		Name = "Frostberry Tea",
		Blurb = "+20 warmth and quicker feet for 30 seconds.",
		Cost = { Berries = 3 },
		Portions = 2,
		Warmth = 20,
		SpeedSeconds = 30,
		Speed = 4,
		Icon = "🍵",
	},
	{
		Id = "HeartyStew",
		Name = "Hearty Stew",
		Blurb = "+50 warmth, and the cold bites 40% less for a minute.",
		Cost = { Fish = 2, Berries = 3, Wood = 2 },
		Portions = 3,
		Warmth = 50,
		ShieldSeconds = 60,
		Shield = 0.4,
		Role = "Cook",
		Icon = "🍲",
	},
} :: { Meal }

local function index<T>(list: { T }): { [string]: T }
	local byId = {}
	for _, entry in list do
		byId[(entry :: any).Id] = entry
	end
	return byId
end

Recipes.UpgradeById = index(Recipes.Upgrades)
Recipes.WeaponById = index(Recipes.Weapons)
Recipes.MealById = index(Recipes.Meals)

return Recipes
