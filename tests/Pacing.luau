-- The pacing every route through the shipped tree is held to, and a
-- playthrough of every route, shared by the tests that check it: the tree's
-- own (Earnings.spec) and what Ghost Catcher and the Moonlight Parade can add
-- on top (Parade.spec). A route picks one path for every building that
-- forks, and the player buys the cheapest upgrade they can each time, earning
-- only passive income; real players who watch their rides pay out or plan
-- ahead get there sooner.

local Balance = require("../src/shared/Config/Balance")
local Earnings = require("../src/shared/Earnings")
local Progression = require("../src/shared/Progression")

local Pacing = {}

Pacing.Rules = {
	-- The whole tree, on any route.
	MinMinutes = 80,
	MaxMinutes = 100,
	-- The slowest route takes at most this much longer than the fastest, so
	-- no choice of paths is a trap.
	MaxSpread = 1.2,
	-- Waits for the next upgrade: short while players learn the game, and
	-- never long enough to feel stuck.
	EarlyMinutes = 10,
	MaxEarlyWait = 120,
	MaxWait = 300,
	-- Every purchase raises income by at least this much.
	MinGain = 0.05,
}

-- Every combination of one path per forking building.
local function routes(): { { [string]: string } }
	local paths = Progression.paths(Balance.Upgrades)
	local result = { {} }
	for building, byPath in paths do
		local nextResult = {}
		for _, route in result do
			for name in byPath do
				local copy = table.clone(route)
				copy[building] = name
				table.insert(nextResult, copy)
			end
		end
		result = nextResult
	end
	return result
end

export type Playthrough = {
	Name: string,
	Seconds: number,
	Waits: { { Id: string, At: number, Wait: number, Gain: number } },
	Owned: { [string]: boolean },
}

local function play(route: { [string]: string }): Playthrough
	local state = { Coins = Balance.StartingCoins, Owned = {} }
	local seconds = 0
	local waits = {}
	while true do
		local available = {}
		for _, upgrade in Progression.available(state.Owned, Balance.Upgrades) do
			if not upgrade.Path or route[upgrade.Building] == upgrade.Path then
				table.insert(available, upgrade)
			end
		end
		if #available == 0 then
			break
		end
		table.sort(available, function(a, b)
			return a.Cost < b.Cost
		end)
		local nextUp = available[1]
		local income = Earnings.perSecond(state.Owned, Balance)
		local wait = if state.Coins >= nextUp.Cost then 0 else (nextUp.Cost - state.Coins) / income
		assert(wait < math.huge, `{nextUp.Id} can never be afforded`)
		seconds += wait
		-- Rounded up so float error can't leave the purchase a hair short.
		state.Coins = math.max(state.Coins + income * wait, nextUp.Cost)
		assert(Progression.purchase(state, Balance.Upgrades, nextUp.Id), `could not buy {nextUp.Id}`)
		local gain = if income > 0 then Earnings.perSecond(state.Owned, Balance) / income - 1 else math.huge
		table.insert(waits, { Id = nextUp.Id, At = seconds, Wait = wait, Gain = gain })
	end
	local names = {}
	for building, path in route do
		table.insert(names, `{building}:{path}`)
	end
	table.sort(names)
	return { Name = table.concat(names, " "), Seconds = seconds, Waits = waits, Owned = state.Owned }
end

local played: { Playthrough }? = nil

-- A playthrough of every route, played once however many tests ask.
function Pacing.playthroughs(): { Playthrough }
	if not played then
		local list = {}
		for _, route in routes() do
			table.insert(list, play(route))
		end
		played = list
	end
	return played :: { Playthrough }
end

-- The quickest route's playthrough.
function Pacing.fastest(): Playthrough
	local fastest = nil
	for _, run in Pacing.playthroughs() do
		if not fastest or run.Seconds < fastest.Seconds then
			fastest = run
		end
	end
	return fastest :: Playthrough
end

return Pacing
