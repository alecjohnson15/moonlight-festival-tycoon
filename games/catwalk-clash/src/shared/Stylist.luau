--!strict
-- Builds a starting outfit for a theme from the pieces a player owns: the
-- wardrobe's "Theme look" button. In each slot it picks one of the owned
-- pieces that fit the theme best (at random among equals, so pressing again
-- gives another idea), fills a few more slots so the look is complete, and
-- paints everything in the theme's colours. Skin, body, pose, entrance and
-- catalog items are kept from the current look. A starting point to edit,
-- not a finished look. rng() returns a number from 0 to 1.

local Look = require(script.Parent.Look)
local Palette = require(script.Parent.Config.Palette)
local Wardrobe = require(script.Parent.Config.Wardrobe)

export type Theme = { Tags: { string }, Colors: { string } }

local Stylist = {}

-- Slots a complete look fills even when nothing in them fits the theme.
Stylist.FILL_TO = 6

local function fit(piece: Wardrobe.Piece, tags: { string }): number
	local count = 0
	for _, tag in piece.Tags do
		if table.find(tags, tag) then
			count += 1
		end
	end
	return count
end

local function pick<T>(list: { T }, rng: () -> number): T
	return list[math.min(#list, math.floor(rng() * #list) + 1)]
end

function Stylist.suggest(
	theme: Theme,
	owns: (piece: Wardrobe.Piece) -> boolean,
	base: Look.Look,
	rng: () -> number
): Look.Look
	local look = Look.default()
	look.Skin = base.Skin
	look.Body = base.Body
	look.Pose = base.Pose
	look.Entrance = base.Entrance
	look.Catalog = table.clone(base.Catalog)

	local colors: { number } = {}
	for _, name in theme.Colors do
		local index = Palette.indexOf(name)
		if index then
			table.insert(colors, index)
		end
	end
	if #colors == 0 then
		colors = { 1 }
	end
	local function color(): number
		return pick(colors, rng)
	end

	look.Top = { S = pick(Look.TopStyles, rng), C = color(), F = "Satin" }
	look.Bottom = { S = pick(Look.BottomStyles, rng), C = color(), F = "Matte" }
	look.Shoes = { C = color(), F = "Satin" }

	local spare: { string } = {}
	local count = 0
	for _, slot in Wardrobe.Slots do
		local best, bestFit = {}, 0
		local any = {}
		for _, piece in Wardrobe.inSlot(slot) do
			if owns(piece) then
				table.insert(any, piece)
				local score = fit(piece, theme.Tags)
				if score > bestFit then
					best, bestFit = { piece }, score
				elseif score == bestFit and score > 0 then
					table.insert(best, piece)
				end
			end
		end
		if #best > 0 then
			local piece = pick(best, rng)
			look.Pieces[slot] = { Id = piece.Id, C = color(), A = color(), F = piece.Finish }
			count += 1
		elseif #any > 0 then
			table.insert(spare, slot)
		end
	end

	-- Fill a few more slots, so the look is complete.
	while count < Stylist.FILL_TO and #spare > 0 do
		local slot = table.remove(spare, math.min(#spare, math.floor(rng() * #spare) + 1)) :: string
		local options = {}
		for _, piece in Wardrobe.inSlot(slot) do
			if owns(piece) then
				table.insert(options, piece)
			end
		end
		local piece = pick(options, rng)
		look.Pieces[slot] = { Id = piece.Id, C = color(), A = color(), F = piece.Finish }
		count += 1
	end
	return look
end

return Stylist
