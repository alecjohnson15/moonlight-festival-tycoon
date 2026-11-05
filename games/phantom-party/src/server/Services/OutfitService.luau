-- Puts each player's outfit on their character: their party mask, and the
-- trail behind them when they run. Blades and blasters are only handed out
-- in a round, by CombatService. Also marks VIP holders, so the chat shows
-- their tag and the lounge's velvet rope lets them through.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = require(ReplicatedStorage.Shared.Look.Gear)
local ProfileService = require(script.Parent.ProfileService)
local PurchaseService = require(script.Parent.PurchaseService)

local OutfitService = {}

OutfitService.VIP_GROUP = "Vip"
OutfitService.GATE_GROUP = "VipGate"

local TRAIL_TAG = "OutfitTrail"

local function clear(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and child.Name == "PartyMask" then
			child:Destroy()
		end
	end
	for _, item in character:GetDescendants() do
		if item:HasTag(TRAIL_TAG) then
			item:Destroy()
		end
	end
end

local function setGroup(character: Model, group: string)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

-- Dresses a character in an outfit (kind to item id). Used for players and
-- for practice dummies.
function OutfitService.dress(character: Model, outfit: { [string]: string })
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	clear(character)
	local ok, err = pcall(function()
		humanoid:AddAccessory(Gear.mask(outfit.Mask))
	end)
	if not ok then
		warn(`Couldn't put on mask {outfit.Mask}: {err}`)
	end
	for _, made in Gear.trail(outfit.Trail, root) do
		made:AddTag(TRAIL_TAG)
	end
end

local function apply(player: Player)
	local character = player.Character
	if not character then
		return
	end
	OutfitService.dress(character, ProfileService.outfit(player))
	local vip = PurchaseService.hasPerk(player, "VIP")
	player:SetAttribute("VIP", vip)
	setGroup(character, if vip then OutfitService.VIP_GROUP else "Default")
end

local function onCharacter(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("Head", 10)
	if player.Character ~= character then
		return
	end
	apply(player)
	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") and player:GetAttribute("VIP") then
			part.CollisionGroup = OutfitService.VIP_GROUP
		end
	end)
end

function OutfitService.init()
	PhysicsService:RegisterCollisionGroup(OutfitService.VIP_GROUP)
	PhysicsService:RegisterCollisionGroup(OutfitService.GATE_GROUP)
	PhysicsService:CollisionGroupSetCollidable(OutfitService.VIP_GROUP, OutfitService.GATE_GROUP, false)
	ProfileService.onOutfit(apply)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return OutfitService
