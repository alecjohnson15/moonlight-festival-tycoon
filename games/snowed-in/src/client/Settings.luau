-- The player's settings: music and wind on or off, how loud the effects
-- are, and reduced motion (no camera shake, fewer particles, gentler
-- flashes) for anyone who finds the screen too busy. They are saved with
-- the player's profile: changes go to the server (the "Settings" remote,
-- checked by shared/Profile) and come back in the profile summary.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = {}

export type Values = { Music: boolean, Sfx: number, ReduceMotion: boolean }

local current: Values = { Music = true, Sfx = 1, ReduceMotion = false }
local callbacks: { (Values) -> () } = {}
local remote: RemoteEvent? = nil

local function changed()
	for _, callback in callbacks do
		task.spawn(callback, current)
	end
end

function Settings.get(): Values
	return current
end

function Settings.reduceMotion(): boolean
	return current.ReduceMotion
end

function Settings.sfx(): number
	return current.Sfx
end

-- Changes a setting here at once and asks the server to save it.
function Settings.set(key: string, value: any)
	local values = current :: any
	if values[key] == value then
		return
	end
	values[key] = value
	if remote then
		remote:FireServer(key, value)
	end
	changed()
end

-- Runs callback(values) whenever a setting changes (and once loaded).
function Settings.onChanged(callback: (Values) -> ())
	table.insert(callbacks, callback)
end

function Settings.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remote = remotes:WaitForChild("Settings") :: RemoteEvent
	remotes:WaitForChild("Profile").OnClientEvent:Connect(function(summary)
		if type(summary) ~= "table" or type(summary.Settings) ~= "table" then
			return
		end
		local saved = summary.Settings
		local next: Values = {
			Music = if type(saved.Music) == "boolean" then saved.Music else current.Music,
			Sfx = if type(saved.Sfx) == "number" then math.clamp(saved.Sfx, 0, 1) else current.Sfx,
			ReduceMotion = if type(saved.ReduceMotion) == "boolean" then saved.ReduceMotion else current.ReduceMotion,
		}
		if next.Music ~= current.Music or next.Sfx ~= current.Sfx or next.ReduceMotion ~= current.ReduceMotion then
			current = next
			changed()
		end
	end)
end

return Settings
