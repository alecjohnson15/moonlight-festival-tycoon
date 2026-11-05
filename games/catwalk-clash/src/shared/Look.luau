--!strict
-- A look: everything a player is wearing, as plain data. Clients send looks
-- to the server, saves keep them, and server/Services/LookService puts them
-- on characters. Look.sanitize is the server's check on whatever a client
-- sends: anything unknown, unowned or malformed is dropped, never trusted.
--
--   Skin     place in Palette.Skins
--   Body     "Classic" (the standard body, fair for everyone) or "Mine"
--   Top      { S = style, C = colour, F = finish }: the painted top
--   Bottom   { S = style, C = colour, F = finish }: the painted bottoms
--   Shoes    { C = colour, F = finish }, or C = 0 for bare feet
--   Gloves   { C = colour }, or C = 0 for bare hands
--   Pieces   { [slot] = { Id, C = main colour, A = accent colour, F = finish } }
--   Catalog  Roblox catalog asset ids to wear (checked again by the server)
--   Pose     Config/Poses id;  Entrance  Config/Entrances id
--
-- A colour is a number (place in Palette.Colors), or "#RRGGBB" for owners of
-- the Color Studio pass.

local Palette = require(script.Parent.Config.Palette)
local Poses = require(script.Parent.Config.Poses)
local Entrances = require(script.Parent.Config.Entrances)
local Wardrobe = require(script.Parent.Config.Wardrobe)

export type Paint = { S: string?, C: any, F: string? }
export type PieceChoice = { Id: string, C: any, A: any, F: string? }

export type Look = {
	Skin: number,
	Body: string,
	Top: Paint,
	Bottom: Paint,
	Shoes: Paint,
	Gloves: Paint,
	Pieces: { [string]: PieceChoice },
	Catalog: { number },
	Pose: string,
	Entrance: string,
}

export type Context = {
	ownsPiece: (id: string) -> boolean,
	ownsPose: (id: string) -> boolean,
	ownsEntrance: (id: string) -> boolean,
	customColors: boolean,
	maxCatalog: number,
}

local Look = {}

Look.TopStyles = { "Tee", "Long", "Tank", "Suit" }
Look.BottomStyles = { "Pants", "Shorts", "Briefs" }
Look.Bodies = { "Classic", "Mine" }

function Look.default(): Look
	return {
		Skin = 3,
		Body = "Classic",
		Top = { S = "Tee", C = Palette.indexOf("Snow"), F = "Satin" },
		Bottom = { S = "Pants", C = Palette.indexOf("Royal Blue"), F = "Matte" },
		Shoes = { C = Palette.indexOf("Snow"), F = "Satin" },
		Gloves = { C = 0 },
		Pieces = {},
		Catalog = {},
		Pose = Poses.Default,
		Entrance = Entrances.Default,
	}
end

local function isWhole(value: any, low: number, high: number): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= low and value <= high
end

-- A colour the player may use, or nil.
local function cleanColor(value: any, customColors: boolean, allowNone: boolean): any
	if allowNone and value == 0 then
		return 0
	end
	if isWhole(value, 1, #Palette.Colors) then
		return value
	end
	if customColors and Palette.isHex(value) then
		return string.upper(value)
	end
	return nil
end

local function cleanFinish(value: any): string?
	if Palette.isFinish(value) then
		return value
	end
	return nil
end

local function cleanPaint(raw: any, fallback: Paint, styles: { string }?, ctx: Context, allowNone: boolean): Paint
	if type(raw) ~= "table" then
		return table.clone(fallback)
	end
	local paint: Paint = {
		C = cleanColor(raw.C, ctx.customColors, allowNone),
		F = cleanFinish(raw.F),
	}
	if paint.C == nil then
		paint.C = fallback.C
	end
	if paint.F == nil then
		paint.F = fallback.F
	end
	if styles then
		paint.S = if type(raw.S) == "string" and table.find(styles, raw.S) then raw.S else fallback.S
	end
	return paint
end

-- A copy of raw with everything invalid or unowned replaced by defaults.
function Look.sanitize(raw: any, ctx: Context): Look
	local base = Look.default()
	if type(raw) ~= "table" then
		return base
	end

	local look = base
	if isWhole(raw.Skin, 1, #Palette.Skins) then
		look.Skin = raw.Skin
	end
	if type(raw.Body) == "string" and table.find(Look.Bodies, raw.Body) then
		look.Body = raw.Body
	end
	look.Top = cleanPaint(raw.Top, base.Top, Look.TopStyles, ctx, false)
	look.Bottom = cleanPaint(raw.Bottom, base.Bottom, Look.BottomStyles, ctx, false)
	look.Shoes = cleanPaint(raw.Shoes, base.Shoes, nil, ctx, true)
	look.Gloves = cleanPaint(raw.Gloves, base.Gloves, nil, ctx, true)
	look.Gloves.F = nil

	if type(raw.Pieces) == "table" then
		for _, slot in Wardrobe.Slots do
			local choice = raw.Pieces[slot]
			if type(choice) == "table" and type(choice.Id) == "string" then
				local piece = Wardrobe.get(choice.Id)
				if piece and piece.Slot == slot and ctx.ownsPiece(piece.Id) then
					look.Pieces[slot] = {
						Id = piece.Id,
						C = cleanColor(choice.C, ctx.customColors, false) or Palette.indexOf(piece.Main),
						A = cleanColor(choice.A, ctx.customColors, false) or Palette.indexOf(piece.Accent),
						F = cleanFinish(choice.F) or piece.Finish,
					}
				end
			end
		end
	end

	if type(raw.Catalog) == "table" then
		local seen = {}
		for _, id in raw.Catalog do
			if #look.Catalog >= ctx.maxCatalog then
				break
			end
			if isWhole(id, 1, 2 ^ 53) and not seen[id] then
				seen[id] = true
				table.insert(look.Catalog, id)
			end
		end
	end

	if type(raw.Pose) == "string" and Poses.get(raw.Pose) and ctx.ownsPose(raw.Pose) then
		look.Pose = raw.Pose
	end
	if type(raw.Entrance) == "string" and Entrances.get(raw.Entrance) and ctx.ownsEntrance(raw.Entrance) then
		look.Entrance = raw.Entrance
	end
	return look
end

export type Summary = {
	Tags: { [string]: number },
	PieceCount: number,
	Colors: { Color3 },
	Glows: boolean,
	CatalogCount: number,
}

-- What the judges look at: the theme tags of the pieces worn, how many
-- pieces, and the colours on show.
function Look.summary(look: Look): Summary
	local summary: Summary = { Tags = {}, PieceCount = 0, Colors = {}, Glows = false, CatalogCount = #look.Catalog }
	for _, choice in look.Pieces do
		local piece = Wardrobe.get(choice.Id)
		if piece then
			summary.PieceCount += 1
			for _, tag in piece.Tags do
				summary.Tags[tag] = (summary.Tags[tag] or 0) + 1
			end
			table.insert(summary.Colors, Palette.resolve(choice.C))
			if choice.F == "Glow" or piece.Slot == "Aura" then
				summary.Glows = true
			end
		end
	end
	table.insert(summary.Colors, Palette.resolve(look.Top.C))
	table.insert(summary.Colors, Palette.resolve(look.Bottom.C))
	if look.Top.F == "Glow" or look.Bottom.F == "Glow" then
		summary.Glows = true
	end
	return summary
end

-- True when two looks would put the same pieces in the same colours on.
function Look.same(a: Look, b: Look): boolean
	local function encode(look: Look): string
		local parts = { tostring(look.Skin), look.Body, look.Pose, look.Entrance }
		for _, paint in { look.Top, look.Bottom, look.Shoes, look.Gloves } do
			table.insert(parts, `{paint.S}:{paint.C}:{paint.F}`)
		end
		for _, slot in Wardrobe.Slots do
			local choice = look.Pieces[slot]
			if choice then
				table.insert(parts, `{slot}={choice.Id}:{choice.C}:{choice.A}:{choice.F}`)
			end
		end
		for _, id in look.Catalog do
			table.insert(parts, tostring(id))
		end
		return table.concat(parts, "|")
	end
	return encode(a) == encode(b)
end

return Look
