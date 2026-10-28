-- Dresses each player in the cosmetics they own and have chosen, saves those
-- choices, and puts new items on as they are earned or bought, so everyone on
-- the server can see how far a player has got.
--
-- Head and back items are welded onto the character, and auras and trails go
-- on its root part. All of it is made here, so it shows for everyone. The held
-- item is a Tool in the player's backpack, carrying a Weapon attribute when it
-- is one. Pets are drawn by each client from the WearPet attribute (see
-- client/Pets), the way plot activity is.
--
-- A client only names the slot and the item it wants; the server checks it is
-- owned. Paid items are checked through PurchaseService, and nothing here
-- touches coins.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Cosmetics = require(Shared.Config.Cosmetics)
local Theme = require(Shared.Config.Theme)
local Wardrobe = require(Shared.Wardrobe)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local DataService = require(script.Parent.DataService)
local PurchaseService = require(script.Parent.PurchaseService)

local EquipCosmetic = ReplicatedStorage.Remotes.EquipCosmetic :: RemoteEvent
local CosmeticSwung = ReplicatedStorage.Remotes.CosmeticSwung :: RemoteEvent

-- Arena stats for each weapon, kept by the PvP arena. Swings here are paced by
-- the same cooldown so what players see matches what hits.
local weaponsModule = Shared.Config:FindFirstChild("Weapons")
local Weapons = if weaponsModule then require(weaponsModule) :: any else {}

-- In Studio every paid item counts as owned, so they can be tried on before
-- any game pass exists. Live servers never do this.
local STUDIO_PREVIEW = RunService:IsStudio()
local DEFAULT_SWING_SECONDS = 0.5
local TRAIL_HEIGHT = 1.1
local CHARACTER_WAIT_SECONDS = 10

local HEADWEAR = {
	[Enum.AccessoryType.Hat] = true,
	[Enum.AccessoryType.Hair] = true,
	[Enum.AccessoryType.Face] = true,
}

type Outfit = {
	Character: Model,
	Ids: { [string]: string },
	Made: { [string]: { Instance } },
}

local CosmeticService = {}

-- Everything each player owns, once their save and game passes are in.
local have: { [Player]: { [string]: boolean } } = {}
local outfits: { [Player]: Outfit } = {}
local lastSwing: { [Player]: number } = {}
local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local equipLimiter = RateLimiter.new(0.3)

local function ownsPremium(player: Player): (string) -> boolean
	return function(id: string): boolean
		return STUDIO_PREVIEW or PurchaseService.owns(player, id)
	end
end

local function holderName(slot: string): string
	return `Cosmetic{slot}`
end

-- Unanchors every part of a model built at the origin and welds it to part,
-- with the model's origin at offset in part's space.
local function weld(model: Model, part: BasePart, offset: CFrame)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local joint = Instance.new("Weld")
			joint.Part0 = part
			joint.Part1 = descendant
			joint.C0 = offset * descendant.CFrame
			joint.Parent = descendant
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanQuery = false
		end
	end
end

-- Hides a part or decal, remembering how see-through it was, or puts it back.
local function setHidden(instance: BasePart | Decal, hidden: boolean)
	local original = instance:GetAttribute("WardrobeHidden")
	if hidden and original == nil then
		instance:SetAttribute("WardrobeHidden", instance.Transparency)
		instance.Transparency = 1
	elseif not hidden and original ~= nil then
		instance.Transparency = original
		instance:SetAttribute("WardrobeHidden", nil)
	end
end

-- Hides the wearer's head, face, hats and hair under something like the
-- pumpkin head, or shows them again.
local function hideHead(character: Model, hidden: boolean)
	character:SetAttribute("WardrobeHidesHead", if hidden then true else nil)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		setHidden(head, hidden)
		for _, child in head:GetChildren() do
			if child:IsA("Decal") then
				setHidden(child, hidden)
			end
		end
	end
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and HEADWEAR[child.AccessoryType] then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				setHidden(handle, hidden)
			end
		end
	end
end

local function findAttachment(character: Model, name: string): Attachment?
	local found = character:FindFirstChild(name, true)
	if found and found:IsA("Attachment") and found.Parent and found.Parent:IsA("BasePart") then
		return found
	end
	return nil
end

local function makeTool(cosmetic: Wardrobe.Cosmetic, entry: any): Tool
	local names = Theme.Cosmetics[cosmetic.Id]
	local tool = Instance.new("Tool")
	tool.Name = names.DisplayName
	tool.ToolTip = names.Blurb
	tool.CanBeDropped = false
	tool.Grip = CFrame.new()
	tool:SetAttribute("Cosmetic", cosmetic.Id)
	if cosmetic.Weapon then
		tool:SetAttribute("Weapon", cosmetic.Weapon)
	end

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	local model = entry.Build()
	weld(model, handle, CFrame.new())
	model.Parent = tool
	return tool
end

-- Where the ground is, below the character's root part.
local function groundBelow(character: Model, root: BasePart): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
		return -root.Size.Y / 2 - 2
	end
	return -root.Size.Y / 2 - (if humanoid then humanoid.HipHeight else 2)
end

local function putOn(player: Player, character: Model, slot: string, id: string): { Instance }
	local cosmetic = Wardrobe.find(Cosmetics, id) :: Wardrobe.Cosmetic
	local entry = Theme.Wearables[id]
	if not entry then
		warn(`The theme has no look for cosmetic {id}`)
		return {}
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if slot == "Head" or slot == "Back" then
		local attachment = findAttachment(character, entry.Attach)
		if not attachment then
			return {}
		end
		local model = entry.Build()
		model.Name = holderName(slot)
		weld(model, attachment.Parent :: BasePart, CFrame.new(attachment.Position))
		model.Parent = character
		if entry.HidesHead then
			hideHead(character, true)
		end
		return { model }
	elseif slot == "Hand" then
		local backpack = player:FindFirstChildOfClass("Backpack")
		if not backpack then
			return {}
		end
		local tool = makeTool(cosmetic, entry)
		tool.Parent = backpack
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and not character:FindFirstChildOfClass("Tool") then
			humanoid:EquipTool(tool)
		end
		return { tool }
	elseif slot == "Aura" and root then
		local attachment = Instance.new("Attachment")
		attachment.Name = holderName(slot)
		attachment.Parent = root
		entry.Build(attachment)
		return { attachment }
	elseif slot == "Trail" and root then
		local ground = groundBelow(character, root)
		local top = Instance.new("Attachment")
		top.Name = holderName(slot) .. "Top"
		top.Position = Vector3.new(0, ground + 0.2 + TRAIL_HEIGHT, 0)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = holderName(slot) .. "Bottom"
		bottom.Position = Vector3.new(0, ground + 0.2, 0)
		bottom.Parent = root
		entry.Build(top, bottom)
		return { top, bottom }
	end
	-- Pets are drawn on each client.
	return {}
end

local function takeOff(outfit: Outfit, slot: string)
	for _, instance in outfit.Made[slot] or {} do
		instance:Destroy()
	end
	outfit.Made[slot] = nil
	if slot == "Head" and outfit.Character:GetAttribute("WardrobeHidesHead") then
		hideHead(outfit.Character, false)
	end
end

-- Builds whatever has changed on the player's character since last time.
local function dress(player: Player)
	local data = DataService.get(player)
	local owned = have[player]
	local character = player.Character
	if not data or not owned or not character or not character.Parent then
		return
	end

	local outfit = outfits[player]
	if not outfit or outfit.Character ~= character then
		if outfit then
			for slot in outfit.Made do
				takeOff(outfit, slot)
			end
		end
		outfit = { Character = character, Ids = {}, Made = {} }
		outfits[player] = outfit
	end

	local worn = Wardrobe.worn(Cosmetics, data.Equipped, owned)
	for _, slot in Wardrobe.SLOTS do
		local id = worn[slot]
		if outfit.Ids[slot] ~= id then
			takeOff(outfit, slot)
			outfit.Ids[slot] = id
			if id then
				outfit.Made[slot] = putOn(player, character, slot, id)
			end
		end
	end
end

-- Tells every client what the player owns and wears, through attributes.
local function publish(player: Player)
	local data = DataService.get(player)
	local owned = have[player]
	if not data or not owned then
		return
	end
	player:SetAttribute("Wardrobe", Wardrobe.encode(Cosmetics, owned))
	local worn = Wardrobe.worn(Cosmetics, data.Equipped, owned)
	for _, slot in Wardrobe.SLOTS do
		player:SetAttribute(`Wear{slot}`, worn[slot])
	end
end

-- Starts tracking a player once their save has loaded and their game passes
-- have been checked. What they own then isn't new, so nothing is put on.
local function begin(player: Player)
	local data = DataService.get(player)
	if have[player] or not data or not PurchaseService.ready(player) then
		return
	end
	have[player] = Wardrobe.owned(Cosmetics, data.Owned, Balance.Upgrades, ownsPremium(player))
	publish(player)
	dress(player)
end

-- Works out what the player owns again, after a purchase or an upgrade, and
-- puts on anything new.
function CosmeticService.refresh(player: Player)
	local data = DataService.get(player)
	local before = have[player]
	if not data or not before then
		return
	end
	local after = Wardrobe.owned(Cosmetics, data.Owned, Balance.Upgrades, ownsPremium(player))
	have[player] = after
	Wardrobe.autoEquip(Cosmetics, data.Equipped, Wardrobe.newlyOwned(Cosmetics, before, after))
	publish(player)
	dress(player)
end

-- The equipped held item and its arena weapon, if it is one.
function CosmeticService.weaponOf(player: Player): (string?, string?)
	local data = DataService.get(player)
	local owned = have[player]
	if not data or not owned then
		return nil, nil
	end
	local id = Wardrobe.worn(Cosmetics, data.Equipped, owned).Hand
	local cosmetic = id and Wardrobe.find(Cosmetics, id)
	return id, cosmetic and cosmetic.Weapon
end

local function swingSeconds(weapon: string): number
	local stats = Weapons[weapon]
	if type(stats) == "table" and type(stats.Cooldown) == "number" then
		return stats.Cooldown
	end
	return DEFAULT_SWING_SECONDS
end

-- A held weapon was clicked: play the tool's swing animation, and have every
-- client play the sound and the puff where it lands. Works for any Tool with
-- a Weapon attribute, including ones the arena hands out.
local function onSwing(player: Player, tool: Tool)
	local weapon = tool:GetAttribute("Weapon")
	if tool.Parent ~= player.Character or type(weapon) ~= "string" then
		return
	end
	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < swingSeconds(weapon) then
		return
	end
	lastSwing[player] = now

	local entry = Theme.Wearables[tool:GetAttribute("Cosmetic") or ""]
	local animation = Instance.new("StringValue")
	animation.Name = "toolanim"
	animation.Value = if entry and entry.Swing then entry.Swing.Anim else "Slash"
	animation.Parent = tool
	Debris:AddItem(animation, 1)
	CosmeticSwung:FireAllClients(player, tool)
end

local function onCharacter(player: Player, character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("Weapon") ~= nil and not hooked[child] then
			hooked[child] = true
			child.Activated:Connect(function()
				onSwing(player, child)
			end)
		elseif child:IsA("Accessory") and character:GetAttribute("WardrobeHidesHead") then
			task.defer(hideHead, character, true)
		end
	end)
	if character:WaitForChild("HumanoidRootPart", CHARACTER_WAIT_SECONDS) then
		dress(player)
	end
end

local function onEquip(player: Player, slot: unknown, id: unknown)
	if typeof(slot) ~= "string" or (id ~= nil and typeof(id) ~= "string") or not equipLimiter:allow(player) then
		return
	end
	local data = DataService.get(player)
	local owned = have[player]
	if not data or not owned or not table.find(Wardrobe.SLOTS, slot) then
		return
	end
	if id == nil then
		data.Equipped[slot] = nil
	elseif Wardrobe.canEquip(Cosmetics, owned, slot, id :: string) then
		data.Equipped[slot] = id :: string
	else
		return
	end
	publish(player)
	dress(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

function CosmeticService.init()
	if STUDIO_PREVIEW then
		print("Studio: every paid cosmetic counts as owned, for trying them on. Live servers never do this.")
	end
	EquipCosmetic.OnServerEvent:Connect(onEquip)
	DataService.onLoaded(begin)
	PurchaseService.onOwnershipChanged(function(player, itemId)
		if itemId then
			CosmeticService.refresh(player)
		else
			begin(player)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		have[player] = nil
		outfits[player] = nil
		lastSwing[player] = nil
		equipLimiter:forget(player)
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CosmeticService
