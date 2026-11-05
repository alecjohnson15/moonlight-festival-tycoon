-- The first minute and the minutes after going out: first-time tips show
-- one at a time and never repeat, and the plaza's wisp hunt is only for
-- those not standing in the round, sits in open air and pays nothing.

local fs = require("@lune/fs")
local Loader = require("./RobloxLoader")
local TestKit = require("./TestKit")

local CFrame = Loader.roblox.CFrame
local Vector3 = Loader.roblox.Vector3
local Lobby = Loader.require("src/shared/Look/Lobby")
local Roles = Loader.require("src/shared/Config/Roles")
local TipConfig = Loader.require("src/shared/Config/Tips")
local Tips = Loader.require("src/shared/Rules/Tips")
local Wisps = Loader.require("src/shared/Rules/Wisps")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("first-time tips", function()
	it("each have their own id, a real role and a real moment", function()
		local ids = {}
		for _, tip in TipConfig.List do
			expect(ids[tip.Id]).toBe(nil)
			ids[tip.Id] = true
			expect(tip.Role == "*" or Roles.List[tip.Role] ~= nil).toBe(true)
			expect(table.find(TipConfig.WHEN, tip.When) ~= nil).toBe(true)
		end
	end)

	it("read right on a keyboard, a touch screen and a controller, and stay short", function()
		for _, tip in TipConfig.List do
			for _, input in { "Keyboard", "Touch", "Gamepad" } do
				local text = Tips.text(tip, input)
				expect(string.find(text, "{", 1, true)).toBe(nil)
				if #text > 110 then
					error(`{tip.Id} on {input} is {#text} characters`)
				end
			end
		end
	end)

	it("give every role a tip as its first round starts", function()
		for roleId in Roles.List do
			expect(Tips.next({}, roleId, "Start") ~= nil).toBe(true)
		end
	end)

	it("show one at a time and never the same one twice", function()
		local seen = {}
		local first = Tips.next(seen, "Phantom", "Start") :: any
		expect(first.Id).toBe("phantom_start")
		seen[first.Id] = true
		expect(Tips.next(seen, "Phantom", "Start")).toBe(nil)
		-- A rejoin brings the saved list back: still nothing to repeat.
		local saved = table.clone(seen)
		expect(Tips.next(saved, "Phantom", "Start")).toBe(nil)
	end)

	it("only save tips that exist", function()
		expect(Tips.valid("phantom_draw")).toBe(true)
		expect(Tips.valid("anything_else")).toBe(false)
		expect(Tips.valid(42)).toBe(false)
	end)

	it("are a banner that can't take the player's input", function()
		local source = fs.readFile("src/client/Tips.luau")
		expect(string.find(source, "Active = false", 1, true) ~= nil).toBe(true)
		expect(string.find(source, "Modal", 1, true)).toBe(nil)
	end)
end)

describe("the plaza wisp hunt", function()
	it("is only for players not standing in the round", function()
		expect(Wisps.canCatch("Lobby")).toBe(true)
		expect(Wisps.canCatch("Out")).toBe(true)
		expect(Wisps.canCatch("Alive")).toBe(false)
		expect(Wisps.canCatch("Dazed")).toBe(false)
	end)

	it("celebrates every goal and starts again", function()
		local count, shows = 0, 0
		for _ = 1, Wisps.Goal * 3 do
			local celebrate
			count, celebrate = Wisps.add(count)
			if celebrate then
				shows += 1
			end
		end
		expect(shows).toBe(3)
		expect(count).toBe(0)
	end)

	it("pays nothing", function()
		local source = fs.readFile("src/server/Services/WispService.luau")
		expect(string.find(source, "Coins", 1, true)).toBe(nil)
		expect(string.find(source, "addXp", 1, true)).toBe(nil)
		expect(string.find(source, "award", 1, true)).toBe(nil)
	end)

	it("floats every wisp in open air over the plaza floor", function()
		local lobby = Lobby.build(CFrame.new(0, 0, 0))
		local solids = {}
		for _, part in lobby:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide then
				table.insert(solids, part)
			end
		end
		local function inside(point, margin)
			for _, part in solids do
				local offset = part.CFrame:PointToObjectSpace(point)
				local half = part.Size / 2
				if
					math.abs(offset.X) <= half.X + margin
					and math.abs(offset.Y) <= half.Y + margin
					and math.abs(offset.Z) <= half.Z + margin
				then
					return part
				end
			end
			return nil
		end
		local spots = lobby:FindFirstChild("Wisps"):GetChildren()
		expect(#spots >= Wisps.Out * 2).toBe(true)
		for _, spot in spots do
			local position = spot.CFrame.Position
			local blocked = inside(position, 1)
			if blocked then
				error(`a wisp spot at {position} is inside {blocked:GetFullName()}`)
			end
			expect(inside(position - Vector3.new(0, 3.4, 0), 0) ~= nil).toBe(true)
		end
	end)
end)
