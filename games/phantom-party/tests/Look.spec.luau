-- Builds both maps, the plaza and every cosmetic through Lune's Roblox
-- library, so a bad property or a missing marker fails here, not in Studio.
-- Also keeps each place under its part and light budget for phones.

local Loader = require("./RobloxLoader")
local TestKit = require("./TestKit")

local roblox = Loader.roblox
local Gear = Loader.require("src/shared/Look/Gear")
local Items = Loader.require("src/shared/Config/Items")
local Lobby = Loader.require("src/shared/Look/Lobby")
local Game = Loader.require("src/shared/Config/Game")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local MAPS = { "Manor", "Carnival" }
local MAP_PARTS = 5000
local MAP_LIGHTS = 40
local LOBBY_PARTS = 2000
local LOBBY_LIGHTS = 36

local function count(model: any): (number, number)
	local parts, lights = 0, 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			parts += 1
		elseif item:IsA("Light") then
			lights += 1
		end
	end
	return parts, lights
end

local built = {}
local function map(name: string): any
	if not built[name] then
		local module = Loader.require(`src/shared/Look/Maps/{name}`)
		built[name] = { Module = module, Model = module.build(roblox.CFrame.new(0, 0, 900)) }
	end
	return built[name]
end

describe("maps", function()
	for _, name in MAPS do
		it(`{name} builds with its name, blurb and lighting`, function()
			local entry = map(name)
			assert(type(entry.Module.Id) == "string", "map needs an Id")
			assert(type(entry.Module.Name) == "string" and #entry.Module.Name > 0, "map needs a Name")
			assert(type(entry.Module.Blurb) == "string", "map needs a Blurb")
			assert(type(entry.Module.Lighting) == "table", "map needs Lighting")
		end)

		it(`{name} has spawns for a full server, coins, clue pages and rooms`, function()
			local model = map(name).Model
			local function size(folder: string): number
				local found = model:FindFirstChild(folder)
				return if found then #found:GetChildren() else 0
			end
			assert(size("Spawns") >= Game.MaxPlayers, "not enough spawns")
			assert(size("Coins") >= 40, "too few candy coins")
			assert(size("Clues") >= 12, "too few clue pages")
			assert(size("Passages") >= 2, "too few secret passages")
			assert(size("Rooms") >= 8, "too few named rooms")
			for _, room in model:FindFirstChild("Rooms"):GetChildren() do
				assert(room:IsA("BasePart"), "rooms are parts")
				assert(type(room:GetAttribute("Room")) == "string" or #room.Name > 0, "rooms need a name")
			end
		end)

		it(`{name} stays under its part and light budget`, function()
			local parts, lights = count(map(name).Model)
			assert(parts <= MAP_PARTS, `{parts} parts, budget {MAP_PARTS}`)
			assert(lights <= MAP_LIGHTS, `{lights} lights, budget {MAP_LIGHTS}`)
		end)
	end

	it("have distinct ids", function()
		expect(map("Manor").Module.Id ~= map("Carnival").Module.Id).toBe(true)
	end)
end)

describe("the plaza", function()
	local model = Lobby.build(roblox.CFrame.new(0, 0, 0))

	it("has spawns, every station, the boards and the VIP balcony", function()
		expect(#model:FindFirstChild("Spawns"):GetChildren() >= Game.MaxPlayers).toBe(true)
		local stations = {}
		for _, marker in model:FindFirstChild("Stations"):GetChildren() do
			stations[marker:GetAttribute("Station")] = true
		end
		for _, station in { "Shop", "Wardrobe", "Crates", "Trade", "Pass", "Stage" } do
			assert(stations[station], `no {station} station`)
		end
		for _, board in model:FindFirstChild("Boards"):GetChildren() do
			assert(board:FindFirstChild("Screen"), `{board.Name} has no screen`)
			assert(type(board:GetAttribute("Stat")) == "string", `{board.Name} has no stat`)
		end
		assert(model:FindFirstChild("MapBoard"), "no map board")
		assert(model:FindFirstChild("VipGate"), "no VIP gate")
		assert(model:FindFirstChild("VipSpawn"), "no VIP spawn")
	end)

	it("stays under its part and light budget", function()
		local parts, lights = count(model)
		assert(parts <= LOBBY_PARTS, `{parts} parts, budget {LOBBY_PARTS}`)
		assert(lights <= LOBBY_LIGHTS, `{lights} lights, budget {LOBBY_LIGHTS}`)
	end)
end)

describe("cosmetics", function()
	it("builds a picture of every item, and the tool or accessory it becomes", function()
		for _, item in Items.List do
			local ok, err = pcall(function()
				local preview = Gear.preview(item.Id)
				assert(preview and preview:IsA("Model"), "preview must be a Model")
				if item.Kind == "Blade" then
					assert(Gear.blade(item.Id):IsA("Tool"), "blade must be a Tool")
				elseif item.Kind == "Blaster" then
					assert(Gear.blaster(item.Id):IsA("Tool"), "blaster must be a Tool")
				elseif item.Kind == "Mask" then
					assert(Gear.mask(item.Id):IsA("Accessory"), "mask must be an Accessory")
				elseif item.Kind == "Effect" then
					local look = item.Look
					Gear.burstPiece(look.Style or "smoke", look.Colors or { "#FFFFFF" }, 1)
				end
			end)
			assert(ok, `{item.Id}: {err}`)
		end
	end)

	it("draws a trail for every trail but the empty one", function()
		local root = roblox.Instance.new("Part")
		for _, item in Items.List do
			if item.Kind == "Trail" then
				local made = Gear.trail(item.Id, root)
				if item.Id == Items.DEFAULTS.Trail then
					expect(#made).toBe(0)
				else
					assert(#made > 0, `{item.Id} draws nothing`)
				end
			end
		end
	end)
end)

return nil
