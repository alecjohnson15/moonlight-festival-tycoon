# Rights register

Every external asset and code dependency in Phantom Party. Add a row before
anything new goes into the game. Marketplace availability and AI generation
do not count as clearance.

## Code dependencies

Nothing third-party ships inside the game. These tools only build and check
it.

| Dependency | Version | Creator | License | Ships in game? |
| --- | --- | --- | --- | --- |
| Rojo | 7.7.1 | Rojo contributors | MPL-2.0 | No, build tool |
| StyLua | 2.6.0 | JohnnyMorganz and contributors | MPL-2.0 | No, formatter |
| Selene | 0.31.0 | Kampfkarren and contributors | MPL-2.0 | No, linter |
| Lune | 0.11.1 | Lune contributors | MPL-2.0 | No, test runner |
| NumPy | 2.x | NumPy developers | BSD-3-Clause | No, used by `tools/make_sounds.py` |
| FFmpeg | any with libvorbis | FFmpeg developers | LGPL-2.1+ (GPL in some builds) | No, encodes the sounds |

## Assets

| Asset | Creator | Source | License | Notes |
| --- | --- | --- | --- | --- |
| Game name, tagline, role names (Phantom, Guardian, Medic, Saboteur, Guest), the Truth Bell, the Moon Pass, map and item names | This project | Written for this game | Original | Generic words; search Roblox for clashes before launch |
| Hollowmere Manor, the Starlight Carnival and the Moonlit Plaza | This project | Built from parts in code (`src/shared/Look/Maps`, `Look/Lobby.luau`, `Look/Kit.luau`, `Look/Pieces.luau`) | Original | The carnival rides are generic fairground types |
| Masks, blades, blasters, knockout effects and trails | This project | Built from parts and engine particles in code (`Look/Gear.luau`) | Original | Cartoon shapes of generic objects; no film or game designs |
| Pass icons (`assets/marketing/passes/*.png`) | This project | Rendered offline with three.js (MIT licence) from the game's own models (`Look/Gear.luau`) and a blocky figure built the same way; three.js is not part of the game | Original | |
| Music, ambience and sound effects (`assets/audio/*.ogg`) | This project | Synthesised from sine waves and noise by `tools/make_sounds.py`. "Masquerade Mixer" (plaza), "Sneaking Suspicion" (rounds), "Last Thirty" (final seconds) and the carnival waltz are original tunes written for this game, not covers, remixes or soundalikes | Original | Rerun the script to reproduce them |
| Stand-in sounds until upload (`rbxasset://sounds/electronicpingshort.wav`, `button.wav`, `clickfast.wav`, `swoosh.wav`, `swordslash.wav`, `swordlunge.wav`, `action_jump_land.mp3`) | Roblox | Ship with the Roblox client | Roblox platform terms | Played only until the game's own sounds are uploaded |
| Emote animations (wave, point, cheer, laugh, dance, dance2, dance3) and the tool slash animation | Roblox | The default character Animate script | Roblox platform terms | Engine-provided |
| Practice dummies | Roblox / this project | `Players:CreateHumanoidModelFromDescription` with a default description, or a block rig built in code | Roblox platform terms | Engine-provided rig |
| Sky, materials, particle textures, Sparkles | Roblox | Built into the engine | Roblox platform terms | Engine-provided |
| UI fonts (Fredoka One, Gotham) | Roblox (Fredoka One by Milena Brandão) | Built into the engine | Roblox platform terms; Fredoka One also SIL OFL | Engine-provided |
| Avatar headshots in the Trading Hall | Roblox | `rbxthumb://` thumbnails of players' own avatars | Roblox platform terms | Shown only to players in the same server |
| Store icon and thumbnails | The project owner | To be generated with an AI image tool from the prompts in `docs/marketing.md` | Depends on the tool's terms | Check commercial use before launch; keep the generation history |

## Player data

No personal data is stored beyond what Roblox provides: saves are keyed by
user id and hold game progress only (`docs/design.md`, Saves). Leaderboards
store a user id and a number. Nothing asks for or stores names, ages, emails,
locations or free text.
