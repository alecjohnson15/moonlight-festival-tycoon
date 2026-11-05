--!strict
-- What a player owns and wears. Owned cosmetics are kept one by one, each
-- with its own id (its uid), so a trade moves that exact copy and a copy
-- can't be traded twice. Default items are owned by everyone, and items from
-- game passes come from Roblox each time the player joins (extra), so
-- neither is stored.

local Items = require(script.Parent.Parent.Config.Items)

export type Holder = {
	Items: { [string]: string },
	NextUid: number,
	Equipped: { [string]: string },
}

local Inventory = {}

-- Gives a new copy of itemId to the holder, whose user id is owner, and
-- returns its uid. Uids carry the owner who first got the copy and a count,
-- so they never collide between players.
function Inventory.add(holder: Holder, owner: number, itemId: string): string
	local uid = `{owner}-{holder.NextUid}`
	holder.NextUid += 1
	holder.Items[uid] = itemId
	return uid
end

-- Takes a copy away, returning which item it was.
function Inventory.remove(holder: Holder, uid: string): string?
	local itemId = holder.Items[uid]
	holder.Items[uid] = nil
	return itemId
end

function Inventory.count(holder: Holder, itemId: string): number
	local count = 0
	for _, owned in holder.Items do
		if owned == itemId then
			count += 1
		end
	end
	return count
end

function Inventory.owns(holder: Holder, itemId: string, extra: { [string]: boolean }?): boolean
	local item = Items.get(itemId)
	if not item then
		return false
	end
	if item.Default or (extra and extra[itemId]) then
		return true
	end
	for _, owned in holder.Items do
		if owned == itemId then
			return true
		end
	end
	return false
end

-- Wears itemId in its kind's slot, if the holder owns it.
function Inventory.equip(holder: Holder, itemId: string, extra: { [string]: boolean }?): (boolean, string?)
	local item = Items.get(itemId)
	if not item then
		return false, "NoSuchItem"
	end
	if not Inventory.owns(holder, itemId, extra) then
		return false, "NotOwned"
	end
	holder.Equipped[item.Kind] = itemId
	return true, nil
end

-- What the holder wears in a kind's slot: their choice while they still own
-- it, or the kind's default.
function Inventory.equipped(holder: Holder, kind: string, extra: { [string]: boolean }?): string
	local chosen = holder.Equipped[kind]
	if chosen and Inventory.owns(holder, chosen, extra) then
		local item = Items.get(chosen)
		if item and item.Kind == kind then
			return chosen
		end
	end
	return Items.DEFAULTS[kind]
end

-- Everything worn, by kind.
function Inventory.outfit(holder: Holder, extra: { [string]: boolean }?): { [string]: string }
	local outfit = {}
	for _, kind in Items.KINDS do
		outfit[kind] = Inventory.equipped(holder, kind, extra)
	end
	return outfit
end

-- Whether the holder may offer this copy in a trade.
function Inventory.canTrade(holder: Holder, uid: string): boolean
	local itemId = holder.Items[uid]
	return itemId ~= nil and Items.tradeable(itemId)
end

return Inventory
