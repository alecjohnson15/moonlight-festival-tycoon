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
| Goods and visitor figures | This project | Generated in code (PlotActivity) | Original | Yes | None needed | This repository |
| Upgrade models, plot dressing and surrounding scenery | This project | Built from parts in code (`src/shared/Kit.luau`, `Themes/MoonlightFestival/Props.luau`, `Pieces.luau`, `Scenery.luau`) | Original | Yes | None needed | This repository |
| Music, ambience and sound effects (`assets/audio/*.ogg`) | This project | Synthesised from sine waves and noise by `tools/make_sounds.py` | Original | Yes | None needed | This repository; rerun the script to reproduce them |
| Night sky, moon and stars | Roblox | The engine's default `Sky` textures, with settings changed | Roblox platform terms | Within Roblox | None needed | Engine-provided |
| Particle textures (default sparkle, `rbxasset://textures/particles/smoke_main.dds`) and the Fire and Smoke effects | Roblox | Built into the Roblox engine | Roblox platform terms | Within Roblox | None needed | Engine-provided |
| Part and terrain materials (grass, cobblestone, slate, wood planks and so on) | Roblox | Built into the Roblox engine | Roblox platform terms | Within Roblox | None needed | Engine-provided |
| UI fonts (Gotham family, Fredoka One) | Roblox (Fredoka One by Milena Brandão) | Built into the Roblox engine | Roblox platform terms; Fredoka One is also under the SIL Open Font License | Within Roblox | None needed | Engine-provided |

No uploaded models, images, audio or music are in the game yet; the team uploads the audio files above when ready. The festival names in `src/shared/Themes/MoonlightFestival/init.luau` (stations, goods and attractions) are original placeholders and need the same review before launch.

## References

Looked at for mood only. Nothing from them is in the game.

| Reference | Owner | Used for |
| --- | --- | --- |
| "Halloween Scare Nights" (Roblox experience) | Universal Roblox Park & Resort | The overall night mood: a dark sky with a big moon, coloured fog and light, and dense spooky props. No builds, names, branding, art or audio were copied. |
