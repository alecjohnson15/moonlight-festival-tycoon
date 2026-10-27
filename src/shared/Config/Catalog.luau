-- Robux items. The brief allows only directly purchased cosmetics whose
-- contents are stated up front: no random rewards, rerolls or anything that
-- speeds up progression. Every price needs a balance and value review before
-- an id is filled in.
--
-- Kind:
--   GamePass          bought once; Roblox tracks ownership.
--   DeveloperProduct  granted through a receipt and recorded in the save.
--
-- An item with id 0 is not set up yet and cannot be bought.

return {
	{
		Id = "stall_skin_lanterns",
		Kind = "GamePass",
		PassId = 0,
		Includes = "A lantern-trimmed look for the starter stall.",
	},
	{
		Id = "companion_moth",
		Kind = "GamePass",
		PassId = 0,
		Includes = "A glowing moth companion that follows you around your festival.",
	},
	{
		Id = "lighting_pack_aurora",
		Kind = "DeveloperProduct",
		ProductId = 0,
		Includes = "Aurora-coloured lights for every built attraction.",
	},
}
