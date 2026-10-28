-- Scratch tuner (not shipped): picks costs and effect sizes for the branching
-- tree so the reference playthrough follows a wait schedule, balances the
-- paths so every route takes about as long, then writes the upgrade list.

local fs = require("@lune/fs")
local process = require("@lune/process")
local Earnings = require("../src/shared/Earnings")
local Progression = require("../src/shared/Progression")

local args = process.args
local TARGET_GAIN = tonumber(args[1]) or 0.25
local TOTAL_MINUTES = tonumber(args[2]) or 90
local ROUNDS = tonumber(args[3]) or 12

local BASE_VISITORS = 1

local PREFIX = {
	starter_stall = "stall",
	grower = "grower",
	kitchen = "kitchen",
	attraction_1 = "attraction_1",
	attraction_2 = "attraction_2",
	attraction_3 = "attraction_3",
}
local BUILDING_ORDER = { "starter_stall", "grower", "kitchen", "attraction_1", "attraction_2", "attraction_3" }

local BUILDINGS = {
	starter_stall = { Kind = "Stall", Makes = "handmade", PerSecond = 1 },
	grower = { Kind = "Grower", Makes = "raw", Requires = "starter_stall", Tune = "PerSecond" },
	kitchen = { Kind = "Kitchen", Takes = "raw", Makes = "cooked", Requires = "grower" },
	attraction_1 = {
		Kind = "Attraction",
		Type = "Walkthrough",
		Draw = 1,
		Capacity = 20,
		Requires = "kitchen",
		Tune = "Ticket",
	},
	attraction_2 = { Kind = "Attraction", Type = "Showpiece", Draw = 4, Ticket = 20, Requires = "attraction_1" },
	attraction_3 = {
		Kind = "Attraction",
		Type = "Ride",
		Draw = 2,
		Seats = 60,
		RoundSeconds = 10,
		Requires = "attraction_2",
		Tune = "Ticket",
	},
}

local SHARED = {
	starter_stall = { { "stall_counter", { PerSecond = 1 } }, { "stall_boost_2", { PerSecond = 1 } } },
	grower = { { "grower_boost", { PerSecond = 1 } }, { "grower_boost_2", { PerSecond = 1 } } },
	kitchen = { { "kitchen_boost", { PerSecond = 1, Value = 1 } }, { "kitchen_boost_2", { PerSecond = 1, Value = 1 } } },
	attraction_1 = { { "attraction_1_boost", { Ticket = 1 } }, { "attraction_1_boost_2", { Capacity = 1, Draw = 1 } } },
	attraction_2 = { { "attraction_2_boost", { Draw = 1 } }, { "attraction_2_boost_2", { Ticket = 1 } } },
	attraction_3 = { { "attraction_3_boost", { Ticket = 1 } }, { "attraction_3_boost_2", { Seats = 1, Draw = 1 } } },
}

local PATH_ORDER = {
	starter_stall = { "output", "vendor", "markup" },
	grower = { "output", "vendor" },
	kitchen = { "value", "vendor" },
	attraction_1 = { "capacity", "ticket" },
	attraction_2 = { "draw", "ticket" },
	attraction_3 = { "seats", "ticket", "draw" },
}
-- Stat weights: each stat is multiplied by the tier's multiplier to this power.
local PATHS = {
	starter_stall = { output = { PerSecond = 1 }, vendor = "Vendor", markup = { Markup = 1, PerSecond = 1 } },
	grower = { output = { PerSecond = 1 }, vendor = "Vendor" },
	kitchen = { value = { Value = 1 }, vendor = "Vendor" },
	attraction_1 = { capacity = { Capacity = 1, Draw = 0.5, Ticket = 1 }, ticket = { Ticket = 1 } },
	attraction_2 = { draw = { Draw = 0.5, Ticket = 1 }, ticket = { Ticket = 1 } },
	attraction_3 = {
		seats = { Seats = 1, Draw = 0.5, Ticket = 1 },
		ticket = { Ticket = 1 },
		draw = { Draw = 0.5, Ticket = 1 },
	},
}

local ORDER = {
	{ "starter_stall", "B" },
	{ "starter_stall", 1 },
	{ "grower", "B" },
	{ "starter_stall", 2 },
	{ "grower", 1 },
	{ "starter_stall", "T1" },
	{ "kitchen", "B" },
	{ "grower", 2 },
	{ "kitchen", 1 },
	{ "grower", "T1" },
	{ "starter_stall", "T2" },
	{ "kitchen", 2 },
	{ "attraction_1", "B" },
	{ "kitchen", "T1" },
	{ "attraction_1", 1 },
	{ "grower", "T2" },
	{ "starter_stall", "T3" },
	{ "attraction_1", 2 },
	{ "attraction_2", "B" },
	{ "attraction_1", "T1" },
	{ "kitchen", "T2" },
	{ "attraction_2", 1 },
	{ "grower", "T3" },
	{ "starter_stall", "T4" },
	{ "attraction_2", 2 },
	{ "attraction_1", "T2" },
	{ "attraction_3", "B" },
	{ "attraction_2", "T1" },
	{ "kitchen", "T3" },
	{ "attraction_3", 1 },
	{ "grower", "T4" },
	{ "attraction_1", "T3" },
	{ "attraction_3", 2 },
	{ "attraction_2", "T2" },
	{ "attraction_3", "T1" },
	{ "kitchen", "T4" },
	{ "attraction_1", "T4" },
	{ "attraction_2", "T3" },
	{ "attraction_3", "T2" },
	{ "attraction_2", "T4" },
	{ "attraction_3", "T3" },
	{ "attraction_3", "T4" },
}

local waits = {}
do
	local raw, sum = {}, 0
	for k = 1, #ORDER - 1 do
		raw[k] = 15 + 180 * (1 - math.exp(-(k - 1) / 16))
		sum += raw[k]
	end
	local scale = TOTAL_MINUTES * 60 / sum
	for k = 1, #ORDER - 1 do
		waits[k] = if k == 1 then 15 else raw[k] * scale
	end
end

local function nice(x: number): number
	if x <= 0 then
		return 0
	end
	if x < 10 then
		return math.max(1, math.floor(x + 0.5))
	end
	local p = 10 ^ (math.floor(math.log10(x)) - 1)
	return math.floor(x / p + 0.5) * p
end

local NICE_MULTS = { 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 80, 100 }
local function niceMult(x, whole)
	local best, bestErr = nil, math.huge
	for _, m in NICE_MULTS do
		if not whole or m == math.floor(m) then
			local err = math.abs(math.log(m) - math.log(x))
			if err < bestErr then
				best, bestErr = m, err
			end
		end
	end
	return best
end

-- Whole numbers only, so tickets, prices and spends read cleanly.
local CANDIDATES = {}
for e = 0, 9 do
	for _, m in { 1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8 } do
		local v = m * 10 ^ e
		if v == math.floor(v) then
			table.insert(CANDIDATES, v)
		end
	end
end

-- Target income gain per purchase: early purchases double income, later
-- ones add about a quarter.
local function gainAt(k)
	return TARGET_GAIN + (1 - TARGET_GAIN) * math.exp(-(k - 2) / 6)
end

local routes = { {} }
for _, b in BUILDING_ORDER do
	local nextRoutes = {}
	for _, r in routes do
		for _, p in PATH_ORDER[b] do
			local copy = table.clone(r)
			copy[b] = p
			table.insert(nextRoutes, copy)
		end
	end
	routes = nextRoutes
end

local function geomean(values)
	local s = 0
	for _, v in values do
		s += math.log(math.max(v, 1e-9))
	end
	return math.exp(s / #values)
end

-- adjust[building][path]: power on the target gain for that path's tiers.
local function tune(adjust)
	local items = { handmade = { Value = 1 }, raw = { Value = 1 }, cooked = { Value = 4 } }
	local upgrades = {}
	local balance = { Items = items, BaseVisitorsPerSecond = BASE_VISITORS, Upgrades = upgrades }
	local owned = {}
	for i = 1, #routes do
		owned[i] = {}
	end
	local function income(i)
		return Earnings.perSecond(owned[i], balance)
	end

	local function pick(spec, candidates, routeIds, target, setValue)
		local before = {}
		for _, i in routeIds do
			before[i] = income(i)
		end
		local best, bestErr = nil, math.huge
		for _, value in candidates do
			setValue(value)
			local ratios = {}
			for _, i in routeIds do
				owned[i][spec.Id] = true
				table.insert(ratios, income(i) / before[i])
				owned[i][spec.Id] = nil
			end
			local err = math.abs(math.log(geomean(ratios)) - math.log(target))
			if err < bestErr then
				best, bestErr = value, err
			end
		end
		setValue(best)
	end

	local function multCandidates(stats)
		local whole = stats.Seats ~= nil
		local cands = {}
		for _, m in NICE_MULTS do
			if not whole or m == math.floor(m) then
				table.insert(cands, m)
			end
		end
		return cands
	end

	local function setMults(spec, stats, v)
		for s, w in stats do
			spec.Multipliers[s] = if w == 1 then v else niceMult(math.max(v ^ w, 1.2), s == "Seats")
		end
	end

	local all = {}
	for i = 1, #routes do
		table.insert(all, i)
	end

	local lastCost = 0
	for k, slot in ORDER do
		local building, step = slot[1], slot[2]
		local beforeAll = {}
		for i = 1, #routes do
			beforeAll[i] = income(i)
		end
		local target = 1 + gainAt(k)
		local new = {}
		if step == "B" then
			local spec = table.clone(BUILDINGS[building])
			local tune = spec.Tune
			spec.Tune = nil
			spec.Id = building
			spec.Cost = 0
			table.insert(upgrades, spec)
			if building == "kitchen" then
				-- Cooks everything the patch grows; the cooked price is tuned.
				local chain = Earnings.chain(owned[1], balance)
				spec.PerSecond = math.ceil(chain.Stations.grower.Out)
				pick(spec, CANDIDATES, all, target, function(v)
					items.cooked.Value = v
				end)
			elseif tune then
				pick(spec, CANDIDATES, all, target, function(v)
					spec[tune] = v
				end)
			end
			table.insert(new, { spec, all })
		elseif type(step) == "number" then
			local def = SHARED[building][step]
			local spec = {
				Id = def[1],
				Kind = "Boost",
				Cost = 0,
				Target = building,
				Multipliers = {},
				Requires = if step == 1 then building else SHARED[building][1][1],
				Building = building,
			}
			table.insert(upgrades, spec)
			pick(spec, multCandidates(def[2]), all, target, function(v)
				setMults(spec, def[2], v)
			end)
			table.insert(new, { spec, all })
		else
			local tier = tonumber(string.sub(step, 2))
			local prefix = PREFIX[building]
			for _, path in PATH_ORDER[building] do
				local def = PATHS[building][path]
				local id = prefix .. "_" .. path .. "_" .. tier
				local requires = if tier == 1
					then SHARED[building][2][1]
					else prefix .. "_" .. path .. "_" .. (tier - 1)
				local routeIds = {}
				for i, r in routes do
					if r[building] == path then
						table.insert(routeIds, i)
					end
				end
				local pathTarget = target ^ adjust[building][path]
				local spec
				if def == "Vendor" and tier == 1 then
					spec = {
						Id = id,
						Kind = "Vendor",
						Cost = 0,
						Target = building,
						Spend = 1,
						Requires = requires,
						Building = building,
						Path = path,
					}
					table.insert(upgrades, spec)
					pick(spec, CANDIDATES, routeIds, pathTarget, function(v)
						spec.Spend = v
					end)
				else
					local stats = if def == "Vendor" then { Spend = 1 } else def
					spec = {
						Id = id,
						Kind = "Boost",
						Cost = 0,
						Target = if def == "Vendor" then prefix .. "_" .. path .. "_1" else building,
						Multipliers = {},
						Requires = requires,
						Building = building,
						Path = path,
					}
					table.insert(upgrades, spec)
					pick(spec, multCandidates(stats), routeIds, pathTarget, function(v)
						setMults(spec, stats, v)
					end)
				end
				table.insert(new, { spec, routeIds })
			end
		end

		local cost = 0
		if k > 1 then
			cost = nice(waits[k - 1] * geomean(beforeAll))
			if cost <= lastCost then
				cost = nice(lastCost * 1.08 + 1)
			end
		end
		lastCost = cost
		for _, entry in new do
			entry[1].Cost = cost
			for _, i in entry[2] do
				owned[i][entry[1].Id] = true
			end
		end
	end
	return balance
end

-- Plays every route, buying the cheapest upgrade it can each time.
local function verify(balance)
	local upgrades = balance.Upgrades
	local results = {}
	for _, route in routes do
		local state = { Coins = 0, Owned = {} }
		local seconds, worst, worstAt, minGain, minGainId, early = 0, 0, "", math.huge, "", 0
		local earlyAt = ""
		while true do
			local available = {}
			for _, u in Progression.available(state.Owned, upgrades) do
				if not u.Path or route[u.Building] == u.Path then
					table.insert(available, u)
				end
			end
			if #available == 0 then
				break
			end
			table.sort(available, function(a, b)
				return a.Cost < b.Cost
			end)
			local nextUp = available[1]
			local inc = Earnings.perSecond(state.Owned, balance)
			local wait = if state.Coins >= nextUp.Cost then 0 else (nextUp.Cost - state.Coins) / inc
			if wait > worst then
				worst, worstAt = wait, nextUp.Id
			end
			if seconds < 10 * 60 and wait > early then
				early = wait
				earlyAt = nextUp.Id
			end
			seconds += wait
			state.Coins = math.max(state.Coins + inc * wait, nextUp.Cost)
			Progression.purchase(state, upgrades, nextUp.Id)
			local gain = Earnings.perSecond(state.Owned, balance) / inc - 1
			if inc > 0 and gain < minGain then
				minGain, minGainId = gain, nextUp.Id
			end
		end
		local name = {}
		for _, b in BUILDING_ORDER do
			table.insert(name, route[b])
		end
		table.insert(results, {
			Route = route,
			Name = table.concat(name, "/"),
			Minutes = seconds / 60,
			Worst = worst,
			WorstAt = worstAt,
			MinGain = minGain,
			MinGainAt = minGainId,
			Early = early,
			EarlyAt = earlyAt,
		})
	end
	return results
end

local adjust = {}
for _, b in BUILDING_ORDER do
	adjust[b] = {}
	for _, p in PATH_ORDER[b] do
		adjust[b][p] = 1
	end
end

local balance, results
for round = 1, ROUNDS do
	balance = tune(adjust)
	results = verify(balance)
	local logAll = 0
	for _, r in results do
		logAll += math.log(r.Minutes)
	end
	logAll /= #results
	local lo, hi = math.huge, 0
	for _, r in results do
		lo, hi = math.min(lo, r.Minutes), math.max(hi, r.Minutes)
	end
	print(string.format("round %d: %.1f to %.1f min (mean %.1f)", round, lo, hi, math.exp(logAll)))
	-- Paths on slow routes get stronger, paths on fast ones weaker.
	for _, b in BUILDING_ORDER do
		for _, p in PATH_ORDER[b] do
			local s, n = 0, 0
			for _, r in results do
				if r.Route[b] == p then
					s += math.log(r.Minutes)
					n += 1
				end
			end
			local diff = s / n - logAll
			adjust[b][p] *= math.exp(diff * 2.5)
		end
	end
end

table.sort(results, function(a, b)
	return a.Minutes < b.Minutes
end)
local function show(r)
	print(
		string.format(
			"%-48s %6.1f min  worst wait %4.0fs (%s)  early %3.0fs (%s) min gain %3.0f%% (%s)",
			r.Name,
			r.Minutes,
			r.Worst,
			r.WorstAt,
			r.Early,
			r.EarlyAt,
			r.MinGain * 100,
			r.MinGainAt
		)
	)
end
for i = 1, 5 do
	show(results[i])
end
print("...")
for i = #results - 4, #results do
	show(results[i])
end
local worstAll, minGainAll, earlyAll = 0, math.huge, 0
for _, r in results do
	worstAll = math.max(worstAll, r.Worst)
	minGainAll = math.min(minGainAll, r.MinGain)
	earlyAll = math.max(earlyAll, r.Early)
end
print(
	string.format(
		"routes %d, fastest %.1f, slowest %.1f, worst wait %.0fs, early worst %.0fs, min gain %.1f%%",
		#results,
		results[1].Minutes,
		results[#results].Minutes,
		worstAll,
		earlyAll,
		minGainAll * 100
	)
)
for _, b in BUILDING_ORDER do
	local parts = {}
	for _, p in PATH_ORDER[b] do
		table.insert(parts, string.format("%s %.2f", p, adjust[b][p]))
	end
	print(b, table.concat(parts, ", "))
end

-- Prints the tree in Config/Balance's own format, ready to paste over it.
local function number(v: number): string
	if v ~= math.floor(v) then
		return tostring(v)
	end
	local digits = string.format("%d", v)
	if v < 1000 then
		return digits
	end
	return (string.gsub(string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1_"))), "^_", ""))
end
local OPEN, CLOSE = "{", "}"
local STAT_ORDER = { "PerSecond", "Markup", "Value", "Spend", "Draw", "Capacity", "Seats", "Ticket" }
local function effect(u): string
	if u.Kind == "Vendor" then
		return `Spend = {number(u.Spend)}`
	end
	local parts = {}
	for _, stat in STAT_ORDER do
		if u.Multipliers[stat] then
			table.insert(parts, `{stat} = {number(u.Multipliers[stat])}`)
		end
	end
	return "Multipliers = { " .. table.concat(parts, ", ") .. " }"
end
local byId = {}
for _, u in balance.Upgrades do
	byId[u.Id] = u
end
local lines = {}
for _, b in BUILDING_ORDER do
	local u = byId[b]
	local fields = {}
	for _, f in
		{
			"Id",
			"Kind",
			"Type",
			"Cost",
			"Takes",
			"Makes",
			"PerSecond",
			"Draw",
			"Capacity",
			"Seats",
			"RoundSeconds",
			"Ticket",
			"Requires",
		}
	do
		if u[f] ~= nil then
			table.insert(fields, `{f} = {if type(u[f]) == "number" then number(u[f]) else string.format("%q", u[f])}`)
		end
	end
	table.insert(lines, "building({ " .. table.concat(fields, ", ") .. " }, {")
	for _, shared in SHARED[b] do
		local s = byId[shared[1]]
		table.insert(lines, `\t{OPEN} Id = "{s.Id}", Cost = {number(s.Cost)}, {effect(s)} {CLOSE},`)
	end
	table.insert(lines, "})")
	local prefix = PREFIX[b]
	for _, p in PATH_ORDER[b] do
		table.insert(lines, `path("{b}", "{prefix}", "{p}", "{SHARED[b][2][1]}", {OPEN}`)
		for tier = 1, 4 do
			local t = byId[prefix .. "_" .. p .. "_" .. tier]
			table.insert(lines, `\t{OPEN} Cost = {number(t.Cost)}, {effect(t)} {CLOSE},`)
		end
		table.insert(lines, "})")
	end
	table.insert(lines, "")
end
table.insert(lines, `Items.cooked.Value = {number(balance.Items.cooked.Value)}`)
print("")
print(table.concat(lines, "\n"))
