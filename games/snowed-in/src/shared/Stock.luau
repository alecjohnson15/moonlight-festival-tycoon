--!strict
-- Counting resources: the team's stockpile, a player's backpack, and the
-- costs of things. A cost is a table of resource id to amount.

local Resources = require(script.Parent.Config.Resources)

export type Counts = { [string]: number }

local Stock = {}

function Stock.empty(): Counts
	local counts = {}
	for _, resource in Resources.List do
		counts[resource.Id] = 0
	end
	return counts
end

function Stock.total(counts: Counts): number
	local total = 0
	for _, amount in counts do
		total += amount
	end
	return total
end

function Stock.canAfford(counts: Counts, cost: Counts): boolean
	for id, amount in cost do
		if (counts[id] or 0) < amount then
			return false
		end
	end
	return true
end

-- Takes the cost out. Returns false, and takes nothing, if it can't afford it.
function Stock.spend(counts: Counts, cost: Counts): boolean
	if not Stock.canAfford(counts, cost) then
		return false
	end
	for id, amount in cost do
		counts[id] -= amount
	end
	return true
end

function Stock.add(counts: Counts, more: Counts)
	for id, amount in more do
		counts[id] = (counts[id] or 0) + amount
	end
end

-- A cost with a discount (0.25 = a quarter off), rounding up so nothing
-- becomes free.
function Stock.discount(cost: Counts, fraction: number): Counts
	local result = {}
	for id, amount in cost do
		result[id] = math.max(1, math.ceil(amount * (1 - fraction)))
	end
	return result
end

-- "6 Wood, 2 Stone", in the HUD's order.
function Stock.describe(cost: Counts): string
	local parts = {}
	for _, resource in Resources.List do
		local amount = cost[resource.Id]
		if amount and amount > 0 then
			table.insert(parts, `{amount} {resource.Name}`)
		end
	end
	if #parts == 0 then
		return "Free"
	end
	return table.concat(parts, ", ")
end

-- What is still missing to afford a cost, or nil if nothing is.
function Stock.missing(counts: Counts, cost: Counts): Counts?
	local missing = {}
	local any = false
	for id, amount in cost do
		local short = amount - (counts[id] or 0)
		if short > 0 then
			missing[id] = short
			any = true
		end
	end
	return if any then missing else nil
end

-- Moves as much as fits from a backpack into room, up to capacity in all.
-- Returns what moved.
function Stock.fill(into: Counts, capacity: number, add: Counts): Counts
	local moved = {}
	local room = capacity - Stock.total(into)
	for _, resource in Resources.List do
		local amount = add[resource.Id]
		if amount and amount > 0 and room > 0 then
			local take = math.min(amount, room)
			into[resource.Id] = (into[resource.Id] or 0) + take
			moved[resource.Id] = take
			room -= take
		end
	end
	return moved
end

return Stock
