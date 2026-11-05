--!strict
-- The onboarding funnel reported to Roblox's Creator Dashboard: the steps a
-- new player goes through in their first shows, in order, so the dashboard
-- shows where players drop off. Each step is logged once per player, ever,
-- and only after every step before it, so the save keeps the last step
-- logged. Pure, so the tests can check it.

local Funnel = {}

-- What the server knows about a player when it checks the funnel.
export type State = {
	Spawned: boolean,
	-- They changed their outfit at least once.
	Dressed: boolean,
	Walks: number,
	Votes: number,
	Shows: number,
	Wins: number,
	SavedLooks: number,
	Sessions: number,
}

Funnel.Steps = {
	{
		Name = "Joined",
		reached = function(_state: State): boolean
			return true
		end,
	},
	{
		Name = "Spawned",
		reached = function(state: State): boolean
			return state.Spawned
		end,
	},
	{
		Name = "Changed outfit",
		reached = function(state: State): boolean
			return state.Dressed
		end,
	},
	{
		Name = "Walked the runway",
		reached = function(state: State): boolean
			return state.Walks > 0
		end,
	},
	{
		Name = "Voted",
		reached = function(state: State): boolean
			return state.Votes > 0
		end,
	},
	{
		Name = "Finished a show",
		reached = function(state: State): boolean
			return state.Shows > 0
		end,
	},
	{
		Name = "Won a matchup",
		reached = function(state: State): boolean
			return state.Wins > 0
		end,
	},
	{
		Name = "Saved an outfit",
		reached = function(state: State): boolean
			return state.SavedLooks > 0
		end,
	},
	{
		Name = "Came back",
		reached = function(state: State): boolean
			return state.Sessions >= 2
		end,
	},
}

-- The steps to log now, by number, for a player whose last logged step is
-- logged: each step after it that they've reached, up to the first they
-- haven't.
function Funnel.toLog(logged: number, state: State): { number }
	local steps = {}
	for index = logged + 1, #Funnel.Steps do
		if not Funnel.Steps[index].reached(state) then
			break
		end
		table.insert(steps, index)
	end
	return steps
end

return Funnel
