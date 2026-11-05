-- Chat name tags: a gold [VIP] in front of the names of VIP pass owners.
-- It only changes how a name looks; who can hear whom is the server's call
-- (ChatService).

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTags = {}

local GOLD = "#FFCD5A"

function ChatTags.start()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute("VIP") == true then
			properties.PrefixText = `<font color="{GOLD}">[VIP]</font> {message.PrefixText}`
		end
		return properties
	end
end

return ChatTags
