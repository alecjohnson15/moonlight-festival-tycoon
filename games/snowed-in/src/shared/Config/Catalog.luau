--!strict
-- Robux items, all game passes, each bought once with its contents stated
-- up front. No random rewards, no loot boxes, no currency packs. The two
-- role passes are early access: they unlock the Ranger or the Medic, which
-- anyone can also earn with 600 snowflakes from playing (about three to five
-- runs). Those roles do help a team a little (the Ranger hits about a third
-- harder, the Medic thaws friends fast); tools/RunModel puts the effect on
-- a team of four's hardest night at about 5 to 7%, and a team of free roles
-- wins every modelled run without them (tests/Pacing.spec). Everything else
-- is something to wear or to put on your cabin.
--
-- PassId 0 means the pass isn't made on Roblox yet: the shop shows "Coming
-- soon" and the server never prompts for it. docs/launch.md lists each pass
-- with its name, description, price and icon prompt; once they are made,
-- paste the ids here.
--
-- Grants lists what owning the pass gives: Roles, Cosmetics, Decor, or
-- Premium (the Expedition Pass's premium track).

export type Pass = {
	Id: string,
	Name: string,
	PassId: number,
	SuggestedRobux: number,
	Includes: string,
	Grants: {
		Roles: { string }?,
		Cosmetics: { string }?,
		Decor: { string }?,
		Premium: boolean?,
	},
}

return {
	{
		Id = "Ranger",
		Name = "Ranger Role",
		PassId = 0,
		SuggestedRobux = 149,
		Includes = "Unlocks the Ranger role straight away (it can also be earned with 600 snowflakes).",
		Grants = { Roles = { "Ranger" } },
	},
	{
		Id = "Medic",
		Name = "Medic Role",
		PassId = 0,
		SuggestedRobux = 149,
		Includes = "Unlocks the Medic role straight away (it can also be earned with 600 snowflakes).",
		Grants = { Roles = { "Medic" } },
	},
	{
		Id = "ExpeditionPremium",
		Name = "Expedition Pass: Premium",
		PassId = 0,
		SuggestedRobux = 299,
		Includes = "Opens the premium row of the Expedition Pass: 13 extra rewards, shown on the pass before you buy. You still earn them by playing.",
		Grants = { Premium = true },
	},
	{
		Id = "AuroraCape",
		Name = "Aurora Cape",
		PassId = 0,
		SuggestedRobux = 129,
		Includes = "A cape that shimmers green and purple like the northern lights.",
		Grants = { Cosmetics = { "AuroraCape" } },
	},
	{
		Id = "IcicleCrown",
		Name = "Icicle Crown",
		PassId = 0,
		SuggestedRobux = 99,
		Includes = "A crown of glowing icicles.",
		Grants = { Cosmetics = { "IcicleCrown" } },
	},
	{
		Id = "AuroraTrail",
		Name = "Aurora Trail",
		PassId = 0,
		SuggestedRobux = 79,
		Includes = "A trail of northern lights that follows your feet.",
		Grants = { Cosmetics = { "AuroraTrail" } },
	},
	{
		Id = "Penguin",
		Name = "Penguin Buddy",
		PassId = 0,
		SuggestedRobux = 149,
		Includes = "A pet penguin in a tiny scarf that waddles after you.",
		Grants = { Cosmetics = { "Penguin" } },
	},
	{
		Id = "ArcticFox",
		Name = "Arctic Fox Buddy",
		PassId = 0,
		SuggestedRobux = 149,
		Includes = "A pet arctic fox with a big fluffy tail.",
		Grants = { Cosmetics = { "ArcticFox" } },
	},
	{
		Id = "CozyCabin",
		Name = "Cozy Cabin Pack",
		PassId = 0,
		SuggestedRobux = 199,
		Includes = "Four cabin decorations: Aurora Lights, Golden Wreath, Giant Snow Globe and Rainbow Glow.",
		Grants = { Decor = { "AuroraLights", "GoldWreath", "SnowGlobe", "RainbowGlow" } },
	},
} :: { Pass }
