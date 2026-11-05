-- The round in progress, shared by the services that run it: who is in it,
-- their secret roles and states, and a few events between services. Only
-- RoundService starts and ends a round; CombatService and PickupService
-- change what happens inside it.
--
-- A participant is usually a player. In a Studio practice round the lone
-- tester plays against practice dummies, which take part the same way but
-- have no Player (their key is their model).

export type Participant = {
	Key: any,
	Player: Player?,
	-- Negative for practice dummies.
	UserId: number,
	Name: string,
	Character: Model?,
	Role: string,
	-- Alive, Dazed (tagged, revivable) or Out.
	State: string,
	-- Picked up a fallen Guardian's blaster.
	Hero: boolean,
	-- Guests this Phantom tagged who then went out.
	Tags: number,
	Revives: number,
	Clues: number,
	Coins: number,
	Takedown: boolean,
	DazedAt: number?,
	-- Nobody can tag them until then (just revived).
	ShieldUntil: number,
	-- Who tagged them, while dazed, so a tag that turns into an out counts.
	TaggedBy: Participant?,
	-- How they were last knocked down: Swing, Throw, Zap or Misfire.
	LastHow: string?,
}

local Match = {}

-- Waiting, Intermission, Reveal, Playing or Results.
Match.State = "Waiting"
-- os.clock() time the current state ends, or 0.
Match.EndsAt = 0
-- Workspace:GetServerTimeNow() time the current state ends, for clients.
Match.EndsAtServer = 0
Match.Practice = false
Match.Map = nil :: Model?
Match.MapId = nil :: string?
-- os.clock() time Playing began.
Match.PlayingSince = 0
Match.Participants = {} :: { [any]: Participant }

local listeners: { [string]: { (...any) -> () } } = {}

-- Runs callback(...) whenever event fires. Events:
--   Down(participant, by): tagged or zapped, now Dazed (guests) or Out.
--   Out(participant): out of the round for good.
--   Revived(participant, medic)
--   State(state): the round moved on.
function Match.on(event: string, callback: (...any) -> ())
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], callback)
end

function Match.fire(event: string, ...: any)
	for _, callback in listeners[event] or {} do
		task.spawn(callback, ...)
	end
end

function Match.setState(state: string, seconds: number?, serverNow: number?)
	Match.State = state
	if seconds then
		Match.EndsAt = os.clock() + seconds
		Match.EndsAtServer = (serverNow or 0) + seconds
	else
		Match.EndsAt = 0
		Match.EndsAtServer = 0
	end
	Match.fire("State", state)
end

-- Whether a round is under way (players are in the map).
function Match.live(): boolean
	return Match.State == "Reveal" or Match.State == "Playing"
end

function Match.reset()
	Match.Participants = {}
	Match.Map = nil
	Match.MapId = nil
	Match.Practice = false
end

function Match.add(
	key: any,
	info: { Player: Player?, UserId: number, Name: string, Character: Model?, Role: string }
): Participant
	local participant: Participant = {
		Key = key,
		Player = info.Player,
		UserId = info.UserId,
		Name = info.Name,
		Character = info.Character,
		Role = info.Role,
		State = "Alive",
		Hero = false,
		Tags = 0,
		Revives = 0,
		Clues = 0,
		Coins = 0,
		Takedown = false,
		DazedAt = nil,
		ShieldUntil = 0,
		TaggedBy = nil,
		LastHow = nil,
	}
	Match.Participants[key] = participant
	return participant
end

-- The participant for a Player or a dummy's model.
function Match.get(key: any): Participant?
	return Match.Participants[key]
end

function Match.byCharacter(character: Instance?): Participant?
	if not character then
		return nil
	end
	for _, participant in Match.Participants do
		if participant.Character == character then
			return participant
		end
	end
	return nil
end

function Match.byUserId(userId: number): Participant?
	for _, participant in Match.Participants do
		if participant.UserId == userId then
			return participant
		end
	end
	return nil
end

function Match.withRole(roleId: string): Participant?
	for _, participant in Match.Participants do
		if participant.Role == roleId then
			return participant
		end
	end
	return nil
end

-- What Rules/Round needs: each participant's role and state.
function Match.entries(): { [any]: { Role: string, State: string } }
	local entries = {}
	for key, participant in Match.Participants do
		entries[key] = { Role = participant.Role, State = participant.State }
	end
	return entries
end

-- Where a player stands for chat (Rules/Chat): Lobby when they're not in a
-- live round, otherwise their state in it.
function Match.chatState(player: Player): string
	if not Match.live() then
		return "Lobby"
	end
	local participant = Match.Participants[player]
	return if participant then participant.State else "Lobby"
end

-- The root part of a participant's character, if they have one in the world.
function Match.root(participant: Participant): BasePart?
	local character = participant.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

return Match
