--!strict
-- Versioned save schema. When the save shape changes, bump CURRENT_VERSION
-- and append a step to STEPS. Never edit a step that has shipped: old saves
-- still run through it.

export type Save = {
	SchemaVersion: number,
	Coins: number,
	-- All the XP ever earned; the level comes from it (Rules/Progress).
	Xp: number,
	-- Owned cosmetics, one entry per copy: uid to item id (Rules/Inventory).
	Items: { [string]: string },
	NextUid: number,
	-- The item worn in each kind's slot.
	Equipped: { [string]: string },
	-- This season's Moon Pass: XP and the tiers claimed on each track.
	Pass: { Season: string, Xp: number, Free: { [string]: boolean }, Premium: { [string]: boolean } },
	-- Per crate, opens in a row without its pity rarity.
	Pity: { [string]: number },
	Stats: {
		Rounds: number,
		Wins: number,
		Tags: number,
		Takedowns: number,
		Revives: number,
		Clues: number,
		Survived: number,
		PhantomRounds: number,
		PhantomWins: number,
		CoinsEarned: number,
		CratesOpened: number,
		Trades: number,
		-- Plaza wisps caught while out of a round (no reward; a count).
		Wisps: number,
	},
	-- The last trades, newest last, for answering "where did my item go?".
	TradeLog: { { With: number, Gave: { string }, Got: { string }, Time: number } },
	Settings: { Music: boolean, ReduceMotion: boolean, Captions: boolean },
	-- Analytics: the last onboarding funnel step logged, and sessions played.
	Onboarding: number,
	Sessions: number,
	-- First-time tips already shown, by tip id (Config/Tips).
	Tips: { [string]: boolean },
	-- Role mastery goals met, by goal id: how many times (Config/Mastery).
	Mastery: { [string]: number },
	-- Trades this save is marked for and hasn't settled, and the last ones
	-- it settled (server/Lib/TradeJournal).
	PendingTrades: { [string]: boolean },
	AppliedTrades: { string },
}

type Step = (data: any) -> ()

local Migrations = {}

Migrations.CURRENT_VERSION = 2

-- STEPS[n] upgrades a save from version n to version n + 1.
local STEPS: { Step } = {
	-- 1 to 2: first-time tips, mastery goals, the trade journal's marks, the
	-- reduce-motion and captions settings and the wisp count. Nothing old
	-- changes: coins, items, the pass and stats stay exactly as they were.
	function(data)
		data.Tips = if type(data.Tips) == "table" then data.Tips else {}
		data.Mastery = if type(data.Mastery) == "table" then data.Mastery else {}
		data.PendingTrades = if type(data.PendingTrades) == "table" then data.PendingTrades else {}
		data.AppliedTrades = if type(data.AppliedTrades) == "table" then data.AppliedTrades else {}
		data.Settings = if type(data.Settings) == "table" then data.Settings else {}
		if type(data.Settings.ReduceMotion) ~= "boolean" then
			data.Settings.ReduceMotion = false
		end
		if type(data.Settings.Captions) ~= "boolean" then
			data.Settings.Captions = false
		end
		data.Stats = if type(data.Stats) == "table" then data.Stats else {}
		if type(data.Stats.Wisps) ~= "number" then
			data.Stats.Wisps = 0
		end
	end,
}

local function template(): Save
	return {
		SchemaVersion = Migrations.CURRENT_VERSION,
		Coins = 0,
		Xp = 0,
		Items = {},
		NextUid = 1,
		Equipped = {},
		Pass = { Season = "", Xp = 0, Free = {}, Premium = {} },
		Pity = {},
		Stats = {
			Rounds = 0,
			Wins = 0,
			Tags = 0,
			Takedowns = 0,
			Revives = 0,
			Clues = 0,
			Survived = 0,
			PhantomRounds = 0,
			PhantomWins = 0,
			CoinsEarned = 0,
			CratesOpened = 0,
			Trades = 0,
			Wisps = 0,
		},
		TradeLog = {},
		Settings = { Music = true, ReduceMotion = false, Captions = false },
		Onboarding = 0,
		Sessions = 0,
		Tips = {},
		Mastery = {},
		PendingTrades = {},
		AppliedTrades = {},
	}
end

-- Adds any field the template has and the save lacks, at every depth.
local function fillMissing(target: { [any]: any }, defaults: { [any]: any })
	for key, value in defaults do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" then
			fillMissing(target[key], value)
		end
	end
end

function Migrations.new(): Save
	return template()
end

-- Brings data up to targetVersion with the given steps. Exposed with explicit
-- steps so tests can exercise migrations before a real one exists.
function Migrations.migrate(data: any, steps: { Step }, targetVersion: number): (any?, string?)
	local version = data.SchemaVersion or 1
	if version > targetVersion then
		return nil, "FutureVersion"
	end
	while version < targetVersion do
		local step = steps[version]
		if not step then
			return nil, `missing migration from version {version}`
		end
		step(data)
		version += 1
		data.SchemaVersion = version
	end
	return data, nil
end

-- Turns whatever is stored (nothing, for a new player) into a current save.
-- Fails with "FutureVersion" when the save was written by a newer server, so
-- an old server never overwrites fields it doesn't know about.
function Migrations.run(stored: any?): (Save?, string?)
	if stored == nil then
		return template(), nil
	end
	if type(stored) ~= "table" then
		return nil, "save is not a table"
	end
	local data, err = Migrations.migrate(stored, STEPS, Migrations.CURRENT_VERSION)
	if not data then
		return nil, err
	end
	fillMissing(data, template())
	return data :: Save, nil
end

function Migrations.isFuture(stored: any?): boolean
	return type(stored) == "table" and (stored.SchemaVersion or 1) > Migrations.CURRENT_VERSION
end

return Migrations
