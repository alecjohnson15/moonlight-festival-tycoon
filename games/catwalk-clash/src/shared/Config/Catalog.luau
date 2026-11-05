--!strict
-- Robux items. Every one is a direct purchase whose contents are stated up
-- front: no random rewards, rerolls, timers or vote boosts. Nothing here
-- changes how votes or judges count; paid wardrobe pieces are tagged like
-- free ones, so a free outfit can always match a theme just as well.
--
-- Kind:
--   GamePass          bought once; Roblox tracks ownership.
--   DeveloperProduct  bought any number of times; granted through a receipt,
--                     recorded in the save so a retried receipt never grants
--                     twice.
--
-- A PassId or ProductId of 0 means it isn't set up on Roblox yet, and the
-- shop shows it as Coming soon. SuggestedRobux is a starting point for the
-- price set on the Roblox website.

export type Item = {
	Id: string,
	Kind: string,
	Name: string,
	PassId: number?,
	ProductId: number?,
	SuggestedRobux: number,
	Includes: string,
	Sparkles: number?,
}

return {
	{
		Id = "style_pass_s1",
		Kind = "GamePass",
		Name = "Style Pass: Season 1",
		PassId = 0,
		SuggestedRobux = 399,
		Includes = "The Style Pass premium track for Season 1: 30 extra rewards, including the Legend Crown, Runway Wings, Spotlight Gown, Golden Hour aura and Sparkles. Every reward is listed on the pass board before you buy.",
	},
	{
		Id = "color_studio",
		Kind = "GamePass",
		Name = "Color Studio",
		PassId = 0,
		SuggestedRobux = 149,
		Includes = "Paint any piece any colour with the full colour picker, not just the 36 palette colours.",
	},
	{
		Id = "big_closet",
		Kind = "GamePass",
		Name = "Big Closet",
		PassId = 0,
		SuggestedRobux = 99,
		Includes = "Save 24 outfits instead of 4.",
	},
	{
		Id = "vip",
		Kind = "GamePass",
		Name = "VIP",
		PassId = 0,
		SuggestedRobux = 249,
		Includes = "A gold VIP name tag, the rooftop VIP Lounge, and the Golden Carpet runway entrance.",
	},
	{
		Id = "royal_gala",
		Kind = "GamePass",
		Name = "Royal Gala Collection",
		PassId = 0,
		SuggestedRobux = 199,
		Includes = "6 royal pieces: Royal Ringlets, Frost Crown, Gala Bodice, Velvet Train, Gala Gown and Crystal Slippers.",
	},
	{
		Id = "neon_night",
		Kind = "GamePass",
		Name = "Neon Night Collection",
		PassId = 0,
		SuggestedRobux = 199,
		Includes = "8 glowing pieces: Light-Up Cap, Pulse Collar, Glowline Jacket, Laser Wings, LED Skirt, Light-Up Kicks, Rave Glowsticks and Neon Haze aura.",
	},
	{
		Id = "fairy_garden",
		Kind = "GamePass",
		Name = "Fairy Garden Collection",
		PassId = 0,
		SuggestedRobux = 199,
		Includes = "5 fairy pieces: Blossom Halo, Petal Top, Blossom Wings, Petal Skirt and Firefly Jar.",
	},
	{
		Id = "star_couture",
		Kind = "GamePass",
		Name = "Star Couture Collection",
		PassId = 0,
		SuggestedRobux = 199,
		Includes = "5 space pieces: Orbit Crown, Nebula Armor, Comet Cape, Galaxy Skirt and Moon Scepter.",
	},
	{
		Id = "supermodel_poses",
		Kind = "GamePass",
		Name = "Supermodel Poses",
		PassId = 0,
		SuggestedRobux = 99,
		Includes = "6 extra runway poses: Superstar, Heart Hands, Hair Flip, Victory, Shy Wave and Power Lean.",
	},
	{
		Id = "showstopper_entrances",
		Kind = "GamePass",
		Name = "Showstopper Entrances",
		PassId = 0,
		SuggestedRobux = 149,
		Includes = "5 extra runway entrances: Fireworks, Starfall, Rainbow Road, Thunder Strut and Neon Pulse.",
	},
	{
		Id = "sparkles_small",
		Kind = "DeveloperProduct",
		Name = "Pouch of Sparkles",
		ProductId = 0,
		SuggestedRobux = 49,
		Sparkles = 500,
		Includes = "500 Sparkles to spend on wardrobe pieces, poses and entrances.",
	},
	{
		Id = "sparkles_medium",
		Kind = "DeveloperProduct",
		Name = "Jar of Sparkles",
		ProductId = 0,
		SuggestedRobux = 129,
		Sparkles = 1500,
		Includes = "1,500 Sparkles to spend on wardrobe pieces, poses and entrances.",
	},
	{
		Id = "sparkles_large",
		Kind = "DeveloperProduct",
		Name = "Chest of Sparkles",
		ProductId = 0,
		SuggestedRobux = 299,
		Sparkles = 4000,
		Includes = "4,000 Sparkles to spend on wardrobe pieces, poses and entrances.",
	},
} :: { Item }
