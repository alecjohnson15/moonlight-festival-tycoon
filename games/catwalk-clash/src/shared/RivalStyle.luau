--!strict
-- Dresses a rival (Config/People) for a theme. A rival's Skill is the chance
-- each choice fits the theme; otherwise they follow their own taste. Rivals
-- may wear anything in the wardrobe. rng() returns a number from 0 to 1.

local Look = require(script.Parent.Look)
local Palette = require(script.Parent.Config.Palette)
local Wardrobe = require(script.Parent.Config.Wardrobe)
local Entrances = require(script.Parent.Config.Entrances)

export type Rival = { Loves: { string }, Skill: number, Skin: number, Pose: string }
export type Theme = { Tags: { string }, Colors: { string } }

local RivalStyle = {}

local function hasAny(tags: { string }, wanted: { string }): boolean
	for _, tag in tags do
		if table.find(wanted, tag) then
			return true
		end
	end
	return false
end

local function pick<T>(list: { T }, rng: () -> number): T?
	if #list == 0 then
		return nil
	end
	return list[math.floor(rng() * #list) + 1]
end

local function colorFor(theme: Theme, skill: number, rng: () -> number): number
	if rng() < skill then
		local name = pick(theme.Colors, rng)
		if name then
			return Palette.indexOf(name) :: number
		end
	end
	return math.floor(rng() * #Palette.Colors) + 1
end

function RivalStyle.dress(rival: Rival, theme: Theme, rng: () -> number): Look.Look
	local look = Look.default()
	look.Skin = rival.Skin
	look.Pose = rival.Pose
	look.Top = { S = pick(Look.TopStyles, rng), C = colorFor(theme, rival.Skill, rng), F = "Satin" }
	look.Bottom = { S = pick(Look.BottomStyles, rng), C = colorFor(theme, rival.Skill, rng), F = "Matte" }
	look.Shoes = { C = colorFor(theme, rival.Skill, rng), F = "Satin" }

	local free = {}
	for _, entrance in Entrances.List do
		if entrance.Price == 0 and not entrance.Pass and not entrance.Season then
			table.insert(free, entrance.Id)
		end
	end
	look.Entrance = pick(free, rng) or Entrances.Default

	-- A few slots, more for more skilled rivals.
	local slots = table.clone(Wardrobe.Slots)
	local count = 3 + math.floor(rival.Skill * 4 + rng() * 2)
	local takenHand = false
	for _ = 1, count do
		if #slots == 0 then
			break
		end
		local slot = table.remove(slots, math.floor(rng() * #slots) + 1) :: string
		if slot == "Hand" and takenHand then
			continue
		end
		local wanted = if rng() < rival.Skill then theme.Tags else rival.Loves
		local fitting, any = {}, {}
		for _, piece in Wardrobe.inSlot(slot) do
			table.insert(any, piece)
			if hasAny(piece.Tags, wanted) then
				table.insert(fitting, piece)
			end
		end
		local piece = pick(if #fitting > 0 then fitting else any, rng)
		if piece then
			takenHand = takenHand or slot == "Hand"
			look.Pieces[slot] = {
				Id = piece.Id,
				C = if rng() < 0.5 then Palette.indexOf(piece.Main) else colorFor(theme, rival.Skill, rng),
				A = Palette.indexOf(piece.Accent),
				F = piece.Finish,
			}
		end
	end
	return look
end

return RivalStyle
