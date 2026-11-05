-- The server's side of the remotes in ReplicatedStorage.Remotes: short ways
-- to tell players things (a corner-card notice, an effect to play, a menu to
-- open), so every service says them the same way.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage.Remotes

local Net = {}

function Net.remote(name: string): RemoteEvent
	return Remotes:WaitForChild(name) :: RemoteEvent
end

-- A short message on the player's corner card. kind picks its colour:
-- "Info", "Good", "Bad" or "Big" (a banner across the top for the whole
-- team, such as nightfall).
function Net.notice(player: Player?, text: string, kind: string?)
	local remote = Net.remote("Notice")
	if player then
		remote:FireClient(player, text, kind or "Info")
	else
		remote:FireAllClients(text, kind or "Info")
	end
end

-- An effect for every client to play (or just one player's, with only).
function Net.fx(kind: string, data: { [string]: any }, only: Player?)
	local remote = Net.remote("Fx")
	if only then
		remote:FireClient(only, kind, data)
	else
		remote:FireAllClients(kind, data)
	end
end

-- Opens one of the client's menus ("Workbench", "Cook", "Roles").
function Net.open(player: Player, menu: string)
	Net.remote("Open"):FireClient(player, menu)
end

-- The player's character root, if they have a character in the world.
function Net.root(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root :: BasePart?
end

-- Whether the player stands within range studs of a point.
function Net.near(player: Player, point: Vector3, range: number): boolean
	local root = Net.root(player)
	return root ~= nil and (root.Position - point).Magnitude <= range
end

function Net.players(): { Player }
	return Players:GetPlayers()
end

return Net
