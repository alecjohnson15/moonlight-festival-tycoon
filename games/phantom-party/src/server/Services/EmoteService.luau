-- Emotes from the emote wheel. Dances and gestures play on the emoting
-- player's own client (animations replicate on their own); this service
-- checks the rest and passes bubbles, suspicions and party effects to the
-- players who'd see them. In a round that's the same people who'd hear the
-- player speak (ChatService), and only a player still standing can emote,
-- so the tagged can't point out who tagged them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Emotes = require(ReplicatedStorage.Shared.Config.Emotes)
local Match = require(script.Parent.Parent.Lib.Match)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local ChatService = require(script.Parent.ChatService)
local PurchaseService = require(script.Parent.PurchaseService)

local EmoteRemote = ReplicatedStorage.Remotes.Emote :: RemoteEvent

local EmoteService = {}

local limiter = RateLimiter.new(Emotes.Cooldown)

local function onEmote(player: Player, emoteId: unknown, targetId: unknown)
	if typeof(emoteId) ~= "string" then
		return
	end
	local emote = Emotes.get(emoteId)
	if not emote or not player.Character then
		return
	end
	if emote.Pass and not PurchaseService.hasPerk(player, "Emotes") then
		return
	end
	local state = Match.chatState(player)
	if state == "Dazed" or (state == "Out" and Match.live()) then
		return
	end
	if not limiter:allow(player) then
		return
	end
	local target: Player? = nil
	if emote.Target then
		target = typeof(targetId) == "number" and Players:GetPlayerByUserId(targetId) or nil
		if not target or target == player then
			return
		end
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and ChatService.canHear(player, other) then
			EmoteRemote:FireClient(other, player, emote.Id, target)
		end
	end
end

function EmoteService.init()
	EmoteRemote.OnServerEvent:Connect(onEmote)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return EmoteService
