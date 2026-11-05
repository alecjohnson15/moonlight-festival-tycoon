# Phantom Party: design

## The round

| Step | Time | What happens |
| --- | --- | --- |
| Waiting | until 1+ player | One player alone gets practice rounds against dummies; real rounds need 2 |
| Intermission | 20 s | Players vote between up to three maps in the plaza |
| Reveal | 6 s | Everyone stands frozen in the map while their private role card shows |
| Playing | 180 s (+5 s per player over 8) | The Phantom's blade is sheathed for the first 8 s |
| Final | last 30 s | Faster music, a red clock and ticks in the last ten seconds |
| Results | 10 s | Who was who, who won, and a pay slip for each player |

The guests win if the Phantom is knocked out or the clock runs out; the
Shadows win if no guest is left standing (`Rules/Round.luau`).

### Roles

| Role | Team | From | Moves |
| --- | --- | --- | --- |
| Phantom | Shadows | 1 player | Draw the blade (everyone sees it), tag up close, throw it (4.5 s cooldown, flies back), sees outlines during a blackout, speed 17 |
| Saboteur | Shadows | 7 players | Two blackouts a round, 30 s apart, not before 20 s; can't tag and can't be tagged by the Phantom |
| Guardian | Guests | 2 players | Moonbeam Blaster: zap the Phantom to win; zap an innocent and both of you are dazed and the blaster drops |
| Medic | Guests | 5 players | Hold E by a dazed guest to revive them (one charge, two on 10+ servers). The revived guest learns who tagged them |
| Guest | Guests | everyone else | Survive, collect candy coins and clue pages; pick up a dropped blaster to become the Hero |

Roles are dealt by tickets (`Rules/Deal.luau`): each round you don't get a
role you gain a ticket for it (up to 10); when you get it you drop back to
one. Over 800 simulated rounds on an 8-player server every player was the
Phantom 70 to 130 times (the test checks it).

### Knockouts, not deaths

A tagged guest is **Dazed** for 8 seconds: they fall over with stars spinning
above them, and a Medic can bring them back. Then they're **Out**, and fade
back to the plaza to spectate or hang out. A Shadow who is zapped is out at
once. Revived guests get a 3 second shield.

### Clues and the Truth Bell

Clue pages glow around the map. Each one a guest picks up adds 10 to the
Truth Bell. At 50 the HUD names the room the Phantom is in, and keeps naming
it as they move; at 100 the Phantom glows red for everyone for 4 seconds and
the bell empties. A Shadow who touches a page tears it up instead. This
gives quiet guests something to do and a reason to split up.

### Chat and emotes

Text chat is proximity-based in a round (`Rules/Chat.luau`): the living hear
the living within 60 studs; the dazed, the out and the plaza hear everyone
but can't be heard by the living. Emotes use the same rule. The Suspect emote
points at a player with a bubble and a red question mark.

### What makes it better than the usual version of the format

- Five roles instead of three, so bigger servers get more to do.
- Ticket dealing, so nobody goes twenty rounds without being the Phantom.
- The Truth Bell, so guests can deduce rather than only run.
- Revives and the "you saw who tagged you" moment.
- A dropped blaster any guest can pick up, so the round doesn't end when the
  Guardian makes a mistake.
- Proximity chat that keeps the out from spoiling the round.
- A real plaza to hang out in between rounds, with a stage, trading and VIP
  balcony, instead of a waiting box.
- Two big, detailed maps with secret passages, named rooms and moving rides.
- Practice rounds for anyone alone on a server, and the role card that
  explains each role in one line.

## Anti-exploit

Everything that matters is decided on the server.

- Roles are sent only to their owner (the Shadows also learn each other).
  Role tools wait in `ServerStorage.RoleTools` and are parented to the
  character only while drawn, so no client can read who holds a blade.
- Swings use the server's own position for the attacker and target, with
  only the facing from the client. Throws and blaster shots are server
  spherecasts from a claimed origin that must be within 10 studs of where
  the server has the player.
- Every action has a cooldown checked on the server, plus a rate limiter on
  each remote. Requests validate their types.
- Crate rolls, purchases, pass claims and trades happen only on the server.
- The client hides prompts that aren't for its role, but the server checks
  the role again when a prompt is used.

## Economy

Coins come only from playing (a typical round pays 30 to 80) and buy coin
shop items (300 to 1,200) or crates (600 and 900). XP (60 to 150 a round)
raises your level and the Moon Pass tier (250 XP each, 30 tiers, about 70
rounds for the whole season).

### Crates

Two crates, opened with coins only: the Masquerade Crate (always there) and
the Harvest Moon Crate (seasonal). The vault shows each crate's odds by
rarity and every item it holds before you open it, and a pity counter
(guaranteed Epic within 10 opens, or Legendary within 8 for the seasonal
crate). There's no way to turn Robux into coins or crates, and no paid
random item anywhere, which keeps the game clear of paid loot boxes.

### Robux (all game passes, all direct purchase)

| Pass | Robux | Gives |
| --- | --- | --- |
| Moon Pass Premium | 399 | The premium track: nine named cosmetics, shown up front |
| Royal Masquerade Set | 249 | Royal Rapier, Gilded Lantern Blaster, Golden Confetti effect |
| Neon Nightmare Blade | 149 | A glowing blade skin |
| Starfall Blaster | 149 | A blaster skin with a golden beam |
| VIP Lounge | 199 | The VIP balcony, a gold chat tag and a gold name in the plaza |
| Golden Sun Mask | 99 | A mask |
| Ghostfire Trail | 99 | A trail |
| Party Emotes | 99 | Five effect emotes |

Every pass is looks or social only: no stat changes, no coins, no crates,
no edge in a round. Paid items are bound to the account and can't be
traded, so trading never involves anything bought with Robux.

The target is $3 to $5 per paying player: Moon Pass Premium alone is about
$5, VIP plus one skin about $3.50.

## Trades

Each side puts up to eight copies on the table. Any change to either offer
clears both accepts. When both accept, a five second countdown runs, then
the server checks every copy again and moves them all at once or none
(`Rules/Trade.luau`). Both saves are written straight away.

**Crash gap:** the swap changes both players' data in memory and then saves
each one. If the server stopped between the two saves, one player could keep
their old items while the other also got them. Roblox has no transaction
across two keys. The gap is a fraction of a second and needs a server crash
at that moment; the trade log on both saves (last 25 trades) lets support
put things right.

## Saves

`DataService` keeps one save per player with session locking and retries
(the tycoon's, with a new store name). `Lib/Migrations.luau` versions the
save, fills fields an older save lacks and refuses a save written by a
newer server. No personal data is stored: the save holds coins, XP, items,
outfit, pass progress, pity counts, stats, the last 25 trades (user ids and
item ids) and the music setting.

## Performance

Only one map is loaded at a time, at z = 900 away from the plaza. Budgets the
tests enforce: at most 5,000 parts and 40 lights a map, 2,000 parts and 36
lights for the plaza. Moving rides, floating crates, pickups and flickering
lights move on each client only, and only within 320 studs of the camera.
Streaming is off so spectating and those motions always have the map.

## Tuning

Every number lives in `src/shared/Config`: `Game.luau` (players, timers,
speeds, chat range), `Combat.luau`, `Rewards.luau`, `Shop.luau`,
`Crates.luau`, `Pass.luau`, `Catalog.luau`. The tests check pacing (a new
player reaches level 2 within three rounds) and that every cosmetic can be
obtained.
