--!strict
-- Versioned save schema (the shape is shared/Profile's Save). When the save
-- shape changes, bump CURRENT_VERSION and append a step to STEPS. Never edit
-- a step that has shipped: old saves still run through it.
-- Adapted from the tycoon's src/server/Lib/Migrations.luau.
--
-- Nothing personal is saved: no names, no chat, no ages, only what the
-- player owns and has done in the game, keyed by their user id.

-- The save's shape is spelled out in shared/Profile (Save); this
-- file doesn't require it, so the tests can load it on its own.
type Save = { [string]: any }

type Step = (data: any) -> ()

local Migrations = {}

Migrations.CURRENT_VERSION = 1

-- STEPS[n] upgrades a save from version n to version n + 1.
local STEPS: { Step } = {}

local function template(): Save
	return {
		SchemaVersion = Migrations.CURRENT_VERSION,
		Flakes = 0,
		Xp = 0,
		Owned = {},
		Roles = {},
		Trophies = {},
		Equipped = {},
		Cabin = {},
		ClaimedFree = 0,
		ClaimedPremium = 0,
		BonusClaimed = 0,
		LastRole = "Scout",
		Stats = { Runs = 0, Wins = 0, BestNight = 0, Knockouts = 0, Parts = 0, Thaws = 0 },
		Receipts = { Ids = {}, Order = {} },
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
