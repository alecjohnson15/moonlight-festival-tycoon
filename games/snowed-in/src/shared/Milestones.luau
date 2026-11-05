--!strict
-- The team's milestones through a run: the moments that tell a new team it
-- is getting somewhere, long before the train. Minute is the design target
-- for when a team of four going at a steady pace reaches it (counted from
-- the start of the first day), after the overnight directive's targets of
-- roughly 3, 8, 15, 25 and 40 minutes. tools/RunModel.luau predicts the
-- timing for 1 to 8 players and tests/Pacing.spec keeps the two within a
-- few minutes. These are targets for the design, not measurements of real
-- players.

export type Milestone = { Id: string, Text: string, Minute: number }

local Milestones = {}

Milestones.List = {
	{ Id = "HearthUp", Text = "The hearth grows! The blizzard pulls back.", Minute = 3 },
	-- The first night ends at 6 minutes on the clock; the hounds of the
	-- first new kind of night are forecast then and arrive at about 9.
	{ Id = "Night1", Text = "First night survived!", Minute = 6 },
	{ Id = "FirstPart", Text = "First radio part found!", Minute = 13 },
	{ Id = "FirstFit", Text = "The radio hums: first part fitted!", Minute = 15 },
	{ Id = "Yeti", Text = "The Old Yeti is beaten!", Minute = 25 },
	{ Id = "OneToGo", Text = "Three radio parts in: one to go!", Minute = 33 },
	{ Id = "Radio", Text = "Radio fixed! The train is on its way.", Minute = 40 },
	{ Id = "Rescue", Text = "Rescued!", Minute = 52 },
} :: { Milestone }

Milestones.ById = {} :: { [string]: Milestone }
for _, milestone in Milestones.List do
	Milestones.ById[milestone.Id] = milestone
end

return Milestones
