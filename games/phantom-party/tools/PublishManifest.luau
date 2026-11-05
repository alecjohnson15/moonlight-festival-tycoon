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

local NAME = "Phantom Party: Masquerade Mystery"
-- Sound asset names have to fit in 50 characters.
local SHORT = "Phantom Party"

-- The store description (docs/marketing.md). Roblox allows 1,000
-- characters.
local DESCRIPTION = [[
Welcome to the masked ball! Every round, one guest is secretly the Phantom, and only you know your own role.

🎭 PHANTOM: tag the guests before time runs out, and don't get caught.
🌙 GUARDIAN: find the Phantom and knock them out with the Moonbeam Blaster.
💖 MEDIC: revive a tagged guest, who saw who tagged them!
💡 SABOTEUR: cut the lights and help the Phantom.
🎉 GUEST: grab candy coins and clue pages to ring the Truth Bell, which shows where the Phantom is hiding.

🏰 Two huge maps: Hollowmere Manor and the Starlight Carnival, with secret passages, a mirror maze and a ferris wheel.
🎁 Collect over 60 masks, blades, blasters, knockout effects and trails. Open crates with coins you earn, trade with friends, and climb the Moon Pass.
💬 Whisper close by: in a round, only people near you can hear you.

Cartoon knockouts, no blood. Have fun, and trust no one!]]

-- Uploaded first, so if Roblox's audio limit stops the script partway the
-- sounds with no stand-in (the music and ambience) are already up.
local FIRST = {
	"LobbyMusic",
	"RoundMusic",
	"FinalMusic",
	"ManorAmbience",
	"CarnivalAmbience",
	"RevealShadow",
	"RevealGuest",
	"GuestsWin",
	"PhantomWins",
}

-- "BackstageMusic" -> "Backstage Music".
local function words(name: string): string
	return (string.gsub(name, "(%l)(%u)", "%1 %2"))
end

function PublishManifest.build(): { [string]: any }
	local order = table.clone(FIRST)
	local rest = {}
	for name in Sounds.List do
		if not table.find(FIRST, name) then
			table.insert(rest, name)
		end
	end
	table.sort(rest)
	table.move(rest, 1, #rest, #order + 1, order)

	local sounds = {}
	for _, name in order do
		local sound = Sounds.List[name]
		table.insert(sounds, {
			name = name,
			file = `assets/audio/{sound.File}`,
			displayName = `{SHORT} - {words(name)}`,
			description = `Original sound for {NAME}, made for the game.`,
		})
	end

	local passes = {}
	for _, item in Catalog do
		table.insert(passes, {
			id = item.Id,
			name = item.Name,
			description = item.Description,
			price = item.Price,
			icon = `assets/marketing/passes/{item.Id}.png`,
		})
	end

	return {
		game = NAME,
		placeFile = "phantom-party.rbxl",
		catalogFile = "src/shared/Config/Catalog.luau",
		soundsFile = "src/shared/Config/Sounds.luau",
		place = {
			displayName = NAME,
			description = DESCRIPTION,
			-- Rounds are tuned for 2 to 12 players.
			serverSize = 12,
		},
		-- Console stays off until someone has played it with a controller.
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
