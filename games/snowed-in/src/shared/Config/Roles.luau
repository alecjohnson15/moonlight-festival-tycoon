--!strict
-- The roles: each player picks one at the start of a run (or when they
-- join one in progress) and keeps it until the run ends. Each changes how
-- they play, not just how strong they are, so a team with different roles
-- does better than a team of the same one.
--
-- Scout, Builder and Cook are free for everyone. Ranger and Medic are
-- unlocked with snowflakes earned by playing (Price), or straight away with
-- their game pass (Config/Catalog, same id). A pass only skips the saving
-- up; the role is the same either way.
--
-- Every role has one Ability on a cooldown (Q, or the button on a phone).

export type Role = {
	Id: string,
	Name: string,
	Icon: string,
	Color: string,
	Blurb: string,
	Perks: { string },
	Price: number,
	-- Perks the game reads.
	SpeedBonus: number?,
	PackBonus: number?,
	ColdResist: number?,
	GatherSpeed: number?,
	BuildDiscount: number?,
	RepairBonus: number?,
	MealBonus: number?,
	ExtraPortions: number?,
	DamageBonus: number?,
	ThawSeconds: number?,
	ThawWarmth: number?,
	-- Teammates near a Medic get cold this much slower.
	AuraResist: number?,
	Ability: {
		Id: string,
		Name: string,
		Blurb: string,
		Cooldown: number,
		Radius: number?,
		Seconds: number?,
		Amount: number?,
	},
}

local Roles = {}

Roles.List = {
	{
		Id = "Scout",
		Name = "Scout",
		Icon = "🧭",
		Color = "#5EC8FF",
		Blurb = "Fast feet, a big pack and a nose for treasure.",
		Perks = { "Walks 20% faster", "Carries 10 more", "Gathers 25% quicker", "Gets cold 20% slower" },
		Price = 0,
		SpeedBonus = 0.2,
		PackBonus = 10,
		GatherSpeed = 0.25,
		ColdResist = 0.2,
		Ability = {
			Id = "Flare",
			Name = "Scout Flare",
			Blurb = "Shows every monster, radio part and supply crate near you for 12 seconds.",
			Cooldown = 40,
			Radius = 120,
			Seconds = 12,
		},
	},
	{
		Id = "Builder",
		Name = "Builder",
		Icon = "🔨",
		Color = "#FFB84D",
		Blurb = "Builds cheaper, fixes faster, and raises Blaze Towers.",
		Perks = { "Builds 25% cheaper", "Repairs twice as much", "Only one who can build Blaze Towers" },
		Price = 0,
		BuildDiscount = 0.25,
		RepairBonus = 1,
		Ability = {
			Id = "QuickFix",
			Name = "Quick Fix",
			Blurb = "Patches every structure near you back up by 40% for free.",
			Cooldown = 45,
			Radius = 30,
			Amount = 0.4,
		},
	},
	{
		Id = "Cook",
		Name = "Cook",
		Icon = "🍲",
		Color = "#FF7A7A",
		Blurb = "Keeps the team warm and fed.",
		Perks = {
			"+1 portion from every meal they cook",
			"Only one who can cook Hearty Stew",
			"Meals warm them 50% more",
		},
		Price = 0,
		MealBonus = 0.5,
		ExtraPortions = 1,
		Ability = {
			Id = "Cocoa",
			Name = "Hot Cocoa",
			Blurb = "Pours a mug for everyone near you: +30 warmth.",
			Cooldown = 50,
			Radius = 25,
			Amount = 30,
		},
	},
	{
		Id = "Ranger",
		Name = "Ranger",
		Icon = "🏹",
		Color = "#7CE07C",
		Blurb = "The night watch. Hits harder and sees monster health.",
		Perks = { "Weapons hit 25% harder", "Sees every monster's health", "Gets cold 10% slower" },
		Price = 600,
		DamageBonus = 0.25,
		ColdResist = 0.1,
		Ability = {
			Id = "Volley",
			Name = "Ember Volley",
			Blurb = "Your next 6 hits do double damage.",
			Cooldown = 40,
			Amount = 6,
		},
	},
	{
		Id = "Medic",
		Name = "Medic",
		Icon = "🩹",
		Color = "#FF9FD6",
		Blurb = "Nobody stays frozen for long with a Medic around.",
		Perks = { "Thaws friends in 1 second", "Thawed friends wake up warmer", "Friends near you get cold 30% slower" },
		Price = 600,
		ThawSeconds = 1,
		ThawWarmth = 70,
		AuraResist = 0.3,
		Ability = {
			Id = "HeatPack",
			Name = "Heat Pack",
			Blurb = "Thaws every frozen friend near you at once.",
			Cooldown = 60,
			Radius = 22,
		},
	},
} :: { Role }

Roles.ById = {} :: { [string]: Role }
for _, role in Roles.List do
	Roles.ById[role.Id] = role
end

Roles.Default = "Scout"

-- Medic aura reach in studs.
Roles.AuraRadius = 18

return Roles
