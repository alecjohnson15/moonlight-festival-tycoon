-- The upgrade's invariants: every way a round can end, walls blocking
-- tags and shots, effects that can't point at the Phantom, and the chat
-- firewall between the out and the living.

local fs = require("@lune/fs")
local Loader = require("./RobloxLoader")
local TestKit = require("./TestKit")

local Vector3 = Loader.roblox.Vector3
local Chat = Loader.require("src/shared/Rules/Chat")
local Combat = Loader.require("src/shared/Rules/Combat")
local Game = Loader.require("src/shared/Config/Game")
local Roles = Loader.require("src/shared/Config/Roles")
local Round = Loader.require("src/shared/Rules/Round")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

-- The rules written out a second way, as a referee would read them, to check
-- Round.outcome against every combination of states.
local function referee(cast, timeLeft)
	local phantom
	local guests = {}
	for _, entry in cast do
		if entry.Role == "Phantom" then
			phantom = entry
		elseif Roles.team(entry.Role) == "Guests" then
			table.insert(guests, entry)
		end
	end
	if phantom.State == "Out" then
		return "Guests", if phantom.Left then "PhantomLeft" else "PhantomOut"
	end
	local standing, gone = 0, 0
	for _, guest in guests do
		if guest.State == "Alive" then
			standing += 1
		elseif guest.Left then
			gone += 1
		end
	end
	if standing == 0 then
		return "Shadows", if #guests > 0 and gone == #guests then "GuestsLeft" else "AllTagged"
	end
	if timeLeft <= 0 then
		return "Guests", "Time"
	end
	return nil, nil
end

local STATES = {
	{ State = "Alive" },
	{ State = "Dazed" },
	{ State = "Out" },
	{ State = "Out", Left = true },
}
local PHANTOM_STATES = {
	{ State = "Alive" },
	{ State = "Out" },
	{ State = "Out", Left = true },
}

describe("round end rules", function()
	it("agree with the referee for every mix of states", function()
		local checked = 0
		for _, phantom in PHANTOM_STATES do
			for _, saboteur in STATES do
				for _, guardian in STATES do
					for _, guest in STATES do
						for _, medic in STATES do
							for _, timeLeft in { 30, 0 } do
								local cast = {
									{ Role = "Phantom", State = phantom.State, Left = phantom.Left },
									{ Role = "Saboteur", State = saboteur.State, Left = saboteur.Left },
									{ Role = "Guardian", State = guardian.State, Left = guardian.Left },
									{ Role = "Guest", State = guest.State, Left = guest.Left },
									{ Role = "Medic", State = medic.State, Left = medic.Left },
								}
								local winner, why = Round.outcome(cast, timeLeft)
								local wantWinner, wantWhy = referee(cast, timeLeft)
								if winner ~= wantWinner or why ~= wantWhy then
									error(
										`mismatch: phantom {phantom.State}, guardian {guardian.State}, guest {guest.State}, `
											.. `medic {medic.State}, time {timeLeft}: got {winner}/{why}, `
											.. `want {wantWinner}/{wantWhy}`
									)
								end
								checked += 1
							end
						end
					end
				end
			end
		end
		expect(checked).toBe(3 * 4 * 4 * 4 * 4 * 2)
	end)

	it("always names a reason that hands the win to the team it says", function()
		for _, phantom in PHANTOM_STATES do
			for _, guest in STATES do
				for _, timeLeft in { 5, 0 } do
					local winner, why = Round.outcome({
						{ Role = "Phantom", State = phantom.State, Left = phantom.Left },
						{ Role = "Guest", State = guest.State, Left = guest.Left },
					}, timeLeft)
					if winner then
						expect(Round.REASONS[why]).toBe(winner)
					else
						expect(why).toBe(nil)
					end
				end
			end
		end
	end)

	it("lets a zap on the Phantom beat a tag on the last guest", function()
		local winner, why = Round.outcome({
			{ Role = "Phantom", State = "Out" },
			{ Role = "Guest", State = "Dazed" },
		}, 30)
		expect(winner).toBe("Guests")
		expect(why).toBe("PhantomOut")
	end)

	it("doesn't let a standing Saboteur keep the round going", function()
		local winner, why = Round.outcome({
			{ Role = "Phantom", State = "Out" },
			{ Role = "Saboteur", State = "Alive" },
			{ Role = "Guest", State = "Out" },
		}, 30)
		expect(winner).toBe("Guests")
		expect(why).toBe("PhantomOut")
	end)

	it("counts a Phantom who left as leaving, not as caught", function()
		local _, why =
			Round.outcome({ { Role = "Phantom", State = "Out", Left = true }, { Role = "Guest", State = "Alive" } }, 9)
		expect(why).toBe("PhantomLeft")
	end)

	it("ends for the Shadows when every guest left, and says so", function()
		local winner, why = Round.outcome({
			{ Role = "Phantom", State = "Alive" },
			{ Role = "Guest", State = "Out", Left = true },
			{ Role = "Guardian", State = "Out", Left = true },
		}, 60)
		expect(winner).toBe("Shadows")
		expect(why).toBe("GuestsLeft")
	end)

	it("never revives the Phantom or the Saboteur, and only the dazed", function()
		expect(Round.canRevive("Phantom", "Dazed")).toBe(false)
		expect(Round.canRevive("Saboteur", "Dazed")).toBe(false)
		expect(Round.canRevive("Guest", "Out")).toBe(false)
		expect(Round.canRevive("Guest", "Alive")).toBe(false)
		expect(Round.canRevive("Guardian", "Dazed")).toBe(true)
	end)

	it("hands a dropped blaster only to a guest still standing", function()
		expect(Round.canPickUp("Guest", "Alive")).toBe(true)
		expect(Round.canPickUp("Medic", "Alive")).toBe(true)
		expect(Round.canPickUp("Guest", "Dazed")).toBe(false)
		expect(Round.canPickUp("Saboteur", "Alive")).toBe(false)
		expect(Round.canPickUp("Phantom", "Alive")).toBe(false)
	end)

	it("names the ruleset honestly for each party size", function()
		expect(Round.ruleset(1)).toBe("Practice")
		expect(Round.ruleset(2)).toBe("Duel")
		expect(Round.ruleset(3)).toBe("Small")
		expect(Round.ruleset(4)).toBe("Small")
		expect(Round.ruleset(5)).toBe("Full")
		expect(Round.ruleset(Game.MaxPlayers)).toBe("Full")
	end)
end)

-- A wall across the room at z = -2, from x = -10 to 10, floor to ceiling.
local function wall(from, to)
	local z = -2
	if (from.Z - z) * (to.Z - z) > 0 then
		return true
	end
	local t = (z - from.Z) / (to.Z - from.Z)
	local x = from.X + (to.X - from.X) * t
	return math.abs(x) > 10
end

describe("walls", function()
	local origin = Vector3.new(0, 0, 0)
	local facing = Vector3.new(0, 0, -1)

	it("stop a swing reaching a guest on the other side", function()
		local behindWall = { { Id = "there", Position = Vector3.new(0, 0, -4) } }
		local hit = Combat.swingTarget(origin, facing, behindWall, 7, 75, 5, nil)
		expect(hit and hit.Id).toBe("there")
		expect(Combat.swingTarget(origin, facing, behindWall, 7, 75, 5, wall)).toBe(nil)
	end)

	it("let a swing past the end of a wall still land", function()
		local around = { { Id = "edge", Position = Vector3.new(0, 0, -1.5) } }
		local hit = Combat.swingTarget(origin, facing, around, 7, 75, 5, wall)
		expect(hit and hit.Id).toBe("edge")
	end)

	it("pick the nearest guest the Phantom can actually see", function()
		local targets = {
			{ Id = "hidden", Position = Vector3.new(0, 0, -3) },
			{ Id = "open", Position = Vector3.new(4, 0, -1) },
		}
		local hit = Combat.swingTarget(origin, Vector3.new(1, 0, -1), targets, 7, 75, 5, wall)
		expect(hit and hit.Id).toBe("open")
	end)

	it("never let a shot start on the far side of a wall", function()
		local here = Vector3.new(0, 1.5, 0)
		expect(Combat.origin(Vector3.new(0, 1.5, -5), here, 10, wall)).toBe(here)
		local muzzle = Vector3.new(0.5, 1.5, -1)
		expect(Combat.origin(muzzle, here, 10, wall)).toBe(muzzle)
	end)

	it("start a shot where the server has the shooter when the claim is far or broken", function()
		local here = Vector3.new(0, 1.5, 0)
		expect(Combat.origin(Vector3.new(30, 1.5, 0), here, 10, nil)).toBe(here)
		expect(Combat.origin(Vector3.new(0 / 0, 0, 0), here, 10, nil)).toBe(here)
		expect(Combat.origin("not a vector", here, 10, nil)).toBe(here)
		expect(Combat.origin(nil, here, 10, nil)).toBe(here)
	end)
end)

describe("a thrown blade, seen from afar", function()
	local start = Vector3.new(0, 0, 0)
	local east = Vector3.new(1, 0, 0)

	it("shows from the start to anyone who could see the thrower", function()
		expect(Combat.pathStart(start, east, 150, Vector3.new(10, 0, 10), 40)).toBe(0)
	end)

	it("shows only from where it comes into view further down the path", function()
		local from = Combat.pathStart(start, east, 150, Vector3.new(100, 0, 0), 40) :: number
		expect(math.abs(from - 60) < 1e-6).toBe(true)
	end)

	it("isn't sent at all to someone it never comes near", function()
		expect(Combat.pathStart(start, east, 150, Vector3.new(60, 0, 80), 40)).toBe(nil)
		expect(Combat.pathStart(start, east, 150, Vector3.new(400, 0, 0), 40)).toBe(nil)
	end)

	it("never shows a viewer a point they couldn't see, over many throws", function()
		local state = 7
		local function roll()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
		for _ = 1, 2000 do
			local angle = roll() * math.pi * 2
			local heading = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local viewer = Vector3.new((roll() - 0.5) * 400, 0, (roll() - 0.5) * 400)
			local from = Combat.pathStart(start, heading, 150, viewer, 40)
			if from then
				local shown = start + heading * from
				expect((shown - viewer).Magnitude <= 40 + 1e-3).toBe(true)
				if from > 0 then
					local before = start + heading * math.max(0, from - 1)
					expect((before - viewer).Magnitude > 40 - 1e-3).toBe(true)
				end
			end
		end
	end)
end)

describe("secrets", function()
	it("keep the out and the plaza from talking to the living", function()
		for _, quiet in { "Dazed", "Out", "Lobby" } do
			expect(Chat.canHear({ State = "Alive", Position = Vector3.new() }, { State = quiet }, 60)).toBe(false)
		end
	end)

	it("never send a role or a user id with a server effect", function()
		-- The one effect that depends on a role is the blackout, where each
		-- client is told only whether they themselves see outlines.
		local allowed = { ['"Blackout", CombatConfig.Blackout.Seconds, other.Role == "Phantom"'] = true }
		local checked = 0
		for _, name in fs.readDir("src/server/Services") do
			local source = fs.readFile(`src/server/Services/{name}`)
			for line in string.gmatch(source, "[^\n]+") do
				if
					string.find(line, "Fx:FireClient", 1, true)
					or string.find(line, "fxAll(", 1, true)
					or string.find(line, "fxNear(", 1, true)
				then
					checked += 1
					local fine = false
					for pattern in allowed do
						if string.find(line, pattern, 1, true) then
							fine = true
						end
					end
					if not fine and (string.find(line, "UserId", 1, true) or string.find(line, "Role", 1, true)) then
						error(`{name} sends a private detail with an effect: {line}`)
					end
				end
			end
		end
		expect(checked > 10).toBe(true)
	end)

	it("guard every chat channel, whispers included", function()
		local source = fs.readFile("src/server/Services/ChatService.luau")
		expect(string.find(source, "channels.ChildAdded:Connect", 1, true) ~= nil).toBe(true)
	end)
end)
