--!strict
-- Which custom analytics events the game may send to Roblox's Creator
-- Dashboard, and what each may carry. AnalyticsService sends nothing that
-- isn't listed here: every field must be one of its listed values (anything
-- else is sent as "Other"), numbers are whole and capped, and each player
-- can send only so many events a minute. No names, user ids, chat or free
-- text ever leave this way (tests/Telemetry.spec checks the source).
--
-- Rollback: Enabled = false stops every custom event (the first-time
-- funnel steps stay, as before this pass). Turning one event off: set its
-- Off = true.

export type Event = { Fields: { string }, Off: boolean? }

local Telemetry = {}

Telemetry.Enabled = true

-- Most events one player can send in a minute; extra ones are dropped.
Telemetry.PerMinute = 30

-- The largest number an event's value may be.
Telemetry.MaxValue = 100_000

-- What a field may say. A list is every allowed value; "Count" is a whole
-- number from 0 to 99, sent as text.
Telemetry.Values = {
	Role = { "Phantom", "Saboteur", "Guardian", "Medic", "Guest" },
	Result = { "Won", "Lost" },
	Action = { "Draw", "Throw", "Shot", "Page", "Revive", "Blackout", "Tear" },
	How = { "Swing", "Throw", "Zap", "Misfire" },
	Shot = { "Missed", "Caught", "Shadow", "Innocent" },
	Ruleset = { "Practice", "Duel", "Small", "Full" },
	Map = { "manor", "carnival" },
	Family = { "Witness", "Commotion", "Footprints", "Tampering" },
	Kind = { "Blade", "Blaster", "Mask", "Effect", "Trail" },
	Crate = { "masquerade", "harvest" },
	Rarity = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" },
	Count = "Count",
} :: { [string]: any }

-- Each event and its fields, in order (CustomField01, 02, 03).
Telemetry.Events = {
	-- A round played (not practice), by role and result.
	RoundPlayed = { Fields = { "Role", "Result" } },
	-- The first thing a player did in a round; value = seconds in.
	FirstAction = { Fields = { "Role", "Action", "Ruleset" } },
	-- A clue page picked up; value = seconds in.
	ClueFound = { Fields = { "Role", "Map" } },
	-- The round's first knockdown, logged for the player knocked down;
	-- value = seconds in.
	FirstElimination = { Fields = { "How", "Ruleset", "Map" } },
	-- A Guardian (or a Hero) fired the blaster, and what it hit.
	GuardianAction = { Fields = { "Shot", "Ruleset" } },
	-- A lead reached a player's notebook.
	LeadSeen = { Fields = { "Family" } },
	-- A player started another round in the same visit; value = how many
	-- rounds this visit.
	Replay = { Fields = { "Ruleset" } },
	-- A cosmetic put on, by kind.
	CosmeticEquip = { Fields = { "Kind" } },
	CrateOpened = { Fields = { "Crate", "Rarity" } },
	-- A trade opened between two players; logged for both.
	TradeInitiated = { Fields = {} },
	-- A trade settled, logged for both; value = items moved; fields =
	-- items this player gave, then got.
	TradeCompleted = { Fields = { "Count", "Count" } },
} :: { [string]: Event }

return Telemetry
