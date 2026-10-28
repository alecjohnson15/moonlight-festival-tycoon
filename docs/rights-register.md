# Rights register

Every external asset and code dependency, as the team brief requires. Add a row before anything new goes into the game. Marketplace availability and AI generation do not count as clearance.

## Code dependencies

Nothing third-party ships inside the game yet. These tools are used only to build and check it.

| Dependency | Version | Creator | Source | License | Ships in game? | Proof |
| --- | --- | --- | --- | --- | --- | --- |
| Rojo | 7.7.1 | Rojo contributors | github.com/rojo-rbx/rojo | MPL-2.0 | No, build tool | License field in the published crate |
| StyLua | 2.6.0 | JohnnyMorganz and contributors | github.com/JohnnyMorganz/StyLua | MPL-2.0 | No, formatter | License field in the published crate |
| Selene | 0.31.0 | Kampfkarren and contributors | github.com/Kampfkarren/selene | MPL-2.0 | No, linter | License field in the published crate |
| Lune | 0.11.1 | Lune contributors | github.com/lune-org/lune | MPL-2.0 | No, test runner | License field in the published crate |
| NumPy | Any 2.x | NumPy developers | numpy.org | BSD-3-Clause | No, used by tools/make_sounds.py | numpy.org/doc/stable/license.html |
| FFmpeg | Any with libvorbis | FFmpeg developers | ffmpeg.org | LGPL-2.1+ (GPL in some builds) | No, encodes the sounds to OGG | ffmpeg.org/legal.html |

## Assets

| Asset | Creator | Source | License | Commercial use | Attribution | Proof |
| --- | --- | --- | --- | --- | --- | --- |
| Plots, plaza, buy pads and greybox upgrade blocks | This project | Generated in code (PlotService) | Original | Yes | None needed | This repository |
| Goods and costumed visitors (ghosts, pumpkin kids, skeletons, witches, mummies) | This project | Built from parts in code (`Themes/MoonlightFestival/Crowd.luau`) | Original | Yes | None needed | This repository |
| Upgrade models, plot dressing and surrounding scenery | This project | Built from parts in code (`src/shared/Kit.luau`, `Themes/MoonlightFestival/Props.luau`, `Pieces.luau`, `Scenery.luau`) | Original | Yes | None needed | This repository |
| Music, ambience and sound effects (`assets/audio/*.ogg`) | This project | Synthesised from sine waves and noise by `tools/make_sounds.py`. The two songs, "Moonlit Mischief" (`music.ogg`) and "Haunted Arcade" (`music2.ogg`), are original melodies written for this project in a general pop style; they are not covers, remixes or soundalikes of any existing song | Original | Yes | None needed | This repository; rerun the script to reproduce them |
| Cosmetics: worn items, held items and weapons, pets, auras and trails | This project | Built from parts and engine particles in code (`Themes/MoonlightFestival/Wearables.luau`). The Big Wooden Mallet is a generic oversized mallet; the Storm-Stone Hammer, Drowned Trident, Reaper's Scythe and Foxfire Fan draw on public-domain myth and folklore with their own designs; the Ghostlight Blade and Crescent Moon Blade are glowing swords with their own shapes and hilts; the four Brainrot Buddies are original characters with original names | Original | Yes | None needed | This repository |
| Tool swing animations (Slash and Lunge) | Roblox | The default character Animate script's tool animations, played by naming them on the tool | Roblox platform terms | Within Roblox | None needed | Engine-provided |
| Night sky, moon and stars | Roblox | The engine's default `Sky` textures, with settings changed | Roblox platform terms | Within Roblox | None needed | Engine-provided |
| Particle textures (default sparkle, `rbxasset://textures/particles/smoke_main.dds`) and the Fire and Smoke effects | Roblox | Built into the Roblox engine | Roblox platform terms | Within Roblox | None needed | Engine-provided |
| Part and terrain materials (grass, cobblestone, slate, wood planks and so on) | Roblox | Built into the Roblox engine | Roblox platform terms | Within Roblox | None needed | Engine-provided |
| UI fonts (Gotham family, Fredoka One) | Roblox (Fredoka One by Milena Brandão) | Built into the Roblox engine | Roblox platform terms; Fredoka One is also under the SIL Open Font License | Within Roblox | None needed | Engine-provided |

No uploaded models, images, audio or music are in the game yet; the team uploads the audio files above when ready. The festival names in `src/shared/Themes/MoonlightFestival/init.luau` (stations, goods, attractions and cosmetics) are original placeholders and need the same review before launch.

## References

Looked at for mood only. Nothing from them is in the game.

| Reference | Owner | Used for |
| --- | --- | --- |
| "Halloween Scare Nights" (Roblox experience) | Universal Roblox Park & Resort | The overall night mood: a dark sky with a big moon, coloured fog and light, and dense spooky props. No builds, names, branding, art or audio were copied. |
| "Tung Tung Tung Sahur" and other "Italian brainrot" meme characters | Their individual creators; rights unclear | The project owner asked for a big carryable mallet like this character's, and for trendy characters. The Big Wooden Mallet is a generic mallet, and the Brainrot Buddies only share the general style of absurd, sing-song names. No characters, names, designs or audio were copied, because the rights to the originals are unclear. |
| The hammer of the Norse thunder god | Public-domain myth | The idea of a thunder hammer for the Storm-Stone Hammer. Marvel's design for Thor's hammer was not used. |
| Lightsabers | Lucasfilm | Avoided on purpose: the Ghostlight Blade is a see-through spirit sword with a bat-wing guard, and the Crescent Moon Blade is curved. Neither has a cylinder hilt, a straight beam or a hum. |
