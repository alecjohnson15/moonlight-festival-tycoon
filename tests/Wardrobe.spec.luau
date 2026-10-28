-- The wardrobe: which cosmetics a player has, what can be worn where, the
-- cosmetics config against the upgrades and catalog, and the theme's look for
-- every item, built with Lune's Roblox library.

local TestKit = require("./TestKit")
local Loader = require("./RobloxLoader")
local Balance = require("../src/shared/Config/Balance")
local Catalog = require("../src/shared/Config/Catalog")
local Cosmetics = require("../src/shared/Config/Cosmetics")
local Theme = require("../src/shared/Themes/MoonlightFestival")
local Wardrobe = require("../src/shared/Wardrobe")
local Migrations = require("../src/server/Lib/Migrations")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local roblox = Loader.roblox
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame
local Wearables = Loader.require("src/shared/Themes/MoonlightFestival/Wearables")

local TOLERANCE = 0.06

local UPGRADES = {
	{ Id = "a" },
	{ Id = "b" },
	{ Id = "c", Building = "kitchen", Path = "gourmet" },
	{ Id = "d", Building = "kitchen", Path = "gourmet" },
	{ Id = "e", Building = "kitchen", Path = "speed" },
}

local COSMETICS = {
	{ Id = "hat", Slot = "Head", Line = "Earned", Unlock = { Owns = "a" } },
	{ Id = "cape", Slot = "Back", Line = "Earned", Unlock = { OwnsAll = { "a", "b" } } },
	{ Id = "pet", Slot = "Pet", Line = "Earned", Unlock = { OwnedCount = 3 } },
	{ Id = "chef", Slot = "Head", Line = "Earned", Unlock = { Building = "kitchen", Path = "gourmet" } },
	{ Id = "crown", Slot = "Head", Line = "Deluxe", Premium = true },
	{ Id = "sword", Slot = "Hand", Line = "Legendary", Weapon = "sword", Premium = true },
}

local CATALOG = { { Id = "crown" }, { Id = "sword" } }

local function nobody(_id: string): boolean
	return false
end

describe("Wardrobe rules", function()
	it("earns a free item once its upgrade is owned, and never earns a paid one", function()
		local hat = COSMETICS[1]
		expect(Wardrobe.isEarned(hat, {}, UPGRADES)).toBe(false)
		expect(Wardrobe.isEarned(hat, { a = true }, UPGRADES)).toBe(true)
		expect(Wardrobe.isEarned(COSMETICS[5], { a = true, b = true }, UPGRADES)).toBe(false)
	end)

	it("needs every upgrade for OwnsAll and enough of them for OwnedCount", function()
		expect(Wardrobe.isEarned(COSMETICS[2], { a = true }, UPGRADES)).toBe(false)
		expect(Wardrobe.isEarned(COSMETICS[2], { a = true, b = true }, UPGRADES)).toBe(true)
		expect(Wardrobe.isEarned(COSMETICS[3], { a = true, b = true }, UPGRADES)).toBe(false)
		expect(Wardrobe.isEarned(COSMETICS[3], { a = true, b = true, e = true }, UPGRADES)).toBe(true)
	end)

	it("counts a path as finished only when every upgrade on it is owned", function()
		local chef = COSMETICS[4]
		expect(Wardrobe.isEarned(chef, { c = true }, UPGRADES)).toBe(false)
		expect(Wardrobe.isEarned(chef, { c = true, e = true }, UPGRADES)).toBe(false)
		expect(Wardrobe.isEarned(chef, { c = true, d = true }, UPGRADES)).toBe(true)
		expect(Wardrobe.pathComplete({}, UPGRADES, "kitchen", "missing")).toBe(false)
	end)

	it("owns earned items and the paid items the player bought", function()
		local have = Wardrobe.owned(COSMETICS, { a = true }, UPGRADES, function(id)
			return id == "crown"
		end)
		expect(have).toEqual({ hat = true, crown = true })
	end)

	it("only lets a player wear what they own, in its own slot", function()
		local have = { hat = true }
		expect(Wardrobe.canEquip(COSMETICS, have, "Head", "hat")).toBe(true)
		expect(select(2, Wardrobe.canEquip(COSMETICS, have, "Back", "hat"))).toBe("WrongSlot")
		expect(select(2, Wardrobe.canEquip(COSMETICS, have, "Head", "crown"))).toBe("NotOwned")
		expect(select(2, Wardrobe.canEquip(COSMETICS, have, "Head", "nope"))).toBe("UnknownCosmetic")
	end)

	it("shows only valid choices but keeps the saved ones", function()
		local equipped = { Head = "crown", Back = "cape", Pet = "hat" }
		local worn = Wardrobe.worn(COSMETICS, equipped, { cape = true, hat = true })
		expect(worn).toEqual({ Back = "cape" })
		expect(equipped.Head).toBe("crown")
	end)

	it("puts earned items into empty slots only, and bought items on straight away", function()
		local equipped = { Head = "hat" }
		local changed = Wardrobe.autoEquip(COSMETICS, equipped, { "chef", "cape" })
		expect(equipped.Head).toBe("hat")
		expect(equipped.Back).toBe("cape")
		expect(changed).toEqual({ "Back" })
		Wardrobe.autoEquip(COSMETICS, equipped, { "crown" })
		expect(equipped.Head).toBe("crown")
	end)

	it("lists what is new in config order", function()
		local fresh = Wardrobe.newlyOwned(COSMETICS, { hat = true }, { sword = true, hat = true, cape = true })
		expect(fresh).toEqual({ "cape", "sword" })
	end)

	it("turns the owned set into text and back", function()
		local text = Wardrobe.encode(COSMETICS, { sword = true, hat = true })
		expect(text).toBe("hat,sword")
		expect(Wardrobe.decode(text)).toEqual({ hat = true, sword = true })
		expect(Wardrobe.decode(nil)).toEqual({})
	end)

	it("finds problems in a broken config", function()
		expect(#Wardrobe.validate(COSMETICS, UPGRADES, CATALOG)).toBe(0)
		local broken = {
			{ Id = "hat", Slot = "Head", Line = "Earned", Unlock = { Owns = "zzz" } },
			{ Id = "hat", Slot = "Feet", Line = "Earned", Unlock = { Owns = "a" } },
			{ Id = "free", Slot = "Back", Line = "Earned" },
			{ Id = "paid", Slot = "Back", Line = "Deluxe", Premium = true },
			{ Id = "cheap", Slot = "Back", Line = "Deluxe", Unlock = { Owns = "a" } },
			{ Id = "wand", Slot = "Head", Line = "Earned", Weapon = "x", Unlock = { Owns = "a" } },
			{ Id = "far", Slot = "Pet", Line = "Earned", Unlock = { OwnedCount = 99 } },
			{ Id = "Bad Id", Slot = "Pet", Line = "Earned", Unlock = { Building = "kitchen", Path = "nope" } },
		}
		local problems = Wardrobe.validate(broken, UPGRADES, { { Id = "stray" } })
		expect(problems).toContain("duplicate cosmetic id hat")
		expect(problems).toContain("unknown upgrade zzz")
		expect(problems).toContain("unknown slot Feet")
		expect(problems).toContain("free: free items need an unlock")
		expect(problems).toContain("paid: paid but not in the catalog")
		expect(problems).toContain("cheap: free items belong in the Earned line")
		expect(problems).toContain("wand: only Hand items can be weapons")
		expect(problems).toContain("far: OwnedCount")
		expect(problems).toContain("Bad Id: ids must be")
		expect(problems).toContain("no upgrades on path nope of kitchen")
		expect(problems).toContain("catalog item stray is not a paid cosmetic")
	end)

	it("gives old saves an empty wardrobe", function()
		local data = Migrations.run({ SchemaVersion = 1, Coins = 5 })
		assert(data)
		expect(data.Equipped).toEqual({})
	end)
end)

describe("cosmetics config", function()
	it("matches the upgrades and the catalog", function()
		local problems = Wardrobe.validate(Cosmetics, Balance.Upgrades, Catalog)
		assert(#problems == 0, table.concat(problems, "\n"))
	end)

	it("gives a new player something to wear from their very first upgrade", function()
		local first = Balance.Upgrades[1].Id
		local have = Wardrobe.owned(Cosmetics, { [first] = true }, Balance.Upgrades, nobody)
		assert(next(have), `nothing unlocks from {first}`)
	end)

	it("has something to earn in every slot, and everything earned by finishing", function()
		local all = {}
		for _, upgrade in Balance.Upgrades do
			all[upgrade.Id] = true
		end
		local have = Wardrobe.owned(Cosmetics, all, Balance.Upgrades, nobody)
		for _, slot in Wardrobe.SLOTS do
			local found = false
			for _, cosmetic in Cosmetics do
				found = found or (cosmetic.Slot == slot and have[cosmetic.Id] == true)
			end
			assert(found, `nothing to earn for the {slot} slot`)
		end
	end)

	it("keeps paid looks of weapons exactly as strong as an earned one", function()
		-- Only Legendary weapons may differ, and only in the arena.
		local earnedWeapons = {}
		for _, cosmetic in Cosmetics do
			if not cosmetic.Premium and cosmetic.Weapon then
				earnedWeapons[cosmetic.Weapon] = true
			end
		end
		for _, cosmetic in Cosmetics do
			if cosmetic.Premium and cosmetic.Weapon and cosmetic.Line ~= "Legendary" then
				assert(earnedWeapons[cosmetic.Weapon], `{cosmetic.Id} is paid but fights unlike any earned weapon`)
			end
		end
	end)
end)

describe("theme wardrobe", function()
	it("names every cosmetic, slot and line, and only real cosmetics", function()
		for _, cosmetic in Cosmetics do
			local entry = Theme.Cosmetics[cosmetic.Id]
			assert(entry and entry.DisplayName and entry.Blurb, `theme has no name for cosmetic {cosmetic.Id}`)
			assert(string.match(entry.Color, "^#%x%x%x%x%x%x$"), `{cosmetic.Id} colour must be #RRGGBB`)
		end
		for id in Theme.Cosmetics do
			assert(Wardrobe.find(Cosmetics, id), `theme names unknown cosmetic {id}`)
		end
		for _, slot in Wardrobe.SLOTS do
			assert(Theme.CosmeticSlots[slot], `theme has no name for slot {slot}`)
		end
		for _, line in Wardrobe.LINES do
			assert(Theme.CosmeticLines[line], `theme has no name for line {line}`)
		end
	end)
end)

-- The box around a part, in world space, as min and max corners.
local function boxOf(part: any): ({ number }, { number })
	local half = part.Size / 2
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = part.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
				local values = { corner.X, corner.Y, corner.Z }
				for axis = 1, 3 do
					lo[axis] = math.min(lo[axis], values[axis])
					hi[axis] = math.max(hi[axis], values[axis])
				end
			end
		end
	end
	return lo, hi
end

-- How far from the origin each kind of item may reach, as { minX, minY,
-- minZ, maxX, maxY, maxZ }, so nothing swamps the character wearing it.
local BOUNDS = {
	Head = { -1.6, -1.8, -1.6, 1.6, 1.8, 1.6 },
	Back = { -3, -3.2, -0.6, 3, 2.2, 1.2 },
	Hand = { -2.4, -2.2, -3.4, 2.4, 5.6, 1.6 },
	Pet = { -2.2, -1.6, -1.2, 2.2, 1.6, 1.2 },
}
local KNOWN_ATTACHMENTS = { HatAttachment = true, FaceCenterAttachment = true, BodyBackAttachment = true }
local MAX_PARTS, MAX_LIGHTS = 60, 2

describe("theme wearables", function()
	it("has a look for every cosmetic, and only real ones", function()
		for _, cosmetic in Cosmetics do
			local entry = Wearables[cosmetic.Id]
			assert(entry and type(entry.Build) == "function", `the theme has no look for {cosmetic.Id}`)
		end
		for id in Wearables do
			assert(Wardrobe.find(Cosmetics, id), `the theme has a look for unknown cosmetic {id}`)
		end
	end)

	it("builds worn, held and pet items that fit and can't touch anything", function()
		for _, cosmetic in Cosmetics do
			local bounds = BOUNDS[cosmetic.Slot]
			if bounds then
				local entry = Wearables[cosmetic.Id]
				if cosmetic.Slot == "Head" or cosmetic.Slot == "Back" then
					assert(KNOWN_ATTACHMENTS[entry.Attach], `{cosmetic.Id} needs an Attach that every avatar has`)
				end
				local model = entry.Build()
				expect(model.ClassName).toBe("Model")
				local parts, lights = 0, 0
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("Light") then
						lights += 1
					elseif descendant:IsA("BasePart") then
						parts += 1
						local where = `{cosmetic.Id}: {descendant.Name}`
						assert(descendant.Anchored, `{where} must be built anchored`)
						assert(not descendant.CanCollide and not descendant.CanTouch, `{where} could bump into or press things`)
						local lo, hi = boxOf(descendant)
						for axis = 1, 3 do
							assert(lo[axis] >= bounds[axis] - TOLERANCE, `{where} reaches too far on axis {axis} ({lo[axis]})`)
							assert(hi[axis] <= bounds[axis + 3] + TOLERANCE, `{where} reaches too far on axis {axis} ({hi[axis]})`)
						end
					end
				end
				assert(parts > 0 and parts <= MAX_PARTS, `{cosmetic.Id} has {parts} parts`)
				assert(lights <= MAX_LIGHTS, `{cosmetic.Id} has {lights} lights`)
			end
		end
	end)

	it("gives every weapon a tip to land on and a swing that exists", function()
		for _, cosmetic in Cosmetics do
			if cosmetic.Weapon then
				local entry = Wearables[cosmetic.Id]
				local model = entry.Build()
				local tip = model:FindFirstChild("Tip", true)
				assert(tip and tip:IsA("BasePart"), `{cosmetic.Id} has no Tip part`)
				local swing = entry.Swing
				assert(swing, `{cosmetic.Id} has no Swing`)
				assert(Theme.Sounds[swing.Sound], `{cosmetic.Id} swings with unknown sound {swing.Sound}`)
				assert(string.match(swing.Dust, "^#%x%x%x%x%x%x$"), `{cosmetic.Id} dust colour must be #RRGGBB`)
				assert(swing.Anim == "Slash" or swing.Anim == "Lunge", `{cosmetic.Id} needs a Slash or Lunge animation`)
			end
		end
	end)

	it("builds auras and trails on attachments", function()
		for _, cosmetic in Cosmetics do
			local entry = Wearables[cosmetic.Id]
			if cosmetic.Slot == "Aura" then
				local attachment = Instance.new("Attachment")
				entry.Build(attachment)
				assert(attachment:FindFirstChildOfClass("ParticleEmitter"), `{cosmetic.Id} makes no particles`)
			elseif cosmetic.Slot == "Trail" then
				local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
				bottom.Position = Vector3.new(0, -1, 0)
				entry.Build(top, bottom)
				local trail = top:FindFirstChildOfClass("Trail")
				assert(trail and trail.Attachment0 == top and trail.Attachment1 == bottom, `{cosmetic.Id} makes no trail`)
			end
		end
	end)
end)

return nil
