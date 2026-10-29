--!strict
-- Versioned save schema. When the save shape changes, bump CURRENT_VERSION
-- and append a step to STEPS. Never edit a step that has shipped: old saves
-- still run through it.

export type Save = {
	SchemaVersion: number,
	Coins: number,
	LifetimeCoins: number,
	Owned: { [string]: boolean },
	Cosmetics: { [string]: boolean },
	-- The cosmetic chosen for each wardrobe slot, by slot name.
	Equipped: { [string]: string },
	Receipts: { Ids: { [string]: number }, Order: { string } },
	Stats: { ServeCount: number },
	Arena: { KOs: number },
	-- Ghost Catcher: the most wisps caught in one round, and rounds played.
	Activity: { Best: number, Rounds: number },
}

type Step = (data: any) -> ()

local Migrations = {}

Migrations.CURRENT_VERSION = 1

-- STEPS[n] upgrades a save from version n to version n + 1.
local STEPS: { Step } = {}

local function template(): Save
	return {
		SchemaVersion = Migrations.CURRENT_VERSION,
		Coins = 0,
		LifetimeCoins = 0,
		Owned = {},
		Cosmetics = {},
		Equipped = {},
		Receipts = { Ids = {}, Order = {} },
		Stats = { ServeCount = 0 },
		Arena = { KOs = 0 },
		Activity = { Best = 0, Rounds = 0 },
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
