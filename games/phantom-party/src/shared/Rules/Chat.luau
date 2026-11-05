--!strict
-- Who hears whom in text chat. Spectators hear everyone; the living hear
-- only the living, and only those close by, so a tagged player can't tell
-- the room who tagged them (unless a Medic brings them back) and whispers
-- in one room don't reach the next. States: Lobby, Alive, Dazed, Out.

local Chat = {}

export type Listener = { State: string, Position: Vector3? }

function Chat.canHear(listener: Listener, speaker: Listener, range: number): boolean
	if speaker.State == "Alive" then
		if listener.State ~= "Alive" then
			return true
		end
		if range == math.huge then
			return true
		end
		local a, b = listener.Position, speaker.Position
		if not a or not b then
			return false
		end
		return (a - b).Magnitude <= range
	end
	return listener.State ~= "Alive"
end

return Chat
