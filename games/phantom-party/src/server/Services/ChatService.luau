-- Proximity chat. In the lobby everyone hears everyone. In a round the
-- living hear only the living close by, so whispers in one room don't reach
-- the next, and the tagged and the out talk among themselves and the lobby
-- without giving away who tagged them (Rules/Chat). Bubbles follow the same
-- rule, because a player only gets the messages they can hear.
--
-- The VIP tag in front of a VIP's name is added on each client
-- (client/ChatTags), from the VIP attribute OutfitService sets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Game = require(Shared.Config.Game)
local Chat = require(Shared.Rules.Chat)
local Match = require(script.Parent.Parent.Lib.Match)

local ChatService = {}

local function listener(player: Player): Chat.Listener
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return {
		State = Match.chatState(player),
		Position = if root and root:IsA("BasePart") then root.Position else nil,
	}
end

-- Whether a message from one player should reach another.
function ChatService.canHear(from: Player, to: Player): boolean
	if from == to then
		return true
	end
	local range = if Match.live() then Game.Chat.RoundRange else Game.Chat.LobbyRange
	return Chat.canHear(listener(to), listener(from), range)
end

local function guard(channel: TextChannel)
	channel.ShouldDeliverCallback = function(message: TextChatMessage, target: TextSource)
		local source = message.TextSource
		if not source then
			return true
		end
		local from = Players:GetPlayerByUserId(source.UserId)
		local to = Players:GetPlayerByUserId(target.UserId)
		if not from or not to then
			return true
		end
		return ChatService.canHear(from, to)
	end
end

function ChatService.init()
	task.spawn(function()
		local channels = TextChatService:WaitForChild("TextChannels", 30)
		if not channels then
			warn("TextChatService has no channels; is the place using the legacy chat?")
			return
		end
		local general = channels:WaitForChild("RBXGeneral", 30)
		if general and general:IsA("TextChannel") then
			guard(general)
		end
	end)
end

return ChatService
