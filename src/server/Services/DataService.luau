-- Loads and saves each player's progress. A session lock stored next to the
-- save stops two servers writing the same player at once, and saveNow lets a
-- purchase be confirmed only after its grant is written.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Lib = script.Parent.Parent.Lib
local Migrations = require(Lib.Migrations)
local SessionLock = require(Lib.SessionLock)

local STORE_NAME = "PlayerSaves"
local AUTOSAVE_SECONDS = 60
local LOAD_ATTEMPTS = 6
local LOAD_RETRY_SECONDS = 5
local WRITE_ATTEMPTS = 3
local SHUTDOWN_SECONDS = 25

local KICK_MESSAGES = {
	Locked = "Your festival is still saving on another server. Please rejoin in a minute.",
	FutureVersion = "This server is running an older version of the game. Please rejoin.",
	Unavailable = "We couldn't load your festival right now. Please rejoin.",
	LostLock = "Your festival was opened on another server. Please rejoin.",
}

type Session = {
	Key: string,
	Data: Migrations.Save,
	Released: boolean,
}

local DataService = {}

-- nil only in Studio without API access, or after keepInMemory, where
-- progress lives in memory.
local store: DataStore? = nil
local memoryOnly = false
local sessions: { [Player]: Session } = {}
local loadedCallbacks: { (Player, Migrations.Save) -> () } = {}

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

-- UpdateAsync with retries. Roblox may run the transform more than once, so
-- transforms here only read their argument and set locals; they never yield.
local function update(key: string, transform: (any) -> any): boolean
	local dataStore = store :: DataStore
	for attempt = 1, WRITE_ATTEMPTS do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key, transform)
		end)
		if ok then
			return true
		end
		warn(`DataStore update for {key} failed (attempt {attempt}): {err}`)
		if attempt < WRITE_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
	return false
end

local function releaseLock(key: string)
	update(key, function(record)
		if record and SessionLock.isHeldBy(record.Lock, game.JobId) then
			record.Lock = nil
			return record
		end
		return nil
	end)
end

local function newSave(): Migrations.Save
	local data = Migrations.new()
	data.Coins = Balance.StartingCoins
	return data
end

local function load(player: Player): (Migrations.Save?, string?)
	if not store then
		return newSave(), nil
	end

	local key = keyFor(player)
	for attempt = 1, LOAD_ATTEMPTS do
		local outcome: string? = nil
		local stored: any = nil
		local ok = update(key, function(record)
			record = record or {}
			if Migrations.isFuture(record.Data) then
				outcome = "FutureVersion"
				return nil
			end
			local decision = SessionLock.decide(record.Lock, game.JobId, os.time())
			outcome = decision
			if decision == "Wait" then
				return nil
			end
			stored = record.Data
			record.Lock = SessionLock.new(game.JobId, os.time())
			return record
		end)

		if not ok then
			return nil, "Unavailable"
		elseif outcome == "FutureVersion" then
			return nil, "FutureVersion"
		elseif outcome ~= "Wait" then
			if outcome == "Steal" then
				warn(`Took over a stale session lock for {player.UserId}`)
			end
			if stored == nil then
				return newSave(), nil
			end
			local data, err = Migrations.run(stored)
			if not data then
				warn(`Could not migrate save for {player.UserId}: {err}`)
				releaseLock(key)
				return nil, "Unavailable"
			end
			return data, nil
		end

		if not player.Parent then
			return nil, "Left"
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(LOAD_RETRY_SECONDS)
		end
	end
	return nil, "Locked"
end

-- Writes the session's data. With release, also gives up the lock so the
-- player can load on another server straight away.
local function save(player: Player, session: Session, release: boolean): boolean
	if not store then
		return true
	end

	local lostLock = false
	local ok = update(session.Key, function(record)
		record = record or {}
		lostLock = not SessionLock.isHeldBy(record.Lock, game.JobId)
		if lostLock then
			return nil
		end
		record.Data = session.Data
		record.Lock = if release then nil else SessionLock.new(game.JobId, os.time())
		return record
	end)

	if lostLock then
		-- After our own release this is just a late autosave; otherwise another
		-- server took the save and this copy must stop writing.
		if not session.Released then
			warn(`Lost session lock for {player.UserId}; this server stops saving them`)
			session.Released = true
			sessions[player] = nil
			player:Kick(KICK_MESSAGES.LostLock)
		end
		return false
	end
	return ok
end

local function onPlayerAdded(player: Player)
	local data, err = load(player)
	if not data then
		if err ~= "Left" then
			player:Kick(KICK_MESSAGES[err :: string] or KICK_MESSAGES.Unavailable)
		end
		return
	end

	local session: Session = { Key = keyFor(player), Data = data, Released = false }
	if not player.Parent then
		-- Left while the save was loading: hand the lock straight back.
		session.Released = true
		save(player, session, true)
		return
	end

	sessions[player] = session
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	sessions[player] = nil
	if session and not session.Released then
		session.Released = true
		save(player, session, true)
	end
end

-- The player's save, or nil while it is loading or after they leave.
function DataService.get(player: Player): Migrations.Save?
	local session = sessions[player]
	return session and session.Data
end

function DataService.waitFor(player: Player, timeoutSeconds: number): Migrations.Save?
	local deadline = os.time() + timeoutSeconds
	while player.Parent and not sessions[player] and os.time() < deadline do
		task.wait(0.5)
	end
	return DataService.get(player)
end

-- Runs callback(player, data) once each player's save has loaded.
function DataService.onLoaded(callback: (Player, Migrations.Save) -> ())
	table.insert(loadedCallbacks, callback)
end

-- Saves immediately. Returns true only if the write succeeded.
function DataService.saveNow(player: Player): boolean
	local session = sessions[player]
	if not session or session.Released then
		return false
	end
	return save(player, session, false)
end

-- Keeps every save in memory, never reading or writing the DataStore. The
-- showcase build (src/showcase) calls it before init, so its maxed-out
-- saves can never reach a real one.
function DataService.keepInMemory()
	memoryOnly = true
end

function DataService.init()
	if memoryOnly then
		return
	end
	local ok, result = pcall(function()
		local candidate = DataStoreService:GetDataStore(STORE_NAME)
		if RunService:IsStudio() then
			-- Errors when Studio access to API services is turned off.
			candidate:GetAsync("studio_access_probe")
		end
		return candidate
	end)

	if ok then
		store = result
	elseif RunService:IsStudio() then
		warn(
			"DataStores are unavailable in Studio, so progress won't be saved this session. "
				.. "Turn on Game Settings > Security > Enable Studio Access to API Services to test saving."
		)
	else
		error(`Could not open the {STORE_NAME} DataStore: {result}`)
	end

	game:BindToClose(function()
		local pending = 0
		for player, session in sessions do
			if not session.Released then
				session.Released = true
				pending += 1
				task.spawn(function()
					save(player, session, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.time() + SHUTDOWN_SECONDS
		while pending > 0 and os.time() < deadline do
			task.wait()
		end
	end)
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	while true do
		task.wait(AUTOSAVE_SECONDS)
		for player, session in sessions do
			if not session.Released then
				task.spawn(save, player, session, false)
			end
		end
	end
end

return DataService
