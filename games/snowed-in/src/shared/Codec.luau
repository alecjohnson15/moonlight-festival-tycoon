--!strict
-- Packs the monsters' positions into a buffer for the ten-a-second snapshot
-- the server sends every client, at 14 bytes a monster: id, kind, pose,
-- position, health and facing. A night's sixty monsters cost under a
-- kilobyte a snapshot.

local Enemies = require(script.Parent.Config.Enemies)

export type Entry = {
	Id: number,
	Kind: string,
	Action: "Walk" | "Attack" | "Idle" | "Windup" | "Tired",
	X: number,
	Z: number,
	-- 0 to 1 of its full health.
	Health: number,
	Heading: number,
}

local Codec = {}

local SIZE = 14
local ACTIONS = { "Walk", "Attack", "Idle", "Windup", "Tired" }
local ACTION_CODE = { Walk = 1, Attack = 2, Idle = 3, Windup = 4, Tired = 5 }
local TAU = 2 * math.pi

function Codec.encode(entries: { Entry }): buffer
	local data = buffer.create(2 + SIZE * #entries)
	buffer.writeu16(data, 0, #entries)
	for index, entry in entries do
		local offset = 2 + SIZE * (index - 1)
		buffer.writeu16(data, offset, entry.Id)
		buffer.writeu8(data, offset + 2, Enemies.Code[entry.Kind] or 1)
		buffer.writeu8(data, offset + 3, ACTION_CODE[entry.Action] or 1)
		buffer.writef32(data, offset + 4, entry.X)
		buffer.writef32(data, offset + 8, entry.Z)
		buffer.writeu8(data, offset + 12, math.clamp(math.floor(entry.Health * 255 + 0.5), 0, 255))
		local turn = (entry.Heading % TAU) / TAU
		buffer.writeu8(data, offset + 13, math.floor(turn * 256) % 256)
	end
	return data
end

function Codec.decode(data: buffer): { Entry }
	local entries = {}
	if buffer.len(data) < 2 then
		return entries
	end
	local count = buffer.readu16(data, 0)
	if buffer.len(data) < 2 + SIZE * count then
		return entries
	end
	for index = 1, count do
		local offset = 2 + SIZE * (index - 1)
		local kind = Enemies.ByCode[buffer.readu8(data, offset + 2)]
		table.insert(entries, {
			Id = buffer.readu16(data, offset),
			Kind = if kind then kind.Id else "Frostling",
			Action = (ACTIONS[buffer.readu8(data, offset + 3)] or "Walk") :: any,
			X = buffer.readf32(data, offset + 4),
			Z = buffer.readf32(data, offset + 8),
			Health = buffer.readu8(data, offset + 12) / 255,
			Heading = buffer.readu8(data, offset + 13) / 256 * TAU,
		})
	end
	return entries
end

return Codec
