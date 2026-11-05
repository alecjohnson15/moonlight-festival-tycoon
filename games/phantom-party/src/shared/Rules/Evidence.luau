--!strict
-- Leads, the pure part: which mask colour a glimpse reports, who saw or
-- heard something, what a lead says and how a notebook fills and empties.
-- EvidenceService decides when; this decides what, so the tests can check
-- that a lead never names anyone, is sometimes wrong, and can't be farmed.

local EvidenceConfig = require(script.Parent.Parent.Config.Evidence)
local Items = require(script.Parent.Parent.Config.Items)

export type Lead = { Id: number, Family: string, Text: string, Room: string, At: number }
export type Book = { Leads: { Lead }, Last: { [string]: number }, Next: number }

local Evidence = {}

Evidence.FAMILIES = { "Witness", "Commotion", "Footprints", "Tampering" }

-- Mask colours, in the words a glimpse uses. Four broad groups, so a glimpse
-- narrows the suspects without pointing at one.
Evidence.TONES = { "dark", "pale", "warm", "cool" }
Evidence.TONE_WORDS = {
	dark = "a dark mask",
	pale = "a pale mask",
	warm = "a red, orange or gold mask",
	cool = "a blue or green mask",
}

-- What each kind of lead says. {room} and {mask} are filled in; nothing
-- else ever is, so no lead can carry a name or a role.
Evidence.TEXT = {
	SawTag = "Saw a tag in the {room}. The tagger wore {mask}.",
	HeardTag = "Heard a scuffle in the {room}.",
	HeardThrow = "Heard a thrown blade hit something in the {room}.",
	Footprints = "Found fresh glowing footprints in the {room}.",
	SawTear = "Saw {mask} tear up a clue page in the {room}.",
	HeardTear = "Heard a clue page torn in the {room}.",
	Lights = "The lights were cut from near the {room}.",
}

-- Which family each kind of lead belongs to.
Evidence.FAMILY_OF = {
	SawTag = "Witness",
	HeardTag = "Commotion",
	HeardThrow = "Commotion",
	Footprints = "Footprints",
	SawTear = "Tampering",
	HeardTear = "Tampering",
	Lights = "Tampering",
}

local function hsv(hex: string): (number, number, number)
	local digits = string.gsub(hex, "#", "")
	local r = (tonumber(string.sub(digits, 1, 2), 16) or 0) / 255
	local g = (tonumber(string.sub(digits, 3, 4), 16) or 0) / 255
	local b = (tonumber(string.sub(digits, 5, 6), 16) or 0) / 255
	local high, low = math.max(r, g, b), math.min(r, g, b)
	local spread = high - low
	local hue = 0
	if spread > 0 then
		if high == r then
			hue = ((g - b) / spread) % 6
		elseif high == g then
			hue = (b - r) / spread + 2
		else
			hue = (r - g) / spread + 4
		end
		hue /= 6
	end
	local saturation = if high > 0 then spread / high else 0
	return hue, saturation, high
end

-- The colour group of a colour given as "#RRGGBB".
function Evidence.toneOfColor(hex: string): string
	local hue, saturation, value = hsv(hex)
	if value < 0.32 then
		return "dark"
	elseif saturation < 0.35 and value > 0.7 then
		return "pale"
	elseif hue < 0.17 or hue >= 0.9 then
		return "warm"
	end
	return "cool"
end

-- The colour group of a mask, from its main colour. Unknown masks count as
-- the default domino's.
function Evidence.tone(maskId: string?): string
	local item = maskId and Items.get(maskId)
	local look = item and (item :: any).Look
	if look and look.Base then
		return Evidence.toneOfColor(look.Base)
	end
	local default = Items.get(Items.DEFAULTS.Mask)
	return Evidence.toneOfColor(((default :: any).Look or {}).Base or "#1E1B26")
end

-- What a glimpse reports: the true colour group most of the time, else one
-- of the others, picked evenly. random() gives a number from 0 up to 1.
function Evidence.glimpse(trueTone: string, random: () -> number, accuracy: number?): string
	if random() < (accuracy or EvidenceConfig.GlimpseAccuracy) then
		return trueTone
	end
	local others = {}
	for _, tone in Evidence.TONES do
		if tone ~= trueTone then
			table.insert(others, tone)
		end
	end
	return others[math.clamp(math.floor(random() * #others) + 1, 1, #others)]
end

-- Whether a player saw ("See") or heard ("Hear") something, or neither.
-- toActor is how far they were from whoever did it, canSee whether nothing
-- solid was in between, and toEvent how far they were from where it
-- happened.
function Evidence.sense(toActor: number?, canSee: boolean, toEvent: number): string?
	if toActor and canSee and toActor <= EvidenceConfig.SeeRange then
		return "See"
	elseif toEvent <= EvidenceConfig.HearRange then
		return "Hear"
	end
	return nil
end

-- A lead's words. room is a room's name, or nil outdoors.
function Evidence.text(kind: string, room: string?, tone: string?): string
	local template = Evidence.TEXT[kind] or ""
	local text = string.gsub(template, "{room}", room or "grounds")
	text = string.gsub(text, "{mask}", Evidence.TONE_WORDS[tone or ""] or "a mask")
	return text
end

function Evidence.newBook(): Book
	return { Leads = {}, Last = {}, Next = 1 }
end

-- Drops leads older than lifetime seconds.
function Evidence.prune(book: Book, now: number, lifetime: number?)
	local keep = {}
	for _, lead in book.Leads do
		if now - lead.At < (lifetime or EvidenceConfig.Lifetime) then
			table.insert(keep, lead)
		end
	end
	book.Leads = keep
end

-- Writes a lead of kind into the notebook, unless one of the same family
-- went in under cooldown seconds ago. Keeps the newest MaxLeads. Returns the
-- lead, or nil if it was skipped.
function Evidence.write(book: Book, kind: string, room: string?, tone: string?, now: number): Lead?
	local family = Evidence.FAMILY_OF[kind]
	if not family then
		return nil
	end
	local last = book.Last[family]
	if last and now - last < EvidenceConfig.Cooldown then
		return nil
	end
	Evidence.prune(book, now)
	book.Last[family] = now
	local lead: Lead = {
		Id = book.Next,
		Family = family,
		Text = Evidence.text(kind, room, tone),
		Room = room or "grounds",
		At = now,
	}
	book.Next += 1
	table.insert(book.Leads, lead)
	while #book.Leads > EvidenceConfig.MaxLeads do
		table.remove(book.Leads, 1)
	end
	return lead
end

return Evidence
