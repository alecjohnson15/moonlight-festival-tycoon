local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local World = RobloxLoader.require("src/shared/Build/World")
local Layout = RobloxLoader.require("src/shared/Config/Layout")
local roblox = RobloxLoader.roblox

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Mobile players need the map to stay light.
local PART_BUDGET = 2600
local LIGHT_BUDGET = 70

describe("World", function()
	it("builds the whole map without errors and within budget", function()
		local workspace = roblox.Instance.new("Folder")
		local refs = World.build(workspace)
		local parts, lights = 0, 0
		for _, descendant in refs.Root:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
			elseif descendant:IsA("Light") then
				lights += 1
			end
		end
		print(`        {parts} parts, {lights} lights`)
		assert(parts <= PART_BUDGET, `{parts} parts is over the budget of {PART_BUDGET}`)
		assert(lights <= LIGHT_BUDGET, `{lights} lights is over the budget of {LIGHT_BUDGET}`)
		for _, name in { "PlazaScreen", "StageScreen", "BackstageScreen", "Leaderboard", "HallOfFame", "VipGate" } do
			assert(refs[name] ~= nil, `missing {name}`)
		end
		for _, name in { "Boutique", "StylePass", "Closet", "Challenges", "Vip" } do
			assert(refs.Prompts[name], `missing prompt {name}`)
		end
		expect(#refs.LaneLights.A).toBe(2)
	end)

	it("sets up the lighting", function()
		local lighting = roblox.Instance.new("Folder")
		World.lighting(lighting)
		assert(lighting:FindFirstChildOfClass("Atmosphere"), "no atmosphere")
	end)

	it("has a booth for every player and room for an audience", function()
		expect(#Layout.Booths).toBe(12)
		assert(#Layout.Audience >= 24, "not enough audience spots")
		expect(#Layout.LobbyRing).toBe(12)
	end)
end)
