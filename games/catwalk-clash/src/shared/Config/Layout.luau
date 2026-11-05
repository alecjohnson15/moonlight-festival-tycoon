--!strict
-- Where everything is. The world builder (shared/Build/World) puts the
-- places here, the server moves characters to them and the clients point
-- cameras at them. Studs, with Y up and the ground at 0.
--
--   Glow Plaza (the lobby)      centred on the origin
--   The Runway (show hall)      north of the plaza, toward -Z
--   Backstage (dressing room)   south of the plaza, toward +Z
--   Boutique and Style Pass     east of the plaza
--   VIP Lounge and Closet       west of the plaza
--
-- Walkers come out of the stage door at the north end of the runway and
-- stride south toward the judges and the camera.

local function facing(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction)
end

local NORTH = Vector3.new(0, 0, -1)
local SOUTH = Vector3.new(0, 0, 1)
local EAST = Vector3.new(1, 0, 0)
local WEST = Vector3.new(-1, 0, 0)

local Layout = {}

Layout.PlazaRadius = 50

-- The runway: two lanes on a raised stage.
Layout.Stage = {
	Top = 3,
	StartZ = -160,
	EndZ = -102,
	LaneX = 6,
	-- The T at the end of the runway, where the podium stands.
	TStartZ = -100,
	TEndZ = -90,
	Width = 26,
}

Layout.Hall = { MinX = -48, MaxX = 48, MinZ = -178, MaxZ = -70, Height = 32 }
Layout.Backstage = { MinX = -46, MaxX = 46, MinZ = 70, MaxZ = 148, Height = 24 }

local stageY = Layout.Stage.Top

-- Where each walker waits behind the stage door, starts and strikes a pose.
Layout.Lanes = {
	A = {
		Wait = facing(Vector3.new(-Layout.Stage.LaneX, stageY + 3, -163), SOUTH),
		Start = facing(Vector3.new(-Layout.Stage.LaneX, stageY + 3, -158), SOUTH),
		Pose = facing(Vector3.new(-Layout.Stage.LaneX, stageY + 3, -104), SOUTH),
	},
	B = {
		Wait = facing(Vector3.new(Layout.Stage.LaneX, stageY + 3, -163), SOUTH),
		Start = facing(Vector3.new(Layout.Stage.LaneX, stageY + 3, -158), SOUTH),
		Pose = facing(Vector3.new(Layout.Stage.LaneX, stageY + 3, -104), SOUTH),
	},
}

-- The podium at the end of the runway: first in the middle.
Layout.Podium = {
	First = facing(Vector3.new(0, stageY + 2.4 + 3, -95), SOUTH),
	Second = facing(Vector3.new(-5.5, stageY + 1.6 + 3, -95), SOUTH),
	Third = facing(Vector3.new(5.5, stageY + 0.9 + 3, -95), SOUTH),
	Heights = { First = 2.4, Second = 1.6, Third = 0.9 },
}

-- The opening lineup: everyone in the show stands on the runway in two
-- staggered rows of six, facing the audience, before the first matchup.
Layout.Lineup = {} :: { CFrame }
for index = 0, 11 do
	local row = index // 6
	local column = index % 6
	local x = -11 + column * 4 + row * 2
	local z = -108 - row * 6
	table.insert(Layout.Lineup, facing(Vector3.new(x, stageY + 3, z), SOUTH))
end

-- Cameras: the wide shot down the runway, a closer one for poses, and the
-- podium shot. Each is a camera position and the point it looks at.
Layout.Cameras = {
	Lineup = { From = Vector3.new(0, 11, -84), At = Vector3.new(0, 5.5, -112) },
	Runway = { From = Vector3.new(0, 12, -76), At = Vector3.new(0, 5.5, -124) },
	Pose = { From = Vector3.new(0, 8.5, -86), At = Vector3.new(0, 6, -104) },
	Podium = { From = Vector3.new(0, 9, -79), At = Vector3.new(0, 7, -95) },
	Reveal = { From = Vector3.new(0, 16, 30), At = Vector3.new(0, 10, -40) },
}

-- Where the audience stands: three tiers on each side of the runway.
Layout.Audience = {} :: { CFrame }
for tier = 1, 3 do
	local x = 15 + tier * 5
	local y = tier * 1.5 + 3
	for z = -150, -110, 8 do
		table.insert(Layout.Audience, facing(Vector3.new(-x, y, z), EAST))
		table.insert(Layout.Audience, facing(Vector3.new(x, y, z), WEST))
	end
end

-- Dressing booths along the backstage walls, six a side.
Layout.Booths = {} :: { CFrame }
for index = 0, 5 do
	local z = 84 + index * 11
	table.insert(Layout.Booths, facing(Vector3.new(-34, 3, z), EAST))
	table.insert(Layout.Booths, facing(Vector3.new(34, 3, z), WEST))
end

-- Where players stand in the lobby after a show: a ring round the fountain.
Layout.LobbyRing = {} :: { CFrame }
for index = 0, 11 do
	local angle = math.rad(index * 30)
	local position = Vector3.new(math.sin(angle) * 24, 3, math.cos(angle) * 24)
	table.insert(Layout.LobbyRing, CFrame.lookAt(position, Vector3.new(0, 3, 0)))
end

Layout.Spawns = {
	facing(Vector3.new(0, 0.5, 30), NORTH),
	facing(Vector3.new(-26, 0.5, 16), NORTH),
	facing(Vector3.new(26, 0.5, 16), NORTH),
}

Layout.HallOfFame = facing(Vector3.new(0, 4.9, -38), SOUTH)

-- The rooftop VIP Lounge, and the gate at the foot of its stairs.
Layout.Lounge = {
	Floor = 10,
	Centre = Vector3.new(-68, 10, 0),
	Gate = CFrame.new(-50, 4, 0),
	Inside = facing(Vector3.new(-68, 13, 0), EAST),
}

-- Kiosks with prompts that open menus.
Layout.Kiosks = {
	Boutique = facing(Vector3.new(58, 0, 0), WEST),
	StylePass = facing(Vector3.new(58, 0, 26), WEST),
	Leaderboard = facing(Vector3.new(58, 0, -26), WEST),
	Closet = facing(Vector3.new(-56, 0, -24), EAST),
	Challenges = facing(Vector3.new(-56, 0, 24), EAST),
}

-- Spots along the runway where photographers' flashes go off.
Layout.Flashes = {} :: { Vector3 }
for z = -150, -104, 6 do
	table.insert(Layout.Flashes, Vector3.new(-13, 5, z))
	table.insert(Layout.Flashes, Vector3.new(13, 5, z))
end

-- The judges' seats, left to right as the walkers see them.
Layout.Judges = {
	facing(Vector3.new(-7, 0, -84), NORTH),
	facing(Vector3.new(0, 0, -84), NORTH),
	facing(Vector3.new(7, 0, -84), NORTH),
}

return Layout
