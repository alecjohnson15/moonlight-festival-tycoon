--!strict
-- Runs code for every player and every character, including any that are
-- already in the game when a service starts (which happens in Studio).

local Players = game:GetService("Players")

local PlayerHooks = {}

-- Calls callback(player) for each player now and each one who joins.
function PlayerHooks.eachPlayer(callback: (Player) -> ())
	Players.PlayerAdded:Connect(callback)
	for _, player in Players:GetPlayers() do
		task.spawn(callback, player)
	end
end

-- Calls callback(player, character) for each character as it spawns.
function PlayerHooks.eachCharacter(callback: (Player, Model) -> ())
	PlayerHooks.eachPlayer(function(player)
		player.CharacterAdded:Connect(function(character)
			callback(player, character)
		end)
		if player.Character then
			task.spawn(callback, player, player.Character)
		end
	end)
end

return PlayerHooks
