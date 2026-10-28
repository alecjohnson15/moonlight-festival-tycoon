--!strict
-- What a plot earns and why: the production chain, visitors, attractions and
-- vendors. Pure functions with no Roblox APIs, so the server, the client and
-- the Lune test suite all run the same code. The server pays from these
-- numbers; the client uses them only to show what an upgrade would add.
-- Config/Balance explains each kind of upgrade.

export type Upgrade = {
	Id: string,
	Kind: string,
	Cost: number,
	Requires: string?,
	Building: string?,
	Path: string?,
	-- Stall, Grower and Kitchen
	Makes: string?,
	Takes: string?,
	PerSecond: number?,
	-- Boost and Vendor
	Target: string?,
	Multipliers: { [string]: number }?,
	Spend: number?,
	-- Attraction
	Type: string?,
	Draw: number?,
	Capacity: number?,
	Seats: number?,
	RoundSeconds: number?,
	Ticket: number?,
	-- Set by Earnings.effective, never in config: what a Stall's Markup and a
	-- station's Value boosts multiply prices by.
	Markup: number?,
	Value: number?,
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

export type Vendor = {
	Visitors: number,
	CoinsPerSecond: number,
}

export type Payout = {
	Id: string,
	Riders: number,
	Coins: number,
}

local STATION_KINDS = { Stall = true, Grower = true, Kitchen = true }

-- What a boost can multiply on each kind of upgrade. Markup and Value start
-- at 1: a Stall's Markup raises the price of everything sold on the plot (the
-- goods at the stall and every vendor's sales), and a station's Value raises
-- the price of the goods it makes.
local BOOSTABLE: { [string]: { [string]: boolean } } = {
	Stall = { PerSecond = true, Markup = true },
	Grower = { PerSecond = true },
	Kitchen = { PerSecond = true, Value = true },
	Vendor = { Spend = true },
	Walkthrough = { Draw = true, Capacity = true, Ticket = true },
	Ride = { Draw = true, Seats = true, Ticket = true },
	Showpiece = { Draw = true, Ticket = true },
}

local Earnings = {}

local function boostableOf(upgrade: Upgrade): { [string]: boolean }?
	if upgrade.Kind == "Attraction" then
		return BOOSTABLE[upgrade.Type or ""]
	end
	return BOOSTABLE[upgrade.Kind]
end

-- Every owned station, attraction and vendor with its owned boosts applied,
-- by id. These are copies; the config is never changed.
function Earnings.effective(owned: Owned, balance: Balance): { [string]: Upgrade }
	local result: { [string]: Upgrade } = {}
	for _, upgrade in balance.Upgrades do
		if owned[upgrade.Id] and upgrade.Kind ~= "Boost" then
			local copy = table.clone(upgrade)
			copy.Markup = 1
			copy.Value = 1
			result[upgrade.Id] = copy
		end
	end
	for _, upgrade in balance.Upgrades do
		local target = upgrade.Target and result[upgrade.Target]
		if upgrade.Kind == "Boost" and owned[upgrade.Id] and target and upgrade.Multipliers then
			local stats = target :: any
			for stat, multiplier in upgrade.Multipliers do
				if stats[stat] then
					stats[stat] *= multiplier
				end
			end
		end
	end
	return result
end

-- What every sale is multiplied by: the owned stalls' Markup.
local function markupOf(balance: Balance, effective: { [string]: Upgrade }): number
	local markup = 1
	for _, upgrade in balance.Upgrades do
		local stall = effective[upgrade.Id]
		if stall and stall.Kind == "Stall" then
			markup *= stall.Markup or 1
		end
	end
	return markup
end

-- Follows the chain for the owned stations: growers and stalls make goods,
-- kitchens (in config order) cook what they have room for, and the stall
-- sells the rest. Nothing is sold without a stall.
local function chainOf(balance: Balance, effective: { [string]: Upgrade }): Chain
	local stations: { [string]: Station } = {}
	local supply: { [string]: number } = {}
	local price: { [string]: number } = {}
	local hasStall = false

	for _, upgrade in balance.Upgrades do
		local station = effective[upgrade.Id]
		if station and STATION_KINDS[station.Kind] then
			local makes = station.Makes :: string
			price[makes] = (price[makes] or 1) * (station.Value or 1)
			hasStall = hasStall or station.Kind == "Stall"
		end
		if station and (station.Kind == "Stall" or station.Kind == "Grower") then
			local makes = station.Makes :: string
			local out = station.PerSecond or 0
			supply[makes] = (supply[makes] or 0) + out
			stations[upgrade.Id] = { Kind = station.Kind, Makes = makes, Out = out }
		end
	end

	for _, upgrade in balance.Upgrades do
		local station = effective[upgrade.Id]
		if station and station.Kind == "Kitchen" then
			local takes, makes = station.Takes :: string, station.Makes :: string
			local capacity = station.PerSecond or 0
			local available = supply[takes] or 0
			local used = math.min(available, capacity)
			supply[takes] = available - used
			supply[makes] = (supply[makes] or 0) + used
			stations[upgrade.Id] = {
				Kind = station.Kind,
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
		local markup = markupOf(balance, effective)
		for item, amount in supply do
			local entry = balance.Items[item]
			coins += amount * (if entry then entry.Value else 0) * (price[item] or 1) * markup
		end
	else
		table.clear(supply)
	end
	return { Stations = stations, Selling = supply, CoinsPerSecond = coins }
end

function Earnings.chain(owned: Owned, balance: Balance): Chain
	return chainOf(balance, Earnings.effective(owned, balance))
end

local function visitorsOf(balance: Balance, effective: { [string]: Upgrade }): number
	local visitors = balance.BaseVisitorsPerSecond
	for _, upgrade in balance.Upgrades do
		local attraction = effective[upgrade.Id]
		if attraction and attraction.Kind == "Attraction" then
			visitors += attraction.Draw or 0
		end
	end
	return visitors
end

function Earnings.visitorsPerSecond(owned: Owned, balance: Balance): number
	return visitorsOf(balance, Earnings.effective(owned, balance))
end

-- Everyone who arrived during one round, up to the ride's seats. Pass the
-- ride from Earnings.effective so its boosts count.
function Earnings.ridersPerRound(ride: Upgrade, visitors: number): number
	return math.min(ride.Seats or 0, math.floor(visitors * (ride.RoundSeconds or 0)))
end

-- What one round pays, in whole coins.
function Earnings.roundCoins(ride: Upgrade, riders: number): number
	return math.floor(riders * (ride.Ticket or 0) + 1e-6)
end

local function attractionsOf(balance: Balance, effective: { [string]: Upgrade }): { [string]: Attraction }
	local visitors = visitorsOf(balance, effective)
	local result: { [string]: Attraction } = {}
	for _, upgrade in balance.Upgrades do
		local attraction = effective[upgrade.Id]
		if attraction and attraction.Kind == "Attraction" then
			local kind = attraction.Type :: string
			local served = visitors
			local coins = 0
			if kind == "Walkthrough" then
				served = math.min(visitors, attraction.Capacity or 0)
				coins = served * (attraction.Ticket or 0)
			elseif kind == "Showpiece" then
				coins = visitors * (attraction.Ticket or 0)
			elseif kind == "Ride" then
				local round = attraction.RoundSeconds :: number
				local riders = Earnings.ridersPerRound(attraction, visitors)
				served = riders / round
				coins = Earnings.roundCoins(attraction, riders) / round
			end
			result[upgrade.Id] = { Type = kind, Visitors = served, CoinsPerSecond = coins }
		end
	end
	return result
end

-- What each owned attraction earns per second on average. Rides pay in
-- rounds (see stepRides); their figure here is the average over a round.
function Earnings.attractions(owned: Owned, balance: Balance): { [string]: Attraction }
	return attractionsOf(balance, Earnings.effective(owned, balance))
end

local function vendorsOf(balance: Balance, effective: { [string]: Upgrade }): { [string]: Vendor }
	local visitors = visitorsOf(balance, effective)
	local markup = markupOf(balance, effective)
	local result: { [string]: Vendor } = {}
	for _, upgrade in balance.Upgrades do
		local vendor = effective[upgrade.Id]
		if vendor and vendor.Kind == "Vendor" then
			result[upgrade.Id] = { Visitors = visitors, CoinsPerSecond = visitors * (vendor.Spend or 0) * markup }
		end
	end
	return result
end

-- What each owned vendor earns per second: every visitor spends at each one,
-- at the stall's markup.
function Earnings.vendors(owned: Owned, balance: Balance): { [string]: Vendor }
	return vendorsOf(balance, Earnings.effective(owned, balance))
end

-- Everything the plot earns per second: the chain, every attraction and
-- every vendor.
function Earnings.perSecond(owned: Owned, balance: Balance): number
	local effective = Earnings.effective(owned, balance)
	local total = chainOf(balance, effective).CoinsPerSecond
	for _, attraction in attractionsOf(balance, effective) do
		total += attraction.CoinsPerSecond
	end
	for _, vendor in vendorsOf(balance, effective) do
		total += vendor.CoinsPerSecond
	end
	return total
end

-- Moves every owned ride's round clock on by dt seconds and returns one
-- payout per round that finished. The caller keeps clocks for each player.
function Earnings.stepRides(clocks: { [string]: number }, owned: Owned, balance: Balance, dt: number): { Payout }
	local payouts: { Payout } = {}
	local effective = Earnings.effective(owned, balance)
	local visitors = visitorsOf(balance, effective)
	for _, upgrade in balance.Upgrades do
		local ride = effective[upgrade.Id]
		if ride and ride.Kind == "Attraction" and ride.Type == "Ride" then
			local round = ride.RoundSeconds :: number
			local clock = (clocks[upgrade.Id] or 0) + dt
			while clock >= round do
				clock -= round
				local riders = Earnings.ridersPerRound(ride, visitors)
				table.insert(payouts, { Id = upgrade.Id, Riders = riders, Coins = Earnings.roundCoins(ride, riders) })
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

local function validateBoost(upgrade: Upgrade, byId: { [string]: Upgrade }, limit: number, problems: { string })
	local id = upgrade.Id
	local target = upgrade.Target and byId[upgrade.Target]
	local boostable = target and boostableOf(target)
	if not target or not boostable then
		table.insert(problems, `{id}: boost must target a station, attraction or vendor`)
		return
	end
	if not requires(byId, upgrade, target.Id, limit) then
		table.insert(problems, `{id}: boost must require its target, directly or through others`)
	end
	if typeof(upgrade.Multipliers) ~= "table" or next(upgrade.Multipliers :: any) == nil then
		table.insert(problems, `{id}: boost needs Multipliers`)
		return
	end
	for stat, multiplier in upgrade.Multipliers :: { [string]: number } do
		if not boostable[stat] then
			table.insert(problems, `{id}: {target.Id} has no {stat} to boost`)
		end
		if not (typeof(multiplier) == "number" and multiplier > 1) then
			table.insert(problems, `{id}: {stat} multiplier must be above 1`)
		elseif stat == "Seats" and multiplier ~= math.floor(multiplier) then
			table.insert(problems, `{id}: Seats multiplier must be whole`)
		end
	end
end

-- Returns a list of problems with the kind-specific fields of the config;
-- empty means valid. Progression.validate covers ids, costs, requirements
-- and paths.
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
			validateBoost(upgrade, byId, #balance.Upgrades, problems)
		elseif upgrade.Kind == "Vendor" then
			local target = upgrade.Target and byId[upgrade.Target]
			if not target or target.Building or target.Kind == "Boost" or target.Kind == "Vendor" then
				table.insert(problems, `{id}: vendor must target the station or attraction it trades from`)
			elseif not requires(byId, upgrade, target.Id, #balance.Upgrades) then
				table.insert(problems, `{id}: vendor must require its target, directly or through others`)
			end
			if not isPositive(upgrade.Spend) then
				table.insert(problems, `{id}: vendor needs a positive Spend`)
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
				if upgrade.Ticket ~= nil and not isWhole(upgrade.Ticket) then
					table.insert(problems, `{id}: Ticket must be a whole number above 0`)
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
