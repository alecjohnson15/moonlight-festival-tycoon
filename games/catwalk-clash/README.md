# Catwalk Clash

**Dress up. Strut. Win the crown.** A Roblox fashion competition for
players aged 9 to 12. The lobby votes on a theme, everyone dresses up
backstage against the clock, then walkers battle head-to-head on the runway
while the audience and three judges vote, until one is crowned.

It's a standalone Rojo project; nothing here depends on the Halloween
Tycoon in the root of this repository.

- [docs/design.md](docs/design.md): the round, what makes it better than
  the usual dress-up game, fair voting, money and safety, and where the
  code is.
- [docs/launch.md](docs/launch.md): publishing it on Roblox, step by step.
- [docs/playtest.md](docs/playtest.md): the play-test script and targets.
- [docs/marketing.md](docs/marketing.md): store text and prompts for the
  icon and thumbnails.
- [publish/README.md](publish/README.md): publishing with an Open Cloud key
  (`publish/publish.ps1`).
- [docs/rights-register.md](docs/rights-register.md): where every asset
  comes from.

## What's in it

- **Rounds:** lobby and theme vote (22 s), reveal, 150 s of dressing in
  your own booth, a head-to-head bracket on a two-lane runway, and a
  crowning with a Hall of Fame statue. Rivals fill the bracket on small
  servers, so a show runs even solo. Players can choose **Watch only** in
  Settings to sit out and vote, and **Reduced motion** to turn off camera
  flashes and swoops.
- **Voting:** server-side, one vote per account per matchup, only while
  both outfits are on show, with walkers barred from their own matchup,
  extra votes from a walker's friends or brand-new accounts counting half
  after the first two, the split hidden until the end, and rule-based
  judges whose weight fades as the audience grows and who give each walker
  a star rating and a compliment. The rules are explained in game.
- **Show:** a random bracket draw (byes by luck), an opening lineup of
  every look, and a catch-up for players who join mid-show.
- **Wardrobe:** 152 original pieces in ten slots, built from parts, each in
  36 colours and eight finishes; painted tops, bottoms, shoes and gloves on
  the avatar; your own body or the classic one; 14 poses and 15 entrances;
  a turntable preview; a closet of saved outfits; **Theme look** for a
  quick starting outfit; and undo and redo.
- **Catalog:** search the Roblox avatar shop, try anything on for free,
  favourite it, wear it on the runway, or buy it with Roblox's prompt (the
  game earns the commission and the creator is paid).
- **Progress:** an Elo Style Score with six ranks and a world leaderboard
  (the first 10 walks can only raise it),
  Sparkles to spend, a 30-tier Style Pass season, three daily challenges, a
  login streak, and 69 themes including seasonal ones that rotate in by
  date, with a weekly double-reward spotlight.
- **Shop:** game passes (four collections, VIP, Color Studio, Big Closet,
  poses, entrances), the Style Pass and Sparkles packs, all with their
  contents stated up front. No loot boxes or random paid items, and paid
  pieces score no higher than ones earned by playing.
- **Sound:** three original songs (lobby, backstage, runway), a crowd loop
  and 16 effects, made by `tools/make_sounds.py`.
- **Analytics:** an onboarding funnel and custom events on the Creator
  Dashboard.

## Getting started

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run
   `rokit install` in this folder for the pinned Rojo, StyLua, Selene and
   Lune.
2. `rojo serve`, open a new Baseplate in Studio, delete the baseplate and
   connect from the Rojo plugin. Or build a place file:
   `rojo build default.project.json -o catwalk-clash.rbxl`.
3. Press **Play**. The server builds the whole map. In Studio every paid
   item counts as owned so it can be tried on.
4. Set **Max Players** to 12 (there are 12 booths) and, to test saves, turn
   on **Security > Enable Studio Access to API Services**.
5. Sounds: run `python3 tools/make_sounds.py` to remake `assets/audio`
   (needs numpy and ffmpeg). Upload the files and paste their ids into
   `src/shared/Config/Sounds.luau` (launch step 2). Until then clicks use
   plain Roblox sounds and there's no music.

## Checks

Run from this folder; CI runs the same in
`.github/workflows/game-catwalk-clash.yml`.

```
stylua --check src tests tools
selene src tests tools
lune run tests/run
rojo build default.project.json -o catwalk-clash.rbxl
```

The Lune tests cover the bracket (including thousands of simulated
shows), voting, judging, the Theme look, rivals, Style Score, the
Style Pass, challenges, streaks, the theme picker, look checks and the
funnel, and build every wardrobe piece and the whole map with Lune's Roblox
library.

## Common changes

- **Round timings, rewards, voting weights:** `src/shared/Config/Game.luau`.
- **A new theme:** add it at the bottom of `Config/Themes.luau`. Give it a
  `Window` to make it seasonal. Never change an id. Then run
  `lune run tools/theme_matrix` to refresh `docs/theme-coverage.md`; the
  tests check that its tags differ from every other theme's and that free
  pieces can nail it.
- **A new piece:** add it to `Config/Wardrobe.luau` with tags from the
  theme tag list; the tests check it builds and stays under 40 parts.
- **Prices and pass ids:** `Config/Catalog.luau` (Robux) and the `Price`
  of each piece, pose and entrance (Sparkles).
- **Next season:** copy `Config/Season.luau` with a new id and dates, and
  add its pass to `Config/Catalog.luau`.
