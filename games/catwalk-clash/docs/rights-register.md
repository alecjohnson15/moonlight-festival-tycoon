# Rights register

Every external asset and code dependency in Catwalk Clash. Add a row before
anything new goes into the game. Marketplace availability and AI generation
do not count as clearance.

## Code dependencies

Nothing third-party ships inside the game. These tools only build and check
it.

| Dependency | Version | Creator | Source | License | Ships in game? |
| --- | --- | --- | --- | --- | --- |
| Rojo | 7.7.1 | Rojo contributors | github.com/rojo-rbx/rojo | MPL-2.0 | No, build tool |
| StyLua | 2.6.0 | JohnnyMorganz and contributors | github.com/JohnnyMorganz/StyLua | MPL-2.0 | No, formatter |
| Selene | 0.31.0 | Kampfkarren and contributors | github.com/Kampfkarren/selene | MPL-2.0 | No, linter |
| Lune | 0.11.1 | Lune contributors | github.com/lune-org/lune | MPL-2.0 | No, test runner |
| NumPy | Any 2.x | NumPy developers | numpy.org | BSD-3-Clause | No, used by `tools/make_sounds.py` |
| FFmpeg | Any with libvorbis | FFmpeg developers | ffmpeg.org | LGPL-2.1+ | No, encodes the sounds to OGG |

## Assets

| Asset | Creator | Source | License | Commercial use |
| --- | --- | --- | --- | --- |
| The map: Glow Plaza, the Runway hall, Backstage and its booths, the Boutique, the VIP Lounge, the skyline, screens, leaderboard and Hall of Fame plinth | This project | Built from parts in code (`src/shared/Build/World.luau`) | Original | Yes |
| 152 wardrobe pieces | This project | Built from parts in code (`Config/Wardrobe.luau`, `Build/Pieces.luau`) | Original | Yes |
| Painted clothes (tops, bottoms, shoes, gloves) | This project | Body-part colours and materials set in code (`LookService`) | Original | Yes |
| 14 poses | This project | R15 joint angles in code (`Config/Poses.luau`) | Original | Yes |
| 15 runway entrances, confetti, flashes, fireworks and the crowd of fans | This project | Parts and engine particles in code (`client/Effects.luau`) | Original | Yes |
| Theme, judge, rival, piece, pose, entrance, pass and outfit names | This project | Original. Seven theme names that echoed existing brands or titles were renamed before launch | Original | Yes; search Roblox for "Catwalk Clash" before launch |
| Music and sound effects (`assets/audio/*.ogg`) | This project | Synthesised from sine waves and noise by `tools/make_sounds.py`. The three songs ("Glow Plaza", "Dressing Room Shuffle" and "Strut") are original melodies on common chord progressions, written for this game; they are not covers, remixes or soundalikes. The crowd and cheers are synthesised, with no words | Original | Yes; rerun the script to reproduce them |
| Fallback sounds (`rbxasset://sounds/electronicpingshort.wav`, `button.wav`, `clickfast.wav`, `swoosh.wav`) | Roblox | Ship with the Roblox client; played only until the project's own sounds are uploaded | Roblox platform terms | Within Roblox |
| Default R15 idle and walk animations (`rbxassetid://507766388`, `507777826`) | Roblox | The standard animations every R15 character uses, played on the rivals | Roblox platform terms | Within Roblox |
| Avatar heads, faces and bodies | Roblox and the player | Each player's own avatar, read with `GetHumanoidDescriptionFromUserIdAsync`; rivals use the default R15 body | Roblox platform terms | Within Roblox |
| Roblox catalog items in the Catalog tab | Their creators (Roblox and UGC creators) | Searched and shown live through `AvatarEditorService` and worn through `HumanoidDescription`; never copied into the game. Purchases use Roblox's prompt, and the creator is paid as usual | Roblox platform terms | Within Roblox |
| Particle textures (`sparkles_main`, `smoke_main`, `fire_sparks_main`, `explosion01_core_main`) | Roblox | Built into the Roblox engine | Roblox platform terms | Within Roblox |
| UI fonts (Gotham, Fredoka One) | Roblox (Fredoka One by Milena Brandão) | Built into the Roblox engine | Roblox platform terms; Fredoka One is also SIL Open Font License | Within Roblox |
| Store icon, thumbnails and pass icons | The project owner, when made | To be generated with an AI image tool from the prompts in `docs/marketing.md` | Depends on the tool's terms | Check the tool allows commercial use before launch |

No uploaded models, images or meshes are in the game.

## References

Looked at for the genre only. Nothing from them is in the game.

| Reference | Used for |
| --- | --- |
| Dress-up competition games on Roblox (theme, timer, dress up, runway, vote) | The genre's general loop, which no one owns. No names, art, UI, outfits, sounds or code were copied. |
