-- The pure rules: dealing roles, when a round ends, who hears whom, map
-- votes, tagging geometry, inventories, trades, crates and the Moon Pass.

local Loader = require("./RobloxLoader")
local TestKit = require("./TestKit")

local Vector3 = Loader.roblox.Vector3
local Crates = Loader.require("src/shared/Rules/Crates")
local CrateConfig = Loader.require("src/shared/Config/Crates")
local Chat = Loader.require("src/shared/Rules/Chat")
local Combat = Loader.require("src/shared/Rules/Combat")
local Deal = Loader.require("src/shared/Rules/Deal")
local Inventory = Loader.require("src/shared/Rules/Inventory")
local Items = Loader.require("src/shared/Config/Items")
local Pass = Loader.require("src/shared/Config/Pass")
local Progress = Loader.require("src/shared/Rules/Progress")
local Roles = Loader.require("src/shared/Config/Roles")
local Round = Loader.require("src/shared/Rules/Round")
local Trade = Loader.require("src/shared/Rules/Trade")
local Vote = Loader.require("src/shared/Rules/Vote")
local Game = Loader.require("src/shared/Config/Game")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- A seeded random source, so the tests always see the same rolls.
local function seeded(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local function ids(count: number): { number }
	local list = {}
	for index = 1, count do
		list[index] = index
	end
	return list
end

local function holder()
	return { Items = {}, NextUid = 1, Equipped = {} }
end

describe("dealing roles", function()
	it("deals exactly one Phantom, and the other roles by server size", function()
		for count = 1, Game.MaxPlayers do
			local roles = Deal.deal(ids(count), {}, seeded(count))
			local tally = {}
			local dealt = 0
			for _, roleId in roles do
				tally[roleId] = (tally[roleId] or 0) + 1
				dealt += 1
			end
			expect(dealt).toBe(count)
			expect(tally.Phantom).toBe(1)
			local want = Roles.counts(count)
			for _, roleId in Roles.DEAL_ORDER do
				expect(tally[roleId] or 0).toBe(want[roleId])
			end
		end
	end)

	it("gives a Medic from five players and a Saboteur from seven", function()
		expect(Roles.counts(4).Medic).toBe(0)
		expect(Roles.counts(5).Medic).toBe(1)
		expect(Roles.counts(6).Saboteur).toBe(0)
		expect(Roles.counts(7).Saboteur).toBe(1)
	end)

	it("makes someone who keeps missing a role likelier to get it", function()
		local players = ids(10)
		local tickets = {}
		local roles = Deal.deal(players, tickets, seeded(7))
		Deal.afterDeal(tickets, roles)
		for id, roleId in roles do
			if roleId == "Phantom" then
				expect(tickets[id].Phantom).toBe(1)
			else
				expect(tickets[id].Phantom).toBe(2)
			end
		end
		local lucky = if roles[1] == "Phantom" then 2 else 1
		local before = Deal.chance(players, tickets, lucky, "Phantom")
		for _ = 1, 5 do
			tickets[lucky].Phantom += 1
		end
		expect(Deal.chance(players, tickets, lucky, "Phantom") > before).toBe(true)
	end)

	it("caps tickets", function()
		local tickets = {}
		for _ = 1, 30 do
			Deal.afterDeal(tickets, { a = "Guest" })
		end
		expect(tickets.a.Phantom).toBe(Deal.MAX_TICKETS)
	end)

	it("spreads the Phantom fairly over many rounds", function()
		local players = ids(8)
		local tickets = {}
		local times = {}
		local random = seeded(42)
		for _ = 1, 800 do
			local roles = Deal.deal(players, tickets, random)
			Deal.afterDeal(tickets, roles)
			for id, roleId in roles do
				if roleId == "Phantom" then
					times[id] = (times[id] or 0) + 1
				end
			end
		end
		for _, id in players do
			-- 100 each on average; nobody far off.
			expect((times[id] or 0) > 70 and (times[id] or 0) < 130).toBe(true)
		end
	end)
end)

describe("a round", function()
	local function entries(list)
		local out = {}
		for index, pair in list do
			out[index] = { Role = pair[1], State = pair[2] }
		end
		return out
	end

	it("goes on while the Phantom and a guest are up and time is left", function()
		local winner = Round.outcome(entries({ { "Phantom", "Alive" }, { "Guest", "Alive" } }), 30)
		expect(winner).toBe(nil)
	end)

	it("ends for the guests when the Phantom is out", function()
		local winner, why = Round.outcome(entries({ { "Phantom", "Out" }, { "Guest", "Alive" } }), 30)
		expect(winner).toBe("Guests")
		expect(why).toBe("PhantomOut")
	end)

	it("ends for the Shadows when no guest is standing", function()
		local winner, why = Round.outcome(
			entries({ { "Phantom", "Alive" }, { "Saboteur", "Alive" }, { "Guest", "Dazed" }, { "Medic", "Out" } }),
			30
		)
		expect(winner).toBe("Shadows")
		expect(why).toBe("AllTagged")
	end)

	it("ends for the guests when the clock runs out", function()
		local winner, why = Round.outcome(entries({ { "Phantom", "Alive" }, { "Guest", "Alive" } }), 0)
		expect(winner).toBe("Guests")
		expect(why).toBe("Time")
	end)

	it("in practice, ends only on the clock", function()
		expect(Round.outcome(entries({ { "Phantom", "Out" } }), 10, true)).toBe(nil)
		expect(Round.outcome(entries({ { "Phantom", "Out" } }), 0, true)).toBe("Guests")
	end)

	it("lets only the Phantom tag, and only guests", function()
		expect(Round.canTag("Phantom", "Guest")).toBe(true)
		expect(Round.canTag("Phantom", "Guardian")).toBe(true)
		expect(Round.canTag("Phantom", "Saboteur")).toBe(false)
		expect(Round.canTag("Saboteur", "Guest")).toBe(false)
		expect(Round.canTag("Guardian", "Phantom")).toBe(false)
	end)

	it("knocks out the shooter too when a blaster hits an innocent", function()
		expect(Round.zap("Phantom").Shooter).toBe(false)
		expect(Round.zap("Saboteur").Shooter).toBe(false)
		expect(Round.zap("Guest").Shooter).toBe(true)
		expect(Round.zap("Medic").Target).toBe(true)
	end)

	it("gets a little longer on full servers", function()
		expect(Round.length(4)).toBe(Game.Seconds.Round)
		expect(Round.length(12)).toBe(Game.Seconds.Round + 4 * Game.Seconds.RoundPerExtraPlayer)
	end)

	it("counts who's standing", function()
		local census = Round.census(entries({ { "Phantom", "Alive" }, { "Guest", "Dazed" }, { "Guest", "Out" } }))
		expect(census.Alive).toBe(1)
		expect(census.Dazed).toBe(1)
		expect(census.Out).toBe(1)
	end)
end)

describe("chat", function()
	local here = Vector3.new(0, 0, 0)
	local near = Vector3.new(20, 0, 0)
	local far = Vector3.new(200, 0, 0)

	it("lets the living hear only the living close by", function()
		expect(Chat.canHear({ State = "Alive", Position = here }, { State = "Alive", Position = near }, 60)).toBe(true)
		expect(Chat.canHear({ State = "Alive", Position = here }, { State = "Alive", Position = far }, 60)).toBe(false)
	end)

	it("keeps the tagged and the lobby from telling the living anything", function()
		for _, state in { "Dazed", "Out", "Lobby" } do
			expect(Chat.canHear({ State = "Alive", Position = here }, { State = state, Position = here }, 60)).toBe(
				false
			)
		end
	end)

	it("lets spectators hear everyone", function()
		expect(Chat.canHear({ State = "Out" }, { State = "Alive", Position = far }, 60)).toBe(true)
		expect(Chat.canHear({ State = "Lobby" }, { State = "Out" }, 60)).toBe(true)
	end)
end)

describe("map votes", function()
	it("offers distinct maps and skips the last one when it can", function()
		local choices = Vote.choices({ "manor", "carnival", "third" }, 2, "manor", seeded(3))
		expect(#choices).toBe(2)
		expect(table.find(choices, "manor")).toBe(nil)
		expect(choices[1] ~= choices[2]).toBe(true)
	end)

	it("still offers every map when there are only enough to fill the vote", function()
		local choices = Vote.choices({ "manor", "carnival" }, 3, "manor", seeded(3))
		expect(#choices).toBe(2)
	end)

	it("picks the most voted map", function()
		local winner = Vote.winner({ "manor", "carnival" }, { a = "carnival", b = "carnival", c = "manor" }, seeded(1))
		expect(winner).toBe("carnival")
		expect(Vote.counts({ "manor", "carnival" }, { a = "manor", b = "nope" }).manor).toBe(1)
	end)
end)

describe("tagging geometry", function()
	local origin = Vector3.new(0, 0, 0)
	local facing = Vector3.new(0, 0, -1)

	it("reaches the nearest target in front", function()
		local targets = {
			{ Id = "behind", Position = Vector3.new(0, 0, 4) },
			{ Id = "far", Position = Vector3.new(0, 0, -6) },
			{ Id = "close", Position = Vector3.new(0.5, 0, -3) },
		}
		local hit = Combat.swingTarget(origin, facing, targets, 7, 60, 5)
		expect(hit and hit.Id).toBe("close")
	end)

	it("misses what's out of reach, behind or far above", function()
		expect(Combat.swingTarget(origin, facing, { { Id = 1, Position = Vector3.new(0, 0, -9) } }, 7, 60, 5)).toBe(nil)
		expect(Combat.swingTarget(origin, facing, { { Id = 1, Position = Vector3.new(0, 0, 4) } }, 7, 60, 5)).toBe(nil)
		expect(Combat.swingTarget(origin, facing, { { Id = 1, Position = Vector3.new(0, 9, -3) } }, 7, 60, 5)).toBe(nil)
	end)

	it("checks cooldowns, claimed positions and aim", function()
		expect(Combat.ready(10, nil, 1, 0.1)).toBe(true)
		expect(Combat.ready(10.95, 10, 1, 0.1)).toBe(true)
		expect(Combat.ready(10.5, 10, 1, 0.1)).toBe(false)
		expect(Combat.near(Vector3.new(0, 0, 0), Vector3.new(3, 0, 0), 10)).toBe(true)
		expect(Combat.near(Vector3.new(0, 0, 0), Vector3.new(30, 0, 0), 10)).toBe(false)
		expect(Combat.aim(Vector3.new(0, 0, 0))).toBe(nil)
		expect(Combat.aim(Vector3.new(0 / 0, 0, 0))).toBe(nil)
		local unit = Combat.aim(Vector3.new(3, 0, 4)) :: any
		expect(math.abs(unit.Magnitude - 1) < 1e-6).toBe(true)
	end)
end)

describe("inventories", function()
	it("owns the defaults and wears them until something else is chosen", function()
		local save = holder()
		local outfit = Inventory.outfit(save)
		for _, kind in Items.KINDS do
			expect(outfit[kind]).toBe(Items.DEFAULTS[kind])
		end
	end)

	it("wears only what it owns", function()
		local save = holder()
		local ok, err = Inventory.equip(save, "mask_cat")
		expect(ok).toBe(false)
		expect(err).toBe("NotOwned")
		Inventory.add(save, 1, "mask_cat")
		expect((Inventory.equip(save, "mask_cat"))).toBe(true)
		expect(Inventory.outfit(save).Mask).toBe("mask_cat")
	end)

	it("falls back to the default when a worn item is traded away", function()
		local save = holder()
		local uid = Inventory.add(save, 1, "mask_cat")
		Inventory.equip(save, "mask_cat")
		Inventory.remove(save, uid)
		expect(Inventory.outfit(save).Mask).toBe(Items.DEFAULTS.Mask)
	end)

	it("counts copies, and gives each a unique id", function()
		local save = holder()
		local a = Inventory.add(save, 7, "blade_candy")
		local b = Inventory.add(save, 7, "blade_candy")
		expect(a ~= b).toBe(true)
		expect(Inventory.count(save, "blade_candy")).toBe(2)
	end)

	it("lets pass items be worn but never traded", function()
		local save = holder()
		expect(Inventory.owns(save, "blade_neon", { blade_neon = true })).toBe(true)
		local uid = Inventory.add(save, 1, "mask_gala")
		expect(Inventory.canTrade(save, uid)).toBe(false)
		local crateUid = Inventory.add(save, 1, "mask_fox")
		expect(Inventory.canTrade(save, crateUid)).toBe(true)
	end)
end)

describe("trades", function()
	local function setup()
		local a, b = holder(), holder()
		local aUid = Inventory.add(a, 1, "mask_fox")
		local bUid = Inventory.add(b, 2, "blade_bone")
		return a, b, aUid, bUid, Trade.new("A", "B")
	end

	it("swaps both offers once both accept and the countdown ends", function()
		local a, b, aUid, bUid, session = setup()
		expect((Trade.setOffer(session, "A", { aUid }, a))).toBe(true)
		expect((Trade.setOffer(session, "B", { bUid }, b))).toBe(true)
		Trade.accept(session, "A", 0)
		Trade.accept(session, "B", 1)
		expect(session.State).toBe("Countdown")
		expect(Trade.due(session, 1 + Trade.COUNTDOWN - 0.1)).toBe(false)
		expect(Trade.due(session, 1 + Trade.COUNTDOWN)).toBe(true)
		expect((Trade.execute(session, a, b))).toBe(true)
		expect(a.Items[bUid]).toBe("blade_bone")
		expect(b.Items[aUid]).toBe("mask_fox")
		expect(a.Items[aUid]).toBe(nil)
		expect(b.Items[bUid]).toBe(nil)
	end)

	it("drops both accepts when either offer changes", function()
		local a, b, aUid, bUid, session = setup()
		Trade.setOffer(session, "A", { aUid }, a)
		Trade.setOffer(session, "B", { bUid }, b)
		Trade.accept(session, "A", 0)
		Trade.accept(session, "B", 0)
		Trade.setOffer(session, "B", {}, b)
		expect(session.State).toBe("Open")
		expect(session.A.Accepted).toBe(false)
		expect((Trade.execute(session, a, b))).toBe(false)
	end)

	it("refuses bound items, repeats and too many", function()
		local a, _, aUid, _, session = setup()
		local bound = Inventory.add(a, 1, "mask_gala")
		expect((Trade.setOffer(session, "A", { bound }, a))).toBe(false)
		expect((Trade.setOffer(session, "A", { aUid, aUid }, a))).toBe(false)
		local many = {}
		for _ = 1, Trade.MAX_ITEMS + 1 do
			table.insert(many, Inventory.add(a, 1, "mask_fox"))
		end
		expect((Trade.setOffer(session, "A", many, a))).toBe(false)
	end)

	it("moves nothing if a copy went missing before the swap", function()
		local a, b, aUid, bUid, session = setup()
		Trade.setOffer(session, "A", { aUid }, a)
		Trade.setOffer(session, "B", { bUid }, b)
		Trade.accept(session, "A", 0)
		Trade.accept(session, "B", 0)
		b.Items[bUid] = nil
		expect((Trade.execute(session, a, b))).toBe(false)
		expect(a.Items[aUid]).toBe("mask_fox")
	end)

	it("can't be accepted empty", function()
		local _, _, _, _, session = setup()
		expect((Trade.accept(session, "A", 0))).toBe(false)
	end)
end)

describe("crates", function()
	it("lists odds that add up to 100", function()
		for _, crate in CrateConfig.List do
			local total = 0
			for _, line in Crates.odds(crate) do
				total += line.Percent
			end
			expect(math.abs(total - 100) < 0.2).toBe(true)
		end
	end)

	it("only gives items the crate lists, of the rolled rarity", function()
		local random = seeded(9)
		for _, crate in CrateConfig.List do
			local pity = 0
			for _ = 1, 400 do
				local itemId, rarity, nextPity = Crates.roll(crate, pity, random)
				expect(table.find(crate.Pools[rarity], itemId) ~= nil).toBe(true)
				expect((Items.get(itemId) :: any).Rarity).toBe(rarity)
				pity = nextPity
			end
		end
	end)

	it("guarantees the pity rarity after a run of misses", function()
		for _, crate in CrateConfig.List do
			local floor = Items.rank(crate.PityRarity)
			local always0 = function()
				return 0
			end
			local _, rarity = Crates.roll(crate, crate.Pity - 1, always0)
			expect(Items.rank(rarity) >= floor).toBe(true)
		end
	end)

	it("never goes longer than the pity count without the pity rarity", function()
		local random = seeded(11)
		for _, crate in CrateConfig.List do
			local floor = Items.rank(crate.PityRarity)
			local pity, streak, worst = 0, 0, 0
			for _ = 1, 2000 do
				local _, rarity, nextPity = Crates.roll(crate, pity, random)
				pity = nextPity
				if Items.rank(rarity) >= floor then
					streak = 0
				else
					streak += 1
					worst = math.max(worst, streak)
				end
			end
			expect(worst < crate.Pity).toBe(true)
		end
	end)
end)

describe("progress", function()
	it("pays every round something, and more for doing well", function()
		local quiet = Progress.pay({
			Won = false,
			Survived = false,
			Tags = 0,
			Takedown = false,
			Revives = 0,
			Clues = 0,
			Coins = 0,
		})
		local great = Progress.pay({
			Won = true,
			Survived = true,
			Tags = 0,
			Takedown = true,
			Revives = 1,
			Clues = 3,
			Coins = 20,
		})
		expect(quiet.Xp > 0).toBe(true)
		expect(great.Coins > quiet.Coins).toBe(true)
		expect(great.Xp > quiet.Xp).toBe(true)
	end)

	it("reaches level 2 in a couple of rounds and the pass's end in a season", function()
		local typical = Progress.pay({
			Won = true,
			Survived = true,
			Tags = 0,
			Takedown = false,
			Revives = 0,
			Clues = 2,
			Coins = 15,
		})
		local roundsToLevel2 = math.ceil(Progress.levelCost(1) / typical.Xp)
		expect(roundsToLevel2 <= 3).toBe(true)
		local roundsForPass = math.ceil(Pass.Tiers * Pass.XpPerTier / typical.Xp)
		-- A season of about four to five hours of rounds for a regular.
		expect(roundsForPass >= 40 and roundsForPass <= 120).toBe(true)
	end)

	it("lets the free track be claimed once per tier reached", function()
		local save = Progress.passFor(nil)
		expect((Progress.canClaim(save, "Free", 1, false))).toBe(false)
		save.Xp = Pass.XpPerTier * 3
		expect((Progress.claim(save, "Free", 1, false)) ~= nil).toBe(true)
		local again, err = Progress.claim(save, "Free", 1, false)
		expect(again).toBe(nil)
		expect(err).toBe("Claimed")
		expect(#Progress.claimable(save, false)).toBe(2)
	end)

	it("keeps the premium track for pass owners, including tiers already reached", function()
		local save = Progress.passFor(nil)
		save.Xp = Pass.XpPerTier * 5
		local _, err = Progress.claim(save, "Premium", 1, false)
		expect(err).toBe("NeedsPremium")
		local reward = Progress.claim(save, "Premium", 1, true) :: any
		expect(reward.Item).toBe(Pass.Premium[1].Item)
		local _, missing = Progress.claim(save, "Premium", 2, true)
		expect(missing).toBe("NoReward")
	end)

	it("starts a fresh pass each season", function()
		local old = { Season = "S0", Xp = 9999, Free = { ["1"] = true }, Premium = {} }
		local fresh = Progress.passFor(old)
		expect(fresh.Season).toBe(Pass.Season)
		expect(fresh.Xp).toBe(0)
	end)
end)

return nil
