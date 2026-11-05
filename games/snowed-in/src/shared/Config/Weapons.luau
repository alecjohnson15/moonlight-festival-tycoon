--!strict
-- Heat beats frost: every weapon throws fire, light or warmth at the
-- monsters, and a monster that runs out of health puffs into snow. Nothing
-- here can hurt a player.
--
-- Kind:
--   Melee   hits every monster within Range in front of the player.
--   Shot    hits the first monster along the aim, up to Range away.
--   Blast   flies to the first monster (or the aim point) and hits every
--           monster within Radius of where it lands.
--   Cone    sprays a short cone: every monster within Range and Angle.
--
-- Damage is per hit and Cooldown the seconds between hits. AimAssist widens
-- shots so taps on a phone still land.

export type Weapon = {
	Id: string,
	Name: string,
	Blurb: string,
	Kind: "Melee" | "Shot" | "Blast" | "Cone",
	Damage: number,
	Cooldown: number,
	Range: number,
	Radius: number?,
	Angle: number?,
	AimAssist: number?,
	Color: string,
	Sound: string,
	-- Its order on the hotbar and in the workbench.
	Order: number,
}

local Weapons = {}

Weapons.List = {
	{
		Id = "Torch",
		Name = "Torch",
		Blurb = "Close-up whacks of fire. Everyone starts with one.",
		Kind = "Melee",
		Damage = 12,
		Cooldown = 0.6,
		Range = 10,
		Angle = 110,
		Color = "#FF9A3C",
		Sound = "Swing",
		Order = 1,
	},
	{
		Id = "EmberSling",
		Name = "Ember Sling",
		Blurb = "Flings glowing embers at one monster far away.",
		Kind = "Shot",
		Damage = 14,
		Cooldown = 0.55,
		Range = 70,
		AimAssist = 3,
		Color = "#FF7A2E",
		Sound = "Sling",
		Order = 2,
	},
	{
		Id = "FlarePistol",
		Name = "Flare Pistol",
		Blurb = "A bright flare that bursts over a crowd.",
		Kind = "Blast",
		Damage = 24,
		Cooldown = 1.3,
		Range = 80,
		Radius = 9,
		AimAssist = 3,
		Color = "#FF4FA0",
		Sound = "Flare",
		Order = 3,
	},
	{
		Id = "BlazeThrower",
		Name = "Blaze Blower",
		Blurb = "A bellows full of hot air that melts everything in front of you.",
		Kind = "Cone",
		Damage = 7,
		Cooldown = 0.15,
		Range = 18,
		Angle = 50,
		Color = "#FFC23C",
		Sound = "Blaze",
		Order = 4,
	},
	{
		Id = "SunstoneCannon",
		Name = "Sunstone Cannon",
		Blurb = "Lobs a little sun. Huge burst, slow to reload.",
		Kind = "Blast",
		Damage = 70,
		Cooldown = 2.2,
		Range = 90,
		Radius = 12,
		AimAssist = 4,
		Color = "#FFE45C",
		Sound = "Cannon",
		Order = 5,
	},
} :: { Weapon }

Weapons.ById = {} :: { [string]: Weapon }
for _, weapon in Weapons.List do
	Weapons.ById[weapon.Id] = weapon
end

Weapons.Starter = "Torch"

return Weapons
