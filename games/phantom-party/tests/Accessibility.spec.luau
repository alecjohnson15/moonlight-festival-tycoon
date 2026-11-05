-- Captions and Reduce motion: every caption is for a real sound, every
-- sound that tells a player something has a caption, the switches are ones
-- the server will save, and bouncy motion goes through the one helper that
-- Reduce motion turns off.

local fs = require("@lune/fs")
local Loader = require("./RobloxLoader")
local TestKit = require("./TestKit")

local Captions = Loader.require("src/shared/Config/Captions")
local SoundConfig = Loader.require("src/shared/Config/Sounds")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- Every Sounds.play("Name" ...) in the client, with whether any call gives
-- it a position.
local function played(): { [string]: boolean }
	local found = {}
	for _, file in fs.readDir("src/client") do
		if string.sub(file, -5) == ".luau" then
			local source = fs.readFile(`src/client/{file}`)
			for name, rest in string.gmatch(source, 'Sounds%.play%("(%w+)"([^\n]*)') do
				local positioned = string.sub(rest, 1, 1) == "," and not string.find(rest, "^, nil")
				found[name] = found[name] or positioned
			end
		end
	end
	return found
end

describe("captions", function()
	it("are only for sounds the game has, and stay short", function()
		for name, text in Captions.Text do
			assert(SoundConfig.List[name], `caption for unknown sound {name}`)
			assert(#text <= 40, `caption for {name} is too long`)
		end
		expect(Captions.Seconds >= 2).toBe(true)
		expect(Captions.MaxLines <= 4).toBe(true)
	end)

	it("cover every sound played from a spot in the world, and the round's big moments", function()
		for name, positioned in played() do
			if positioned and name ~= "Pop" then
				assert(Captions.Text[name], `{name} plays in the world but has no caption`)
			end
		end
		for _, name in { "Bell", "Blackout", "Tick", "Tag", "Zap", "Revive", "GuestsWin", "PhantomWins" } do
			assert(Captions.Text[name], `no caption for {name}`)
		end
	end)

	it("leave out menu clicks and music", function()
		for _, name in { "Click", "Deny", "LobbyMusic", "RoundMusic", "FinalMusic" } do
			expect(Captions.Text[name]).toBe(nil)
		end
	end)
end)

describe("settings", function()
	it("offers only switches the server saves", function()
		local server = fs.readFile("src/server/Services/ProfileService.luau")
		local whitelist = string.match(server, "local SETTINGS = (%b{})")
		assert(whitelist, "no settings whitelist in ProfileService")
		local client = fs.readFile("src/client/Settings.luau")
		local count = 0
		for name in string.gmatch(client, 'flip%("(%w+)"') do
			count += 1
			assert(string.find(whitelist, name .. " = true", 1, true), `{name} isn't saved by the server`)
		end
		expect(count >= 3).toBe(true)
	end)

	it("send bouncy motion through Ui.pop, which Reduce motion turns off", function()
		for _, file in fs.readDir("src/client") do
			if string.sub(file, -5) == ".luau" and file ~= "Ui.luau" and file ~= "Controls.luau" then
				local source = fs.readFile(`src/client/{file}`)
				assert(not string.find(source, "EasingStyle.Back", 1, true), `{file} bounces without Ui.pop`)
			end
		end
		local controls = fs.readFile("src/client/Controls.luau")
		assert(string.find(controls, "ReduceMotion", 1, true), "the hit marker ignores Reduce motion")
		local motion = fs.readFile("src/client/Motion.luau")
		assert(string.find(motion, "Ui.ReduceMotion", 1, true), "lights flicker with Reduce motion on")
	end)
end)

return nil
