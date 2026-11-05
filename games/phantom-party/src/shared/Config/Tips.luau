-- First-time tips: one short line at a time, shown the first time a player
-- meets each thing, then never again (the save remembers, Migrations
-- version 2). They never stop play: a tip is a banner that fades.
--
-- {Draw}, {Use}, {Throw}, {Blackout}, {Revive} and {Leads} become the right
-- words for the player's keyboard, touch screen or controller (Keys).
--
-- When says what shows a tip:
--   Start         the round starts playing, for this role
--   BladeReady    the Phantom's blade can be drawn
--   Drawn         the player drew their blade or blaster
--   Tagged        the Phantom's first tag landed
--   SomeoneDazed  a guest lies dazed (for the Medic)
--   Lead          the player's first lead arrived
--   BellHint      the Truth Bell named a room
--   Out           the player is out of the round
-- Role "*" means any role.

local Tips = {}

Tips.WHEN = { "Start", "BladeReady", "Drawn", "Tagged", "SomeoneDazed", "Lead", "BellHint", "Out" }

Tips.List = {
	{
		Id = "phantom_start",
		Role = "Phantom",
		When = "Start",
		Text = "You're the Phantom! Act like a guest: your blade is ready in a few seconds.",
	},
	{
		Id = "phantom_draw",
		Role = "Phantom",
		When = "BladeReady",
		Text = "Your blade is ready. {Draw} to draw it, when nobody's looking.",
	},
	{
		Id = "phantom_tag",
		Role = "Phantom",
		When = "Drawn",
		Text = "Get close to a guest and {Use} to tag. Everyone can see a drawn blade!",
	},
	{
		Id = "phantom_throw",
		Role = "Phantom",
		When = "Tagged",
		Text = "{Throw} to throw your blade at a guest far away. It flies back to you.",
	},
	{
		Id = "guardian_start",
		Role = "Guardian",
		When = "Start",
		Text = "You're the Guardian. {Draw} to draw your blaster once you know who the Phantom is.",
	},
	{
		Id = "guardian_zap",
		Role = "Guardian",
		When = "Drawn",
		Text = "{Use} to zap. Zap an innocent guest and you're both knocked out, so be sure!",
	},
	{
		Id = "medic_start",
		Role = "Medic",
		When = "Start",
		Text = "You're the Medic. Stay close to the others: you can bring a tagged guest back.",
	},
	{
		Id = "medic_revive",
		Role = "Medic",
		When = "SomeoneDazed",
		Text = "A guest is down! Hold {Revive} beside them to revive them before they fade.",
	},
	{
		Id = "saboteur_start",
		Role = "Saboteur",
		When = "Start",
		Text = "You help the Phantom. {Blackout} to cut the lights, from 20 seconds in.",
	},
	{
		Id = "guest_start",
		Role = "Guest",
		When = "Start",
		Text = "Walk into glowing pages to fill the Truth Bell. Stay near other guests!",
	},
	{
		Id = "any_lead",
		Role = "*",
		When = "Lead",
		Text = "You noticed something! {Leads} to see your leads. A lead can be wrong.",
	},
	{
		Id = "any_bell",
		Role = "*",
		When = "BellHint",
		Text = "The Truth Bell named a room. Tell the Guardian where the Phantom was!",
	},
	{
		Id = "any_out",
		Role = "*",
		When = "Out",
		Text = "You're out this round. Watch the party, or catch wisps in the plaza until the next.",
	},
}

-- The words for each move, by how the player plays.
Tips.Keys = {
	Keyboard = {
		Draw = "Press 1",
		Use = "click",
		Throw = "Press E",
		Blackout = "Press F",
		Revive = "E",
		Leads = "Press N",
	},
	Touch = {
		Draw = "Tap the Blade button",
		Use = "tap Tag",
		Throw = "Tap Throw",
		Blackout = "Tap Lights out",
		Revive = "the Revive button",
		Leads = "Tap Leads",
	},
	Gamepad = {
		Draw = "Press Y",
		Use = "press R2",
		Throw = "Press B",
		Blackout = "Press L1",
		Revive = "X",
		Leads = "Press up on the D-pad",
	},
}

-- How long a tip stays up.
Tips.Seconds = 7

return Tips
