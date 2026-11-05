-- Keeps the configs in step: every cosmetic has a way to get it, nothing
-- for Robux is random or gives coins, passes are ready to be made, and
-- every sound has its file.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Loader = require("./RobloxLoader")
local TestKit = require("./TestKit")

local Catalog = Loader.require("src/shared/Config/Catalog")
local CrateConfig = Loader.require("src/shared/Config/Crates")
local Emotes = Loader.require("src/shared/Config/Emotes")
local Game = Loader.require("src/shared/Config/Game")
local Items = Loader.require("src/shared/Config/Items")
local Pass = Loader.require("src/shared/Config/Pass")
local Roles = Loader.require("src/shared/Config/Roles")
local Shop = Loader.require("src/shared/Config/Shop")
local Sounds = Loader.require("src/shared/Config/Sounds")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function hex(value: string): boolean
	return string.match(value, "^#%x%x%x%x%x%x$") ~= nil
end

-- Where each item comes from.
local function sources(): { [string]: { string } }
	local from: { [string]: { string } } = {}
	local function add(itemId: string, source: string)
		from[itemId] = from[itemId] or {}
		table.insert(from[itemId], source)
	end
	for _, offer in Shop.Offers do
		add(offer.Item, "Shop")
	end
	for _, crate in CrateConfig.List do
		for _, pool in crate.Pools do
			for _, itemId in pool do
				add(itemId, "Crate")
			end
		end
	end
	for tier = 1, Pass.Tiers do
		local free = Pass.freeReward(tier)
		if free.Item then
			add(free.Item, "PassFree")
		end
		local premium = Pass.Premium[tier]
		if premium and premium.Item then
			add(premium.Item, "PassPremium")
		end
	end
	for _, product in Catalog do
		for _, itemId in product.Items do
			add(itemId, "Robux")
		end
	end
	return from
end

describe("items", function()
	it("are all well formed, with unique ids", function()
		local seen = {}
		for _, item in Items.List do
			assert(not seen[item.Id], `{item.Id} is listed twice`)
			seen[item.Id] = true
			assert(table.find(Items.KINDS, item.Kind), `{item.Id} has unknown kind {item.Kind}`)
			assert(Items.rank(item.Rarity) > 0, `{item.Id} has unknown rarity {item.Rarity}`)
			assert(type(item.Name) == "string" and #item.Name > 0, `{item.Id} has no name`)
		end
		for _, rarity in Items.RARITIES do
			assert(hex(Items.RARITY_COLORS[rarity]), `{rarity} needs a #RRGGBB colour`)
		end
	end)

	it("has a default of every kind", function()
		for _, kind in Items.KINDS do
			local item = Items.get(Items.DEFAULTS[kind])
			assert(item and item.Default and item.Kind == kind, `default {kind} is wrong`)
		end
	end)

	it("can all be got some way, and defaults aren't sold", function()
		local from = sources()
		for _, item in Items.List do
			if item.Default then
				assert(from[item.Id] == nil, `{item.Id} is a default but is also given out`)
			else
				assert(from[item.Id] ~= nil, `{item.Id} can't be got anywhere`)
			end
		end
		for itemId in from do
			assert(Items.get(itemId), `{itemId} is given out but isn't an item`)
		end
	end)

	it("binds Moon Pass and Robux items, and only those", function()
		for itemId, list in sources() do
			local item = Items.get(itemId) :: any
			local paid = table.find(list, "Robux") or table.find(list, "PassPremium") or table.find(list, "PassFree")
			if paid then
				assert(item.Bound, `{itemId} comes from a pass or Robux and must be Bound`)
				assert(#list == 1, `{itemId} is bound but also comes from {table.concat(list, ", ")}`)
			else
				assert(not item.Bound, `{itemId} is earned and should be tradeable`)
			end
		end
	end)
end)

describe("crates", function()
	it("are opened with coins, list real items of the right rarity, and have sane pity", function()
		for _, crate in CrateConfig.List do
			assert(crate.Price > 0, `{crate.Id} needs a coin price`)
			assert(hex(crate.Color), `{crate.Id} colour must be #RRGGBB`)
			assert(Items.rank(crate.PityRarity) > 0, `{crate.Id} pity rarity is unknown`)
			assert(crate.Pity >= 2, `{crate.Id} pity is too small`)
			local total = 0
			for rarity, weight in crate.Odds do
				total += weight
				local pool = crate.Pools[rarity]
				assert(pool and #pool > 0, `{crate.Id} has odds for {rarity} but no items`)
				for _, itemId in pool do
					local item = Items.get(itemId)
					assert(item, `{crate.Id} lists unknown item {itemId}`)
					assert(item.Rarity == rarity, `{itemId} is {item.Rarity}, listed as {rarity}`)
					assert(not item.Bound and not item.Default, `{itemId} can't come from a crate`)
				end
			end
			expect(total).toBe(100)
			local pityReachable = false
			for rarity, weight in crate.Odds do
				if weight > 0 and Items.rank(rarity) >= Items.rank(crate.PityRarity) then
					pityReachable = true
				end
			end
			assert(pityReachable, `{crate.Id} can never give its pity rarity`)
		end
	end)
end)

describe("Robux catalog", function()
	it("sells only game passes with their contents stated, never coins or crates", function()
		local seen = {}
		for _, product in Catalog do
			assert(not seen[product.Id], `{product.Id} is listed twice`)
			seen[product.Id] = true
			expect(product.Kind).toBe("GamePass")
			assert(product.Price > 0, `{product.Id} needs a price`)
			assert(#product.Description > 10, `{product.Id} needs a description`)
			assert(#product.Items > 0 or product.Perk ~= nil, `{product.Id} gives nothing`)
			local lower = string.lower(product.Name .. " " .. product.Description)
			assert(not string.find(lower, "coin", 1, true), `{product.Id} mentions coins`)
			assert(not string.find(lower, "crate", 1, true), `{product.Id} mentions crates`)
			assert(not string.find(lower, "random", 1, true), `{product.Id} mentions something random`)
		end
	end)

	it("leaves PassId at 0 until the passes are made on Roblox", function()
		for _, product in Catalog do
			expect(product.PassId).toBe(0)
		end
	end)

	it("keeps the premium pass track to cosmetics", function()
		for tier, reward in Pass.Premium do
			assert(reward.Item ~= nil, `premium tier {tier} must be an item`)
			assert(reward.Coins == nil and reward.Crate == nil, `premium tier {tier} gives coins or a crate`)
		end
	end)

	it("matches tools/passes.json, the list the pass-making script reads", function()
		local list = serde.decode("json", fs.readFile("tools/passes.json"))
		expect(#list).toBe(#Catalog)
		for index, product in Catalog do
			local entry = list[index]
			expect(entry.id).toBe(product.Id)
			expect(entry.name).toBe(product.Name)
			expect(entry.price).toBe(product.Price)
			expect(entry.description).toBe(product.Description)
		end
	end)
end)

describe("free Moon Pass track", function()
	it("gives real items and crates, and coins in between", function()
		for tier = 1, Pass.Tiers do
			local reward = Pass.freeReward(tier)
			if reward.Item then
				assert(Items.get(reward.Item), `free tier {tier} lists unknown item`)
			elseif reward.Crate then
				assert(CrateConfig.get(reward.Crate), `free tier {tier} lists unknown crate`)
			else
				assert((reward.Coins or 0) > 0, `free tier {tier} gives nothing`)
			end
		end
	end)
end)

describe("roles and the game", function()
	it("gives every role a colour, a goal and moves", function()
		for id, role in Roles.List do
			expect(role.Id).toBe(id)
			assert(hex(role.Color), `{id} colour must be #RRGGBB`)
			assert(#role.Goal > 0 and #role.Moves > 0, `{id} needs a goal and moves`)
			assert(table.find(Roles.TEAMS, role.Team), `{id} has unknown team`)
		end
	end)

	it("never deals more special roles than players", function()
		for count = 1, Game.MaxPlayers do
			local total = 0
			for _, number in Roles.counts(count) do
				total += number
			end
			assert(total <= count, `{count} players get {total} special roles`)
		end
	end)

	it("lists emotes with unique ids and one action each", function()
		local seen = {}
		for _, emote in Emotes.List do
			assert(not seen[emote.Id], `{emote.Id} is listed twice`)
			seen[emote.Id] = true
			local actions = (if emote.Anim then 1 else 0)
				+ (if emote.Bubble then 1 else 0)
				+ (if emote.Effect then 1 else 0)
				+ (if emote.Target then 1 else 0)
			expect(actions).toBe(1)
		end
	end)
end)

describe("sounds", function()
	it("has a generated file for every sound, and no stray files", function()
		local named = {}
		for name, sound in Sounds.List do
			assert(fs.isFile(`assets/audio/{sound.File}`), `{name} has no file assets/audio/{sound.File}`)
			assert(sound.Volume > 0 and sound.Volume <= 1, `{name} volume out of range`)
			assert(sound.Id == "" or string.match(sound.Id, "^rbxassetid://%d+$"), `{name} id must be rbxassetid://`)
			named[sound.File] = true
		end
		for _, file in fs.readDir("assets/audio") do
			assert(named[file], `assets/audio/{file} isn't used by any sound`)
		end
	end)
end)

return nil
