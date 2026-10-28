--!strict
-- Cosmetic rules: which cosmetics a player has, and what can be worn where.
-- Pure functions with no Roblox APIs, like Progression, so the server, the
-- client and the Lune test suite all run the same code. Only the server's
-- answer counts; the client uses it to decide what to show.

export type Unlock = {
	Owns: string?,
	OwnsAll: { string }?,
	OwnedCount: number?,
	Building: string?,
	Path: string?,
}

export type Cosmetic = {
	Id: string,
	Slot: string,
	Line: string,
	Unlock: Unlock?,
	Premium: boolean?,
	Weapon: string?,
}

-- The parts of an upgrade the unlock rules read.
type Upgrade = { Id: string, Building: string?, Path: string? }

type CatalogItem = { Id: string }

local Wardrobe = {}

Wardrobe.SLOTS = { "Head", "Back", "Hand", "Pet", "Aura", "Trail" }
Wardrobe.LINES = { "Earned", "Deluxe", "Brainrot", "Legendary" }

local function isSlot(slot: string): boolean
	return table.find(Wardrobe.SLOTS, slot) ~= nil
end

function Wardrobe.find(cosmetics: { Cosmetic }, id: string): Cosmetic?
	for _, cosmetic in cosmetics do
		if cosmetic.Id == id then
			return cosmetic
		end
	end
	return nil
end

local function ownedCount(owned: { [string]: boolean }): number
	local count = 0
	for _, has in owned do
		if has then
			count += 1
		end
	end
	return count
end

-- Whether a path of a building's tree is finished: there is at least one
-- upgrade on it, and every one of them is owned.
function Wardrobe.pathComplete(owned: { [string]: boolean }, upgrades: { Upgrade }, building: string, path: string): boolean
	local any = false
	for _, upgrade in upgrades do
		if upgrade.Building == building and upgrade.Path == path then
			any = true
			if not owned[upgrade.Id] then
				return false
			end
		end
	end
	return any
end

-- Whether building has earned a free cosmetic. Paid ones are never earned.
function Wardrobe.isEarned(cosmetic: Cosmetic, owned: { [string]: boolean }, upgrades: { Upgrade }): boolean
	local unlock = cosmetic.Unlock
	if cosmetic.Premium or not unlock then
		return false
	end
	if unlock.Owns and not owned[unlock.Owns] then
		return false
	end
	if unlock.OwnsAll then
		for _, id in unlock.OwnsAll do
			if not owned[id] then
				return false
			end
		end
	end
	if unlock.OwnedCount and ownedCount(owned) < unlock.OwnedCount then
		return false
	end
	if unlock.Building and not Wardrobe.pathComplete(owned, upgrades, unlock.Building, unlock.Path or "") then
		return false
	end
	return true
end

-- Every cosmetic the player has: the free ones their upgrades have earned,
-- and the paid ones ownsPremium says they bought.
function Wardrobe.owned(
	cosmetics: { Cosmetic },
	owned: { [string]: boolean },
	upgrades: { Upgrade },
	ownsPremium: (id: string) -> boolean
): { [string]: boolean }
	local have = {}
	for _, cosmetic in cosmetics do
		local has = if cosmetic.Premium then ownsPremium(cosmetic.Id) else Wardrobe.isEarned(cosmetic, owned, upgrades)
		if has then
			have[cosmetic.Id] = true
		end
	end
	return have
end

-- Why an item can't be put on: UnknownCosmetic, WrongSlot or NotOwned.
function Wardrobe.canEquip(cosmetics: { Cosmetic }, have: { [string]: boolean }, slot: string, id: string): (boolean, string?)
	local cosmetic = Wardrobe.find(cosmetics, id)
	if not cosmetic then
		return false, "UnknownCosmetic"
	end
	if cosmetic.Slot ~= slot then
		return false, "WrongSlot"
	end
	if not have[id] then
		return false, "NotOwned"
	end
	return true, nil
end

-- What actually shows, by slot: the saved choices that are still valid. A
-- choice that isn't valid right now, such as a game pass Roblox couldn't
-- confirm, stays saved and simply doesn't show.
function Wardrobe.worn(cosmetics: { Cosmetic }, equipped: { [string]: string }, have: { [string]: boolean }): { [string]: string }
	local worn = {}
	for slot, id in equipped do
		if isSlot(slot) and Wardrobe.canEquip(cosmetics, have, slot, id) then
			worn[slot] = id
		end
	end
	return worn
end

-- Ids in after that aren't in before, in config order.
function Wardrobe.newlyOwned(cosmetics: { Cosmetic }, before: { [string]: boolean }, after: { [string]: boolean }): { string }
	local fresh = {}
	for _, cosmetic in cosmetics do
		if after[cosmetic.Id] and not before[cosmetic.Id] then
			table.insert(fresh, cosmetic.Id)
		end
	end
	return fresh
end

-- Puts newly owned items on, so other players see progress straight away.
-- An earned item only fills an empty slot, so it never replaces something the
-- player chose; something they just paid for goes straight on. Returns the
-- slots it changed.
function Wardrobe.autoEquip(cosmetics: { Cosmetic }, equipped: { [string]: string }, fresh: { string }): { string }
	local changed = {}
	for _, id in fresh do
		local cosmetic = Wardrobe.find(cosmetics, id)
		if cosmetic and (cosmetic.Premium or equipped[cosmetic.Slot] == nil) then
			equipped[cosmetic.Slot] = id
			if not table.find(changed, cosmetic.Slot) then
				table.insert(changed, cosmetic.Slot)
			end
		end
	end
	return changed
end

-- The set of owned ids as text, for a player attribute, and back.
function Wardrobe.encode(cosmetics: { Cosmetic }, have: { [string]: boolean }): string
	local ids = {}
	for _, cosmetic in cosmetics do
		if have[cosmetic.Id] then
			table.insert(ids, cosmetic.Id)
		end
	end
	return table.concat(ids, ",")
end

function Wardrobe.decode(text: string?): { [string]: boolean }
	local have = {}
	for id in string.gmatch(text or "", "[^,]+") do
		have[id] = true
	end
	return have
end

-- Returns a list of problems; empty means valid. Checks the cosmetics
-- against the upgrades they unlock from and the catalog that sells them.
function Wardrobe.validate(cosmetics: { Cosmetic }, upgrades: { Upgrade }, catalog: { CatalogItem }): { string }
	local problems = {}
	local upgradeIds = {}
	for _, upgrade in upgrades do
		upgradeIds[upgrade.Id] = true
	end
	local catalogIds = {}
	for _, item in catalog do
		catalogIds[item.Id] = true
	end

	local seen = {}
	for _, cosmetic in cosmetics do
		local id = cosmetic.Id
		if seen[id] then
			table.insert(problems, `duplicate cosmetic id {id}`)
		end
		seen[id] = cosmetic
		-- Ids go into attributes and comma lists.
		if type(id) ~= "string" or not string.match(id, "^[%l%d_]+$") then
			table.insert(problems, `{id}: ids must be lower case letters, digits and underscores`)
		end
		if not isSlot(cosmetic.Slot) then
			table.insert(problems, `{id}: unknown slot {cosmetic.Slot}`)
		end
		if not table.find(Wardrobe.LINES, cosmetic.Line) then
			table.insert(problems, `{id}: unknown line {cosmetic.Line}`)
		end
		if cosmetic.Weapon ~= nil and (cosmetic.Slot ~= "Hand" or type(cosmetic.Weapon) ~= "string") then
			table.insert(problems, `{id}: only Hand items can be weapons`)
		end

		if cosmetic.Premium then
			if cosmetic.Unlock then
				table.insert(problems, `{id}: a paid item can't also be earned`)
			end
			if not catalogIds[id] then
				table.insert(problems, `{id}: paid but not in the catalog`)
			end
			if cosmetic.Line == "Earned" then
				table.insert(problems, `{id}: paid items can't be in the Earned line`)
			end
		else
			if cosmetic.Line ~= "Earned" then
				table.insert(problems, `{id}: free items belong in the Earned line`)
			end
			if catalogIds[id] then
				table.insert(problems, `{id}: free but also in the catalog`)
			end
			local unlock = cosmetic.Unlock
			if not unlock or not (unlock.Owns or unlock.OwnsAll or unlock.OwnedCount or unlock.Building) then
				table.insert(problems, `{id}: free items need an unlock`)
			else
				local needed = { unlock.Owns }
				for _, required in unlock.OwnsAll or {} do
					table.insert(needed, required)
				end
				for _, required in needed do
					if not upgradeIds[required] then
						table.insert(problems, `{id}: unlocks from unknown upgrade {required}`)
					end
				end
				if unlock.OwnedCount and (unlock.OwnedCount < 1 or unlock.OwnedCount > #upgrades) then
					table.insert(problems, `{id}: OwnedCount must be between 1 and the number of upgrades`)
				end
				if unlock.Building or unlock.Path then
					local exists = false
					for _, upgrade in upgrades do
						if upgrade.Building == unlock.Building and upgrade.Path == unlock.Path then
							exists = true
						end
					end
					if not exists then
						table.insert(problems, `{id}: no upgrades on path {unlock.Path} of {unlock.Building}`)
					end
				end
			end
		end
	end

	for _, item in catalog do
		local cosmetic = seen[item.Id]
		if not cosmetic or not cosmetic.Premium then
			table.insert(problems, `catalog item {item.Id} is not a paid cosmetic`)
		end
	end

	return problems
end

return Wardrobe
