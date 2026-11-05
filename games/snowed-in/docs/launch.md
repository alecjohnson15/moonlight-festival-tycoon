# Publishing Snowed In

How to put **Snowed In: Survive 10 Nights** on Roblox, from the place file to
a public game. Do it on the Roblox account that uploads the sounds: Roblox
only plays audio in games its owner may use.

Roblox changes these screens often. If a button has moved, the
[publishing guide](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
has the current one. The account rules (ID check for public games, the extra
steps for players under 16) are the same as for Halloween Tycoon; see the
root `docs/launch.md`, "Before you start".

## The short way: let Claude do it with an API key

`publish/publish.ps1` does steps 2, 3, 4, 6 and 7 in one run from the
linked PC, through Roblox's Open Cloud API:

1. On the [Creator Dashboard](https://create.roblox.com/dashboard/creations),
   **Create Experience** (an empty one is fine) and note its universe id and
   place id.
2. Make an API key with `universe-places`, `universe` and `universe.place`
   (write), `game-pass` and `asset` (read and write) for this game.
   `publish/README.md` has the clicks.
3. Paste the key, universe id and place id in the project chat and say "go
   ahead". The script uploads the 45 sounds, makes the nine passes with the
   names, descriptions, prices and icons below, puts every id in Config,
   builds the place, sets the name, description, 8-player servers and
   devices, and publishes it. Delete the key when it's done.

You still do the genre, icon and thumbnails (step 2), the content rating
questionnaire (step 5) and the soft launch (step 9). Everything below is the
same thing by hand.

## 1. Open the place file

Download `snowed-in.rbxl` and double-click it, or in Studio choose
**File > Open from File**. It holds the whole game; Rojo isn't needed. Press
**Play** (or **Start** with 2 to 4 players under **Test > Clients and
Servers**) for a quick look. The first run starts 30 seconds after someone
joins.

## 2. Publish it (still private)

**File > Publish to Roblox**, then **Create new experience**. Fill in:

- **Name:** `Snowed In: Survive 10 Nights`
- **Description:**

  > A blizzard has buried Pinehollow and the rescue train won't come until
  > someone fixes the radio. Keep the Great Hearth burning for 10 nights!
  > Chop wood, dig up coal and scrap, build walls, lanterns and ember turrets,
  > and fight off frostlings, snow hounds and two giant yetis with torches,
  > slings and a sunstone cannon. Pick a role: Scout, Builder, Cook, Ranger or
  > Medic, each with its own power. Find the four frozen radio parts, carry
  > them to the tower and call the train. Get frozen? A friend can thaw you.
  > Earn snowflakes, decorate your own cabin, and climb the Expedition Pass.
  > Co-op for up to 8 friends. Cartoon monsters, no gore.

- **Genre:** Survival (or Action if Survival isn't offered).
- **Icon:** `assets/marketing/icon.png`. **Thumbnail:** `assets/marketing/thumbnail.png`
  (make both from the prompts in `docs/marketing.md` first).
- **Devices:** computer, phone and tablet. The game has controller
  buttons, so tick console too once someone has played it with a
  controller (the script leaves console off).

Save. The game exists on Roblox, but only you can play it.

## 3. Experience settings

Open **File > Experience Settings**.

- **Places:** click **⋯** next to the place, **Configure Place**, and set the
  server size to **8**. The town has 8 cabins and the waves are tuned for 1
  to 8 players.
- **Security:** **Enable Studio Access to API Services** only matters for
  testing saves in Studio. The live game saves either way (DataStore
  `SnowedInSaves`).
- **Permissions > Playability:** leave it **Private** until the soft launch
  (step 8).

## 4. Upload the sounds

The 45 sounds in `assets/audio/` were made by `tools/make_sounds.py` and are
all original. Until a sound has an id the game plays a plain built-in Roblox
sound or nothing, so this step can wait, but the game is much better with it.

1. In Studio open **Window > Asset Manager**, click **Bulk Import**, and pick
   every `.ogg` in `assets/audio/` (or upload them one at a time on the
   Creator Hub under **Development Items > Audio**). If Roblox limits how many
   you can upload this month, start with the four songs and wind, then
   `night_horn`, `dawn_chime`, `freeze`, `thaw`, `chop`, `feed` and `hit`.
2. Wait until each one passes moderation (a few minutes).
3. Copy the ids and paste them in the project chat, one per line, like
   `music_day 1234567890`. Claude puts them in `src/shared/Config/Sounds.luau`
   and sends a new place file.

| Name in Config/Sounds | File |
| --- | --- |
| `MusicDay` | `assets/audio/music_day.ogg` |
| `MusicNight` | `assets/audio/music_night.ogg` |
| `MusicBoss` | `assets/audio/music_boss.ogg` |
| `Wind` | `assets/audio/wind.ogg` |
| `Chop` | `assets/audio/chop.ogg` |
| `Mine` | `assets/audio/mine.ogg` |
| `Dig` | `assets/audio/dig.ogg` |
| `Splash` | `assets/audio/splash.ogg` |
| `Pick` | `assets/audio/pick.ogg` |
| `Deposit` | `assets/audio/deposit.ogg` |
| `Crate` | `assets/audio/crate.ogg` |
| `PackFull` | `assets/audio/pack_full.ogg` |
| `Feed` | `assets/audio/feed.ogg` |
| `HearthUp` | `assets/audio/hearth_up.ogg` |
| `Build` | `assets/audio/build.ogg` |
| `Broken` | `assets/audio/broken.ogg` |
| `Repair` | `assets/audio/repair.ogg` |
| `Craft` | `assets/audio/craft.ogg` |
| `Cook` | `assets/audio/cook.ogg` |
| `Eat` | `assets/audio/eat.ogg` |
| `Swing` | `assets/audio/swing.ogg` |
| `Sling` | `assets/audio/sling.ogg` |
| `Flare` | `assets/audio/flare.ogg` |
| `Blaze` | `assets/audio/blaze.ogg` |
| `Cannon` | `assets/audio/cannon.ogg` |
| `Hit` | `assets/audio/hit.ogg` |
| `Poof` | `assets/audio/poof.ogg` |
| `Slam` | `assets/audio/slam.ogg` |
| `Roar` | `assets/audio/roar.ogg` |
| `Freeze` | `assets/audio/freeze.ogg` |
| `Thaw` | `assets/audio/thaw.ogg` |
| `Chill` | `assets/audio/chill.ogg` |
| `Ability` | `assets/audio/ability.ogg` |
| `NightHorn` | `assets/audio/night_horn.ogg` |
| `DawnChime` | `assets/audio/dawn_chime.ogg` |
| `IceBreak` | `assets/audio/ice_break.ogg` |
| `RadioFit` | `assets/audio/radio_fit.ogg` |
| `Called` | `assets/audio/called.ogg` |
| `TrainHorn` | `assets/audio/train_horn.ogg` |
| `Win` | `assets/audio/win.ogg` |
| `Lose` | `assets/audio/lose.ogg` |
| `Click` | `assets/audio/click.ogg` |
| `Unlock` | `assets/audio/unlock.ogg` |
| `Deny` | `assets/audio/deny.ogg` |
| `Notice` | `assets/audio/notice.ogg` |
## 5. The content rating questionnaire

On the [Creator Dashboard](https://create.roblox.com/dashboard/creations),
open the game, then **Publish settings > Content rating**. Click **Start**,
answer as below, check the preview and **Submit**. It should come out
**Mild**, open to every age.

| Question | Answer | Why |
| --- | --- | --- |
| Age-restricted content | No | |
| Violence | Yes: unrealistic, repeated | Cartoon snow monsters puff into snow when hit with torches, embers and fire. A player who gets too cold or is hit too often freezes in a block of ice and is thawed by a friend or wakes up by the hearth. No death, no blood |
| Blood | None | |
| Fear | Yes: mild, repeated | Dark snowy nights, glowing-eyed cartoon monsters, a growling yeti boss, a night horn. No jump scares |
| Crude humour | None | |
| Romance, alcohol, drugs, tobacco, strong language, gambling, sensitive real-world issues | None | |
| Social hangout | No | It's a co-op survival game |
| Free-form user creation | No | Buildings snap to a grid from a fixed list; cabin decorations are picked from lists; nobody types or draws on anything |
| Paid random items | No | Every pass says exactly what it gives; there are no crates, spins or random rewards for Robux |
| Paid item trading | No | There's no trading |

Supply crates in the snow are free, found by playing, and always hold the
same mix (4 scrap, 2 coal, 1 fish), written on the crate before it opens.

## 6. Make the game passes

Creator Dashboard, the game, **Monetization > Passes > Create pass**, once
for each row:

1. Upload the icon from `assets/marketing/passes/` (512x512; Roblox crops it
   to a circle, and every icon keeps its picture inside the ring).
2. Type the name and description from the table, and **Create pass**.
3. Open the pass, turn on **Item for Sale** on its **Sales** page and enter
   the price.
4. Back in the list, click **⋯** on the pass and **Copy Asset ID**.

Prices are the suggestions in `Config/Catalog.luau`; change them if you like.
The two role passes are early access: both roles can also be earned with 600
snowflakes (about three wins, or three to five runs). They help a team a
little (the run model puts it at about 5 to 7% on a team of four's hardest
night), and free roles win without them; say "unlock early" in the store
text, not "more power". Everything else is to wear or to put on your cabin.

| Id | Name | Description | Robux | Icon |
| --- | --- | --- | --- | --- |
| `Ranger` | Ranger Role | Unlocks the Ranger role straight away (it can also be earned with 600 snowflakes). | 149 | `ranger.png` |
| `Medic` | Medic Role | Unlocks the Medic role straight away (it can also be earned with 600 snowflakes). | 149 | `medic.png` |
| `ExpeditionPremium` | Expedition Pass: Premium | Opens the premium row of the Expedition Pass: 13 extra rewards, shown on the pass before you buy. You still earn them by playing. | 299 | `expedition_premium.png` |
| `AuroraCape` | Aurora Cape | A cape that shimmers green and purple like the northern lights. | 129 | `aurora_cape.png` |
| `IcicleCrown` | Icicle Crown | A crown of glowing icicles. | 99 | `icicle_crown.png` |
| `AuroraTrail` | Aurora Trail | A trail of northern lights that follows your feet. | 79 | `aurora_trail.png` |
| `Penguin` | Penguin Buddy | A pet penguin in a tiny scarf that waddles after you. | 149 | `penguin.png` |
| `ArcticFox` | Arctic Fox Buddy | A pet arctic fox with a big fluffy tail. | 149 | `arctic_fox.png` |
| `CozyCabin` | Cozy Cabin Pack | Four cabin decorations: Aurora Lights, Golden Wreath, Giant Snow Globe and Rainbow Glow. | 199 | `cozy_cabin.png` |

Then paste the ids in the project chat, one per line, like
`Ranger 1234567890`. Claude puts them in `PassId` in
`src/shared/Config/Catalog.luau` and sends a new place file. Until then the
game runs fine: the shop shows **Coming soon** for each pass.

## 7. Publish the new file over the old one

Open the new place file, **File > Publish to Roblox As**, pick Snowed In,
then its place, and **Overwrite**. Do the same for every later update.
Running servers keep the old version until they close; **Restart servers**
in the game's menu on the Creator Dashboard moves everyone over.

## 8. Analytics

Nothing to set up: the game reports its funnels itself. After players have
been in, open the game on the Creator Dashboard, **Analytics > Funnels**: the
"Onboarding" funnel shows where new players stop on their first run, and the
"Run" funnel where runs stop. **Analytics > Custom events** has the run
results. `docs/design.md` lists every step.

## 9. Soft launch

1. Set the game to **Friends** (or keep it private and invite testers) and
   play a whole run with 3 to 6 people. `docs/playtest.md` has what to watch.
2. Check a run is won around minute 52 and that snowflakes, the Expedition
   Pass and cabin decorations are still there after rejoining.
3. Then **Public**. New games open to players aged 16 and up first; the
   under-16 steps are in the root `docs/launch.md`.
