--!strict
-- The plaza's wisp hunt, the pure part. While a round is on, glowing wisps
-- float round the plaza for anyone not standing in the round (out, sitting
-- out, or just joined) to catch. Every Goal caught together lights the
-- plaza's moon and sets off fireworks. It pays nothing and can't reach the
-- round, so it can't be farmed and can't tell the living anything.

local Wisps = {}

-- Wisps caught together for each show.
Wisps.Goal = 8
-- Wisps out at once, and seconds before a caught one comes back.
Wisps.Out = 3
Wisps.Respawn = { 4, 8 }

-- Whether a player in this chat state (Match.chatState) may catch wisps:
-- only those not standing in a round.
function Wisps.canCatch(chatState: string): boolean
	return chatState == "Lobby" or chatState == "Out"
end

-- Adds a catch to the plaza's count. Returns the new count and whether it
-- reached the goal (the count then starts again).
function Wisps.add(count: number, goal: number?): (number, boolean)
	local target = goal or Wisps.Goal
	local after = count + 1
	if after >= target then
		return 0, true
	end
	return after, false
end

return Wisps
