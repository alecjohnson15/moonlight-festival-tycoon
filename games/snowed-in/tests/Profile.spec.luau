-- The save: owning things, run rewards, the Expedition Pass and migrations.

local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Profile = RobloxLoader.require("src/shared/Profile")
local Migrations = RobloxLoader.require("src/server/Lib/Migrations")
local Expedition = RobloxLoader.require("src/shared/Config/Expedition")
local Balance = RobloxLoader.require("src/shared/Config/Balance")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function fresh()
	local save = Migrations.new()
	Profile.tidy(save, Profile.noGrants())
	return save
end

describe("owning things", function()
	it("gives everyone the free roles and the starter decorations", function()
		local save = fresh()
		local grants = Profile.noGrants()
		expect(Profile.ownsRole(save, grants, "Scout")).toBe(true)
		expect(Profile.ownsRole(save, grants, "Cook")).toBe(true)
		expect(Profile.ownsRole(save, grants, "Medic")).toBe(false)
		expect(save.Cabin.Roof).toBe("PlainRoof")
		expect(Profile.ownsDecor(save, grants, "PlainRoof")).toBe(true)
	end)

	it("unlocks a role with snowflakes or its pass, the same role either way", function()
		local save = fresh()
		local grants = Profile.noGrants()
		save.Flakes = 700
		local ok = Profile.buy(save, grants, "Ranger")
		expect(ok).toBe(true)
		expect(save.Flakes).toBe(100)
		expect(Profile.ownsRole(save, grants, "Ranger")).toBe(true)
		local other = fresh()
		local passGrants = Profile.noGrants()
		passGrants.Roles.Medic = true
		expect(Profile.ownsRole(other, passGrants, "Medic")).toBe(true)
	end)

	it("won't sell pass, trophy or tier items for snowflakes", function()
		local save = fresh()
		save.Flakes = 10000
		local grants = Profile.noGrants()
		expect((Profile.buy(save, grants, "AuroraCape"))).toBe(false)
		expect((Profile.buy(save, grants, "YetiHood"))).toBe(false)
		expect((Profile.buy(save, grants, "SnowOwl"))).toBe(false)
		expect((Profile.buy(save, grants, "BobbleHat"))).toBe(true)
		expect((Profile.buy(save, grants, "BobbleHat"))).toBe(false)
	end)

	it("only equips what the player owns, in its own slot", function()
		local save = fresh()
		local grants = Profile.noGrants()
		expect(Profile.equip(save, grants, "Hat", "BobbleHat")).toBe(false)
		save.Owned.BobbleHat = true
		expect(Profile.equip(save, grants, "Back", "BobbleHat")).toBe(false)
		expect(Profile.equip(save, grants, "Hat", "BobbleHat")).toBe(true)
		expect(save.Equipped.Hat).toBe("BobbleHat")
		expect(Profile.equip(save, grants, "Hat", "")).toBe(true)
		expect(save.Equipped.Hat).toBe(nil)
	end)

	it("puts decorations back to the default when a pass goes away", function()
		local save = fresh()
		local grants = Profile.noGrants()
		grants.Decor.SnowGlobe = true
		expect(Profile.decorate(save, grants, "Yard", "SnowGlobe")).toBe(true)
		Profile.tidy(save, Profile.noGrants())
		expect(save.Cabin.Yard).toBe("EmptyYard")
	end)
end)

describe("run rewards", function()
	it("pays for nights, parts, the win and knockouts", function()
		local rewards = Balance.Rewards
		local flakes = Profile.runFlakes({ Nights = 10, Parts = 4, Won = true, Knockouts = 12 })
		expect(flakes).toBe(10 * rewards.PerNight + 4 * rewards.PerPart + rewards.Win + 2)
	end)

	it("records trophies and stats", function()
		local save = fresh()
		Profile.finishRun(save, { Nights = 10, Parts = 4, Won = true, Knockouts = 30 }, true)
		expect(save.Trophies.Rescue).toBe(true)
		expect(save.Trophies.Yeti).toBe(true)
		expect(save.Stats.Wins).toBe(1)
		expect(save.Stats.BestNight).toBe(10)
		expect(Profile.ownsCosmetic(save, Profile.noGrants(), "HuskyPup")).toBe(true)
		expect(Profile.ownsDecor(save, Profile.noGrants(), "YetiTrophy")).toBe(true)
	end)
end)

describe("expedition pass", function()
	it("pays each free tier once as XP reaches it", function()
		local save = fresh()
		save.Xp = Expedition.TierXp * 2
		local given = Profile.claim(save, false)
		expect(#given).toBe(2)
		expect(save.ClaimedFree).toBe(2)
		expect(save.Owned.EmberBrazier).toBe(true)
		expect(#Profile.claim(save, false)).toBe(0)
	end)

	it("pays the premium rewards already reached when premium is bought later", function()
		local save = fresh()
		save.Xp = Expedition.TierXp * 4
		Profile.claim(save, false)
		expect(save.ClaimedPremium).toBe(0)
		Profile.claim(save, true)
		expect(save.ClaimedPremium).toBe(4)
		expect(save.Owned.AntlerBeanie).toBe(true)
		expect(save.Owned.IceSculpture).toBe(true)
	end)

	it("pays bonus snowflakes after the end of the track", function()
		local save = fresh()
		save.Xp = Expedition.TierXp * (#Expedition.Tiers + 3)
		Profile.claim(save, false)
		expect(save.BonusClaimed).toBe(3)
	end)

	it("takes several wins to finish, not one", function()
		local perWin = Profile.runFlakes({ Nights = 10, Parts = 4, Won = true, Knockouts = 40 })
			* Balance.Rewards.XpPerFlake
		local wins = Expedition.TierXp * #Expedition.Tiers / perWin
		assert(wins > 3 and wins < 12, `the pass takes {wins} wins to finish`)
	end)
end)

describe("save migrations", function()
	it("makes a complete save for a new player", function()
		local save = Migrations.run(nil)
		expect(save.SchemaVersion).toBe(Migrations.CURRENT_VERSION)
		expect(save.Stats.Wins).toBe(0)
	end)

	it("fills in fields an older save lacks", function()
		local save = Migrations.run({ SchemaVersion = 1, Flakes = 40 })
		expect(save.Flakes).toBe(40)
		expect(save.Stats.Runs).toBe(0)
		expect(type(save.Receipts.Ids)).toBe("table")
	end)

	it("refuses a save from a newer server", function()
		local save, err = Migrations.run({ SchemaVersion = Migrations.CURRENT_VERSION + 1 })
		expect(save).toBe(nil)
		expect(err).toBe("FutureVersion")
		expect(Migrations.isFuture({ SchemaVersion = Migrations.CURRENT_VERSION + 1 })).toBe(true)
	end)
end)
