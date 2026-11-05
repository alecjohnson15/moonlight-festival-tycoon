# Phantom Party: Masquerade Mystery

*One Phantom. One Guardian. Who's behind the mask?*

A round-based hidden-role party game for Roblox, for up to 12 players. Every
round one guest at the masked ball is secretly the **Phantom**, tagging guests
with a cartoon blade. One **Guardian** has the Moonbeam Blaster and one shot at
a time to knock the Phantom out. On bigger servers a **Medic** can revive a
tagged guest (who then knows who tagged them) and a **Saboteur** helps the
Phantom by cutting the lights. Everyone else is a **Guest**: survive, grab
candy coins, and find clue pages that fill the Truth Bell until it names the
Phantom's room, then lights them up for everyone.

Mild for ages 9 to 12: tagged players are "dazed" (stars spin over their
head) and then fade back to the plaza. No blood, no deaths, cartoon gear.

Everything here is original: the name, the maps, the gear, the music and the
sounds, all built or synthesised in code. Nothing for Robux is random: crates
are opened only with coins earned by playing, and their odds are shown first.

## What's in it

- **Two maps built from parts in code**: Hollowmere Manor (a moonlit masked
  ball with a foyer, ballroom, library, conservatory, dining room, kitchen,
  study, an upstairs bedroom and balcony, a garden and secret passages)
  and the Starlight Carnival (a closed fair with a carousel, big top,
  ferris wheel, mirror maze, ghost train, hay maze and swing ride).
  Players vote between rounds.
- **The Moonlit Plaza**: the lobby hangout, with a giant floating mask over
  the fountain, the Mask Boutique and Wardrobe, the Crate Vault, the Trading
  Hall, the Moon Pass board, the Moonlight Stage for emotes, three
  leaderboards and a VIP balcony.
- **Five roles** dealt with tickets, so everyone gets their turn as the
  Phantom or the Guardian, and the Shadows know each other.
- **Proximity chat in rounds**: the living hear only the living nearby;
  the tagged and the plaza talk among themselves and can't give anything
  away. Emotes follow the same rule.
- **Cosmetics in five kinds** (masks, blades, blasters, knockout effects and
  trails) across six rarities, from a coin boutique, two crates (one
  seasonal) opened with coins, the free and premium Moon Pass tracks, and
  eight game passes. Earned copies can be traded; paid ones stay with you.
- **A trading hub** with a both-accept countdown and an all-or-nothing swap.
- **A 30-tier Moon Pass** season with a free track (coins, items and crates)
  and a premium track of nine named cosmetics.
- **Practice rounds** against dummies for a player alone on a server, so
  nobody waits in an empty plaza.
- **Original music and sound**: a plaza party tune, tiptoeing round music, a
  racing final-thirty-seconds track, ambience for each map, stings and 24
  effects, all from `tools/make_sounds.py`.

`docs/design.md` explains the design, `docs/launch.md` how to publish it, and
`docs/marketing.md` has the store text and the prompts for the icon and
thumbnails.

## Folder map

```
default.project.json   Rojo project for this game alone
src/shared/Config      Tunable numbers and lists: roles, rounds, combat,
                       items, shop, crates, the pass, the Robux catalog,
                       rewards, emotes, sounds
src/shared/Rules       Pure rules the tests check: dealing, round outcome,
                       chat, votes, tagging, inventories, trades, crates,
                       progress
src/shared/Look        Builders: the two maps, the plaza, every cosmetic
src/server             Services: rounds, combat, pickups, maps, the plaza,
                       saves, purchases, profiles, outfits, trades, chat,
                       emotes, analytics
src/client             HUD, role card, map vote, round buttons, effects,
                       lighting and music, menus, spectating
tests                  Lune tests (lune run tests/run)
tools                  make_sounds.py and passes.json
assets/audio           The generated sounds, ready to upload
```

## Working on it

Install the tools with `rokit install` (Rojo 7.7.1, StyLua 2.6.0 built with
Luau support, Selene 0.31.0 and Lune 0.11.1), then from this folder:

```
stylua src tests            # format
selene src                  # lint (writes roblox.yml on its first run)
lune run tests/run          # 73 tests
rojo build -o phantom-party.rbxl
rojo serve                  # live sync into Studio
python3 tools/make_sounds.py    # remake every sound (numpy and ffmpeg)
```

CI runs the same checks in `.github/workflows/game-phantom-party.yml`.

## Trying it in Studio

Open the place file and press **Play**. Alone, you get practice rounds:
you take each role in turn against five dummies, and a dummy Phantom tags a
dummy guest now and then so there's someone to revive or catch. Use
**Test > Clients and Servers** with 2 or more players for real rounds. In
Studio, data saves only if **Enable Studio Access to API Services** is on.
