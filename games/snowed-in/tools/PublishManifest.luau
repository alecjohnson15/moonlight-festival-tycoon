-- What publish/publish.ps1 makes on Roblox: the sounds to upload, the game
-- passes and developer products (names, descriptions, prices, icons), and
-- the experience's name, description, server size and devices. Built from
-- Config so it can't drift from the game: `lune run tools/make_manifest`
-- writes it to publish/manifest.json, and tests/Publish.spec checks the
-- file still matches. Run both from the game's folder.

local RobloxLoader = require("../tests/RobloxLoader")

local Catalog = RobloxLoader.require("src/shared/Config/Catalog")
local Sounds = RobloxLoader.require("src/shared/Config/Sounds")

local PublishManifest = {}

PublishManifest.PATH = "publish/manifest.json"

local NAME = "Snowed In: Survive 10 Nights"
-- Sound asset names have to fit in 50 characters.
local SHORT = "Snowed In"

-- The store description (docs/launch.md, step 2). Roblox allows 1,000
-- characters.
local DESCRIPTION = [[
A blizzard has buried Pinehollow and the rescue train won't come until someone fixes the radio. Keep the Great Hearth burning for 10 nights!

Chop wood, dig up coal and scrap, build walls, lanterns and ember turrets, and fight off frostlings, snow hounds and two giant yetis with torches, slings and a sunstone cannon. Pick a role: Scout, Builder, Cook, Ranger or Medic, each with its own power. Find the four frozen radio parts, carry them to the tower and call the train. Get frozen? A friend can thaw you.

Earn snowflakes, decorate your own cabin, and climb the Expedition Pass. Co-op for up to 8 friends. Cartoon monsters, no gore.]]

-- Uploaded first, so if Roblox's audio limit stops the script partway the
-- sounds with no stand-in (the music, wind and chill) are already up.
-- (docs/launch.md, step 4).
local FIRST = {
	"MusicDay",
	"MusicNight",
	"MusicBoss",
	"Wind",
	"Chill",
	"Notice",
	"NightHorn",
	"DawnChime",
	"Freeze",
	"Thaw",
	"Chop",
	"Feed",
	"Hit",
}

-- "MusicDay" -> "Music Day".
local function words(name: string): string
	return (string.gsub(name, "(%l)(%u)", "%1 %2"))
end

-- "MusicDay" -> "music_day", the name tools/make_sounds.py gives its file,
-- and the name of each pass icon.
local function snake(name: string): string
	return string.lower((string.gsub(name, "(%l)(%u)", "%1_%2")))
end

function PublishManifest.build(): { [string]: any }
	local order = table.clone(FIRST)
	local rest = {}
	for name in Sounds do
		if not table.find(FIRST, name) then
			table.insert(rest, name)
		end
	end
	table.sort(rest)
	table.move(rest, 1, #rest, #order + 1, order)

	local sounds = {}
	for _, name in order do
		table.insert(sounds, {
			name = name,
			file = `assets/audio/{snake(name)}.ogg`,
			displayName = `{SHORT} - {words(name)}`,
			description = `Original sound for {NAME}, made for the game.`,
		})
	end

	local passes = {}
	for _, item in Catalog do
		table.insert(passes, {
			id = item.Id,
			name = item.Name,
			description = item.Includes,
			price = item.SuggestedRobux,
			icon = `assets/marketing/passes/{snake(item.Id)}.png`,
		})
	end

	return {
		game = NAME,
		placeFile = "snowed-in.rbxl",
		catalogFile = "src/shared/Config/Catalog.luau",
		soundsFile = "src/shared/Config/Sounds.luau",
		place = {
			displayName = NAME,
			description = DESCRIPTION,
			-- Eight cabins; the waves are tuned for 1 to 8 players.
			serverSize = 8,
		},
		-- Console stays off until someone has played it with a controller (the
		-- game has controller buttons, but nobody has tried one yet).
		devices = {
			desktopEnabled = true,
			mobileEnabled = true,
			tabletEnabled = true,
			consoleEnabled = false,
			vrEnabled = false,
		},
		sounds = sounds,
		passes = passes,
		products = {},
	}
end

return PublishManifest
