-- The five roles. Two teams: the Shadows (the Phantom and, on bigger
-- servers, a Saboteur who helps them) and the Guests (everyone else, led by
-- a Guardian and patched up by a Medic). A role is secret: the server tells
-- each player only their own, and tells the Shadows about each other.

export type Role = {
	Id: string,
	Name: string,
	Team: string,
	Color: string,
	-- One line on the role card, said as an instruction.
	Goal: string,
	-- What the role can do, one short line each.
	Moves: { string },
}

local Roles = {}

Roles.TEAMS = { "Shadows", "Guests" }

Roles.List = {
	Phantom = {
		Id = "Phantom",
		Name = "Phantom",
		Team = "Shadows",
		Color = "#FF4D6D",
		Goal = "Tag every guest before the clock runs out. Don't get caught.",
		Moves = {
			"Draw your blade to tag guests up close (everyone sees it drawn)",
			"Throw it to tag from afar; it flies back to you",
			"See everyone's outline while the lights are out",
		},
	},
	Saboteur = {
		Id = "Saboteur",
		Name = "Saboteur",
		Team = "Shadows",
		Color = "#B066FF",
		Goal = "Help the Phantom win. You can't tag anyone, so cause chaos.",
		Moves = {
			"Cut the lights twice a round",
			"The Phantom can't tag you, and knows who you are",
		},
	},
	Guardian = {
		Id = "Guardian",
		Name = "Guardian",
		Team = "Guests",
		Color = "#4DABFF",
		Goal = "Find the Phantom and knock them out with your Moonbeam Blaster.",
		Moves = {
			"Zap the Phantom to win the round for the guests",
			"Zap an innocent guest and you're both knocked out",
			"If you go down, anyone can pick up your blaster",
		},
	},
	Medic = {
		Id = "Medic",
		Name = "Medic",
		Team = "Guests",
		Color = "#4DFF9A",
		Goal = "Revive a tagged guest before they fade away.",
		Moves = {
			"Hold E beside a dazed guest to revive them",
			"They saw who tagged them, so listen closely",
		},
	},
	Guest = {
		Id = "Guest",
		Name = "Guest",
		Team = "Guests",
		Color = "#FFE08A",
		Goal = "Survive. Grab candy coins and clue pages.",
		Moves = {
			"Clue pages fill the Truth Bell, which shows where the Phantom is",
			"Pick up a dropped blaster to become the Hero",
		},
	},
} :: { [string]: Role }

-- The Hero is a guest who picked up a fallen Guardian's blaster. It isn't a
-- role anyone is dealt, only a title shown on the results.
Roles.HERO_COLOR = "#7FE0FF"

-- How many of each special role a round with count players deals. Everyone
-- else is a Guest.
function Roles.counts(count: number): { [string]: number }
	return {
		Phantom = if count >= 1 then 1 else 0,
		Guardian = if count >= 2 then 1 else 0,
		Medic = if count >= 5 then 1 else 0,
		Saboteur = if count >= 7 then 1 else 0,
	}
end

-- The special roles in the order they are dealt.
Roles.DEAL_ORDER = { "Phantom", "Guardian", "Medic", "Saboteur" }

function Roles.team(roleId: string): string
	local role = Roles.List[roleId]
	return if role then role.Team else "Guests"
end

return Roles
