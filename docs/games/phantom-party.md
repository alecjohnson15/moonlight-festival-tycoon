# Phantom Party: Masquerade Mystery

*One Phantom. One Guardian. Who's behind the mask?*

| | |
| --- | --- |
| **Genre** | Round-based hidden-role mystery (Party & Casual, Social Deduction) |
| **Players** | Up to 12 per server. Alone, you get practice rounds against dummies |
| **Session** | About 4 minutes per round (20 s vote, 3 min round, results) |
| **For** | Ages 9 to 12, aimed at Roblox's **Mild** label (tagged players get "dazed", nobody dies) |
| **Status** | Built, all checks pass, **not yet played in Studio**, not yet on Roblox |
| **Code** | `games/phantom-party/` (its own Rojo project), branch `claude/project-thread-mpq3h7` |
| **Pull request** | [PR #16](https://github.com/alecjohnson15/moonlight-festival-tycoon/pull/16) (open) |
| **Place file** | `/mnt/project-files/release/phantom-party.rbxl` |
| **Release kit** | `/mnt/project-files/release/phantom-party-launch.md`, `phantom-party-audio/` (33 .ogg) and `phantom-party-audio.zip` |
| **Build thread** | "Build a one-versus-all mystery game" |

## What it is

A masked ball where one guest is secretly the **Phantom**, tagging guests
with a cartoon blade. One **Guardian** has the Moonbeam Blaster and must work
out who it is. Everyone else is a **Guest**: survive, grab candy coins, and
find clue pages that point to the Phantom.

Everything is original: the name, the maps, the gear, the music and the
sounds, all built or synthesised in code.

## How a round plays

| Step | Time | What happens |
| --- | --- | --- |
| Intermission | 20 s | Players vote between maps in the plaza |
| Reveal | 6 s | Everyone stands frozen in the map while their private role card shows |
| Playing | 180 s (+5 s per player over 8) | The Phantom's blade is sheathed for the first 8 s |
| Final | last 30 s | Faster music, a red clock, ticks in the last ten seconds |
| Results | 10 s | Who was who, who won, and a pay slip for each player |

The Guests win if the Phantom is knocked out or the clock runs out. The
Shadows (Phantom and Saboteur) win if no guest is left standing.

### Roles

| Role | Team | From | What they do |
| --- | --- | --- | --- |
| Phantom | Shadows | always 1 | Draw the blade (everyone sees it), tag up close or throw it (it flies back), sees outlines in a blackout |
| Guardian | Guests | 2 players | Moonbeam Blaster: zap the Phantom to win. Zap an innocent and both are dazed and the blaster drops |
| Medic | Guests | 5 players | Revive a dazed guest (one charge, two on 10+ servers). The revived guest learns who tagged them |
| Saboteur | Shadows | 7 players | Two blackouts a round. Can't tag, can't be tagged |
| Guest | Guests | everyone else | Survive, collect coins and clue pages. Pick up a dropped blaster to become the Hero |

Roles are dealt with tickets: every round you don't get a role, your chance
for it goes up, so nobody goes twenty rounds without being the Phantom.

### Key mechanics

- **Knockouts, not deaths.** A tagged guest is **Dazed** for 8 seconds,
  falling over with stars spinning above them, and a Medic can bring them
  back. Then they're **Out** and fade back to the plaza.
- **The Truth Bell.** Each clue page adds 10. At 50 the HUD names the room
  the Phantom is in; at 100 the Phantom glows red for everyone for 4 seconds.
  A Shadow who touches a page tears it up. Quiet guests get something to do
  and a reason to split up.
- **Proximity chat in rounds.** The living hear only the living within 60
  studs. The dazed, the out and the plaza talk among themselves and can't
  give anything away. Emotes follow the same rule.
- **Practice rounds.** A player alone on a server plays each role in turn
  against five dummies, so nobody waits in an empty plaza.

## The world

- **Hollowmere Manor:** a moonlit masked ball with a foyer, ballroom,
  library, conservatory, dining room, kitchen, study, upstairs bedroom and
  balcony, a garden and secret passages.
- **Starlight Carnival:** a closed fair with a carousel, big top, ferris
  wheel, mirror maze, ghost train, hay maze and swing ride.
- **Moonlit Plaza** (the lobby): a giant floating mask over the fountain, the
  Mask Boutique and Wardrobe, the Crate Vault, the Trading Hall, the Moon Pass
  board, the Moonlight Stage for emotes, three leaderboards and a VIP
  balcony.

## Progression and rewards

- **Coins** come only from playing (30 to 80 a round) and buy boutique items
  (300 to 1,200) or crates (600 and 900).
- **Cosmetics** in five kinds (masks, blades, blasters, knockout effects,
  trails) across six rarities. Over 60 in total.
- **Crates** (Masquerade and the seasonal Harvest Moon) open with **coins
  only**. The vault shows the odds by rarity and every item inside before you
  open one, and a pity counter guarantees an Epic within 10 opens (Legendary
  within 8 for the seasonal crate). There's no way to turn Robux into coins
  or crates.
- **Trading:** earned items can be traded in the Trading Hall, with a
  both-accept countdown and an all-or-nothing swap. Items bought with Robux
  are bound to the buyer and can't be traded.
- **Moon Pass:** 30 tiers over a season (about 70 rounds), a free track with
  coins, items and crates, and a premium track of nine named cosmetics.

## Money (Robux)

8 game passes, all direct purchases, all looks or social only: no stat
changes, no coins, no crates, no edge in a round. No paid random items
anywhere.

| Pass | What it gives | Robux |
| --- | --- | --- |
| Moon Pass Premium | The premium track: nine cosmetics, shown up front | 399 |
| Royal Masquerade Set | Royal Rapier, Gilded Lantern Blaster, Golden Confetti effect | 249 |
| VIP Lounge | VIP balcony, gold chat tag, gold name in the plaza | 199 |
| Neon Nightmare Blade | A glowing blade skin | 149 |
| Starfall Blaster | A blaster skin with a golden beam | 149 |
| Golden Sun Mask | A mask | 99 |
| Ghostfire Trail | A trail | 99 |
| Party Emotes | Five effect emotes | 99 |

## Safety and fairness

- Roles are sent only to their owner. Role tools sit in server storage and
  only reach the character while drawn, so no client can read who holds a
  blade.
- Swings, throws and blaster shots are checked on the server against the
  server's own positions, with cooldowns and a rate limit on every remote.
- Crate rolls, purchases, pass claims and trades happen only on the server.
- Saves are session-locked and versioned. No personal data is stored.
- Known gap: a trade saves both players one after the other, so a server
  crash in that split second could duplicate items. The trade log on both
  saves (last 25 trades) lets support fix it.

## Status

- Built and pushed in PR #16. 73 Lune tests pass, lint is clean, the place
  builds, and CI is green.
- **Nobody has played it in Studio yet.** Open the place file and press
  **Play** for a practice round; use **Test > Clients and Servers** with 2+
  players for real rounds.
- 33 original sounds are made but not uploaded. Until then effects use
  Roblox's stand-in sounds and there's no music.
- Pass ids are 0 (the boutique shows **Soon** until they're set).
- **Store icon and thumbnails are not made yet.** Prompts are in
  `games/phantom-party/docs/marketing.md`.

## How to publish

The quick way, with an API key (the same as Halloween Tycoon):

1. **Create the experience.** On the
   [Creator Hub](https://create.roblox.com/dashboard/creations), click
   **Create Experience** (an empty one is fine) and open it.
2. **Copy two ids.** The **universe id** is the number after
   `/experiences/` in the address bar. The **place id** is on the Places tab,
   under **⋯ > Copy Place ID**.
3. **Make an Open Cloud API key** on the
   [API Keys page](https://create.roblox.com/dashboard/credentials). Name it
   "Phantom Party" and add these API systems, choosing this experience where
   it asks:
   - `universe-places`: write (publish the place file)
   - `universe`: write (name, description, devices)
   - `universe.place`: write (12 players per server)
   - `game-pass`: read and write (the 8 passes)
   - `asset`: read and write (upload the 33 sounds)
   - optional `legacy-universe`: manage (icon and thumbnails, once they exist)

   Set an expiry a few days out and add your PC's IP under Accepted IP
   Addresses (or `0.0.0.0/0` with that short expiry).
4. **Paste the key, the universe id and the place id** in the "Build a
   one-versus-all mystery game" thread and say **"go ahead"**. From your PC,
   Claude uploads the 33 sounds, creates the 8 passes, puts the ids in the
   game, sets the name, description, devices and 12 players per server, and
   publishes it. The game stays private.
5. **You still do:** the content rating questionnaire (below), the store
   icon and thumbnails, pass icons if you want pictures on them, and the
   release. Delete the API key when it's done.

**Content rating answers** (Creator Dashboard > Publish settings > Content
rating). It should come out **Mild**:

| Question | Answer |
| --- | --- |
| Violence | Yes: unrealistic, repeated (cartoon blade tags and blaster zaps; tagged players fall over with stars and fade back to the plaza) |
| Fear | Yes: mild (a moonlit manor, a closed carnival at night, a ghost train; no jump scares) |
| Blood, crude humour, romance, alcohol, drugs, tobacco, strong language, gambling, sensitive issues | None |
| Social hangout | No (the plaza is a lobby between rounds) |
| Free-form user creation | No |
| Paid random items | No (crates open only with earned coins) |
| Paid item trading | No (only earned items trade; Robux items are bound) |

**Then soft launch:** keep it private for a day or two. Alone, check you get
practice rounds and hear sound. With 2 to 12 friends, play both maps, try
every role, revive someone, pick up a dropped blaster, fill the Truth Bell,
open a crate, trade, buy one cheap pass and rejoin to check it all saved. Try
a phone. Then set it to **Public** and watch the funnel (joined, role
revealed, finished a round, second round, equipped an item). Players under 16
need the same extra steps as Halloween Tycoon.

Every later update: open the new place file, **File > Publish to Roblox As**,
pick Phantom Party and its place, **Overwrite**.

## Where things are

- `games/phantom-party/README.md`: overview, folder map, checks.
- `games/phantom-party/docs/design.md`: the round, roles, anti-exploit,
  economy, trades, saves, performance.
- `games/phantom-party/docs/launch.md`: publishing by hand and the full pass
  table (same as `release/phantom-party-launch.md`).
- `games/phantom-party/docs/marketing.md`, `rights-register.md`.
- `games/phantom-party/src/shared/Config/`: every number (players, timers,
  combat, rewards, shop, crates, the pass, the catalog).
- `games/phantom-party/tools/passes.json`: the pass list for the Open Cloud
  script.
