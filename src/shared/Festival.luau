--!strict
-- The rules for each player's own festival (Config/Festival): what they have
-- unlocked, which choices are allowed, the name a new festival starts with,
-- and how choices travel as text in attributes. Pure functions with no
-- Roblox APIs, like Wardrobe, so the server, the client and the Lune tests
-- all run the same code. Only the server's answer counts.

export type Unlock = {
	Owns: string?,
	Building: string?,
	Path: string?,
	Tier: number?,
	ActivityBest: number?,
	Parades: number?,
}

export type Choice = { Id: string, Unlock: Unlock? }

export type Config = {
	NameWords: number,
	Palettes: { Choice },
	Decor: { Choice },
	DefaultDecor: { string },
}

-- What the unlocks read: the upgrades owned, the best Ghost Catcher round
-- and the Moonlight Parades taken part in.
export type Progress = {
	Owned: { [string]: boolean },
	ActivityBest: number,
	Parades: number,
}

-- What a player has chosen, as saved. Decor is keyed by the spot's number
-- as a string, so the save is a plain dictionary.
export type Choices = {
	Name: { number },
	Palette: string,
	Decor: { [string]: string },
}

type Upgrade = { Id: string, Building: string?, Path: string? }

local Festival = {}

function Festival.find(list: { Choice }, id: string): Choice?
	for _, choice in list do
		if choice.Id == id then
			return choice
		end
	end
	return nil
end

-- Whether the player owns tier (or, without one, every tier) of path, or of
-- any of building's paths when path is nil.
local function pathReached(
	owned: { [string]: boolean },
	upgrades: { Upgrade },
	building: string,
	path: string?,
	tier: number?
): boolean
	local tiers: { [string]: number } = {}
	local bought: { [string]: number } = {}
	for _, upgrade in upgrades do
		local name = upgrade.Path
		if upgrade.Building == building and name and (path == nil or name == path) then
			tiers[name] = (tiers[name] or 0) + 1
			if owned[upgrade.Id] then
				bought[name] = (bought[name] or 0) + 1
			end
		end
	end
	for name, count in tiers do
		if (bought[name] or 0) >= (tier or count) then
			return true
		end
	end
	return false
end

-- Every path the player has finished, as { Building, Path }, in the order
-- the upgrades are listed.
function Festival.finishedPaths(
	owned: { [string]: boolean },
	upgrades: { Upgrade }
): { { Building: string, Path: string } }
	local finished = {}
	local seen: { [string]: boolean } = {}
	for _, upgrade in upgrades do
		local building, path = upgrade.Building, upgrade.Path
		if building and path and not seen[`{building}/{path}`] then
			seen[`{building}/{path}`] = true
			if pathReached(owned, upgrades, building, path, nil) then
				table.insert(finished, { Building = building, Path = path })
			end
		end
	end
	return finished
end

function Festival.isUnlocked(choice: Choice, progress: Progress, upgrades: { Upgrade }): boolean
	local unlock = choice.Unlock
	if not unlock then
		return true
	end
	if unlock.Owns and not progress.Owned[unlock.Owns] then
		return false
	end
	if unlock.Building and not pathReached(progress.Owned, upgrades, unlock.Building, unlock.Path, unlock.Tier) then
		return false
	end
	if unlock.ActivityBest and progress.ActivityBest < unlock.ActivityBest then
		return false
	end
	if unlock.Parades and progress.Parades < unlock.Parades then
		return false
	end
	return true
end

-- The ids in list the player has unlocked, as a set.
function Festival.unlocked(list: { Choice }, progress: Progress, upgrades: { Upgrade }): { [string]: boolean }
	local set = {}
	for _, choice in list do
		if Festival.isUnlocked(choice, progress, upgrades) then
			set[choice.Id] = true
		end
	end
	return set
end

-- The ids in after but not before, in list order, for "new!" notes.
function Festival.newlyUnlocked(
	list: { Choice },
	before: { [string]: boolean },
	after: { [string]: boolean }
): { string }
	local ids = {}
	for _, choice in list do
		if after[choice.Id] and not before[choice.Id] then
			table.insert(ids, choice.Id)
		end
	end
	return ids
end

-- A name for a new festival: a word from each list, picked from seed (the
-- player's id), so a player's first festival name is always the same.
-- counts holds how many words each list has.
function Festival.defaultName(seed: number, counts: { number }): { number }
	local state = math.floor(math.abs(seed)) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local words = {}
	for _, count in counts do
		state = (state * 16807) % 2147483647
		table.insert(words, state % count + 1)
	end
	return words
end

-- Whether words is a whole number from 1 to each list's count, for each list.
function Festival.validName(words: any, counts: { number }): boolean
	if type(words) ~= "table" or #words ~= #counts then
		return false
	end
	for index, count in counts do
		local word = words[index]
		if type(word) ~= "number" or word ~= math.floor(word) or word < 1 or word > count then
			return false
		end
	end
	return true
end

-- The decoration in spot (1 to the number of spots): the player's choice if
-- it's still unlocked, else the spot's default.
function Festival.decorAt(config: Config, choices: Choices?, unlocked: { [string]: boolean }?, spot: number): string
	local chosen = choices and choices.Decor[tostring(spot)]
	if chosen and Festival.find(config.Decor, chosen) and (unlocked == nil or unlocked[chosen]) then
		return chosen
	end
	return config.DefaultDecor[spot]
end

-- The palette shown: the player's choice if it's still unlocked, else the
-- first.
function Festival.paletteOf(config: Config, choices: Choices?, unlocked: { [string]: boolean }?): string
	local chosen = choices and choices.Palette
	if chosen and Festival.find(config.Palettes, chosen) and (unlocked == nil or unlocked[chosen]) then
		return chosen
	end
	return config.Palettes[1].Id
end

-- A set of ids as text, for an attribute, and back.
function Festival.encode(set: { [string]: boolean }): string
	local ids = {}
	for id, has in set do
		if has then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

function Festival.decode(text: string?): { [string]: boolean }
	local set = {}
	for id in string.gmatch(text or "", "[^,]+") do
		set[id] = true
	end
	return set
end

-- Problems with a config, given how many decoration spots the layout has,
-- the upgrades and the most wisps a Ghost Catcher round has.
function Festival.validate(config: Config, spots: number, upgrades: { Upgrade }, wisps: number): { string }
	local problems = {}
	local upgradeIds = {}
	local buildings = {}
	for _, upgrade in upgrades do
		upgradeIds[upgrade.Id] = true
		if upgrade.Building then
			buildings[upgrade.Building] = true
		end
	end
	for _, list in { config.Palettes, config.Decor } do
		local seen = {}
		for _, choice in list do
			if seen[choice.Id] then
				table.insert(problems, `{choice.Id} is listed twice`)
			end
			seen[choice.Id] = true
			local unlock = choice.Unlock
			if unlock then
				if unlock.Owns and not upgradeIds[unlock.Owns] then
					table.insert(problems, `{choice.Id} needs unknown upgrade {unlock.Owns}`)
				end
				if unlock.Building and not buildings[unlock.Building] then
					table.insert(problems, `{choice.Id} needs a path of {unlock.Building}, which has none`)
				end
				if unlock.ActivityBest and unlock.ActivityBest > wisps then
					table.insert(problems, `{choice.Id} needs more wisps than a round has`)
				end
			end
		end
	end
	if config.Palettes[1] == nil or config.Palettes[1].Unlock ~= nil then
		table.insert(problems, "the first palette must be free")
	end
	if #config.DefaultDecor ~= spots then
		table.insert(problems, `{#config.DefaultDecor} default decorations for {spots} spots`)
	end
	for _, id in config.DefaultDecor do
		local choice = Festival.find(config.Decor, id)
		if not choice then
			table.insert(problems, `default decoration {id} is unknown`)
		elseif choice.Unlock then
			table.insert(problems, `default decoration {id} must be free`)
		end
	end
	return problems
end

return Festival
