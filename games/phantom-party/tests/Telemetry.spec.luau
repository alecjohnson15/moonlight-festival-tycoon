-- Analytics: only listed events go out, cleaned to listed values, a few a
-- minute at most, and nothing that names a player (Config/Telemetry,
-- Rules/Telemetry, server/Services/AnalyticsService).

local fs = require("@lune/fs")
local Loader = require("./RobloxLoader")
local TestKit = require("./TestKit")

local Telemetry = Loader.require("src/shared/Rules/Telemetry")
local TelemetryConfig = Loader.require("src/shared/Config/Telemetry")
local Roles = Loader.require("src/shared/Config/Roles")
local Items = Loader.require("src/shared/Config/Items")
local Crates = Loader.require("src/shared/Config/Crates")
local Round = Loader.require("src/shared/Rules/Round")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("telemetry", function()
	it("sends only listed events", function()
		local ok = Telemetry.clean("NotAnEvent", 1, {})
		expect(ok).toBe(false)
		local sent, value, fields = Telemetry.clean("RoundPlayed", 1, { "Guardian", "Won" })
		expect(sent).toBe(true)
		expect(value).toBe(1)
		expect(fields).toEqual({ "Guardian", "Won" })
	end)

	it("replaces anything unlisted with Other, so a name can't slip through", function()
		local _, _, fields = Telemetry.clean("RoundPlayed", 1, { "xXPlayerNameXx", 123456789 })
		expect(fields).toEqual({ "Other", "Other" })
		local _, _, more = Telemetry.clean("CosmeticEquip", 1, { "Mask", "extra", "fields" })
		expect(more).toEqual({ "Mask" })
		local _, _, none = Telemetry.clean("FirstAction", 1, nil)
		expect(none).toEqual({ "Other", "Other", "Other" })
	end)

	it("keeps numbers whole and in range", function()
		local _, big = Telemetry.clean("Replay", 1e12, { "Full" })
		expect(big).toBe(TelemetryConfig.MaxValue)
		local _, negative = Telemetry.clean("Replay", -5, { "Full" })
		expect(negative).toBe(0)
		local _, nan = Telemetry.clean("Replay", 0 / 0, { "Full" })
		expect(nan).toBe(1)
		local _, _, counts = Telemetry.clean("TradeCompleted", 3, { 2.7, 500 })
		expect(counts).toEqual({ "2", "99" })
	end)

	it("can be switched off, as a whole or one event at a time", function()
		local off = table.clone(TelemetryConfig)
		off.Enabled = false
		expect((Telemetry.clean("RoundPlayed", 1, {}, off))).toBe(false)
		local one = table.clone(TelemetryConfig)
		one.Events = table.clone(TelemetryConfig.Events)
		one.Events.LeadSeen = { Fields = { "Family" }, Off = true }
		expect((Telemetry.clean("LeadSeen", 1, { "Witness" }, one))).toBe(false)
		expect((Telemetry.clean("RoundPlayed", 1, {}, one))).toBe(true)
	end)

	it("lets a player send only so many a minute", function()
		local limiter = Telemetry.limiter()
		local sent = 0
		for second = 0, 59, 0.5 do
			if Telemetry.allow(limiter, second, 30) then
				sent += 1
			end
		end
		expect(sent).toBe(30)
		-- A minute after the first ones, there's room again.
		expect(Telemetry.allow(limiter, 60.1, 30)).toBe(true)
	end)

	it("lists the values the game really uses", function()
		local values = TelemetryConfig.Values
		for roleId in Roles.List do
			assert(table.find(values.Role, roleId), `role {roleId} not listed`)
		end
		for _, kind in Items.KINDS do
			assert(table.find(values.Kind, kind), `item kind {kind} not listed`)
		end
		for _, rarity in Items.RARITIES do
			assert(table.find(values.Rarity, rarity), `rarity {rarity} not listed`)
		end
		for _, crate in Crates.List do
			assert(table.find(values.Crate, crate.Id), `crate {crate.Id} not listed`)
		end
		for _, name in { "Manor", "Carnival" } do
			local map = Loader.require(`src/shared/Look/Maps/{name}`)
			assert(table.find(values.Map, map.Id), `map {map.Id} not listed`)
		end
		for _, ruleset in { "Practice", "Duel", "Small", "Full" } do
			assert(table.find(values.Ruleset, ruleset), `ruleset {ruleset} not listed`)
		end
		expect(Round.ruleset(2)).toBe("Duel")
		for _, event in TelemetryConfig.Events do
			for _, field in event.Fields do
				assert(values[field] ~= nil, `field {field} has no values`)
			end
			assert(#event.Fields <= 3, "Roblox takes three custom fields at most")
		end
	end)

	it("never sends a name, user id or chat from the server", function()
		local source = fs.readFile("src/server/Services/AnalyticsService.luau")
		local calls = 0
		for _ in string.gmatch(source, "LogCustomEvent%(") do
			calls += 1
		end
		expect(calls).toBe(1)
		for line in string.gmatch(source, "[^\n]+") do
			if string.find(line, "track(", 1, true) and not string.find(line, "function", 1, true) then
				for _, word in { "Name", "UserId", "DisplayName", "Message", "Text" } do
					assert(not string.find(line, word, 1, true), `analytics line mentions {word}: {line}`)
				end
				local event = string.match(line, 'track%([^,]+, "(%w+)"')
				assert(event and TelemetryConfig.Events[event], `unlisted event in: {line}`)
			end
		end
		-- Every other service goes through the named helpers.
		for _, name in fs.readDir("src/server/Services") do
			if name ~= "AnalyticsService.luau" then
				local other = fs.readFile(`src/server/Services/{name}`)
				assert(not string.find(other, "LogCustomEvent", 1, true), `{name} logs events directly`)
			end
		end
	end)
end)

return nil
