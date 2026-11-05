-- What this client knows: the player's profile (sent by the server whenever
-- it changes) and the round (RoundState attributes). Other client modules
-- read it here and listen for changes, and use the same ownership rules as
-- the server to show what's locked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Wardrobe = require(Config.Wardrobe)
local Poses = require(Config.Poses)
local Entrances = require(Config.Entrances)
local Themes = require(Config.Themes)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RoundState = ReplicatedStorage:WaitForChild("RoundState")

local State = {}

State.Profile = nil :: any

local profileCallbacks: { (any) -> () } = {}
local roundCallbacks: { (string) -> () } = {}

local KINDS = {
	Piece = { Config = Wardrobe, Owned = "Pieces" },
	Pose = { Config = Poses, Owned = "Poses" },
	Entrance = { Config = Entrances, Owned = "Entrances" },
}

-- Calls callback(profile) now (if known) and whenever it changes.
function State.onProfile(callback: (any) -> ())
	table.insert(profileCallbacks, callback)
	if State.Profile then
		task.spawn(callback, State.Profile)
	end
end

-- Calls callback(attributeName) whenever the round changes.
function State.onRound(callback: (string) -> ())
	table.insert(roundCallbacks, callback)
end

function State.round(name: string): any
	return RoundState:GetAttribute(name)
end

function State.phase(): string
	return RoundState:GetAttribute("Phase") or "Waiting"
end

function State.now(): number
	return Workspace:GetServerTimeNow()
end

function State.timeLeft(): number
	local endsAt = RoundState:GetAttribute("EndsAt") or 0
	return math.max(0, endsAt - State.now())
end

function State.theme(): any
	local id = RoundState:GetAttribute("Theme")
	return if type(id) == "string" and id ~= "" then Themes.get(id) else nil
end

function State.hasPass(passId: string): boolean
	local profile = State.Profile
	return profile ~= nil and profile.Passes ~= nil and profile.Passes[passId] == true
end

function State.item(kind: string, id: string): any
	local info = KINDS[kind]
	return info and info.Config.get(id)
end

-- Whether the player may use an item, by the server's rules.
function State.owns(kind: string, id: string): boolean
	local item = State.item(kind, id)
	local profile = State.Profile
	if not item then
		return false
	end
	if profile and profile.Owned and profile.Owned[KINDS[kind].Owned][id] then
		return true
	end
	if item.Pass then
		return State.hasPass(item.Pass)
	end
	return item.Price == 0 and item.Season == nil
end

function State.sparkles(): number
	return if State.Profile then State.Profile.Sparkles else 0
end

function State.start()
	(Remotes:WaitForChild("Profile") :: RemoteEvent).OnClientEvent:Connect(function(profile)
		State.Profile = profile
		for _, callback in profileCallbacks do
			task.spawn(callback, profile)
		end
	end)
	RoundState.AttributeChanged:Connect(function(name)
		for _, callback in roundCallbacks do
			task.spawn(callback, name)
		end
	end)
end

return State
