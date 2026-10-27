--!strict
-- What a plot earns and why: the production chain, visitors and attractions.
-- Pure functions with no Roblox APIs, so the server, the client and the Lune
-- test suite all run the same code. The server pays from these numbers; the
-- client uses them only to show what an upgrade would add. Config/Balance
-- explains each kind of upgrade.

export type Upgrade = {
	Id: string,
	Kind: string,
	Cost: number,
	Requires: string?,
	-- Stall, Grower and Kitchen
	Makes: string?,
	Takes: string?,
	PerSecond: number?,
	-- Boost
	Target: string?,
	Multiplier: number?,
	-- Attraction
	Type: string?,
	Draw: number?,
	Capacity: number?,
	Seats: number?,
	RoundSeconds: number?,
	Ticket: number?,
}

export type Balance = {
	Items: { [string]: { Value: number } },
	BaseVisitorsPerSecond: number,
	Upgrades: { Upgrade },
}

export type Owned = { [string]: boolean }

-- One station's part in the chain. Rates are per second.
export type Station = {
	Kind: string,
	Makes: string,
	Out: number,
	-- Kitchens only: how much they took, the most they could take, and what
	-- was left for the stall to sell as it is.
	Takes: string?,
	In: number?,
	Capacity: number?,
	Overflow: number?,
}

export type Chain = {
	Stations: { [string]: Station },
	-- Goods reaching the stall per second, by item.
	Selling: { [string]: number },
	CoinsPerSecond: number,
}

export type Attraction = {
	Type: string,
	-- Visitors per second this attraction serves.
	Visitors: number,
	CoinsPerSecond: number,
}

export type Payout = {
	Id: string,
	Riders: number,
	Coins: number,
}

local STATION_KINDS = { Stall = true, Grower = true, Kitchen = true }

local Earnings = {}

local function multipliers(owned: Owned, upgrades: { Upgrade }): { [string]: number }
	local result: { [string]: number } = {}
	for _, upgrade in upgrades do
		if upgrade.Kind == "Boost" and owned[upgrade.Id] and upgrade.Target then
			result[upgrade.Target] = (result[upgrade.Target] or 1) * (upgrade.Multiplier or 1)
		end
	end
	return result
end

-- Follows the chain for the owned stations: growers and stalls make goods,
-- kitchens (in config order) cook what they have room for, and the stall
-- sells the rest. Nothing is sold without a stall.
function Earnings.chain(owned: Owned, balance: Balance): Chain
	local boost = multipliers(owned, balance.Upgrades)
	local stations: { [string]: Station } = {}
	local supply: { [string]: number } = {}
	local hasStall = false

	for _, upgrade in balance.Upgrades do
		if owned[upgrade.Id] and (upgrade.Kind == "Stall" or upgrade.Kind == "Grower") then
			local makes = upgrade.Makes :: string
			local out = (upgrade.PerSecond or 0) * (boost[upgrade.Id] or 1)
			supply[makes] = (supply[makes] or 0) + out
			stations[upgrade.Id] = { Kind = upgrade.Kind, Makes = makes, Out = out }
			hasStall = hasStall or upgrade.Kind == "Stall"
		end
	end

	for _, upgrade in balance.Upgrades do
		if owned[upgrade.Id] and upgrade.Kind == "Kitchen" then
			local takes, makes = upgrade.Takes :: string, upgrade.Makes :: string
			local capacity = (upgrade.PerSecond or 0) * (boost[upgrade.Id] or 1)
			local available = supply[takes] or 0
			local used = math.min(available, capacity)
			supply[takes] = available - used
			supply[makes] = (supply[makes] or 0) + used
			stations[upgrade.Id] = {
				Kind = upgrade.Kind,
				Makes = makes,
				Out = used,
				Takes = takes,
				In = used,
				Capacity = capacity,
				Overflow = available - used,
			}
		end
	end

	local coins = 0
	if hasStall then
		for item, amount in supply do
			local entry = balance.Items[item]
			coins += amount * (if entry then entry.Value else 0)
		end
	else
		table.clear(supply)
	end
	return { Stations = stations, Selling = supply, CoinsPerSecond = coins }
end

function Earnings.visitorsPerSecond(owned: Owned, balance: Balance): number
	local visitors = balance.BaseVisitorsPerSecond
	for _, upgrade in balance.Upgrades do
		if upgrade.Kind == "Attraction" and owned[upgrade.Id] then
			visitors += upgrade.Draw or 0
		end
	end
	return visitors
end

-- Everyone who arrived during one round, up to the ride's seats.
function Earnings.ridersPerRound(ride: Upgrade, visitors: number): number
	return math.min(ride.Seats or 0, math.floor(visitors * (ride.RoundSeconds or 0)))
end

-- What each owned attraction earns per second on average. Rides pay in
-- rounds (see stepRides); their figure here is the average over a round.
function Earnings.attractions(owned: Owned, balance: Balance): { [string]: Attraction }
	local visitors = Earnings.visitorsPerSecond(owned, balance)
	local result: { [string]: Attraction } = {}
	for _, upgrade in balance.Upgrades do
		if upgrade.Kind == "Attraction" and owned[upgrade.Id] then
			local kind = upgrade.Type :: string
			local served = visitors
			local coins = 0
			if kind == "Walkthrough" then
				served = math.min(visitors, upgrade.Capacity or 0)
				coins = served * (upgrade.Ticket or 0)
			elseif kind == "Ride" then
				served = Earnings.ridersPerRound(upgrade, visitors) / (upgrade.RoundSeconds :: number)
				coins = served * (upgrade.Ticket or 0)
			end
			result[upgrade.Id] = { Type = kind, Visitors = served, CoinsPerSecond = coins }
		end
	end
	return result
end

-- Everything the plot earns per second: the chain plus every attraction.
function Earnings.perSecond(owned: Owned, balance: Balance): number
	local total = Earnings.chain(owned, balance).CoinsPerSecond
	for _, attraction in Earnings.attractions(owned, balance) do
		total += attraction.CoinsPerSecond
	end
	return total
end

-- Moves every owned ride's round clock on by dt seconds and returns one
-- payout per round that finished. The caller keeps clocks for each player.
function Earnings.stepRides(clocks: { [string]: number }, owned: Owned, balance: Balance, dt: number): { Payout }
	local payouts: { Payout } = {}
	local visitors = Earnings.visitorsPerSecond(owned, balance)
	for _, upgrade in balance.Upgrades do
		if upgrade.Kind == "Attraction" and upgrade.Type == "Ride" and owned[upgrade.Id] then
			local round = upgrade.RoundSeconds :: number
			local clock = (clocks[upgrade.Id] or 0) + dt
			while clock >= round do
				clock -= round
				local riders = Earnings.ridersPerRound(upgrade, visitors)
				table.insert(payouts, { Id = upgrade.Id, Riders = riders, Coins = riders * (upgrade.Ticket or 0) })
			end
			clocks[upgrade.Id] = clock
		end
	end
	return payouts
end

local function isPositive(value: any): boolean
	return typeof(value) == "number" and value > 0
end

local function isWhole(value: any): boolean
	return isPositive(value) and value == math.floor(value)
end

-- True if upgrade can only be bought after targetId.
local function requires(byId: { [string]: Upgrade }, upgrade: Upgrade, targetId: string, limit: number): boolean
	local current = upgrade
	for _ = 1, limit do
		local nextUp = current.Requires and byId[current.Requires]
		if not nextUp then
			return false
		end
		if nextUp.Id == targetId then
			return true
		end
		current = nextUp
	end
	return false
end

-- Returns a list of problems with the kind-specific fields of the config;
-- empty means valid. Progression.validate covers ids, costs and requirements.
function Earnings.validate(balance: Balance): { string }
	local problems = {}
	local byId: { [string]: Upgrade } = {}
	local made: { [string]: boolean } = {}
	local hasStall = false

	for _, upgrade in balance.Upgrades do
		byId[upgrade.Id] = upgrade
		if (upgrade.Kind == "Stall" or upgrade.Kind == "Grower") and upgrade.Makes then
			made[upgrade.Makes] = true
		end
		hasStall = hasStall or upgrade.Kind == "Stall"
	end

	if not hasStall then
		table.insert(problems, "no stall, so nothing can be sold")
	end
	for item, entry in balance.Items do
		if not isPositive(entry.Value) then
			table.insert(problems, `item {item}: Value must be above 0`)
		end
	end

	for _, upgrade in balance.Upgrades do
		local id = upgrade.Id
		if STATION_KINDS[upgrade.Kind] then
			if not (upgrade.Makes and balance.Items[upgrade.Makes]) then
				table.insert(problems, `{id}: makes unknown item {upgrade.Makes}`)
			end
			if not isPositive(upgrade.PerSecond) then
				table.insert(problems, `{id}: needs a positive PerSecond`)
			end
			if upgrade.Kind == "Kitchen" and not (upgrade.Takes and made[upgrade.Takes]) then
				table.insert(problems, `{id}: takes {upgrade.Takes}, which no stall or grower makes`)
			end
		elseif upgrade.Kind == "Boost" then
			local target = upgrade.Target and byId[upgrade.Target]
			if not target or not STATION_KINDS[target.Kind] then
				table.insert(problems, `{id}: boost must target a stall, grower or kitchen`)
			elseif not requires(byId, upgrade, target.Id, #balance.Upgrades) then
				table.insert(problems, `{id}: boost must require its target, directly or through others`)
			end
			if not (typeof(upgrade.Multiplier) == "number" and (upgrade.Multiplier :: number) > 1) then
				table.insert(problems, `{id}: boost needs a Multiplier above 1`)
			end
		elseif upgrade.Kind == "Attraction" then
			if upgrade.Draw ~= nil and not (typeof(upgrade.Draw) == "number" and (upgrade.Draw :: number) >= 0) then
				table.insert(problems, `{id}: Draw must be 0 or more`)
			end
			if upgrade.Type == "Walkthrough" then
				if not isPositive(upgrade.Capacity) then
					table.insert(problems, `{id}: walkthrough needs a positive Capacity`)
				end
				if not isWhole(upgrade.Ticket) then
					table.insert(problems, `{id}: Ticket must be a whole number above 0`)
				end
			elseif upgrade.Type == "Ride" then
				if not isWhole(upgrade.Seats) then
					table.insert(problems, `{id}: ride needs a whole number of Seats`)
				end
				if not isPositive(upgrade.RoundSeconds) then
					table.insert(problems, `{id}: ride needs a positive RoundSeconds`)
				end
				if not isWhole(upgrade.Ticket) then
					table.insert(problems, `{id}: Ticket must be a whole number above 0`)
				end
			elseif upgrade.Type == "Showpiece" then
				if not isPositive(upgrade.Draw) then
					table.insert(problems, `{id}: showpiece needs a positive Draw`)
				end
			else
				table.insert(problems, `{id}: unknown attraction type {upgrade.Type}`)
			end
		else
			table.insert(problems, `{id}: unknown kind {upgrade.Kind}`)
		end
	end

	return problems
end

return Earnings
