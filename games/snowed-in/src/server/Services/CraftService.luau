-- The workbench and the cook pot. Their prompts open the client's menus;
-- the menus ask for a recipe (Config/Recipes) and the server checks the
-- player is standing at the station, the hearth is built up enough, the
-- role fits and the stockpile can pay. A second prompt on the cook pot
-- takes a meal from the pantry into the player's pocket.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Stock = require(ReplicatedStorage.Shared.Stock)
local Lib = script.Parent.Parent.Lib
local Net = require(Lib.Net)
local RateLimiter = require(Lib.RateLimiter)
local GameLoop = require(script.Parent.GameLoop)
local PlayerService = require(script.Parent.PlayerService)
local TeamService = require(script.Parent.TeamService)
local WorldService = require(script.Parent.WorldService)

local CraftService = {}

local REACH = 18

local limiter = RateLimiter.new(0.3)
local workbenchAt: Vector3
local cookPotAt: Vector3

local function short(player: Player, cost: Stock.Counts)
	local missing = Stock.missing(TeamService.stock(), cost)
	Net.notice(player, `The stockpile needs {Stock.describe(missing or {})} more.`, "Bad")
end

local function onCraft(player: Player, id: unknown)
	if typeof(id) ~= "string" or not limiter:allow(player) or not GameLoop.isPlaying() then
		return
	end
	if not Net.near(player, workbenchAt, REACH) then
		Net.notice(player, "Use the workbench to make that.", "Bad")
		return
	end
	local upgrade = Recipes.UpgradeById[id]
	if upgrade then
		if TeamService.hasUpgrade(id) then
			return
		end
		if TeamService.level() < upgrade.Needs then
			Net.notice(player, `Build up the hearth to level {upgrade.Needs} first.`, "Bad")
			return
		end
		if not TeamService.spend(upgrade.Cost) then
			short(player, upgrade.Cost)
			return
		end
		TeamService.grantUpgrade(id)
		Net.notice(nil, `{player.DisplayName} made {upgrade.Name}! {upgrade.Blurb}`, "Big")
		Net.fx("Crafted", { Id = id, Position = workbenchAt })
		return
	end
	local weapon = Recipes.WeaponById[id]
	if weapon then
		if PlayerService.hasWeapon(player, id) then
			Net.notice(player, "You already have that.", "Info")
			return
		end
		if TeamService.level() < weapon.Needs then
			Net.notice(player, `Build up the hearth to level {weapon.Needs} first.`, "Bad")
			return
		end
		if not TeamService.spend(weapon.Cost) then
			short(player, weapon.Cost)
			return
		end
		PlayerService.giveWeapon(player, id)
		Net.notice(player, `You made the {Weapons.ById[id].Name}! It's on your hotbar.`, "Good")
		Net.fx("Crafted", { Id = id, Position = workbenchAt })
	end
end

local function onCook(player: Player, id: unknown)
	if typeof(id) ~= "string" or not limiter:allow(player) or not GameLoop.isPlaying() then
		return
	end
	local meal = Recipes.MealById[id]
	if not meal then
		return
	end
	if not Net.near(player, cookPotAt, REACH) then
		Net.notice(player, "Use the cook pot to cook.", "Bad")
		return
	end
	if meal.Role and player:GetAttribute("Role") ~= meal.Role then
		Net.notice(player, `Only the {meal.Role} knows that recipe.`, "Bad")
		return
	end
	if not TeamService.spend(meal.Cost) then
		short(player, meal.Cost)
		return
	end
	local role = PlayerService.role(player)
	local portions = meal.Portions + (role and role.ExtraPortions or 0)
	TeamService.addMeal(id, portions)
	Net.notice(player, `You cooked {portions} {meal.Name}. Take one from the pot!`, "Good")
	Net.fx("Cooked", { Id = id, Position = cookPotAt })
end

-- Takes the warmest meal in the pantry into the player's pocket.
local function onTakeMeal(player: Player)
	if not GameLoop.isPlaying() or not limiter:allow(player) then
		return
	end
	if PlayerService.pocketFull(player) then
		Net.notice(player, "Your pocket is full. Eat something first (press G).", "Info")
		return
	end
	local best = nil
	for _, meal in Recipes.Meals do
		if (TeamService.pantry()[meal.Id] or 0) > 0 and (not best or meal.Warmth > best.Warmth) then
			best = meal
		end
	end
	if not best then
		Net.notice(player, "The pantry is empty. Cook something!", "Info")
		Net.open(player, "Cook")
		return
	end
	if TeamService.takeMeal(best.Id) and PlayerService.pocket(player, best.Id) then
		Net.notice(player, `You took {best.Name}. Press G to eat it when you're cold.`, "Good")
	end
end

local function prompt(part: BasePart, action: string, object: string, key: Enum.KeyCode?): ProximityPrompt
	local made = Instance.new("ProximityPrompt")
	made.ActionText = action
	made.ObjectText = object
	made.HoldDuration = 0
	made.MaxActivationDistance = 12
	made.RequiresLineOfSight = false
	if key then
		made.KeyboardKeyCode = key
		made.UIOffset = Vector2.new(0, 80)
	end
	made.Parent = part
	return made
end

function CraftService.init()
	local town = WorldService.get()
	local workbench = town.Workbench:FindFirstChild("Prompt") :: BasePart
	local cookPot = town.CookPot:FindFirstChild("Prompt") :: BasePart
	workbenchAt = workbench.Position
	cookPotAt = cookPot.Position

	prompt(workbench, "Open workbench", "Weapons and team upgrades").Triggered:Connect(function(player)
		Net.open(player, "Workbench")
	end)
	prompt(cookPot, "Cook", "Meals for the team").Triggered:Connect(function(player)
		Net.open(player, "Cook")
	end)
	prompt(cookPot, "Take a meal", "From the pantry", Enum.KeyCode.F).Triggered:Connect(onTakeMeal)

	Net.remote("Craft").OnServerEvent:Connect(onCraft)
	Net.remote("Cook").OnServerEvent:Connect(onCook)
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

return CraftService
