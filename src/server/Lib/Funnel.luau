--!strict
-- The onboarding funnel AnalyticsService reports to Roblox's Creator
-- Dashboard: the steps a new player goes through in their first minutes, in
-- order, so the dashboard shows where players drop off. Each step is logged
-- once per player, ever, and only after every step before it, so the save
-- keeps the last step logged. Pure, so the tests can check it.

local Funnel = {}

-- What the server knows about a player when it checks the funnel.
export type State = {
	-- Their character has spawned, so they have control.
	Spawned: boolean,
	-- They have been close to a free gate.
	NearGate: boolean,
	HasPlot: boolean,
	Owned: { [string]: boolean },
	-- Coins earned, ever, from income, Ghost Catcher and parades.
	LifetimeCoins: number,
}

type Upgrade = { Id: string, Cost: number, Kind: string?, Path: string? }

local function owns(state: State, upgrades: { Upgrade }, test: (Upgrade) -> boolean): boolean
	for _, upgrade in upgrades do
		if state.Owned[upgrade.Id] and test(upgrade) then
			return true
		end
	end
	return false
end

-- The steps in order, each with the name the dashboard shows and whether a
-- player has reached it.
Funnel.Steps = {
	{
		Name = "Joined",
		reached = function(_state: State, _upgrades: { Upgrade }): boolean
			return true
		end,
	},
	{
		Name = "Spawned",
		reached = function(state: State, _upgrades: { Upgrade }): boolean
			return state.Spawned
		end,
	},
	{
		Name = "Reached a gate",
		reached = function(state: State, _upgrades: { Upgrade }): boolean
			return state.NearGate or state.HasPlot
		end,
	},
	{
		Name = "Claimed a plot",
		reached = function(state: State, _upgrades: { Upgrade }): boolean
			return state.HasPlot
		end,
	},
	{
		Name = "Built the stall",
		reached = function(state: State, upgrades: { Upgrade }): boolean
			return owns(state, upgrades, function()
				return true
			end)
		end,
	},
	{
		Name = "Earned coins",
		reached = function(state: State, _upgrades: { Upgrade }): boolean
			return state.LifetimeCoins > 0
		end,
	},
	{
		Name = "Bought an upgrade",
		reached = function(state: State, upgrades: { Upgrade }): boolean
			return owns(state, upgrades, function(upgrade)
				return upgrade.Cost > 0
			end)
		end,
	},
	{
		Name = "Built an attraction",
		reached = function(state: State, upgrades: { Upgrade }): boolean
			return owns(state, upgrades, function(upgrade)
				return upgrade.Kind == "Attraction"
			end)
		end,
	},
	{
		Name = "Picked a path",
		reached = function(state: State, upgrades: { Upgrade }): boolean
			return owns(state, upgrades, function(upgrade)
				return upgrade.Path ~= nil
			end)
		end,
	},
}

-- The steps to log now, by number, for a player whose last logged step is
-- logged: each step after it that they've reached, up to the first they
-- haven't.
function Funnel.toLog(logged: number, state: State, upgrades: { Upgrade }): { number }
	local steps = {}
	for index = logged + 1, #Funnel.Steps do
		if not Funnel.Steps[index].reached(state, upgrades) then
			break
		end
		table.insert(steps, index)
	end
	return steps
end

-- The paths in chosen that weren't in known, as building and path pairs,
-- sorted so they log in a steady order.
function Funnel.newPaths(
	known: { [string]: string },
	chosen: { [string]: string }
): { { Building: string, Path: string } }
	local list = {}
	for building, path in chosen do
		if known[building] ~= path then
			table.insert(list, { Building = building, Path = path })
		end
	end
	table.sort(list, function(a, b)
		return a.Building < b.Building
	end)
	return list
end

return Funnel
