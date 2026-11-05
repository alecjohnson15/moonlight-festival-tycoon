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

local NAME = "Catwalk Clash"

-- The store description (docs/marketing.md). Roblox allows 1,000
-- characters.
local DESCRIPTION = [[
👗 DRESS UP. STRUT. WIN THE CROWN. 👑

Every round the lobby votes on a theme, from Red Carpet Gala to Space Explorer. You get 2 and a half minutes backstage to build your look from 150+ pieces in any colour, or try on anything from the Roblox catalog. Then it's SHOWTIME: walk the runway head-to-head with your entrance effect, strike your pose, and let the crowd and the judges decide who moves on. Win the bracket to take the crown and your statue in the plaza!

⭐ Head-to-head runway battles with live audience voting
🎨 150+ pieces, 36 colours and 8 finishes, plus the Roblox catalog
✨ 15 runway entrances and 14 poses
🏆 Style Score ranks, from Newcomer to Legend, and a world leaderboard
🎟️ Style Pass seasons with free rewards on every tier
📅 New themes every season and a double-reward spotlight theme every week

Fair voting: you can't vote for yourself, and every outfit gets seen before votes count. Free outfits can win any theme.]]

-- Uploaded first, so if Roblox's audio limit stops the script partway the
-- sounds with no stand-in (the music, the crowd) are already up.
local FIRST = { "LobbyMusic", "BackstageMusic", "RunwayMusic", "CrowdLoop", "Cheer", "Crown", "MatchWin" }

-- "BackstageMusic" -> "Backstage Music".
local function words(name: string): string
	return (string.gsub(name, "(%l)(%u)", "%1 %2"))
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
		local sound = Sounds[name]
		table.insert(sounds, {
			name = name,
			file = `assets/audio/{sound.File}`,
			displayName = `{NAME} - {words(name)}`,
			description = `Original sound for {NAME}, made for the game.`,
		})
	end

	local passes, products = {}, {}
	for _, item in Catalog do
		local entry = {
			id = item.Id,
			name = item.Name,
			description = item.Includes,
			price = item.SuggestedRobux,
			icon = `assets/marketing/passes/{item.Id}.png`,
		}
		table.insert(if item.Kind == "DeveloperProduct" then products else passes, entry)
	end

	return {
		game = NAME,
		placeFile = "catwalk-clash.rbxl",
		catalogFile = "src/shared/Config/Catalog.luau",
		soundsFile = "src/shared/Config/Sounds.luau",
		place = {
			displayName = NAME,
			description = DESCRIPTION,
			-- Twelve dressing booths; rivals fill the bracket when fewer join.
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
		products = products,
	}
end

return PublishManifest
