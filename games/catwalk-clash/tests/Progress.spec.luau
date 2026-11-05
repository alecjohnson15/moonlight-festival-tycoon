local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Progress = RobloxLoader.require("src/shared/Progress")
local ThemePicker = RobloxLoader.require("src/shared/ThemePicker")
local Look = RobloxLoader.require("src/shared/Look")
local Funnel = RobloxLoader.require("src/server/Lib/Funnel")
local Season = RobloxLoader.require("src/shared/Config/Season")
local Quests = RobloxLoader.require("src/shared/Config/Quests")
local Themes = RobloxLoader.require("src/shared/Config/Themes")
local Wardrobe = RobloxLoader.require("src/shared/Config/Wardrobe")
local Palette = RobloxLoader.require("src/shared/Config/Palette")
local Poses = RobloxLoader.require("src/shared/Config/Poses")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local open = Season.Starts + 3600

describe("Style Pass", function()
	it("reports each tier reached while the season is open", function()
		local pass = Progress.newPass(Season.Id)
		local reached = Progress.addXp(pass, Season, Season.XpPerTier * 2 + 10, open)
		expect(reached).toEqual({ 1, 2 })
		expect(#Progress.addXp(pass, Season, 10, open)).toBe(0)
		expect(#Progress.addXp(pass, Season, 99999, Season.Ends)).toBe(0)
		expect(Progress.tier(Season, 10 ^ 9)).toBe(#Season.Tiers)
	end)

	it("only lets reached, unclaimed tiers be claimed, premium with the pass", function()
		local pass = Progress.newPass(Season.Id)
		Progress.addXp(pass, Season, Season.XpPerTier * 3, open)
		expect((Progress.canClaim(pass, Season, 2, "Free", false))).toBe(true)
		expect(select(2, Progress.canClaim(pass, Season, 4, "Free", false))).toBe("Locked")
		expect(select(2, Progress.canClaim(pass, Season, 2, "Premium", false))).toBe("NeedPass")
		expect((Progress.canClaim(pass, Season, 2, "Premium", true))).toBe(true)
		pass.Free["2"] = true
		expect(select(2, Progress.canClaim(pass, Season, 2, "Free", false))).toBe("Claimed")
		expect(select(2, Progress.canClaim(pass, Season, 1.5, "Free", false))).toBe("NoTier")
		expect(select(2, Progress.canClaim(pass, Season, "2", "Free", false))).toBe("NoTier")
		expect(select(2, Progress.canClaim(pass, Season, 2, "Gold", false))).toBe("NoTrack")
	end)

	it("starts a fresh pass when a new season begins", function()
		local old = Progress.newPass("S0")
		old.Xp = 5000
		expect(Progress.passFor(old, Season).Xp).toBe(0)
		local current = Progress.newPass(Season.Id)
		expect(Progress.passFor(current, Season)).toBe(current)
	end)

	it("stops XP when the season ends but keeps reached rewards claimable", function()
		-- What the pass board promises after 1 February 2027: "Claim any
		-- rewards you reached; they're yours to keep."
		local pass = Progress.newPass(Season.Id)
		Progress.addXp(pass, Season, Season.XpPerTier * 4, open)
		local after = Season.Ends + 30 * 86400
		expect(Progress.seasonOpen(Season, after)).toBe(false)
		expect(#Progress.addXp(pass, Season, Season.XpPerTier * 10, after)).toBe(0)
		expect(Progress.tier(Season, pass.Xp)).toBe(4)
		expect((Progress.canClaim(pass, Season, 4, "Free", false))).toBe(true)
		expect(select(2, Progress.canClaim(pass, Season, 5, "Free", false))).toBe("Locked")
		-- Season 1's dates are real and the pass ends after it starts.
		expect(Season.Ends > Season.Starts).toBe(true)
		expect(os.date("!%Y-%m-%d", Season.Ends)).toBe("2027-02-01")
	end)
end)

describe("Daily challenges", function()
	it("gives everyone the same three different challenges each day", function()
		local first = Progress.questsFor(Quests, 20000, 3)
		expect(first).toEqual(Progress.questsFor(Quests, 20000, 3))
		expect(#first).toBe(3)
		expect(first[1] ~= first[2] and first[2] ~= first[3] and first[1] ~= first[3]).toBe(true)
		local changed = false
		for day = 20001, 20010 do
			changed = changed or not TestKit.equal(first, Progress.questsFor(Quests, day, 3))
		end
		expect(changed).toBe(true)
	end)

	it("counts events towards the goal and completes each challenge once", function()
		local state = Progress.questsToday(nil, Quests, 20000)
		local quest
		for _, entry in Quests do
			if entry.Id == state.Ids[1] then
				quest = entry
			end
		end
		local done = Progress.recordQuest(state, Quests, quest.Event, quest.Goal + 5)
		expect(#done >= 1).toBe(true)
		expect(state.Progress[1]).toBe(quest.Goal)
		expect(state.Done[1]).toBe(true)
		for _, again in Progress.recordQuest(state, Quests, quest.Event, 1) do
			expect(again.Id ~= quest.Id).toBe(true)
		end
		expect(Progress.questsToday(state, Quests, 20000)).toBe(state)
		expect(Progress.questsToday(state, Quests, 20001).Day).toBe(20001)
	end)
end)

describe("Login streak", function()
	it("grows on back-to-back days and starts over after a gap", function()
		local streak = { LastDay = 0, Count = 0 }
		expect(Progress.claimStreak(streak, 100)).toBe(1)
		expect(Progress.claimStreak(streak, 100)).toBe(nil)
		expect(Progress.claimStreak(streak, 101)).toBe(2)
		expect(Progress.claimStreak(streak, 102)).toBe(3)
		expect(Progress.claimStreak(streak, 105)).toBe(1)
	end)

	it("repeats the last reward once the list runs out", function()
		expect(Progress.streakReward({ 10, 20, 30 }, 2)).toBe(20)
		expect(Progress.streakReward({ 10, 20, 30 }, 9)).toBe(30)
	end)
end)

describe("Theme picker", function()
	local october = os.time({ year = 2027, month = 10, day = 20, hour = 12 })
	local march = os.time({ year = 2027, month = 3, day = 2, hour = 12 })

	local function counter(seed)
		local state = seed
		return function(n)
			state = (state * 48271) % 2147483647
			return state % n + 1
		end
	end

	it("handles windows that wrap past New Year", function()
		local window = { From = { 12, 1 }, To = { 1, 6 } }
		expect(ThemePicker.inWindow(window, 12, 25)).toBe(true)
		expect(ThemePicker.inWindow(window, 1, 3)).toBe(true)
		expect(ThemePicker.inWindow(window, 2, 1)).toBe(false)
	end)

	it("only offers seasonal themes in season", function()
		local _, inOctober = ThemePicker.available(Themes.List, october)
		local _, inMarch = ThemePicker.available(Themes.List, march)
		expect(#inOctober >= 1).toBe(true)
		for _, theme in inMarch do
			expect(ThemePicker.inWindow(theme.Window, 3, 2)).toBe(true)
		end
	end)

	it("offers three different themes with the spotlight and a seasonal one", function()
		local options = ThemePicker.options(Themes.List, october, {}, counter(3), 3)
		expect(#options).toBe(3)
		expect(options[1] ~= options[2] and options[2] ~= options[3] and options[1] ~= options[3]).toBe(true)
		expect(table.find(options, ThemePicker.spotlight(Themes.List, october)) ~= nil).toBe(true)
		local _, seasonal = ThemePicker.available(Themes.List, october)
		local hasSeasonal = false
		for _, theme in seasonal do
			hasSeasonal = hasSeasonal or table.find(options, theme.Id) ~= nil
		end
		expect(hasSeasonal).toBe(true)
	end)

	it("rests recent themes", function()
		local recent = {}
		for index = 1, ThemePicker.REST do
			recent[index] = Themes.List[index].Id
		end
		local spotlight = ThemePicker.spotlight(Themes.List, march)
		for round = 1, 20 do
			for _, id in ThemePicker.options(Themes.List, march, recent, counter(round), 3) do
				if id ~= spotlight then
					expect(table.find(recent, id)).toBe(nil)
				end
			end
		end
	end)

	it("keeps the spotlight for a week, then moves on", function()
		local monday = os.time({ year = 2027, month = 3, day = 1, hour = 1 })
		local sunday = monday + 6 * 86400
		expect(ThemePicker.spotlight(Themes.List, monday)).toBe(ThemePicker.spotlight(Themes.List, sunday))
		expect(ThemePicker.spotlight(Themes.List, monday) ~= ThemePicker.spotlight(Themes.List, sunday + 86400)).toBe(
			true
		)
	end)

	it("picks the most voted theme and breaks ties at random", function()
		local options = { "a", "b", "c" }
		expect(ThemePicker.winner(options, { u1 = 2, u2 = 2, u3 = 1 }, counter(1))).toBe("b")
		local tie = ThemePicker.winner(options, { u1 = 1, u2 = 3 }, counter(1))
		expect(tie == "a" or tie == "c").toBe(true)
		expect(table.find(options, ThemePicker.winner(options, {}, counter(5))) ~= nil).toBe(true)
	end)
end)

describe("Look checks", function()
	local nothing = {
		ownsPiece = function()
			return false
		end,
		ownsPose = function()
			return false
		end,
		ownsEntrance = function()
			return false
		end,
		customColors = false,
		maxCatalog = 3,
	}

	local function freePiece(slot)
		for _, piece in Wardrobe.inSlot(slot) do
			if Wardrobe.source(piece) == "Free" then
				return piece
			end
		end
		error(`no free piece in {slot}`)
	end

	it("turns anything that isn't a look into the default look", function()
		expect(Look.same(Look.sanitize("hello", nothing), Look.default())).toBe(true)
		expect(Look.same(Look.sanitize({ Skin = 0 / 0, Body = 5, Top = "x" }, nothing), Look.default())).toBe(true)
	end)

	it("drops unowned pieces, pieces in the wrong slot and unowned poses", function()
		local ownsFree = table.clone(nothing)
		ownsFree.ownsPiece = function(id)
			return Wardrobe.source(Wardrobe.get(id)) == "Free"
		end
		local hair = freePiece("Hair")
		local paid
		for _, piece in Wardrobe.Pieces do
			if Wardrobe.source(piece) ~= "Free" and piece.Slot ~= "Hair" and piece.Slot ~= "Head" then
				paid = piece
				break
			end
		end
		local look = Look.sanitize({
			Pieces = {
				Hair = { Id = hair.Id, C = 2, A = 3 },
				Head = { Id = hair.Id },
				[paid.Slot] = { Id = paid.Id },
			},
			Pose = Poses.List[#Poses.List].Id,
		}, ownsFree)
		expect(look.Pieces.Hair.Id).toBe(hair.Id)
		expect(look.Pieces.Head).toBe(nil)
		expect(look.Pieces[paid.Slot]).toBe(nil)
		expect(look.Pose).toBe(Poses.Default)
	end)

	it("only allows picked colours with the Color Studio pass", function()
		local raw = { Top = { S = "Tank", C = "#ff00aa", F = "Glow" }, Shoes = { C = 0 } }
		local plain = Look.sanitize(raw, nothing)
		expect(plain.Top.C).toBe(Look.default().Top.C)
		expect(plain.Top.S).toBe("Tank")
		expect(plain.Shoes.C).toBe(0)
		local studio = table.clone(nothing)
		studio.customColors = true
		expect(Look.sanitize(raw, studio).Top.C).toBe("#FF00AA")
		expect(Look.sanitize({ Top = { C = #Palette.Colors + 1 } }, nothing).Top.C).toBe(Look.default().Top.C)
	end)

	it("keeps a few distinct whole catalog ids", function()
		local look = Look.sanitize({ Catalog = { 5, 5, -1, 2.5, "7", 8, 9, 10 } }, nothing)
		expect(look.Catalog).toEqual({ 5, 8, 9 })
	end)

	it("counts the theme tags and colours the judges see", function()
		local look = Look.default()
		local hair = freePiece("Hair")
		look.Pieces.Hair = { Id = hair.Id, C = 1, A = 1, F = "Glow" }
		local summary = Look.summary(look)
		expect(summary.PieceCount).toBe(1)
		expect(summary.Tags[hair.Tags[1]]).toBe(1)
		expect(#summary.Colors).toBe(3)
		expect(summary.Glows).toBe(true)
	end)
end)

describe("Funnel", function()
	local function state(changes)
		local base = {
			Spawned = false,
			Dressed = false,
			Walks = 0,
			Votes = 0,
			Shows = 0,
			Wins = 0,
			SavedLooks = 0,
			Sessions = 1,
		}
		for key, value in changes do
			base[key] = value
		end
		return base
	end

	it("logs steps in order and stops at the first one not reached", function()
		expect(Funnel.toLog(0, state({}))).toEqual({ 1 })
		expect(Funnel.toLog(1, state({ Spawned = true, Dressed = true, Votes = 3 }))).toEqual({ 2, 3 })
		expect(Funnel.toLog(3, state({ Spawned = true, Dressed = true, Walks = 1, Votes = 1 }))).toEqual({ 4, 5 })
	end)

	it("never logs a step twice", function()
		local all = state({
			Spawned = true,
			Dressed = true,
			Walks = 1,
			Votes = 1,
			Shows = 1,
			Wins = 1,
			SavedLooks = 1,
			Sessions = 2,
		})
		expect(#Funnel.toLog(0, all)).toBe(#Funnel.Steps)
		expect(#Funnel.toLog(#Funnel.Steps, all)).toBe(0)
	end)
end)
