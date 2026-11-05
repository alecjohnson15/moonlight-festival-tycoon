# Catwalk Clash

*Dress up. Strut. Win the crown.*

| | |
| --- | --- |
| **Genre** | Avatar fashion competition (Roleplay & Avatar Sim, Dress Up) |
| **Players** | Up to 12 per server (12 dressing booths). Rivals fill the bracket on small servers, so it works solo |
| **Session** | 4 to 7 minutes per round |
| **For** | Ages 9 to 12. Aimed at **Mild**, and in practice has nothing above Minimal (no violence, no fear) |
| **Status** | Built, all checks pass, **not yet played in Studio**, not yet on Roblox |
| **Code** | `games/catwalk-clash/` (its own Rojo project), branch `claude/project-thread-boq9ks` |
| **Pull request** | [PR #15](https://github.com/alecjohnson15/moonlight-festival-tycoon/pull/15) (open) |
| **Place file** | `/mnt/project-files/release/catwalk-clash.rbxl` |
| **Sounds** | `/mnt/project-files/release/catwalk-clash-audio/` (20 .ogg files) |
| **Build thread** | "Build an avatar fashion competition game" |

## What it is

A fashion show game. Every few minutes the lobby votes on a theme, everyone
dresses up against the clock, and then walkers go down the runway two at a
time while the audience and three judges vote, until one player is crowned.

It keeps the loop that dress-up games on Roblox have proven (theme, timer,
runway, vote) and fixes what players complain about: votes decided by friend
groups, half the room sitting idle, nothing to keep between rounds, and looks
limited to whatever the game stocks.

## How a round plays

| Phase | Time | What happens |
| --- | --- | --- |
| Lobby | 22 s | Hang out in Glow Plaza. The last 15 s is the theme vote: three cards, one of them the week's spotlight theme (pays double) |
| Reveal | 5 s | The theme lands on the big screens with a fanfare |
| Dressing | 150 s | Your own booth backstage and the Wardrobe. When everyone presses **Ready** it cuts to 8 s. Late joiners can enter with 40 s left |
| Showtime | ~17 s a matchup | A head-to-head bracket: two walkers stride down their own lanes with their entrance effect, strike a pose, and the audience votes pink or aqua. Judges add their votes, the split is revealed, the winner moves on |
| Crowning | 14 s | The champion gets a crown, fireworks and confetti, and becomes the Hall of Fame statue in the plaza until the next show |

Anyone who isn't walking is voting, so nobody waits with nothing to do.
Players can choose **Watch only** in Settings to sit out and vote.

## What makes it better

- **Head-to-head brackets** instead of rating everyone 1 to 5 stars. Short
  matchups, a clear winner every time, seeded by Style Score so the two best
  walkers meet in the final.
- **Fair voting, decided on the server:** walkers can't vote in their own
  matchup; votes only count while both outfits are on show; one vote per
  account per matchup; Roblox friends of a walker and accounts under 7 days
  old count half; the running split is hidden until votes close.
- **Three judges** (Madame Velour, DJ Pixel and Nana Stitch) score how well a
  look fits the theme. They decide quiet servers and fade as the audience
  grows.
- **A big wardrobe:** 152 original pieces in ten slots, built in code, each in
  36 colours and eight finishes (matte, satin, shiny, sequin, glow, metal,
  glass, frost). Painted clothes go on the avatar itself. 14 poses, 15 runway
  entrances, a turntable preview, and a closet of saved outfits.
- **The whole Roblox catalog:** search Roblox's real avatar shop, try anything
  on for free, wear it on the runway, or buy it through Roblox's own prompt
  (the item's creator is paid and the game earns the commission).
- **Things to come back for:** an Elo **Style Score** with six ranks
  (Newcomer to Legend) and a world leaderboard, Sparkles to spend, a 30-tier
  **Style Pass** season, three daily challenges, a 7-day login streak, and
  69 themes, including seasonal ones that appear by date and a weekly
  double-reward spotlight.
- **Broadcast camera:** wide runway shot, close-ups for poses, then the
  podium. Fans along the runway hop and wave glowsticks.

## Money (Robux)

10 game passes and 3 Sparkles packs (developer products), all with their
contents stated up front, plus the commission on catalog sales. No loot
boxes, no random rewards, no rerolls, no timers, no vote boosts. A test checks
that for every theme a brand-new player with only free pieces can reach the
judges' top score, and that pieces bought with Robux never score higher than
pieces bought with earned Sparkles.

| Item | What it gives | Robux |
| --- | --- | --- |
| Style Pass: Season 1 | The premium track: 30 extra rewards, all shown before you buy | 399 |
| VIP | Gold name tag, rooftop VIP Lounge, Golden Carpet entrance | 249 |
| Royal Gala Collection | 6 royal pieces | 199 |
| Neon Night Collection | 8 glowing pieces | 199 |
| Fairy Garden Collection | 5 fairy pieces | 199 |
| Star Couture Collection | 5 space pieces | 199 |
| Color Studio | Full colour picker for any piece | 149 |
| Showstopper Entrances | 5 extra runway entrances | 149 |
| Supermodel Poses | 6 extra poses | 99 |
| Big Closet | Save 24 outfits instead of 4 | 99 |
| Pouch / Jar / Chest of Sparkles | 500 / 1,500 / 4,000 Sparkles (fixed amounts) | 49 / 129 / 299 |

Season 1, "Glow Up", runs 2026-11-01 to 2027-02-01. Season 2 needs a new
season config and a new pass.

## Safety

- No child personal data: the save holds game progress keyed by Roblox user
  id. Analytics are Roblox's own, with no names or free text.
- Nobody types anything other players see. Outfit names come from word
  lists; the only text box (catalog search) goes to Roblox's search and is
  never shown to others.

## Status

- Built and pushed in PR #15. 56 Lune tests pass (bracket, voting, judging,
  rivals, Style Score, Style Pass, challenges, streaks, theme picker, look
  checks, funnel, and building every piece and the map), and CI is green.
- **Nobody has played it in Studio yet.** In Studio every paid item counts as
  owned so it can be tried on; the live game never does that.
- 20 original sounds (3 songs, a crowd loop, 16 effects) are made but not
  uploaded. Until then clicks use plain Roblox sounds and there's no music.
- All pass and product ids are 0 (paid items show **Coming soon**).
- **Store icon, thumbnails and pass icons are not made yet.** Prompts are in
  `games/catwalk-clash/docs/marketing.md`.

## How to publish

The quick way, with an API key (the same as Halloween Tycoon):

1. **Create the experience.** On the
   [Creator Hub](https://create.roblox.com/dashboard/creations), click
   **Create Experience** (an empty one is fine). Or open `catwalk-clash.rbxl`
   in Studio and use **File > Publish to Roblox > Create new experience**
   once.
2. **Copy two ids.** The **universe id** is the number after
   `/experiences/` in the address bar. The **place id** is on the Places tab,
   under **⋯ > Copy Place ID**.
3. **Make an Open Cloud API key** on the
   [API Keys page](https://create.roblox.com/dashboard/credentials). Add these
   API systems, choosing this experience where it asks:
   - `universe-places`: write (publish the place file)
   - `universe`: write (name, description, devices)
   - `universe.place`: write (12 players per server)
   - `game-pass`: read and write (the 10 passes)
   - `developer-product`: read and write (the 3 Sparkles packs)
   - `asset`: read and write (upload the 20 sounds)
   - optional `legacy-universe`: manage (icon and thumbnails, once they exist)

   Set an expiry a few days out and add your PC's IP under Accepted IP
   Addresses (or `0.0.0.0/0` with that short expiry).
4. **Paste the key, the universe id and the place id** in the "Build an avatar
   fashion competition game" thread and say **"go ahead"**. From your PC,
   Claude uploads the sounds, creates the passes and packs, puts the ids in
   the game, sets the name, description and server size, and publishes it.
   The game stays private.
5. **You still do, in Studio (File > Experience Settings):**
   - **Avatar:** check the avatar type is **R15** (poses, painted clothes and
     catalog try-on need it).
   - **Security:** turn on **Allow Third Party Sales**, or the Catalog tab's
     Buy button can't sell other creators' items and earns no commission.
6. **Also yours:** the content rating questionnaire (below), the store art,
   and the release. Delete the API key when it's done.

**Content rating answers** (Creator Dashboard > Publish settings > Content
rating): every content question **None** (violence, blood, fear, crude
humour, romance, alcohol, drugs, tobacco, strong language, gambling,
sensitive issues), and **No** for social hangout, free-form creation, paid
random items and paid item trading. It should come out **Mild** or lower.

**Then soft launch:** keep it private for a day or two and play real shows
with a few friends (`games/catwalk-clash/docs/playtest.md`). Then set it to
**Public**. Skip ads for the first week, watch the onboarding funnel,
next-day retention and session length in Analytics, and fix the biggest drop
first. Players under 16 need the same extra steps as Halloween Tycoon.

Every later update: open the new place file, **File > Publish to Roblox As**,
pick Catwalk Clash and its place, **Overwrite**.

## Where things are

- `games/catwalk-clash/README.md`: overview, getting started, checks.
- `games/catwalk-clash/docs/design.md`: the round, fair voting, money,
  safety, and where the code is.
- `games/catwalk-clash/docs/launch.md`: publishing by hand and the full pass
  table with exact descriptions.
- `games/catwalk-clash/docs/playtest.md`, `marketing.md`,
  `rights-register.md`.
- `games/catwalk-clash/src/shared/Config/`: round timings and voting weights
  (`Game.luau`), themes, wardrobe, poses, entrances, the season, the catalog,
  judges and rivals.
