--!strict
-- The save schema, versioned. When the shape changes, bump CURRENT_VERSION
-- and append a step to STEPS; never edit a step that has shipped, because
-- old saves still run through it. Fields the template has and an old save
-- lacks are filled in on load, so adding a field needs no step.
--
-- A save holds no personal data: it is keyed by user id and contains only
-- game progress.

export type Save = {
	SchemaVersion: number,
	Sparkles: number,
	StyleScore: number,
	Stats: {
		Walks: number,
		Wins: number,
		Crowns: number,
		Shows: number,
		Votes: number,
		Taste: number,
		Nailed: number,
		BestFinish: number,
	},
	-- Rounds won per theme id.
	ThemeWins: { [string]: number },
	-- Pieces, poses and entrances earned with Sparkles or the Style Pass.
	Owned: { Pieces: { [string]: boolean }, Poses: { [string]: boolean }, Entrances: { [string]: boolean } },
	-- Saved outfits: Name holds a word from each list in Config/Words.
	Looks: { { Name: { number }, Look: any } },
	-- What the player last wore, so they start the next round in it.
	Current: any,
	Favorites: { number },
	Pass: { Id: string, Xp: number, Free: { [string]: boolean }, Premium: { [string]: boolean } },
	Quests: { Day: number, Ids: { string }, Progress: { number }, Done: { boolean } },
	Streak: { LastDay: number, Count: number },
	Settings: { Music: boolean, Effects: boolean, WatchOnly: boolean },
	Receipts: { Ids: { [string]: number }, Order: { string } },
	Onboarding: number,
	Sessions: number,
}

type Step = (data: any) -> ()

local Saves = {}

Saves.CURRENT_VERSION = 1

-- STEPS[n] upgrades a save from version n to version n + 1.
local STEPS: { Step } = {}

function Saves.new(startingSparkles: number, startingScore: number): Save
	return {
		SchemaVersion = Saves.CURRENT_VERSION,
		Sparkles = startingSparkles,
		StyleScore = startingScore,
		Stats = { Walks = 0, Wins = 0, Crowns = 0, Shows = 0, Votes = 0, Taste = 0, Nailed = 0, BestFinish = 0 },
		ThemeWins = {},
		Owned = { Pieces = {}, Poses = {}, Entrances = {} },
		Looks = {},
		Current = nil,
		Favorites = {},
		Pass = { Id = "", Xp = 0, Free = {}, Premium = {} },
		Quests = { Day = 0, Ids = {}, Progress = {}, Done = {} },
		Streak = { LastDay = 0, Count = 0 },
		Settings = { Music = true, Effects = true, WatchOnly = false },
		Receipts = { Ids = {}, Order = {} },
		Onboarding = 0,
		Sessions = 0,
	}
end

local function fillMissing(target: { [any]: any }, defaults: { [any]: any })
	for key, value in defaults do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" then
			fillMissing(target[key], value)
		end
	end
end

function Saves.isFuture(data: any): boolean
	return type(data) == "table" and type(data.SchemaVersion) == "number" and data.SchemaVersion > Saves.CURRENT_VERSION
end

-- Brings data up to targetVersion with the given steps (exposed so tests can
-- run migrations before a real one exists).
function Saves.migrate(data: any, steps: { Step }, targetVersion: number): (any?, string?)
	if type(data) ~= "table" then
		return nil, "NotATable"
	end
	local version = data.SchemaVersion or 1
	if version > targetVersion then
		return nil, "FutureVersion"
	end
	while version < targetVersion do
		local step = steps[version]
		if not step then
			return nil, `No migration from version {version}`
		end
		step(data)
		version += 1
		data.SchemaVersion = version
	end
	return data, nil
end

-- Upgrades a stored save and fills in anything missing.
function Saves.load(data: any, startingSparkles: number, startingScore: number): (Save?, string?)
	local migrated, err = Saves.migrate(data, STEPS, Saves.CURRENT_VERSION)
	if not migrated then
		return nil, err
	end
	fillMissing(migrated, Saves.new(startingSparkles, startingScore) :: any)
	return migrated :: Save, nil
end

return Saves
