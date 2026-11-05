-- VIP touches: a gold [VIP] in front of VIP pass owners' names in chat, and
-- a gold name over their heads in the plaza (hidden in a round, where it
-- would make them easy to pick out). Looks only; who can hear whom is the
-- server's call (ChatService).

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Ui = require(script.Parent.Ui)

local ChatTags = {}

local GOLD = "#FFCD5A"

local function syncTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head then
		return
	end
	local tag = head:FindFirstChild("VipTag") :: BillboardGui?
	local wanted = player:GetAttribute("VIP") == true and character:GetAttribute("Pid") == nil
	if not wanted then
		if tag then
			tag:Destroy()
		end
		return
	end
	if tag then
		return
	end
	local board = Ui.make("BillboardGui", {
		Name = "VipTag",
		Size = UDim2.fromOffset(160, 26),
		StudsOffset = Vector3.new(0, 2.6, 0),
		MaxDistance = 80,
		LightInfluence = 0,
	}, head)
	Ui.label(board, `★ {player.DisplayName}`, {
		Size = UDim2.fromScale(1, 1),
		Font = Ui.Title,
		TextSize = 18,
		TextColor3 = Ui.Colors.Gold,
		TextStrokeTransparency = 0.3,
	})
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("VIP"):Connect(function()
		syncTag(player)
	end)
	local function onCharacter(character: Model)
		character:GetAttributeChangedSignal("Pid"):Connect(function()
			syncTag(player)
		end)
		character:WaitForChild("Head", 10)
		syncTag(player)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

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
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return ChatTags
