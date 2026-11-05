-- Builds the whole town the way the server does, in Lune, and checks it:
-- every part and light property is real (a wrong one errors here as in
-- Studio), the town stays inside its part and light budget, and every node
-- can be gathered.

local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Town = RobloxLoader.require("src/shared/World/Town")
local Map = RobloxLoader.require("src/shared/Config/Map")
local roblox = RobloxLoader.roblox

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- The most parts and lights the town may use, leaving room for what players
-- build (Balance.Build.MaxStructures, each under its Parts limit).
local PART_BUDGET = 3000
local LIGHT_BUDGET = 30

local built = nil
local function town()
	if not built then
		local folder = roblox.Instance.new("Folder")
		built = Town.build(folder)
	end
	return built
end

local function count(root, predicate): number
	local n = 0
	for _, descendant in root:GetDescendants() do
		if predicate(descendant) then
			n += 1
		end
	end
	return n
end

describe("town", function()
	it("stays within the part and light budgets", function()
		local folder = town().Folder
		local parts = count(folder, function(i)
			return i:IsA("BasePart")
		end)
		local lights = count(folder, function(i)
			return i:IsA("Light")
		end)
		print(`        town: {parts} parts, {lights} lights`)
		assert(parts <= PART_BUDGET, `town uses {parts} parts`)
		assert(lights <= LIGHT_BUDGET, `town uses {lights} lights`)
	end)

	it("anchors every part", function()
		for _, descendant in town().Folder:GetDescendants() do
			if descendant:IsA("BasePart") then
				assert(descendant.Anchored, `{descendant:GetFullName()} is not anchored`)
			end
		end
	end)

	it("gives every node a kind and a part to hold the prompt", function()
		local kinds = {}
		for _, node in town().Nodes do
			local kind = node:GetAttribute("Node")
			assert(kind, `{node.Name} has no Node attribute`)
			assert(node.PrimaryPart and node.PrimaryPart.Name == "Hit", `{node.Name} has no Hit part`)
			kinds[kind] = (kinds[kind] or 0) + 1
		end
		for _, kind in { "Pine", "Rock", "CoalSeam", "Salvage", "FishingHole", "BerryBush" } do
			assert((kinds[kind] or 0) > 0, `the town has no {kind}`)
		end
		assert(kinds.Pine >= Map.Trees * 0.9, `only {kinds.Pine} trees found room`)
	end)

	it("puts a frozen-part spot in every landmark and decor spots on every cabin", function()
		for _, landmark in Map.Landmarks do
			local model = town().Landmarks[landmark.Id]
			assert(model:FindFirstChild("PartSpot", true), `{landmark.Id} has no PartSpot`)
		end
		expect(#town().Cabins).toBe(Map.CabinCount)
		for _, cabin in town().Cabins do
			for _, spot in { "Roof", "Door", "Porch", "Yard", "Flag" } do
				assert(cabin:FindFirstChild(spot, true), `{cabin.Name} has no {spot} spot`)
			end
		end
	end)

	it("gives each station a prompt part", function()
		for _, name in { "Hearth", "Workbench", "Stockpile", "CookPot", "RadioTower" } do
			local model = town()[name]
			assert(model:FindFirstChild("Prompt"), `{name} has no Prompt part`)
		end
	end)
end)

describe("layout", function()
	local layout = Town.layout()

	it("keeps cabins apart from each other and off the monsters' roads", function()
		for i, a in layout.Cabins do
			for j, b in layout.Cabins do
				if i < j then
					local d = math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
					assert(d > 24, `cabins {i} and {j} are {d} apart`)
				end
			end
			-- The monsters walk in along the eight compass lines.
			for index = 0, 7 do
				local angle = index * math.pi / 4
				local ux, uz = math.sin(angle), -math.cos(angle)
				local along = a.X * ux + a.Z * uz
				local off = math.abs(a.X * uz - a.Z * ux)
				assert(along < 0 or off > 14, `cabin {i} sits on a monster road`)
			end
		end
	end)

	it("keeps the cabins clear of the lodge", function()
		for i, cabin in layout.Cabins do
			local dx = math.abs(cabin.X - Map.Lodge[1])
			local dz = math.abs(cabin.Z - Map.Lodge[2])
			assert(dx > 16 + 8 or dz > 11 + 8, `cabin {i} overlaps the lodge`)
		end
	end)

	it("keeps trees off the roads, the lake and the base", function()
		for _, tree in layout.Trees do
			local d = math.sqrt(tree.X ^ 2 + tree.Z ^ 2)
			assert(d >= 95, "a tree grows in the base")
			local lake = math.sqrt((tree.X - Map.Lake.At[1]) ^ 2 + (tree.Z - Map.Lake.At[2]) ^ 2)
			assert(lake > Map.Lake.Radius, "a tree grows on the lake")
		end
	end)

	it("puts every fishing hole on the lake and off the lighthouse islet", function()
		local lighthouse = Map.LandmarkById.Lighthouse.At
		for _, hole in layout.Holes do
			local lake = math.sqrt((hole.X - Map.Lake.At[1]) ^ 2 + (hole.Z - Map.Lake.At[2]) ^ 2)
			assert(lake < Map.Lake.Radius - 4, "a fishing hole is off the lake")
			local islet = math.sqrt((hole.X - lighthouse[1]) ^ 2 + (hole.Z - lighthouse[2]) ^ 2)
			assert(islet > 16, "a fishing hole is on the lighthouse islet")
		end
	end)

	it("spawns monsters inside the valley wall", function()
		for _, spawn in layout.Spawns do
			assert(math.sqrt(spawn.X ^ 2 + spawn.Z ^ 2) < Map.WallRadius - 20, "a spawn point is in the mountains")
		end
	end)
end)
