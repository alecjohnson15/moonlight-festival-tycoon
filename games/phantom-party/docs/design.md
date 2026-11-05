# Phantom Party: design

## The round

| Step | Time | What happens |
| --- | --- | --- |
| Waiting | until 1+ player | One player alone gets practice rounds against dummies; real rounds need 2 |
| Intermission | 20 s | Players vote between up to three maps in the plaza |
| Reveal | 6 s | Everyone stands frozen in the map while their private role card shows |
| Playing | 180 s (+5 s per player over 8) | The Phantom's blade is sheathed for the first 8 s |
| Final | last 30 s | Faster music, a red clock and ticks in the last ten seconds |
| Results | 10 s | Who won, the moment that decided it, who was who, the party star, a pay slip and (privately) any mastery goals met |

### How a round ends

`Round.outcome` in `Rules/Round.luau` is the only place that decides it,
checked in this order every quarter second (tests/Fairness.spec checks it
against a second, independent referee for every mix of states):

| Reason | Winner | When |
| --- | --- | --- |
| PhantomLeft | Guests | The Phantom left the server |
| PhantomOut | Guests | The Phantom was knocked out |
| GuestsLeft | Shadows | No guest is standing and every guest left the server |
| AllTagged | Shadows | No guest is standing (dazed or out) |
| Time | Guests | The clock ran out |

A standing Saboteur never keeps a round going. The Phantom and the
Saboteur can't be revived; only a dazed guest can. A dropped blaster can be
picked up only by a guest who is standing. With two players the round is a
**Duel** (both know who's who, and the role card says so); three or four is
**Small**; a lone player gets **Practice** against stand-ins that pays
nothing.

### Roles

| Role | Team | From | Moves |
| --- | --- | --- | --- |
| Phantom | Shadows | 1 player | Draw the blade (everyone sees it), tag up close, throw it (4.5 s cooldown, flies back), sees outlines during a blackout, speed 17 |
| Saboteur | Shadows | 7 players | Two blackouts a round, 30 s apart, not before 20 s; can't tag and can't be tagged by the Phantom |
| Guardian | Guests | 2 players | Moonbeam Blaster: zap the Phantom to win; zap an innocent and both of you are dazed and the blaster drops |
| Medic | Guests | 5 players | Hold E by a dazed guest to revive them (one charge, two on 10+ servers). The revived guest learns who tagged them |
| Guest | Guests | everyone else | Survive, collect candy coins and clue pages; pick up a dropped blaster to become the Hero |

Roles are dealt by tickets (`Rules/Deal.luau`): each round you don't get a
role you gain a ticket for it (up to 20); when you get it you drop back to
one. Your chance is weighted by your tickets squared, so a long wait
catches up quickly. Over 10,000 modelled rounds every player gets within a
point or two of a fair share of each role at 2 to 12 players, and the
longest wait for a Phantom turn on a full server is 30 rounds (88 with the
old, unsquared weighting). `lune run tools/simulate` prints the table;
rollback is `WEIGHT_POWER = 1`, `MAX_TICKETS = 10`.

### Knockouts, not deaths

A tagged guest is **Dazed** for 8 seconds: they fall over with stars spinning
above them, and a Medic can bring them back. Then they're **Out**, and fade
back to the plaza to spectate or hang out. A Shadow who is zapped is out at
once. Revived guests get a 3 second shield.

### Clues and the Truth Bell

Clue pages glow around the map. A guest who picks one up fills the Truth
Bell; a bigger party needs more pages (`Rules/Bell.luau`: 8 plus 0.75 per
guest, 8 to 18). Halfway, the HUD names the room the Phantom was in at that
moment for 12 seconds (a snapshot, not a tracker); when full, the Phantom
glows red with a PHANTOM! label for 4 seconds, once a round. A Shadow who
touches a page tears it up instead, which leaves scraps and a lead. The
first version (10 per page, live room tracking, no limit on rings) rang
2.77 times a round on a full server in the model, 58% of the time inside
the first minute; rollback values are in `Config/Rewards.luau`.

### Leads

Between bell rings, deduction runs on **leads** (`Config/Evidence.luau`,
`Rules/Evidence.luau`, `EvidenceService`): small, imperfect notes the
server sends to one player at a time, never a name or a role.

| Family | Where it comes from |
| --- | --- |
| SEEN (Witness) | You saw a tag nearby: the tagger's mask colour group (dark, pale, warm, cool), right 75% of the time |
| HEARD (Commotion) | A scuffle or a thrown blade in a room, heard from further away |
| TRAIL (Footprints) | Faint footprints the Phantom leaves for a few seconds after a tag, with a little jitter |
| TAMPER (Tampering) | A torn page's scraps, or where a blackout was cut from (right 70% of the time) |

Leads expire after 75 seconds, the notebook holds eight, each family has a
cooldown, and a new round starts empty. The notebook (N, or up on the
D-pad) says "Leads, not proof". Flags: `Evidence.Enabled`,
`Evidence.Footprints.Enabled`, `Evidence.Blackout.Enabled`.

### First rounds and sitting out

- **Tips** (`Config/Tips.luau`): one short banner at a time, the first time a
  player meets each thing (their role, the blade being ready, a first draw
  or tag, someone dazed, a first lead, the bell's hint, going out), worded
  for keyboard, touch or controller. Never blocks input; saved so it never
  repeats.
- **Joining mid-round**: a corner card says when the next party starts.
- **Out or in the plaza**: a next-party countdown, the spectator bar, and
  the **wisp hunt** (`Rules/Wisps.luau`, `WispService`): wisps float round
  the plaza during a round; every eight caught together light the plaza moon
  and set off fireworks. It pays nothing and can't reach the round.

### Results, the party star and mastery

The results card leads with the moment that decided the round
(`Rules/Recap.luau`): who unmasked the Phantom and with how long to spare,
who tagged the last guest, or how many saw dawn. The **party star** is the
guest-side player who helped most without catching anyone (revives count
3, pages 1 up to the pay cap, staying up 4, picking up the blaster 2).
Each role has two or three **mastery goals** (`Config/Mastery.luau`), each
needing a win, a catch or a revive, counted in the save and shown only to
that player. They pay nothing. Flag: `Mastery.Enabled`.

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
  only the facing from the client, and need a clear line of sight. Throws
  and blaster shots are server spherecasts from a claimed origin that must
  be within 10 studs of where the server has the player and must not be
  on the far side of a wall; otherwise the server's own position is used
  (`Rules/Combat.luau`, flag `Combat.LineOfSight`).
- Effects (swings, knockouts, throws) go only to players close enough to
  see them and never carry a user id or a role; each viewer sees a throw
  only from where it comes into their view. Whisper channels follow the
  proximity chat rule. tests/Fairness.spec scans the source for both.
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
the server checks every copy again and settles the trade
(`Rules/Trade.luau`, `Lib/TradeJournal.luau`):

1. **Prepare**: the trade is written to its own key in the
   `PhantomPartyTrades` DataStore, marked Prepared.
2. **Mark**: both saves get the trade's id in `PendingTrades` and are saved.
   If either save fails, the trade is called off and nothing moves.
3. **Decide**: one write flips the journal key to Committed. That single
   write is the moment the trade happens.
4. **Apply**: both saves move the items, remember the id in
   `AppliedTrades` and drop the mark.

When a player loads, any trade still in their `PendingTrades` is settled
from the journal: Committed is applied (once), Prepared is called off.
**What this guarantees:** after a crash at any point, both players end up
with the trade applied or neither does. **What it doesn't:** the two saves
change at different moments, so it isn't atomic in real time, and if the
journal can't be reached the trade waits until it can. A player can't start
a new trade while one is pending. tests/Trades.spec crashes a trade after
every step with every mix of autosaves.

## Saves

`DataService` keeps one save per player with session locking and retries
(the tycoon's, with a new store name). `Lib/Migrations.luau` versions the
save, fills fields an older save lacks and refuses a save written by a
newer server. No personal data is stored: the save holds coins, XP, items,
outfit, pass progress, pity counts, stats, the last 25 trades (user ids and
item ids) and settings. Version 2 adds tips seen, mastery counts, pending
and applied trade ids, the Reduce motion and Captions settings, and the
wisp count; the migration leaves everything already there untouched.

## Settings and accessibility

Music, **Reduce motion** (no bouncing menus, no crate shuffle, steady
lights) and **Captions** (words for sounds, with the direction they came
from: `Config/Captions.luau`) are saved on the server. Every in-round
control works on keyboard, touch and controller, and the tips name the
right button for each.

## Analytics

`AnalyticsService` logs the first-time funnel and custom events listed in
`Config/Telemetry.luau` only: RoundPlayed, FirstAction, ClueFound,
FirstElimination, GuardianAction, LeadSeen, Replay, CosmeticEquip,
CrateOpened, TradeInitiated and TradeCompleted. Every field must be one of
its listed values (anything else is sent as "Other"), numbers are capped,
and a player sends at most 30 a minute. No names, ids or chat are sent
(tests/Telemetry.spec scans the source). `Telemetry.Enabled = false` turns
custom events off.

## Performance

Only one map is loaded at a time, at z = 900 away from the plaza. Budgets the
tests enforce: at most 5,000 parts and 40 lights a map, 2,000 parts and 36
lights for the plaza. Moving rides, floating crates, pickups and flickering
lights move on each client only, and only within 320 studs of the camera.
Streaming is off so spectating and those motions always have the map.

## Maps

tests/Maps.spec walks each built map (tests/MapCheck: solid parts only, a
character 2 by 5 studs that can step or jump 4 studs and drop any
distance, passages joining their ends) and checks every spawn, clue page,
candy coin and passage end is clear, on a floor and reachable from the
first spawn, and that spawns are further apart than a blade reaches. It
doesn't climb ladders and counts wedges as full boxes.

## Tuning

Every number lives in `src/shared/Config`: `Game.luau` (players, timers,
speeds, chat range), `Combat.luau`, `Rewards.luau`, `Evidence.luau`,
`Tips.luau`, `Mastery.luau`, `Captions.luau`, `Telemetry.luau`,
`Shop.luau`, `Crates.luau`, `Pass.luau`, `Catalog.luau`. The tests check pacing (a new
player reaches level 2 within three rounds) and that every cosmetic can be
obtained.
