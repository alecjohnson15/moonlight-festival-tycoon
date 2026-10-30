# Store page art

The icon and thumbnails for the game's Roblox page are in `assets/marketing`. The project owner generated them with an AI image tool; they were resized here, and the icons' white rounded frame was filled in with the colours next to it, because Roblox rounds icon corners itself.

| File | Size | What it shows |
| --- | --- | --- |
| `icon.png` | 512x512 | The screaming avatar in a witch hat, the moon, the wheel and the "Halloween Tycoon" logo |
| `icon-vs.png` | 512x512 | A "$1 vs $1M" split: a sad avatar at a rainy stall and the screaming avatar at the glowing festival |
| `thumbnail.png` | 1920x1080 | "I built a $1,000,000 Halloween festival!" over the festival, with a chest of coins |
| `thumbnail-vs.png` | 1920x1080 | "$1 Festival vs $1,000,000 Festival" split |

Use `icon.png` as the icon to start with and keep `icon-vs.png` to try against it later. Upload both thumbnails.

## Screenshots from the game

Real screenshots sit well beside the generated art, and show players what they'll actually find. The showcase build has the festival ready for them: build it with `rojo build showcase.project.json -o showcase.rbxl` (or use a place file someone built), open it in Studio and press Play. Your plot is maxed out beside the courtyard, three neighbours are busy, the parade starts 20 seconds in, and **H** hides everything on the screen. The README's "Store screenshots" section has the rest. Thumbnails are 16:9, so take shots with Studio's window wide, then crop them to 1920x1080.

## Uploading

Open the [Creator Dashboard](https://create.roblox.com/dashboard/creations), pick the game, then go to **Configurations > Places** and choose the start place (marked with a star).

- **Icon:** choose **Icon** in the place's menu, set the type to **Image**, click **Change**, pick the file and **Save Changes**. Roblox wants a square of at least 512x512, and shows it as small as about 150x150.
- **Thumbnails:** choose **Thumbnails** in the place's menu and add both files on the **Experience Detail Page** tab (up to 10). The **Home Page** tab takes 2 to 5 images under 3 MB each for home page personalization; both files fit. Thumbnails are 16:9, and anything else is stretched.

Every image goes through Roblox moderation before other players see it. Roblox's own guides: [Icons](https://create.roblox.com/docs/production/publishing/experience-icons) and [Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails).

## Before launch

The art shows things players should find in the game: the wheel, the ghost train, ghosts, skeletons, mummies and pumpkins are all there, and the "$1" and "$1,000,000" stand for the festival's coins, not real money. If the game changes so the art no longer matches, make new art rather than leave a page that oversells it.
