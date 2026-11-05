-- The results card's recap (Rules/Recap) and the role mastery goals
-- (Config/Mastery, Rules/Mastery).

local fs = require("@lune/fs")
local Loader = require("./RobloxLoader")
local TestKit = require("./TestKit")

local Recap = Loader.require("src/shared/Rules/Recap")
local Mastery = Loader.require("src/shared/Rules/Mastery")
local MasteryConfig = Loader.require("src/shared/Config/Mastery")
local Roles = Loader.require("src/shared/Config/Roles")
local Round = Loader.require("src/shared/Rules/Round")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function entry(name: string, role: string, overrides: { [string]: any }?): any
	local made = {
		UserId = #name * 100 + 1,
		Name = name,
		Role = role,
		State = "Alive",
		Hero = false,
		Takedown = false,
		Tags = 0,
		Revives = 0,
		Clues = 0,
	}
	for key, value in overrides or {} do
		(made :: any)[key] = value
	end
	return made
end

local function party(): { any }
	return {
		entry("Vex", "Phantom"),
		entry("Juno", "Guardian"),
		entry("Pip", "Medic"),
		entry("Ash", "Guest"),
		entry("Bo", "Guest"),
	}
end

local function facts(role: string, overrides: { [string]: any }?): any
	local made = {
		Role = role,
		Won = false,
		Survived = false,
		BellRang = false,
		Misfired = false,
		Hero = false,
		Dawn = false,
		Takedown = false,
		Tags = 0,
		Revives = 0,
		Clues = 0,
		BlackoutsUsed = 0,
	}
	for key, value in overrides or {} do
		made[key] = value
	end
	return made
end

describe("the decisive moment", function()
	it("names who caught the Phantom and the time to spare", function()
		local line = Recap.decisive("PhantomOut", 73, party(), { Catch = { By = "Juno", Hero = false } })
		expect(line).toBe("Juno unmasked Vex, with 1:13 to spare!")
	end)

	it("says when a borrowed blaster made the catch", function()
		local line = Recap.decisive("PhantomOut", 5, party(), { Catch = { By = "Bo", Hero = true } })
		expect(line).toBe("Bo unmasked Vex with a borrowed blaster, with 0:05 to spare!")
	end)

	it("falls back to the takedown flag if the moment wasn't seen", function()
		local entries = party()
		entries[2].Takedown = true
		expect(Recap.decisive("PhantomOut", 0, entries, {})).toBe("Juno unmasked Vex, with 0:00 to spare!")
	end)

	it("names the last tag, and doesn't blame the Phantom for a misfire", function()
		local tagged =
			Recap.decisive("AllTagged", 0, party(), { LastDown = { By = "Vex", Target = "Bo", How = "Swing" } })
		expect(tagged).toBe("Vex tagged Bo, the last guest standing.")
		local misfire =
			Recap.decisive("AllTagged", 0, party(), { LastDown = { By = nil, Target = "Juno", How = "Misfire" } })
		expect(misfire).toBe("A misfired zap knocked out the last guests standing.")
	end)

	it("counts who saw dawn", function()
		local entries = party()
		entries[4].State = "Out"
		entries[5].State = "Dazed"
		expect(Recap.decisive("Time", 0, entries, {})).toBe("Dawn broke with 2 guests still standing!")
		entries[3].State = "Out"
		expect(Recap.decisive("Time", 0, entries, {})).toBe("Dawn broke with one guest still standing!")
	end)

	it("has a line for every way a round can end", function()
		for reason in Round.REASONS do
			local line = Recap.decisive(reason, 30, party(), {})
			assert(type(line) == "string" and #line > 0, `no line for {reason}`)
			assert(#line <= 90, `{reason} line too long: {line}`)
		end
	end)
end)

describe("the party star", function()
	it("is nobody when no guest did more than stand there", function()
		expect(Recap.star(party())).toBe(nil)
	end)

	it("favours revives and pages over just surviving", function()
		local entries = party()
		entries[3].Revives = 2
		entries[3].State = "Out"
		entries[4].Clues = 3
		local star = Recap.star(entries)
		-- Pip: 2 revives = 6; Ash: 3 pages + survived = 7.
		expect(star.Name).toBe("Ash")
		expect(star.Why).toBe("3 clue pages, made it through")
		entries[3].Revives = 3
		expect(Recap.star(entries).Name).toBe("Pip")
	end)

	it("never picks a Shadow, a practice stand-in or the catch itself", function()
		local entries = party()
		entries[1].Clues = 9
		entries[2].Takedown = true
		entries[5].UserId = -3
		entries[5].Clues = 9
		expect(Recap.star(entries)).toBe(nil)
	end)

	it("caps pages the same way pay does", function()
		local entries = party()
		entries[4].Clues = 50
		entries[5].Revives = 4
		-- Ash: 10 (capped) + 4 = 14; Bo: 12 + 4 = 16.
		expect(Recap.star(entries).Name).toBe("Bo")
	end)

	it("breaks ties the same way every time", function()
		local entries = party()
		entries[4].Clues = 2
		entries[5].Clues = 2
		expect(Recap.star(entries).Name).toBe("Ash")
	end)
end)

describe("mastery goals", function()
	it("has two or three goals for every role, with unique ids and short text", function()
		local ids = {}
		local perRole = {}
		for _, goal in MasteryConfig.List do
			assert(not ids[goal.Id], `duplicate goal {goal.Id}`)
			ids[goal.Id] = true
			assert(Roles.List[goal.Role], `{goal.Id} has no real role`)
			assert(#goal.Text <= 70, `{goal.Id} text too long`)
			perRole[goal.Role] = (perRole[goal.Role] or 0) + 1
		end
		for roleId in Roles.List do
			local count = perRole[roleId] or 0
			assert(count >= 2 and count <= 3, `{roleId} has {count} goals`)
		end
	end)

	it("only asks for things that help the player's team", function()
		for _, goal in MasteryConfig.List do
			-- Every goal needs a win, a catch or a revive; none can be met by
			-- losing on purpose.
			local helps = goal.Won == true or goal.Takedown == true or (goal.Min and (goal.Min.Revives or 0) > 0)
			assert(helps, `{goal.Id} could be met by throwing the round`)
			expect(goal.Misfired == true).toBe(false)
		end
	end)

	it("meets each goal exactly when its conditions hold", function()
		local function has(list: { any }, id: string): boolean
			for _, goal in list do
				if goal.Id == id then
					return true
				end
			end
			return false
		end
		expect(has(Mastery.earned(facts("Phantom", { Won = true })), "phantom_silent")).toBe(true)
		expect(has(Mastery.earned(facts("Phantom", { Won = true, BellRang = true })), "phantom_silent")).toBe(false)
		expect(has(Mastery.earned(facts("Phantom", { Won = true, Tags = 3 })), "phantom_triple")).toBe(true)
		expect(has(Mastery.earned(facts("Phantom", { Won = false, Tags = 5 })), "phantom_triple")).toBe(false)
		expect(has(Mastery.earned(facts("Guardian", { Takedown = true })), "guardian_clean")).toBe(true)
		expect(has(Mastery.earned(facts("Guardian", { Takedown = true, Misfired = true })), "guardian_clean")).toBe(
			false
		)
		expect(has(Mastery.earned(facts("Medic", { Revives = 2 })), "medic_field")).toBe(true)
		expect(has(Mastery.earned(facts("Guest", { Won = true, Survived = true, Dawn = true })), "guest_dawn")).toBe(
			true
		)
		expect(has(Mastery.earned(facts("Guest", { Won = true, Survived = true })), "guest_dawn")).toBe(false)
		-- A goal never counts for a different role.
		expect(#Mastery.earned(facts("Saboteur", { Revives = 5, Takedown = true }))).toBe(0)
		expect(has(Mastery.earned(facts("Saboteur", { Won = true, BlackoutsUsed = 2 })), "saboteur_lights")).toBe(true)
	end)

	it("counts each goal in the save and reports the new count", function()
		local saved = { guest_dawn = 2 }
		local shown =
			Mastery.record(saved, Mastery.earned(facts("Guest", { Won = true, Survived = true, Dawn = true })))
		expect(saved.guest_dawn).toBe(3)
		expect(shown[1].Count).toBe(3)
		expect(shown[1].Name).toBe("Dawn Survivor")
		-- A junk value in an old save doesn't break the count.
		local junk = { guest_dawn = "lots" } :: any
		Mastery.record(junk, Mastery.earned(facts("Guest", { Won = true, Survived = true, Dawn = true })))
		expect(junk.guest_dawn).toBe(1)
	end)

	it("pays nothing: no goal or record touches coins, XP or items", function()
		local source = fs.readFile("src/shared/Rules/Mastery.luau") .. fs.readFile("src/shared/Config/Mastery.luau")
		for _, word in { "Coins", "Xp", "Items", "addCoins", "Grant" } do
			assert(not string.find(source, word, 1, true), `mastery mentions {word}`)
		end
	end)
end)

return nil
