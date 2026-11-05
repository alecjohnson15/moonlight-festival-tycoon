-- Everything a player keeps between runs: snowflakes, the Expedition Pass,
-- what they own, what they wear and how their cabin looks. Applies the
-- rules in shared/Profile to the save DataService loaded, answers the
-- shop, wardrobe and cabin remotes, dresses each character in its
-- cosmetics, and sends each player a summary of their profile whenever it
-- changes (the client's menus read only that).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Config.Cosmetics)
local Decor = require(ReplicatedStorage.Shared.Config.Decor)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Roles = require(ReplicatedStorage.Shared.Config.Roles)
local Gear = require(ReplicatedStorage.Shared.World.Gear)
local Wearables = require(ReplicatedStorage.Shared.World.Wearables)
local Lib = script.Parent.Parent.Lib
local Net = require(Lib.Net)
local RateLimiter = require(Lib.RateLimiter)
local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)

local ProfileService = {}

local callbacks: { (Player) -> () } = {}
local limiter = RateLimiter.new(0.25)

local function grants(player: Player): Profile.Grants
	return PassService.grants(player)
end

-- What the client is told about its own profile.
local function summary(player: Player, save: Profile.Save)
	local g = grants(player)
	local cosmetics, decor, roles = {}, {}, {}
	for _, item in Cosmetics.List do
		if Profile.ownsCosmetic(save, g, item.Id) then
			cosmetics[item.Id] = true
		end
	end
	for _, item in Decor.List do
		if Profile.ownsDecor(save, g, item.Id) then
			decor[item.Id] = true
		end
	end
	for _, role in Roles.List do
		if Profile.ownsRole(save, g, role.Id) then
			roles[role.Id] = true
		end
	end
	local passes = {}
	for _, pass in require(ReplicatedStorage.Shared.Config.Catalog) do
		if PassService.owns(player, pass.Id) then
			passes[pass.Id] = true
		end
	end
	return {
		Flakes = save.Flakes,
		Xp = save.Xp,
		Premium = g.Premium,
		ClaimedFree = save.ClaimedFree,
		ClaimedPremium = save.ClaimedPremium,
		Cosmetics = cosmetics,
		Decor = decor,
		Roles = roles,
		Passes = passes,
		Equipped = save.Equipped,
		Cabin = save.Cabin,
		Stats = save.Stats,
		Trophies = save.Trophies,
		LastRole = save.LastRole,
	}
end

local function sync(player: Player)
	local save = DataService.get(player)
	if not save then
		return
	end
	player:SetAttribute("Flakes", save.Flakes)
	Net.remote("Profile"):FireClient(player, summary(player, save))
	for _, callback in callbacks do
		task.spawn(callback, player)
	end
end

-- Runs callback(player) whenever a player's profile changes (their cabin,
-- their outfit, what they own).
function ProfileService.onChanged(callback: (Player) -> ())
	table.insert(callbacks, callback)
end

function ProfileService.save(player: Player): Profile.Save?
	return DataService.get(player)
end

function ProfileService.grants(player: Player): Profile.Grants
	return grants(player)
end

function ProfileService.ownsRole(player: Player, roleId: string): boolean
	local save = DataService.get(player)
	return save ~= nil and Profile.ownsRole(save, grants(player), roleId)
end

-- Remembers the role a player last chose, for next time.
function ProfileService.rememberRole(player: Player, roleId: string)
	local save = DataService.get(player)
	if save then
		save.LastRole = roleId
	end
end

-- Pays a player for a finished run and saves straight away. Returns the
-- snowflakes earned and the pass rewards it unlocked.
function ProfileService.finishRun(player: Player, stats: Profile.RunStats, beatYeti: boolean): (number, { string })
	local save = DataService.get(player)
	if not save then
		return 0, {}
	end
	local flakes = Profile.finishRun(save, stats, beatYeti)
	local given = Profile.claim(save, grants(player).Premium)
	DataService.saveNow(player)
	sync(player)
	return flakes, given
end

-- Dresses a character in the player's hat, back item and trail; the pet is
-- an attribute the clients draw (client/Pets).
local function dress(player: Player)
	local character = player.Character
	local save = DataService.get(player)
	if not character or not save then
		return
	end
	local old = character:FindFirstChild("Cosmetics")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Cosmetics"
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, slot in { "Hat", "Back" } do
		local id = save.Equipped[slot]
		local body = if slot == "Hat" then head else torso
		if id and body then
			local model = Wearables.build(nil, id, slot)
			if model and model.PrimaryPart then
				model:PivotTo(body.CFrame)
				Gear.weld(model, model.PrimaryPart)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = model.PrimaryPart
				weld.Parent = model.PrimaryPart
				model.Parent = folder
			end
		end
	end
	local trailId = save.Equipped.Trail
	if trailId and root then
		local top = Instance.new("Attachment")
		top.Name = "TrailTop"
		top.Position = Vector3.new(0, -0.6, 0.6)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "TrailBottom"
		bottom.Position = Vector3.new(0, -2.6, 0.6)
		bottom.Parent = root
		local trail = Wearables.trail(trailId, top, bottom)
		if trail then
			trail.Parent = folder
		end
	end
	folder.Parent = character
	player:SetAttribute("Pet", save.Equipped.Pet or "")
end

local function onShop(player: Player, id: unknown)
	if typeof(id) ~= "string" or not limiter:allow(player) then
		return
	end
	local save = DataService.get(player)
	if not save then
		return
	end
	local ok, reason = Profile.buy(save, grants(player), id)
	if ok then
		local item: any = Cosmetics.ById[id] or Decor.ById[id] or Roles.ById[id]
		Net.notice(player, `Unlocked {item and item.Name or id}!`, "Good")
		Net.fx("Unlock", { Id = id }, player)
		DataService.saveNow(player)
		sync(player)
	else
		Net.notice(player, reason or "You can't buy that.", "Bad")
	end
end

local function onEquip(player: Player, slot: unknown, id: unknown)
	if typeof(slot) ~= "string" or typeof(id) ~= "string" or not limiter:allow(player) then
		return
	end
	local save = DataService.get(player)
	if save and Profile.equip(save, grants(player), slot, id) then
		dress(player)
		sync(player)
	end
end

local function onDecorate(player: Player, spot: unknown, id: unknown)
	if typeof(spot) ~= "string" or typeof(id) ~= "string" or not limiter:allow(player) then
		return
	end
	local save = DataService.get(player)
	if save and Profile.decorate(save, grants(player), spot, id) then
		sync(player)
	end
end

local function refresh(player: Player)
	local save = DataService.get(player)
	if not save or not PassService.ready(player) then
		return
	end
	local g = grants(player)
	Profile.tidy(save, g)
	local given = Profile.claim(save, g.Premium)
	for _, name in given do
		Net.notice(player, `Expedition Pass: {name}`, "Good")
	end
	dress(player)
	sync(player)
end

function ProfileService.init()
	Net.remote("Shop").OnServerEvent:Connect(onShop)
	Net.remote("Equip").OnServerEvent:Connect(onEquip)
	Net.remote("Decorate").OnServerEvent:Connect(onDecorate)
	DataService.onLoaded(function(player)
		refresh(player)
	end)
	PassService.onChanged(refresh)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			dress(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return ProfileService
