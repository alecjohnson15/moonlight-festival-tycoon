-- Simple models for the simulations (tests/Sims.spec and tools/simulate):
-- the role deal over many rounds, and how fast a party fills the Truth
-- Bell. These are models with stated assumptions, not measurements: only
-- real play can tell how fast guests actually find pages.

local Loader = require("./RobloxLoader")

local Bell = Loader.require("src/shared/Rules/Bell")
local Deal = Loader.require("src/shared/Rules/Deal")
local Game = Loader.require("src/shared/Config/Game")
local Roles = Loader.require("src/shared/Config/Roles")
local Round = Loader.require("src/shared/Rules/Round")

local Models = {}

function Models.seeded(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

-- Deals rounds rounds to players players (with the real ticket rules) and
-- reports, per special role: the share each player got (lowest and
-- highest), the fair share, and the longest run of rounds any player went
-- without it.
function Models.deal(players: number, rounds: number, seed: number)
	local random = Models.seeded(seed)
	local ids = {}
	for index = 1, players do
		ids[index] = index
	end
	local tickets = {}
	local counts: { [string]: { [number]: number } } = {}
	local since: { [string]: { [number]: number } } = {}
	local longest: { [string]: number } = {}
	for _, roleId in Roles.DEAL_ORDER do
		counts[roleId], since[roleId], longest[roleId] = {}, {}, 0
		for _, id in ids do
			counts[roleId][id], since[roleId][id] = 0, 0
		end
	end
	for _ = 1, rounds do
		local dealt = Deal.deal(ids, tickets, random)
		Deal.afterDeal(tickets, dealt)
		for _, roleId in Roles.DEAL_ORDER do
			for _, id in ids do
				if dealt[id] == roleId then
					counts[roleId][id] += 1
					since[roleId][id] = 0
				else
					since[roleId][id] += 1
					longest[roleId] = math.max(longest[roleId], since[roleId][id])
				end
			end
		end
	end
	local report = {}
	for _, roleId in Roles.DEAL_ORDER do
		local per = (Roles.counts(players)[roleId] or 0)
		local low, high = math.huge, 0
		for _, id in ids do
			local share = counts[roleId][id] / rounds
			low, high = math.min(low, share), math.max(high, share)
		end
		report[roleId] = {
			Fair = per / players,
			Low = low,
			High = high,
			LongestWait = if per > 0 then longest[roleId] else 0,
		}
	end
	return report
end

-- How long, on average, the party takes to find a page on the floor, in
-- seconds. An assumption: one guest alone takes about 70 seconds to reach
-- a given page on a big map, and more guests spread out and find pages
-- faster, with diminishing returns.
function Models.findSeconds(guests: number): number
	return 70 / math.max(1, guests) ^ 0.6
end

-- Plays the Truth Bell through rounds rounds with players players: five
-- pages out at once, each found after a random time (Models.findSeconds on
-- average) and replaced 10 to 20 seconds after it's taken, as in
-- PickupService. Shadows tearing pages is left out, which flatters the
-- guests. Returns the share of rounds where the bell rang at least once,
-- rang in the first minute, the average rings a round and the median
-- second of the first ring.
function Models.bell(players: number, rounds: number, seed: number, config: any?)
	local random = Models.seeded(seed)
	local counts = Roles.counts(players)
	local shadows = (counts.Phantom or 0) + (counts.Saboteur or 0)
	local guests = math.max(1, players - shadows)
	local length = Round.length(players)
	local mean = Models.findSeconds(guests)
	local rang, early, rings = 0, 0, 0
	local firsts = {}
	for _ = 1, rounds do
		local finds = {}
		for _ = 1, 5 do
			local at = 0
			while true do
				at += -math.log(1 - random()) * mean
				if at > length then
					break
				end
				table.insert(finds, at)
				at += 10 + random() * 10
			end
		end
		table.sort(finds)
		local bell = Bell.new(guests, config)
		local first = nil
		for _, at in finds do
			if Bell.add(bell, config) == "Ring" then
				rings += 1
				first = first or at
			end
		end
		if first then
			rang += 1
			table.insert(firsts, first)
			if first <= 60 then
				early += 1
			end
		end
	end
	table.sort(firsts)
	return {
		Rang = rang / rounds,
		Early = early / rounds,
		Rings = rings / rounds,
		MedianFirst = firsts[math.max(1, math.floor(#firsts / 2))] or 0,
		Guests = guests,
		Pages = Bell.need(guests, config),
		Length = length,
	}
end

-- The first version's bell, for comparison.
function Models.oldBell(config: any): any
	local old = table.clone(config)
	old.Base, old.PerGuest, old.Min, old.Max, old.MaxRings = 10, 0, 10, 10, math.huge
	return old
end

Models.MaxPlayers = Game.MaxPlayers

return Models
