-- A walk-through of both party maps (tests/MapCheck): nobody spawns in a
-- wall or on top of someone's blade, and every spawn, clue page, candy
-- coin and secret passage end can be walked to from the first spawn. The
-- check's assumptions are listed at the top of tests/MapCheck.

local Loader = require("./RobloxLoader")
local MapCheck = require("./MapCheck")
local TestKit = require("./TestKit")

local roblox = Loader.roblox
local CombatConfig = Loader.require("src/shared/Config/Combat")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local MAPS = { "Manor", "Carnival" }
-- How far below a marker the floor may be: a page or coin floats 2.2
-- studs up, a spawn (the character's middle) 3.
local FLOOR_REACH = { Spawns = 4, Clues = 4, Coins = 4 }

local function positionOf(marker: any): any
	local part = if marker:IsA("BasePart") then marker else marker:FindFirstChildWhichIsA("BasePart", true)
	return part.CFrame.Position
end

local checked = {}
local function walk(name: string): any
	if checked[name] then
		return checked[name]
	end
	local module = Loader.require(`src/shared/Look/Maps/{name}`)
	local model = module.build(roblox.CFrame.new(0, 0, 900))
	local grid = MapCheck.grid(model)
	local links = {}
	local ends = {}
	for _, passage in model:FindFirstChild("Passages"):GetChildren() do
		local pair = {}
		for _, side in { "A", "B" } do
			local spot = positionOf(passage:FindFirstChild(side))
			local index, height = MapCheck.standAt(grid, spot.X, spot.Y, spot.Z, 6)
			table.insert(ends, { Name = `{passage.Name}.{side}`, Index = index, Height = height })
			pair[side] = if index then { index, height } else nil
		end
		if pair.A and pair.B then
			table.insert(links, { pair.A, pair.B })
		end
	end
	local first = positionOf(model:FindFirstChild("Spawns"):GetChildren()[1])
	local startIndex, startHeight = MapCheck.standAt(grid, first.X, first.Y, first.Z, FLOOR_REACH.Spawns)
	assert(startIndex, `{name}: the first spawn has no floor`)
	local seen = MapCheck.flood(grid, startIndex, startHeight, links)
	checked[name] = { Model = model, Grid = grid, Seen = seen, Ends = ends }
	return checked[name]
end

describe("map walk-through", function()
	for _, name in MAPS do
		for _, folder in { "Spawns", "Clues", "Coins" } do
			it(`{name}: every one of its {string.lower(folder)} is clear, on a floor and reachable`, function()
				local map = walk(name)
				local problems = {}
				for _, marker in map.Model:FindFirstChild(folder):GetChildren() do
					local spot = positionOf(marker)
					local label =
						`{marker.Name} at {math.floor(spot.X)}, {math.floor(spot.Y)}, {math.floor(spot.Z - 900)}`
					-- A spawn is a whole character: check its feet, middle and head.
					local heights = if folder == "Spawns" then { -2, 0, 1.5 } else { 0 }
					for _, offset in heights do
						if MapCheck.solidAt(map.Grid, spot.X, spot.Y + offset, spot.Z) then
							table.insert(problems, `{label} is inside something solid`)
							break
						end
					end
					local index, height = MapCheck.standAt(map.Grid, spot.X, spot.Y, spot.Z, FLOOR_REACH[folder])
					if not index then
						table.insert(problems, `{label} has no floor under it`)
					elseif not MapCheck.reached(map.Seen, index, height :: number) then
						table.insert(problems, `{label} can't be walked to`)
					end
				end
				assert(#problems == 0, table.concat(problems, "; "))
			end)
		end

		it(`{name}: both ends of every secret passage can be walked to`, function()
			local map = walk(name)
			for _, finish in map.Ends do
				assert(finish.Index, `{finish.Name} has no floor`)
				assert(MapCheck.reached(map.Seen, finish.Index, finish.Height), `{finish.Name} can't be walked to`)
			end
		end)

		it(`{name}: spawns are further apart than a blade can reach`, function()
			local spawns = walk(name).Model:FindFirstChild("Spawns"):GetChildren()
			local closest = math.huge
			for i = 1, #spawns do
				for j = i + 1, #spawns do
					closest = math.min(closest, (positionOf(spawns[i]) - positionOf(spawns[j])).Magnitude)
				end
			end
			-- The blade's reach plus a body's width.
			expect(closest > CombatConfig.Blade.Reach + 2).toBe(true)
		end)
	end

	it("the checker itself sees walls and floors", function()
		local model = roblox.Instance.new("Model")
		local function slab(position: any, size: any)
			local part = roblox.Instance.new("Part")
			part.Anchored = true
			part.Size = size
			part.CFrame = roblox.CFrame.new(position)
			part.Parent = model
		end
		slab(roblox.Vector3.new(0, -1, 0), roblox.Vector3.new(60, 2, 60))
		-- A wall across the middle, too tall to climb, with no gap.
		slab(roblox.Vector3.new(0, 10, 0), roblox.Vector3.new(2, 20, 60))
		local grid = MapCheck.grid(model)
		local leftIndex, leftHeight = MapCheck.standAt(grid, -10, 3, 0, 4)
		local rightIndex, rightHeight = MapCheck.standAt(grid, 10, 3, 0, 4)
		assert(leftIndex and rightIndex, "no floor found")
		local seen = MapCheck.flood(grid, leftIndex, leftHeight)
		expect(MapCheck.reached(seen, rightIndex, rightHeight)).toBe(false)
		expect(MapCheck.solidAt(grid, 0, 5, 0)).toBe(true)
		-- A passage through the wall joins the two sides.
		local joined =
			MapCheck.flood(grid, leftIndex, leftHeight, { { { leftIndex, leftHeight }, { rightIndex, rightHeight } } })
		expect(MapCheck.reached(joined, rightIndex, rightHeight)).toBe(true)
	end)
end)

return nil
