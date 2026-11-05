-- Each player in the run: their role, their warmth, freezing and thawing,
-- their backpack, the meals in their pocket and the weapons they have made.
-- What the HUD needs is kept in attributes on the Player ("Role",
-- "Warmth", "Frozen", "Pack_Wood", "Food" and so on).
--
-- Getting too cold freezes a player in a block of ice: the game's
-- knockout. A teammate holds the prompt on the ice to thaw them, or after a
-- while they wake up by the hearth, which costs the hearth a little flame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Features = require(ReplicatedStorage.Shared.Config.Features)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Roles = require(ReplicatedStorage.Shared.Config.Roles)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Stock = require(ReplicatedStorage.Shared.Stock)
local Warmth = require(ReplicatedStorage.Shared.Warmth)
local Gear = require(ReplicatedStorage.Shared.World.Gear)
local Lib = script.Parent.Parent.Lib
local Analytics = require(Lib.Analytics)
local Heat = require(Lib.Heat)
local Net = require(Lib.Net)
local RateLimiter = require(Lib.RateLimiter)
local RunStats = require(Lib.RunStats)
local GameLoop = require(script.Parent.GameLoop)
local ProfileService = require(script.Parent.ProfileService)
local TeamService = require(script.Parent.TeamService)
local WorldService = require(script.Parent.WorldService)

local PlayerService = {}

type Survivor = {
	Pack: Stock.Counts,
	Food: { string },
	Weapons: { [string]: boolean },
	Ice: BasePart?,
	-- Server times when the stew's shield and the tea's speed wear off.
	ShieldUntil: number,
	SpeedUntil: number,
	Speed: number,
	Shield: number,
	Volley: number,
	JoinedAt: number,
	-- Server time until which monsters can't chill them (just thawed).
	GraceUntil: number,
}

local survivors: { [Player]: Survivor } = {}
local frozenCallbacks: { (Player) -> () } = {}
local eatLimiter = RateLimiter.new(0.5)
local roleLimiter = RateLimiter.new(0.5)

local TICK = 0.25

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function survivor(player: Player): Survivor
	local entry = survivors[player]
	if not entry then
		entry = {
			Pack = Stock.empty(),
			Food = {},
			Weapons = { [Weapons.Starter] = true },
			ShieldUntil = 0,
			SpeedUntil = 0,
			Speed = 0,
			Shield = 0,
			Volley = 0,
			JoinedAt = now(),
			GraceUntil = 0,
		}
		survivors[player] = entry
	end
	return entry
end

function PlayerService.role(player: Player): Roles.Role?
	return Roles.ById[player:GetAttribute("Role") or ""]
end

function PlayerService.isFrozen(player: Player): boolean
	return player:GetAttribute("Frozen") == true
end

-- Runs callback(player) when a player freezes.
function PlayerService.onFrozen(callback: (Player) -> ())
	table.insert(frozenCallbacks, callback)
end

-- Backpack -------------------------------------------------------------

function PlayerService.packSize(player: Player): number
	local role = PlayerService.role(player)
	local size = Balance.Backpack + (role and role.PackBonus or 0)
	if TeamService.hasUpgrade("BigPacks") then
		size += 10
	end
	return size
end

local function publishPack(player: Player)
	local entry = survivor(player)
	for _, resource in Resources.List do
		player:SetAttribute(`Pack_{resource.Id}`, entry.Pack[resource.Id] or 0)
	end
	player:SetAttribute("PackUsed", Stock.total(entry.Pack))
	player:SetAttribute("PackSize", PlayerService.packSize(player))
end

-- Puts what was gathered in the backpack, as much as fits. Returns what fit.
function PlayerService.carry(player: Player, counts: Stock.Counts): Stock.Counts
	local entry = survivor(player)
	local moved = Stock.fill(entry.Pack, PlayerService.packSize(player), counts)
	publishPack(player)
	return moved
end

-- A copy of what is in the backpack.
function PlayerService.pack(player: Player): Stock.Counts
	return table.clone(survivor(player).Pack)
end

-- Takes things out of the backpack (to hand in at a landmark). Returns
-- false, taking nothing, if they aren't all there.
function PlayerService.takeFromPack(player: Player, counts: Stock.Counts): boolean
	local entry = survivor(player)
	if not Stock.spend(entry.Pack, counts) then
		return false
	end
	publishPack(player)
	return true
end

function PlayerService.packFull(player: Player): boolean
	return Stock.total(survivor(player).Pack) >= PlayerService.packSize(player)
end

-- Empties the backpack and returns what was in it.
function PlayerService.unpack(player: Player): Stock.Counts
	local entry = survivor(player)
	local pack = entry.Pack
	entry.Pack = Stock.empty()
	publishPack(player)
	return pack
end

-- Speed ---------------------------------------------------------------------

function PlayerService.refreshSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if PlayerService.isFrozen(player) then
		humanoid.WalkSpeed = 0
		return
	end
	local entry = survivor(player)
	local role = PlayerService.role(player)
	local speed = Balance.WalkSpeed * (1 + (role and role.SpeedBonus or 0))
	if entry.SpeedUntil > now() then
		speed += entry.Speed
	end
	if (player:GetAttribute("Carrying") or "") ~= "" then
		speed *= 0.85
	end
	humanoid.WalkSpeed = speed
end

-- Weapons -------------------------------------------------------------------

local function giveTool(player: Player, weaponId: string)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local weapon = Weapons.ById[weaponId]
	if not backpack or not weapon then
		return
	end
	for _, container in { backpack, player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("Weapon") == weaponId then
					return
				end
			end
		end
	end
	local tool = Gear.weapon(weaponId, weapon.Name)
	tool.ToolTip = weapon.Blurb
	tool.Parent = backpack
end

function PlayerService.hasWeapon(player: Player, weaponId: string): boolean
	return survivor(player).Weapons[weaponId] == true
end

function PlayerService.giveWeapon(player: Player, weaponId: string)
	survivor(player).Weapons[weaponId] = true
	giveTool(player, weaponId)
end

-- The equipped weapon, if the player is holding one.
function PlayerService.equipped(player: Player): string?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("Weapon")
end

-- The multiplier on this player's next hit: the Ranger's bonus, and double
-- while the Ranger's volley lasts (which this uses up one of).
function PlayerService.damageScale(player: Player): number
	local role = PlayerService.role(player)
	local scale = 1 + (role and role.DamageBonus or 0)
	local entry = survivor(player)
	if entry.Volley > 0 then
		entry.Volley -= 1
		player:SetAttribute("Volley", entry.Volley)
		scale *= 2
	end
	return scale
end

function PlayerService.startVolley(player: Player, shots: number)
	local entry = survivor(player)
	entry.Volley = shots
	player:SetAttribute("Volley", shots)
end

-- Warmth --------------------------------------------------------------------

function PlayerService.warmth(player: Player): number
	return player:GetAttribute("Warmth") or Balance.Warmth.Max
end

function PlayerService.setWarmth(player: Player, value: number)
	player:SetAttribute("Warmth", math.floor(Warmth.clamp(value) * 10 + 0.5) / 10)
end

local function resists(player: Player, x: number, z: number): { number }
	local list = {}
	local role = PlayerService.role(player)
	if role and role.ColdResist then
		table.insert(list, role.ColdResist)
	end
	if TeamService.hasUpgrade("WoolCoats") then
		table.insert(list, 0.25)
	end
	local entry = survivor(player)
	if entry.ShieldUntil > now() then
		table.insert(list, entry.Shield)
	end
	for other in survivors do
		if other ~= player and other:GetAttribute("Role") == "Medic" and not PlayerService.isFrozen(other) then
			local root = Net.root(other)
			if
				root
				and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(x, 0, z)).Magnitude
					<= Roles.AuraRadius
			then
				table.insert(list, Roles.ById.Medic.AuraResist :: number)
				break
			end
		end
	end
	return list
end

local freeze: (Player) -> ()

-- Whether a player was thawed a moment ago and can't be chilled yet.
function PlayerService.inGrace(player: Player): boolean
	return Features.ThawGrace and survivor(player).GraceUntil > now()
end

-- A monster's hit: warmth off, less for well-wrapped players.
function PlayerService.chill(player: Player, amount: number)
	if PlayerService.isFrozen(player) or not GameLoop.isPlaying() or PlayerService.inGrace(player) then
		return
	end
	local root = Net.root(player)
	if not root then
		return
	end
	local taken = Warmth.hit(amount, resists(player, root.Position.X, root.Position.Z))
	local warmth = PlayerService.warmth(player) - taken
	PlayerService.setWarmth(player, warmth)
	Net.fx("Chilled", { Player = player.UserId, Amount = taken }, player)
	if warmth <= 0 then
		freeze(player)
	end
end

function PlayerService.warm(player: Player, amount: number)
	if PlayerService.isFrozen(player) then
		return
	end
	PlayerService.setWarmth(player, PlayerService.warmth(player) + amount)
end

-- Freezing ------------------------------------------------------------------

local function setMovement(player: Player, frozen: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = Net.root(player)
	if humanoid then
		humanoid.JumpHeight = if frozen then 0 else 7.2
		humanoid.JumpPower = if frozen then 0 else 50
	end
	if root then
		root.Anchored = frozen
		if not frozen then
			-- Anchoring takes the character away from its player's physics;
			-- hand it back so their movement stays smooth.
			pcall(root.SetNetworkOwner, root, player)
		end
	end
	PlayerService.refreshSpeed(player)
end

local thaw: (Player, Player?) -> ()

function freeze(player: Player)
	if PlayerService.isFrozen(player) then
		return
	end
	local root = Net.root(player)
	if not root then
		return
	end
	player:SetAttribute("Frozen", true)
	player:SetAttribute("WakeAt", now() + Balance.Warmth.FrozenSeconds)
	PlayerService.setWarmth(player, 0)
	setMovement(player, true)
	local entry = survivor(player)
	local ice = Gear.iceBlock(Workspace, root.CFrame * CFrame.new(0, -0.3, 0))
	ice.Name = `Ice_{player.UserId}`
	entry.Ice = ice
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Thaw"
	prompt.ActionText = `Thaw {player.DisplayName}`
	prompt.ObjectText = "Frozen solid!"
	prompt.HoldDuration = Balance.Warmth.ThawSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = ice
	local holding: { [Player]: boolean } = {}
	prompt.PromptButtonHoldBegan:Connect(function(by)
		holding[by] = true
		local role = PlayerService.role(by)
		if role and role.ThawSeconds and role.ThawSeconds < Balance.Warmth.ThawSeconds then
			task.delay(role.ThawSeconds, function()
				if holding[by] and PlayerService.isFrozen(player) then
					thaw(player, by)
				end
			end)
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function(by)
		holding[by] = nil
	end)
	prompt.Triggered:Connect(function(by)
		if by ~= player then
			thaw(player, by)
		end
	end)
	Net.fx("Freeze", { Player = player.UserId, Position = root.Position })
	Net.notice(player, "You froze! Wait for a friend to thaw you, or wake up by the hearth soon.", "Bad")
	for other in survivors do
		if other ~= player then
			Net.notice(other, `{player.DisplayName} is frozen! Hold E on the ice to thaw them.`, "Bad")
		end
	end
	for _, callback in frozenCallbacks do
		task.spawn(callback, player)
	end
end

-- Thaws a player where they stand (by is the friend who did it), or, with
-- no friend, wakes them up at the hearth.
function thaw(player: Player, by: Player?)
	if not PlayerService.isFrozen(player) then
		return
	end
	local entry = survivor(player)
	if entry.Ice then
		entry.Ice:Destroy()
		entry.Ice = nil
	end
	player:SetAttribute("Frozen", false)
	player:SetAttribute("WakeAt", 0)
	if Features.ThawGrace then
		entry.GraceUntil = now() + Balance.Warmth.ThawGraceSeconds
		player:SetAttribute("GraceUntil", entry.GraceUntil)
	end
	setMovement(player, false)
	local root = Net.root(player)
	if by then
		local role = PlayerService.role(by)
		PlayerService.setWarmth(player, role and role.ThawWarmth or Balance.Warmth.ThawWarmth)
		RunStats.thaw(by)
		Net.notice(player, `{by.DisplayName} thawed you out!`, "Good")
		Net.notice(by, `You thawed {player.DisplayName}!`, "Good")
	else
		PlayerService.setWarmth(player, Balance.Warmth.RespawnWarmth)
		if root then
			local character = player.Character
			if character then
				character:PivotTo(WorldService.spawnPoint())
			end
		end
		if GameLoop.isPlaying() then
			TeamService.douse(Balance.Warmth.RespawnFlameCost)
		end
		Net.notice(player, "You woke up by the hearth.", "Info")
	end
	if root then
		Net.fx("Thaw", { Player = player.UserId, Position = root.Position })
	end
end

function PlayerService.thaw(player: Player, by: Player?)
	thaw(player, by)
end

-- Food ----------------------------------------------------------------------

local function publishFood(player: Player)
	player:SetAttribute("Food", table.concat(survivor(player).Food, ","))
end

function PlayerService.pocketFull(player: Player): boolean
	return #survivor(player).Food >= Balance.FoodPocket
end

function PlayerService.pocket(player: Player, mealId: string): boolean
	local entry = survivor(player)
	if #entry.Food >= Balance.FoodPocket then
		return false
	end
	table.insert(entry.Food, mealId)
	publishFood(player)
	return true
end

local function onEat(player: Player, mealId: unknown)
	if not eatLimiter:allow(player) or PlayerService.isFrozen(player) then
		return
	end
	local entry = survivor(player)
	if #entry.Food == 0 then
		Net.notice(player, "Your pocket is empty. Take a meal from the cook pot.", "Bad")
		return
	end
	-- The meal asked for, or the first one in the pocket.
	local index = if typeof(mealId) == "string" then table.find(entry.Food, mealId) else 1
	index = index or 1
	local id = table.remove(entry.Food, index) :: string
	publishFood(player)
	local meal = Recipes.MealById[id]
	if not meal then
		return
	end
	local role = PlayerService.role(player)
	local bonus = 1 + (role and role.MealBonus or 0)
	PlayerService.warm(player, meal.Warmth * bonus)
	if meal.ShieldSeconds and meal.Shield then
		entry.ShieldUntil = now() + meal.ShieldSeconds
		entry.Shield = meal.Shield
		player:SetAttribute("ShieldUntil", entry.ShieldUntil)
	end
	if meal.SpeedSeconds and meal.Speed then
		entry.SpeedUntil = now() + meal.SpeedSeconds
		entry.Speed = meal.Speed
		player:SetAttribute("SpeedUntil", entry.SpeedUntil)
		PlayerService.refreshSpeed(player)
		task.delay(meal.SpeedSeconds + 0.1, function()
			if player.Parent then
				PlayerService.refreshSpeed(player)
			end
		end)
	end
	Net.fx("Eat", { Player = player.UserId, Meal = id })
end

-- Roles ---------------------------------------------------------------------

function PlayerService.setRole(player: Player, roleId: string)
	player:SetAttribute("Role", roleId)
	ProfileService.rememberRole(player, roleId)
	publishPack(player)
	PlayerService.refreshSpeed(player)
	Analytics.step(player, "PickedRole")
end

local function onPickRole(player: Player, roleId: unknown)
	if typeof(roleId) ~= "string" or not roleLimiter:allow(player) then
		return
	end
	local current = player:GetAttribute("Role") or ""
	local phase = GameLoop.phase()
	if current ~= "" and phase ~= "Intermission" and phase ~= "Waiting" then
		Net.notice(player, "You can change role between runs.", "Info")
		return
	end
	if not Roles.ById[roleId] or not ProfileService.ownsRole(player, roleId) then
		Net.notice(player, "That role is locked. Unlock it in the shop.", "Bad")
		return
	end
	PlayerService.setRole(player, roleId)
	local role = Roles.ById[roleId]
	Net.notice(player, `You are the {role.Name}. {role.Ability.Name}: press Q.`, "Good")
end

-- Gives anyone who hasn't chosen by the time the run is under way the role
-- they had last time (or the Scout).
local function assignMissingRoles()
	for _, player in Players:GetPlayers() do
		if (player:GetAttribute("Role") or "") == "" then
			local entry = survivor(player)
			if now() - entry.JoinedAt >= Balance.RoleChoiceSeconds or GameLoop.phase() == "Night" then
				local save = ProfileService.save(player)
				local last = save and save.LastRole or Roles.Default
				PlayerService.setRole(player, if ProfileService.ownsRole(player, last) then last else Roles.Default)
			end
		end
	end
end

-- Runs ----------------------------------------------------------------------

local function resetPlayer(player: Player)
	local entry = survivor(player)
	if entry.Ice then
		entry.Ice:Destroy()
	end
	survivors[player] = nil
	entry = survivor(player)
	entry.JoinedAt = now()
	player:SetAttribute("Role", "")
	player:SetAttribute("Frozen", false)
	player:SetAttribute("WakeAt", 0)
	player:SetAttribute("Carrying", "")
	player:SetAttribute("Volley", 0)
	player:SetAttribute("ShieldUntil", 0)
	player:SetAttribute("SpeedUntil", 0)
	player:SetAttribute("GraceUntil", 0)
	player:SetAttribute("Knockouts", 0)
	PlayerService.setWarmth(player, Balance.Warmth.Max)
	publishPack(player)
	publishFood(player)
	-- Take away made weapons; everyone keeps the torch.
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("Weapon") ~= Weapons.Starter then
					child:Destroy()
				end
			end
		end
	end
	if player.Character then
		setMovement(player, false)
		player.Character:PivotTo(WorldService.spawnPoint())
	end
	giveTool(player, Weapons.Starter)
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	-- Monsters chill, they never hurt, so a character only dies by falling
	-- or resetting.
	humanoid.BreakJointsOnDeath = false
	local entry = survivor(player)
	if entry.Ice then
		entry.Ice:Destroy()
		entry.Ice = nil
	end
	if PlayerService.isFrozen(player) then
		player:SetAttribute("Frozen", false)
		player:SetAttribute("WakeAt", 0)
		PlayerService.setWarmth(player, Balance.Warmth.RespawnWarmth)
	end
	for weaponId in entry.Weapons do
		giveTool(player, weaponId)
	end
	task.defer(PlayerService.refreshSpeed, player)
end

function PlayerService.init()
	Net.remote("Eat").OnServerEvent:Connect(onEat)
	Net.remote("PickRole").OnServerEvent:Connect(onPickRole)

	local function added(player: Player)
		survivor(player)
		player:SetAttribute("Role", "")
		PlayerService.setWarmth(player, Balance.Warmth.Max)
		publishPack(player)
		publishFood(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, player in Players:GetPlayers() do
		task.spawn(added, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local entry = survivors[player]
		if entry and entry.Ice then
			entry.Ice:Destroy()
		end
		-- Someone leaving mid-run leaves their backpack at the stockpile, so
		-- the team doesn't lose what they gathered.
		if entry and GameLoop.isPlaying() and Stock.total(entry.Pack) > 0 then
			TeamService.add(entry.Pack)
		end
		Analytics.forget(player)
		survivors[player] = nil
		eatLimiter:forget(player)
		roleLimiter:forget(player)
		RunStats.forget(player)
	end)

	GameLoop.onPhase(function(phase)
		if phase == "Intermission" then
			for _, player in Players:GetPlayers() do
				resetPlayer(player)
			end
		elseif phase == "Night" then
			assignMissingRoles()
		end
	end)
	TeamService.onUpgrade(function(id)
		if id == "BigPacks" then
			for _, player in Players:GetPlayers() do
				publishPack(player)
			end
		end
	end)
end

function PlayerService.start()
	while true do
		task.wait(TICK)
		local playing = GameLoop.isPlaying()
		local night = GameLoop.isNight()
		local radius = TeamService.radius()
		local hearth = WorldService.hearth
		local time = now()
		for player in survivors do
			if PlayerService.isFrozen(player) then
				if time >= (player:GetAttribute("WakeAt") or 0) then
					thaw(player, nil)
				end
			elseif not playing then
				PlayerService.setWarmth(player, Balance.Warmth.Max)
			else
				local root = Net.root(player)
				if root then
					local position = root.Position
					local flat = Vector3.new(position.X - hearth.X, 0, position.Z - hearth.Z)
					local rate = Warmth.rate({
						AtHearth = flat.Magnitude <= radius,
						NearWarmth = Heat.at(position.X, position.Z),
						Night = night,
						Resists = resists(player, position.X, position.Z),
					})
					local warmth = PlayerService.warmth(player) + rate * TICK
					PlayerService.setWarmth(player, warmth)
					if warmth <= 0 then
						freeze(player)
					end
				end
			end
		end
		if playing then
			assignMissingRoles()
		end
	end
end

return PlayerService
