-- The publish kit: publish/manifest.json (what publish/publish.ps1 makes on
-- Roblox) must match Config, every file it names must exist, and any ids
-- the script has written back must agree with publish/ids.json.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local RobloxLoader = require("./RobloxLoader")
local TestKit = require("./TestKit")
local PublishManifest = require("../tools/PublishManifest")

local Catalog = RobloxLoader.require("src/shared/Config/Catalog")
local Sounds = RobloxLoader.require("src/shared/Config/Sounds").List

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local manifest = serde.decode("json", fs.readFile(PublishManifest.PATH))

-- Width and height from a PNG's header.
local function pngSize(path: string): (number, number)
	local data = fs.readFile(path)
	assert(string.sub(data, 2, 4) == "PNG", `{path} isn't a PNG`)
	return string.unpack(">I4I4", data, 17)
end

local function forSale(): { any }
	local list = table.clone(manifest.passes)
	table.move(manifest.products, 1, #manifest.products, #list + 1, list)
	return list
end

describe("publish kit", function()
	it("matches Config (run `lune run tools/make_manifest` after changing a pass, price or sound)", function()
		expect(manifest).toEqual(PublishManifest.build())
	end)

	it("fits Roblox's limits for the name and description", function()
		assert(utf8.len(manifest.place.displayName) <= 50, "name is over 50 characters")
		assert(utf8.len(manifest.place.description) <= 1000, "description is over 1,000 characters")
		assert(manifest.place.serverSize >= 1 and manifest.place.serverSize <= 100, "server size out of range")
	end)

	it("uploads every sound once, from a file that exists", function()
		local seen = {}
		for _, sound in manifest.sounds do
			assert(Sounds[sound.name], `{sound.name} isn't in Config/Sounds`)
			assert(not seen[sound.name], `{sound.name} is listed twice`)
			seen[sound.name] = true
			assert(fs.isFile(sound.file), `missing {sound.file}`)
			assert(utf8.len(sound.displayName) <= 50, `{sound.name}'s asset name is too long`)
		end
		for name in Sounds do
			assert(seen[name], `{name} isn't uploaded by the publish script`)
		end
	end)

	it("lists every Robux item, each with a 512x512 icon", function()
		expect(#forSale()).toBe(#Catalog)
		for _, entry in forSale() do
			assert(entry.price > 0, `{entry.id} has no price`)
			assert(#entry.description > 0, `{entry.id} has no description`)
			local width, height = pngSize(entry.icon)
			assert(width == 512 and height == 512, `{entry.icon} is {width}x{height}, not 512x512`)
		end
	end)

	it("has the same ids in Config as in publish/ids.json", function()
		local ids = if fs.isFile("publish/ids.json")
			then serde.decode("json", fs.readFile("publish/ids.json"))
			else { passes = {}, products = {}, sounds = {} }
		for _, item in Catalog do
			local made = ids.passes[item.Id]
			expect(item.PassId).toBe(if made then tonumber(made) else 0)
		end
		for name, sound in Sounds do
			local made = ids.sounds[name]
			expect(sound.Id).toBe(if made then `rbxassetid://{made}` else "")
		end
	end)
end)
