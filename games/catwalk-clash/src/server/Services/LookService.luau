-- Puts looks on characters. A client sends the look it wants (SetLook);
-- the server cleans it (shared/Look), checks the catalog items, saves it as
-- the player's current look and dresses their character in it. Requests
-- that arrive faster than a character can be dressed are merged, so only
-- the newest is applied.
--
-- Dressing a character, step by step:
--   1. A HumanoidDescription is made: the player's own head and face (and
--      body, if they chose "Mine"), the skin colour, no shirt or pants, and
--      the catalog items they picked.
--   2. Humanoid:ApplyDescriptionAsync puts it on.
--   3. The body is painted: top, bottoms, shoes and gloves are colours and
--      finishes on the body parts themselves.
--   4. The game's own pieces (Config/Wardrobe) are built and hung on.
--
-- Rivals use the same steps on rigs the server makes (makeRig). Poses turn
-- the R15 joints and are shown to everyone because the server sets them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Game = require(Shared.Config.Game)
local Palette = require(Shared.Config.Palette)
local Poses = require(Shared.Config.Poses)
local Wardrobe = require(Shared.Config.Wardrobe)
local Look = require(Shared.Look)
local Pieces = require(Shared.Build.Pieces)
local DataService = require(script.Parent.DataService)
local ProfileService = require(script.Parent.ProfileService)
local CatalogService = require(script.Parent.CatalogService)
local PlayerHooks = require(script.Parent.Parent.Lib.PlayerHooks)

local SetLook = ReplicatedStorage.Remotes.SetLook :: RemoteEvent

local LookService = {}

local BODY_PARTS = { "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local SCALES = { "HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale" }
local ANIMATIONS = {
	"IdleAnimation",
	"WalkAnimation",
	"RunAnimation",
	"JumpAnimation",
	"FallAnimation",
	"ClimbAnimation",
	"SwimAnimation",
	"MoodAnimation",
}
local COLOR_FIELDS = { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }

local ALL_PARTS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

-- Which body parts each top and bottom style covers.
local TOP_PARTS = {
	Tee = { "UpperTorso", "LeftUpperArm", "RightUpperArm" },
	Long = { "UpperTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" },
	Tank = { "UpperTorso" },
	Suit = { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" },
}
local BOTTOM_PARTS = {
	Pants = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" },
	Shorts = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg" },
	Briefs = { "LowerTorso" },
}

export type Dressed = { Look: Look.Look, Catalog: { CatalogService.Item } }

local baseDescriptions: { [number]: HumanoidDescription | false } = {}
local current: { [Player]: Dressed } = {}
local pending: { [Player]: any } = {}
local working: { [Player]: boolean } = {}
local locked: { [Player]: boolean } = {}
local tried: { [Player]: { Catalog: { [number]: boolean }, Recolor: { [string]: boolean } } } = {}
local restC0 = setmetatable({}, { __mode = "k" }) :: { [Motor6D]: CFrame }

-- The player's own avatar, for their head, face and (if chosen) body.
local function baseFor(userId: number): HumanoidDescription?
	local known = baseDescriptions[userId]
	if known ~= nil then
		return known or nil
	end
	if userId <= 0 then
		baseDescriptions[userId] = false
		return nil
	end
	local ok, description = pcall(Players.GetHumanoidDescriptionFromUserIdAsync, Players, userId)
	if ok and description then
		baseDescriptions[userId] = description
		return description
	end
	return nil
end

local function describe(
	look: Look.Look,
	base: HumanoidDescription?,
	catalog: { CatalogService.Item }
): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	if base then
		description.Head = base.Head
		description.Face = base.Face
		for _, name in ANIMATIONS do
			(description :: any)[name] = (base :: any)[name]
		end
		if look.Body == "Mine" then
			for _, name in BODY_PARTS do
				(description :: any)[name] = (base :: any)[name]
			end
			for _, name in SCALES do
				(description :: any)[name] = (base :: any)[name]
			end
		end
	end
	local skin = Palette.skin(look.Skin)
	for _, name in COLOR_FIELDS do
		(description :: any)[name] = skin
	end
	description.Shirt = 0
	description.Pants = 0
	description.GraphicTShirt = 0
	description:SetAccessories(CatalogService.accessories(catalog), true)
	return description
end

local function paint(part: Instance?, color: Color3, finishName: string?)
	if part and part:IsA("BasePart") then
		local finish = Palette.finish(finishName)
		part.Color = color
		part.Material = finish.Material
		part.Reflectance = finish.Reflectance
	end
end

local function paintBody(character: Model, look: Look.Look)
	local skin = Palette.skin(look.Skin)
	for _, name in ALL_PARTS do
		paint(character:FindFirstChild(name), skin, "Satin")
	end
	local bottomColor = Palette.resolve(look.Bottom.C)
	for _, name in BOTTOM_PARTS[look.Bottom.S or "Pants"] or BOTTOM_PARTS.Pants do
		paint(character:FindFirstChild(name), bottomColor, look.Bottom.F)
	end
	local topColor = Palette.resolve(look.Top.C)
	for _, name in TOP_PARTS[look.Top.S or "Tee"] or TOP_PARTS.Tee do
		paint(character:FindFirstChild(name), topColor, look.Top.F)
	end
	if look.Shoes.C ~= 0 then
		local shoeColor = Palette.resolve(look.Shoes.C)
		paint(character:FindFirstChild("LeftFoot"), shoeColor, look.Shoes.F)
		paint(character:FindFirstChild("RightFoot"), shoeColor, look.Shoes.F)
	end
	if look.Gloves.C ~= 0 then
		local gloveColor = Palette.resolve(look.Gloves.C)
		paint(character:FindFirstChild("LeftHand"), gloveColor, "Satin")
		paint(character:FindFirstChild("RightHand"), gloveColor, "Satin")
	end
end

local function hangPieces(humanoid: Humanoid, look: Look.Look)
	for _, accessory in humanoid:GetAccessories() do
		if accessory:GetAttribute(Pieces.ATTRIBUTE) then
			accessory:Destroy()
		end
	end
	for _, slot in Wardrobe.Slots do
		local choice = look.Pieces[slot]
		local piece = choice and Wardrobe.get(choice.Id)
		if choice and piece then
			local main = Palette.resolve(choice.C, Palette.resolve(piece.Main))
			local accent = Palette.resolve(choice.A, Palette.resolve(piece.Accent))
			for _, accessory in Pieces.build(piece, main, accent, choice.F or piece.Finish) do
				humanoid:AddAccessory(accessory)
			end
		end
	end
end

-- Dresses a character (a player's or a rival's rig) in a look. Yields.
function LookService.dress(
	character: Model,
	look: Look.Look,
	base: HumanoidDescription?,
	catalog: { CatalogService.Item }
): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return false
	end
	local description = describe(look, base, catalog)
	local ok, err = pcall(humanoid.ApplyDescriptionAsync, humanoid, description)
	if not ok then
		warn(`Could not dress {character.Name}: {err}`)
	end
	if not character.Parent then
		return false
	end
	paintBody(character, look)
	hangPieces(humanoid, look)
	character:SetAttribute("Glows", Look.summary(look).Glows)
	return ok
end

-- A rival's rig dressed in a look, or nil if Roblox couldn't make one.
function LookService.makeRig(name: string, look: Look.Look): Model?
	local description = describe(look, nil, {})
	local ok, model =
		pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, description, Enum.HumanoidRigType.R15)
	if not ok or not model then
		warn(`Could not make a rig for {name}: {model}`)
		return nil
	end
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	paintBody(model, look)
	hangPieces(humanoid, look)
	model:SetAttribute("Glows", Look.summary(look).Glows)
	return model
end

-- The player's look as the server last applied it.
function LookService.current(player: Player): Dressed?
	return current[player]
end

-- Names of the catalog items a player is wearing, for the judges.
function LookService.catalogNames(player: Player): { string }
	local dressed = current[player]
	local names = {}
	if dressed then
		for _, item in dressed.Catalog do
			table.insert(names, item.Name)
		end
	end
	return names
end

-- While locked (on the runway), a player's look can't change.
function LookService.setLocked(player: Player, isLocked: boolean)
	locked[player] = if isLocked then true else nil
end

local function contextFor(player: Player): Look.Context
	return {
		ownsPiece = function(id)
			return ProfileService.owns(player, "Piece", id)
		end,
		ownsPose = function(id)
			return ProfileService.owns(player, "Pose", id)
		end,
		ownsEntrance = function(id)
			return ProfileService.owns(player, "Entrance", id)
		end,
		customColors = ProfileService.hasPass(player, "color_studio"),
		maxCatalog = Game.Looks.MaxCatalogItems,
	}
end

-- Checks a look the client sent: what it may wear, and which catalog items
-- are real accessories. Yields for catalog lookups.
function LookService.clean(player: Player, raw: any): (Look.Look, { CatalogService.Item })
	local look = Look.sanitize(raw, contextFor(player))
	local catalog = CatalogService.items(look.Catalog)
	local valid = {}
	for _, item in catalog do
		table.insert(valid, item.Id)
	end
	look.Catalog = valid
	return look, catalog
end

local function countChallenges(player: Player, previous: Look.Look?, look: Look.Look)
	local seen = tried[player]
	if not seen then
		seen = { Catalog = {}, Recolor = {} }
		tried[player] = seen
	end
	local newCatalog = 0
	for _, id in look.Catalog do
		if not seen.Catalog[id] then
			seen.Catalog[id] = true
			newCatalog += 1
		end
	end
	if newCatalog > 0 then
		ProfileService.record(player, "CatalogTry", newCatalog)
	end
	if previous then
		local recolored = 0
		for slot, choice in look.Pieces do
			local before = previous.Pieces[slot]
			local changed = before
				and before.Id == choice.Id
				and (before.C ~= choice.C or before.A ~= choice.A or before.F ~= choice.F)
			if changed and not seen.Recolor[choice.Id] then
				seen.Recolor[choice.Id] = true
				recolored += 1
			end
		end
		if recolored > 0 then
			ProfileService.record(player, "Recolor", recolored)
		end
	end
end

-- Cleans, saves and puts on a look. Yields.
local function wear(player: Player, raw: any, fromClient: boolean)
	local data = DataService.get(player)
	if not data then
		return
	end
	local look, catalog = LookService.clean(player, raw)
	if fromClient and type(raw) == "table" and type(raw.Catalog) == "table" and #look.Catalog < #raw.Catalog then
		ProfileService.notify(player, "Info", "Some catalog items can't be worn here, so they were left off.")
	end
	local previous = current[player]
	if fromClient then
		countChallenges(player, previous and previous.Look, look)
		player:SetAttribute("Dressed", true)
	end
	current[player] = { Look = look, Catalog = catalog }
	data.Current = look
	ProfileService.push(player)
	local character = player.Character
	if character and character.Parent then
		LookService.dress(character, look, baseFor(player.UserId), catalog)
	end
end

-- Puts the player's saved current look on their character again.
function LookService.reapply(player: Player)
	local dressed = current[player]
	local character = player.Character
	if dressed and character then
		LookService.dress(character, dressed.Look, baseFor(player.UserId), dressed.Catalog)
	end
end

local function request(player: Player, raw: any, fromClient: boolean)
	pending[player] = { Raw = raw, FromClient = fromClient }
	if working[player] then
		return
	end
	working[player] = true
	task.spawn(function()
		while pending[player] and player.Parent do
			local job = pending[player]
			pending[player] = nil
			local ok, err = pcall(wear, player, job.Raw, job.FromClient)
			if not ok then
				warn(`Could not change {player.Name}'s look: {err}`)
			end
			task.wait(Game.Cooldowns.SetLook)
		end
		working[player] = nil
	end)
end

-- Sets a look from the server (a saved outfit, or a reset).
function LookService.set(player: Player, look: any)
	request(player, look, false)
end

local function onSetLook(player: Player, raw: any)
	if locked[player] then
		ProfileService.notify(player, "Info", "Your look is locked in for the show!")
		return
	end
	if type(raw) ~= "table" then
		return
	end
	request(player, raw, true)
end

-- Joints turned for a pose, by Motor6D name.
local function motors(character: Model): { [string]: Motor6D }
	local found = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			found[descendant.Name] = descendant
		end
	end
	return found
end

-- Strikes a pose (Config/Poses) on an R15 character.
function LookService.strike(character: Model, poseId: string)
	local pose = Poses.get(poseId) or Poses.get(Poses.Default)
	if not pose then
		return
	end
	local found = motors(character)
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for name, turn in pose.Joints do
		local motor = found[name]
		if motor then
			local rest = restC0[motor] or motor.C0
			restC0[motor] = rest
			local goal = rest * CFrame.Angles(math.rad(turn[1]), math.rad(turn[2]), math.rad(turn[3]))
			TweenService:Create(motor, info, { C0 = goal }):Play()
		end
	end
end

-- Puts every posed joint back where it rests.
function LookService.relax(character: Model)
	local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, motor in motors(character) do
		local rest = restC0[motor]
		if rest then
			TweenService:Create(motor, info, { C0 = rest }):Play()
			restC0[motor] = nil
		end
	end
end

local function onCharacter(player: Player, character: Model)
	local data = DataService.waitFor(player, 30)
	if not data or player.Character ~= character then
		return
	end
	character:WaitForChild("Humanoid", 10)
	if not current[player] then
		request(player, data.Current, false)
	else
		task.spawn(LookService.reapply, player)
	end
end

function LookService.init()
	SetLook.OnServerEvent:Connect(onSetLook)
	PlayerHooks.eachCharacter(onCharacter)
	Players.PlayerRemoving:Connect(function(player)
		current[player] = nil
		pending[player] = nil
		locked[player] = nil
		tried[player] = nil
		baseDescriptions[player.UserId] = nil
	end)
end

return LookService
