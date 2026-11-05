-- What the game reports and celebrates: the analytics funnels, the team
-- milestones, and a check of the source that every sound, milestone and
-- funnel step the code names really exists (a typo there fails silently
-- in game, so it is caught here instead).

local fs = require("@lune/fs")
local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Funnel = RobloxLoader.require("src/shared/Funnel")
local Milestones = RobloxLoader.require("src/shared/Milestones")
local Sounds = RobloxLoader.require("src/shared/Config/Sounds")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Every .luau file under a folder, read as text.
local function sources(folder: string): { [string]: string }
	local found = {}
	local function walk(path: string)
		for _, name in fs.readDir(path) do
			local full = `{path}/{name}`
			if fs.isDir(full) then
				walk(full)
			elseif string.sub(name, -5) == ".luau" then
				found[full] = fs.readFile(full)
			end
		end
	end
	walk(folder)
	return found
end

-- Every string literal passed to a call matching the pattern (e.g.
-- "Sounds%.play"), as its first argument or, with second set, its second;
-- with the file it is in.
local function named(folder: string, call: string, second: boolean?): { { Name: string, File: string } }
	local list = {}
	local pattern = call .. (if second then '%(%s*[^,%)]+,%s*"([%w_]+)"' else '%(%s*"([%w_]+)"')
	for file, text in sources(folder) do
		for name in string.gmatch(text, pattern) do
			table.insert(list, { Name = name, File = file })
		end
	end
	return list
end

describe("funnels", function()
	it("counts each step once, with its place in the funnel", function()
		local record = Funnel.new(Funnel.Onboarding)
		expect(Funnel.mark(record, "Joined")).toBe(1)
		expect(Funnel.mark(record, "Joined")).toBe(nil)
		expect(Funnel.mark(record, "FedHearth")).toBe(5)
		expect(Funnel.mark(record, "NotAStep")).toBe(nil)
	end)

	it("keeps run steps apart from first-time steps", function()
		local run = Funnel.new(Funnel.Run)
		expect(Funnel.mark(run, "Started")).toBe(1)
		expect(Funnel.mark(run, "PickedRole")).toBe(nil)
	end)

	it("only reports steps the funnels list", function()
		local known = {}
		for _, step in Funnel.Onboarding do
			known[step] = true
		end
		for _, step in Funnel.Run do
			known[step] = true
		end
		local used = named("src/server", "Analytics%.step", true)
		assert(#used >= 10, `found {#used} reported steps`)
		for _, use in used do
			assert(known[use.Name], `{use.File} reports unknown step {use.Name}`)
		end
	end)
end)

describe("milestones", function()
	it("come in order, each later than the one before", function()
		local last = 0
		for _, milestone in Milestones.List do
			assert(milestone.Minute > last, `{milestone.Id} comes after the one before`)
			last = milestone.Minute
			expect(Milestones.ById[milestone.Id]).toBe(milestone)
		end
	end)

	it("puts something to celebrate in the first few minutes", function()
		assert(Milestones.List[1].Minute <= 5, "an early win")
		local gaps = 0
		for index = 2, #Milestones.List do
			gaps = math.max(gaps, Milestones.List[index].Minute - Milestones.List[index - 1].Minute)
		end
		assert(gaps <= 15, `no more than 15 minutes between milestones (longest {gaps})`)
	end)

	it("only celebrates milestones that exist", function()
		local used = named("src/server", "Celebrate%.milestone")
		assert(#used >= 5, `found {#used} celebrations`)
		local seen = {}
		for _, use in used do
			assert(Milestones.ById[use.Name], `{use.File} celebrates unknown milestone {use.Name}`)
			seen[use.Name] = true
		end
		for _, milestone in Milestones.List do
			assert(seen[milestone.Id], `nothing celebrates {milestone.Id}`)
		end
	end)
end)

describe("sound audit", function()
	it("plays only sounds that exist", function()
		local used = {}
		for _, call in { "Sounds%.play", "Sounds%.at", "Sounds%.get" } do
			for _, use in named("src/client", call) do
				table.insert(used, use)
			end
		end
		assert(#used >= 30, `found {#used} sound calls`)
		for _, use in used do
			assert(Sounds[use.Name] ~= nil, `{use.File} plays unknown sound {use.Name}`)
		end
	end)
end)
