-- Keeps the balance, layout, theme and catalog files in step with each other,
-- so a theme swap or a new upgrade can't ship half-configured.

local TestKit = require("./TestKit")
local Balance = require("../src/shared/Config/Balance")
local Catalog = require("../src/shared/Config/Catalog")
local Layout = require("../src/shared/Config/Layout")
local Theme = require("../src/shared/Themes/MoonlightFestival")
local Progression = require("../src/shared/Progression")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("theme pack", function()
	it("names every upgrade, and only real upgrades", function()
		for _, upgrade in Balance.Upgrades do
			local entry = Theme.Upgrades[upgrade.Id]
			assert(entry and entry.DisplayName, `theme has no entry for {upgrade.Id}`)
			assert(string.match(entry.Color, "^#%x%x%x%x%x%x$"), `{upgrade.Id} colour must be #RRGGBB`)
		end
		for id in Theme.Upgrades do
			assert(Progression.find(Balance.Upgrades, id), `theme names unknown upgrade {id}`)
		end
	end)
end)

describe("layout", function()
	it("has a slot for every producer and none for anything else", function()
		for _, upgrade in Balance.Upgrades do
			if upgrade.Kind == "Producer" then
				assert(Layout.Slots[upgrade.Id], `no layout slot for producer {upgrade.Id}`)
			end
		end
		for id in Layout.Slots do
			local upgrade = Progression.find(Balance.Upgrades, id)
			assert(upgrade and upgrade.Kind == "Producer", `layout slot {id} is not a producer`)
		end
	end)

	it("keeps every slot inside the plot", function()
		local half = Layout.PlotSize / 2
		for id, slot in Layout.Slots do
			local width, depth = slot.Size[1], slot.Size[3]
			assert(math.abs(slot.X) + width / 2 <= half, `{id} sticks out of the plot sideways`)
			assert(math.abs(slot.Z) + depth / 2 <= half, `{id} sticks out of the plot front or back`)
		end
	end)

	it("leaves a gap between plots", function()
		expect(Layout.PlotSpacing > Layout.PlotSize).toBe(true)
	end)
end)

describe("serve task", function()
	it("sits on a free producer so every player has it from the start", function()
		local upgrade = Progression.find(Balance.Upgrades, Balance.ServeTask.UpgradeId)
		assert(upgrade, "serve task upgrade is missing")
		expect(upgrade.Kind).toBe("Producer")
		expect(upgrade.Cost).toBe(0)
	end)
end)

describe("catalog", function()
	it("has unique ids, known kinds and a stated description for each item", function()
		local seen = {}
		for _, item in Catalog do
			assert(not seen[item.Id], `duplicate catalog id {item.Id}`)
			seen[item.Id] = true
			assert(item.Kind == "GamePass" or item.Kind == "DeveloperProduct", `{item.Id} has unknown kind`)
			local idField = if item.Kind == "GamePass" then item.PassId else item.ProductId
			assert(type(idField) == "number", `{item.Id} needs a numeric id (0 until set up)`)
			assert(type(item.Includes) == "string" and #item.Includes > 0, `{item.Id} must say what it includes`)
		end
	end)
end)

return nil
