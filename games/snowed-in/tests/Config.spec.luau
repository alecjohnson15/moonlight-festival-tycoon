-- Checks the config tables agree with each other and with what is drawn:
-- every reward on the Expedition Pass is a real item that says it comes
-- from the pass, every pass item belongs to a game pass, every item and
-- decoration has a model, every building stays inside its part budget, and
-- every sound the game plays has a file made by tools/make_sounds.py.

local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local roblox = RobloxLoader.roblox
local Buildings = RobloxLoader.require("src/shared/World/Buildings")
local CabinDecor = RobloxLoader.require("src/shared/World/CabinDecor")
local Catalog = RobloxLoader.require("src/shared/Config/Catalog")
local Cosmetics = RobloxLoader.require("src/shared/Config/Cosmetics")
local Decor = RobloxLoader.require("src/shared/Config/Decor")
local Enemies = RobloxLoader.require("src/shared/Config/Enemies")
local Expedition = RobloxLoader.require("src/shared/Config/Expedition")
local Gear = RobloxLoader.require("src/shared/World/Gear")
local Monsters = RobloxLoader.require("src/shared/World/Monsters")
local Recipes = RobloxLoader.require("src/shared/Config/Recipes")
local Resources = RobloxLoader.require("src/shared/Config/Resources")
local Roles = RobloxLoader.require("src/shared/Config/Roles")
local Sounds = RobloxLoader.require("src/shared/Config/Sounds")
local Structures = RobloxLoader.require("src/shared/Config/Structures")
local Wearables = RobloxLoader.require("src/shared/World/Wearables")
local Weapons = RobloxLoader.require("src/shared/Config/Weapons")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function parts(model): number
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

local function snake(name: string): string
	local out = string.gsub(name, "(%l)(%u)", "%1_%2")
	return string.lower(out)
end

-- Every id a game pass hands out.
local function passItems(): { [string]: string }
	local items = {}
	for _, pass in Catalog do
		for _, list in { pass.Grants.Roles or {}, pass.Grants.Cosmetics or {}, pass.Grants.Decor or {} } do
			for _, id in list do
				items[id] = pass.Id
			end
		end
	end
	return items
end

describe("passes and rewards", function()
	it("puts only real tier items on the Expedition Pass", function()
		for index, tier in Expedition.Tiers do
			for _, reward in { tier.Free, tier.Premium } do
				if reward.Item then
					local item = Cosmetics.ById[reward.Item] or Decor.ById[reward.Item]
					if not item then
						error(`tier {index} gives {reward.Item}, which doesn't exist`)
					end
					expect(item.Source).toBe("Tier")
				else
					expect((reward.Flakes or 0) > 0).toBe(true)
				end
			end
		end
	end)

	it("puts every tier item on the pass exactly once", function()
		local seen = {}
		for _, tier in Expedition.Tiers do
			for _, reward in { tier.Free, tier.Premium } do
				if reward.Item then
					expect(seen[reward.Item]).toBe(nil)
					seen[reward.Item] = true
				end
			end
		end
		for _, list in { Cosmetics.List, Decor.List } do
			for _, item in list do
				if item.Source == "Tier" and not seen[item.Id] then
					error(`{item.Id} says it comes from the pass but isn't on it`)
				end
			end
		end
	end)

	it("sells every pass item through a game pass that exists", function()
		local items = passItems()
		for _, item in Cosmetics.List do
			if item.Source == "Pass" and not items[item.Id] then
				error(`{item.Id} has no game pass`)
			end
		end
		for _, item in Decor.List do
			if item.Source == "Pack" and not items[item.Id] then
				error(`{item.Id} has no game pass`)
			end
		end
		for id in items do
			local exists = Cosmetics.ById[id] or Decor.ById[id] or Roles.ById[id]
			if not exists then
				error(`a pass gives {id}, which doesn't exist`)
			end
		end
	end)

	it("lists every pass with a placeholder id, a price and what it gives", function()
		local ids = {}
		for _, pass in Catalog do
			expect(ids[pass.Id]).toBe(nil)
			ids[pass.Id] = true
			expect(type(pass.PassId)).toBe("number")
			expect(pass.SuggestedRobux > 0).toBe(true)
			expect(#pass.Includes > 10).toBe(true)
		end
	end)

	it("lets every paid role also be earned with snowflakes", function()
		local items = passItems()
		for _, role in Roles.List do
			if role.Price > 0 then
				expect(items[role.Id]).toBe(role.Id)
			end
		end
	end)

	it("sells shop items for snowflakes only", function()
		for _, list in { Cosmetics.List, Decor.List } do
			for _, item in list do
				if item.Source == "Shop" then
					expect((item.Price or 0) > 0).toBe(true)
				end
			end
		end
	end)
end)

describe("models", function()
	it("draws every hat, back item and pet, and every trail", function()
		for _, item in Cosmetics.List do
			if item.Slot == "Trail" then
				local a = roblox.Instance.new("Attachment")
				local b = roblox.Instance.new("Attachment")
				if not Wearables.trail(item.Id, a, b) then
					error(`no trail for {item.Id}`)
				end
			else
				local model = Wearables.build(nil, item.Id, item.Slot)
				if not model or not model.PrimaryPart then
					error(`no model for {item.Id}`)
				end
			end
		end
	end)

	it("knows how to put up every cabin decoration", function()
		for _, item in Decor.List do
			if not CabinDecor.has(item.Id) then
				error(`no cabin model for {item.Id}`)
			end
		end
	end)

	it("keeps every building inside its part budget", function()
		local folder = roblox.Instance.new("Folder")
		for _, def in Structures.List do
			local builder = Buildings[def.Id]
			if not builder then
				error(`no model for {def.Id}`)
			end
			local model = builder(folder, roblox.CFrame.new())
			expect(model.PrimaryPart ~= nil).toBe(true)
			if parts(model) > def.Parts then
				error(`{def.Id} uses {parts(model)} parts, more than its {def.Parts}`)
			end
		end
	end)

	it("draws every monster standing on the ground", function()
		for _, def in Enemies.List do
			local builder = Monsters[def.Id]
			if not builder then
				error(`no model for {def.Id}`)
			end
			local model = builder(nil)
			expect(model.PrimaryPart ~= nil).toBe(true)
			expect(model.PrimaryPart.Name).toBe("Root")
			if parts(model) > 40 then
				error(`{def.Id} uses {parts(model)} parts; monsters are drawn by the dozen`)
			end
		end
	end)

	it("makes a tool for every weapon, held by its handle", function()
		for _, weapon in Weapons.List do
			local tool = Gear.weapon(weapon.Id, weapon.Name)
			expect(tool.ClassName).toBe("Tool")
			expect(tool:GetAttribute("Weapon")).toBe(weapon.Id)
			expect(tool:FindFirstChild("Handle") ~= nil).toBe(true)
		end
	end)

	it("crafts only real weapons and cooks for real roles", function()
		for _, recipe in Recipes.Weapons do
			expect(Weapons.ById[recipe.Id] ~= nil).toBe(true)
		end
		for _, meal in Recipes.Meals do
			if meal.Role then
				expect(Roles.ById[meal.Role] ~= nil).toBe(true)
			end
		end
	end)
end)

describe("sounds", function()
	it("has a sound for every gathering node and weapon", function()
		for _, node in Resources.Nodes do
			expect(Sounds[node.Sound] ~= nil).toBe(true)
		end
		for _, weapon in Weapons.List do
			expect(Sounds[weapon.Sound] ~= nil).toBe(true)
		end
	end)

	it("has a made file for every sound", function()
		for name in Sounds do
			local path = `assets/audio/{snake(name)}.ogg`
			if not fs.isFile(path) then
				error(`{name} has no {path}; run tools/make_sounds.py`)
			end
		end
	end)
end)
