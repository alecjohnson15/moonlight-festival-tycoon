-- What this client knows, in one place: the player's profile (coins, items,
-- pass), the round (its state, the clock, the vote), and, during a round,
-- the player's own secret role and kit. Screens read it and listen for
-- changes by name: Profile, Round, Vote, Role, Kit, Me, Bell, Census,
-- Results, Pay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProfileRemote = Remotes:WaitForChild("Profile") :: RemoteEvent
local RoundRemote = Remotes:WaitForChild("Round") :: RemoteEvent
local Request = Remotes:WaitForChild("Request") :: RemoteFunction

local State = {}

State.Profile = nil :: { [string]: any }?
State.Round = { State = "Waiting", EndsAt = 0, Map = nil, MapName = nil, Practice = false, InRound = false }
State.Vote = { Choices = {}, Counts = {}, EndsAt = 0 }
State.Role = nil :: string?
State.Allies = {} :: { { Name: string, Role: string } }
State.Guests = {} :: { { UserId: number, Name: string } }
State.Kit = {} :: { [string]: any }
-- This player in the round: Lobby, Alive, Dazed or Out.
State.Me = "Lobby"
State.Bell = { Value = 0, Room = nil :: string? }
State.Census = { Alive = 0, Dazed = 0, Out = 0, Total = 0 }
State.Results = nil :: { [string]: any }?
State.Pay = nil :: { [string]: any }?

local listeners: { [string]: { (...any) -> () } } = {}

function State.on(name: string, callback: (...any) -> ())
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], callback)
end

function State.fire(name: string, ...: any)
	for _, callback in listeners[name] or {} do
		task.spawn(callback, ...)
	end
end

function State.now(): number
	return Workspace:GetServerTimeNow()
end

-- Seconds left until a server time.
function State.left(at: number): number
	return math.max(0, at - State.now())
end

function State.request(action: string, ...: any): { [string]: any }
	local ok, result = pcall(Request.InvokeServer, Request, action, ...)
	if ok and typeof(result) == "table" then
		return result
	end
	return { Ok = false, Error = "Failed" }
end

-- Whether this player is in the round going on, still standing.
function State.playing(): boolean
	return State.Round.InRound and State.Me == "Alive" and State.Round.State == "Playing"
end

local handlers = {}

function handlers.State(message)
	local wasLive = State.Round.State == "Reveal" or State.Round.State == "Playing"
	State.Round = {
		State = message.State,
		EndsAt = message.EndsAt or 0,
		Map = message.Map,
		MapName = message.MapName,
		Practice = message.Practice,
		InRound = message.InRound,
	}
	if message.State == "Waiting" or message.State == "Intermission" then
		State.Role = nil
		State.Allies = {}
		State.Kit = {}
		State.Me = "Lobby"
		State.Bell = { Value = 0, Room = nil }
		State.fire("Role")
		State.fire("Kit")
		State.fire("Me")
	elseif message.State == "Playing" and message.InRound and not wasLive then
		State.Me = "Alive"
	end
	State.fire("Round")
end

function handlers.Vote(message)
	State.Vote = { Choices = message.Choices, Counts = message.Counts, EndsAt = message.EndsAt }
	State.fire("Vote")
end

function handlers.Role(message)
	State.Role = message.Role
	State.Allies = message.Allies or {}
	State.Guests = message.Guests or {}
	State.Me = "Alive"
	State.Bell = { Value = 0, Room = nil }
	State.fire("Role", message)
	State.fire("Me")
end

function handlers.Kit(message)
	State.Kit = message
	State.fire("Kit")
end

function handlers.You(message)
	State.Me = message.State
	State.fire("Me", message)
end

function handlers.Bell(message)
	State.Bell = { Value = message.Value, Room = message.Room }
	State.fire("Bell")
end

function handlers.Census(message)
	State.Census = message
	State.fire("Census")
end

function handlers.Final()
	State.fire("Final")
end

function handlers.Results(message)
	State.Results = message
	State.fire("Results", message)
end

function handlers.Pay(message)
	State.Pay = message
	State.fire("Pay", message)
end

function State.start()
	ProfileRemote.OnClientEvent:Connect(function(snapshot)
		State.Profile = snapshot
		State.fire("Profile")
	end)
	RoundRemote.OnClientEvent:Connect(function(message)
		local handler = typeof(message) == "table" and handlers[message.Kind]
		if handler then
			handler(message)
		end
	end)
	task.spawn(function()
		local snapshot = State.request("Snapshot")
		if snapshot and snapshot.Coins then
			State.Profile = snapshot
			State.fire("Profile")
		end
		State.request("RoundState")
	end)
end

return State
