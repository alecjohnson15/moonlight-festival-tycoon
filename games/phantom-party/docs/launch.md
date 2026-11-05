# Publishing Phantom Party

How to put Phantom Party: Masquerade Mystery on Roblox, from the place file
to a public game. There are two ways: let Claude do most of it with an Open
Cloud API key (quickest), or do every step by hand in Studio and the Creator
Dashboard. Either way, use one Roblox account throughout: Roblox only plays
audio in games its owner may use.

Roblox changes these screens often. If a button has moved, the
[publishing guide](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
has the current one.

## Before you start

- **Can you publish public games?** Check
  [your eligibility page](https://create.roblox.com/settings/eligibility/public-publish)
  (ID verification, or a real-money purchase made on or after 1 January 2025).
- **Players under 16** need the same extra steps as Halloween Tycoon (an age
  check, 2-Step Verification, the publishing fee or two months of Premium,
  then Roblox's engagement check and safety review). Every new game opens to
  players aged 16 and up first, so this can wait until after launch.
- **The name:** search Roblox for "Phantom Party" and make sure no big game
  already uses it.
- **The store art:** made with an AI image tool from `docs/marketing.md`.
  Check its terms allow commercial use (`docs/rights-register.md`).

## Quick way: Claude does it with an API key

1. On the [Creator Dashboard](https://create.roblox.com/dashboard/creations),
   click **Create Experience** (an empty one is fine) and open it. Copy the
   **universe id** from the address bar (the number after
   `/experiences/`) and the **start place id** (Places tab, **⋯** > Copy Place
   ID).
2. Open [API Keys](https://create.roblox.com/dashboard/credentials) >
   **Create API Key**. Name it "Phantom Party", then **Add API System** for
   each of these, choosing this experience where it asks:
   - **universe-places**: write (to publish the place file)
   - **universe**: write (name, description, devices)
   - **universe.place**: write (12 players per server)
   - **game-pass**: read and write (to make the eight passes)
   - **asset**: read and write (to upload the 33 sounds)

   Under **Accepted IP Addresses** add `0.0.0.0/0`, set an expiry a few days
   out, then **Save & Generate Key** and copy it.
3. Paste the key, the universe id and the place id into the project thread.
   Claude, working from your PC as with Halloween Tycoon, then:
   - uploads the 33 sounds and puts their ids in `Config/Sounds.luau`,
   - creates the eight passes with their names, descriptions and prices and
     puts their ids in `Config/Catalog.luau`,
   - sets the name, description, devices and a 12-player server size,
   - builds the place and publishes it to your experience.
4. You still do, on the Creator Dashboard: the icon and thumbnails (step 2
   below), the content rating questionnaire (step 4), pass icons if you want
   pictures on them, and the release (step 8). Delete the API key when it's
   done.

## By hand

### 1. Open the place file

Open `phantom-party.rbxl` in Studio (**File > Open from File**). It holds the
whole game; Rojo isn't needed. Press **Play** for a practice round.

### 2. Publish it (still private)

**File > Publish to Roblox > Create new experience**:

- **Name:** `Phantom Party: Masquerade Mystery`
- **Description:** the store text from `docs/marketing.md`.
- **Genre:** Party & Casual (or the closest, such as Social Deduction).
- **Icon and thumbnails:** made from the prompts in `docs/marketing.md`.
- **Devices:** computer, phone and tablet. Leave console off until it has
  been tried with a controller.

### 3. Experience settings

**File > Experience Settings**:

- **Places:** **⋯** next to the place > **Configure Place**, server size
  **12**.
- **Communication:** text chat on. The game makes chat proximity-based in
  rounds by itself.
- **Security:** **Enable Studio Access to API Services** only matters for
  testing saves in Studio.

### 4. The content rating questionnaire

Creator Dashboard > the game > **Publish settings > Content rating**. It
should come out **Mild**.

| Question | Answer | Why |
| --- | --- | --- |
| Violence | Yes: unrealistic, repeated | Cartoon blade tags and blaster zaps. A tagged player falls over with stars spinning above them, then fades back to the plaza. Nobody dies, no blood |
| Blood | None | |
| Fear | Yes: mild | A moonlit manor and a closed carnival at night, a ghost train. No jump scares, no gore |
| Crude humour, romance, alcohol, drugs, tobacco, strong language, gambling, sensitive issues | None | |
| Social hangout | No | The plaza is a lobby between rounds of a game |
| Free-form user creation | No | |
| Paid random items | No | Crates open only with coins earned by playing. Every Robux purchase is a pass that says exactly what it gives |
| Paid item trading | No | Only items earned in play can be traded; Robux items are bound to the buyer |

### 5. Upload the sounds

The 33 sounds are in `assets/audio` (and in the zip next to the place file).
In Studio, **View > Asset Manager > Bulk Import**, pick them all and wait for
moderation. Then copy each id and paste the list into the project thread as
`file_name.ogg 1234567890`; Claude puts them in `Config/Sounds.luau` and
sends a new place file. Until then the game plays Roblox's own stand-in
sounds for effects and no music.

### 6. Make the game passes

Creator Dashboard > the game > **Monetization > Passes > Create pass**, once
for each row. Turn on **Item for Sale** with the price, then **⋯ > Copy
Asset ID** and paste the ids into the thread like `moon_pass 1234567890`.
Until then the boutique shows them as **Soon**.

| Id | Name | Description | Robux |
| --- | --- | --- | --- |
| `moon_pass` | Moon Pass Premium | Unlocks the premium track of the Moon Pass: nine exclusive cosmetics, including the Midnight Gala Blade at tier 30. Tiers you've already reached unlock at once. | 399 |
| `royal_set` | Royal Masquerade Set | The Royal Rapier blade, the Gilded Lantern Blaster and the Golden Confetti knockout effect. | 249 |
| `neon_blade` | Neon Nightmare Blade | A glowing pink and cyan Phantom blade. Looks only: it tags like every other blade. | 149 |
| `starfall_blaster` | Starfall Blaster | A navy and gold Guardian blaster that fires a golden beam. Looks only. | 149 |
| `sun_mask` | Golden Sun Mask | A shining golden sun mask with glowing rays. | 99 |
| `ghostfire_trail` | Ghostfire Trail | A trail of green ghostfire that follows you as you run. | 99 |
| `vip` | VIP Lounge | Entry to the VIP lounge on the plaza's balcony, a gold VIP tag in chat and a gold name over your head in the lobby. | 199 |
| `party_emotes` | Party Emotes | Five extra emotes for the lobby and rounds: Spotlight, Confetti Cannon, Glitter Puff, Star Halo and Applause. Looks only. | 99 |

(`tools/passes.json` holds the same list for the Open Cloud script.)

### 7. Publish the new file over the old one

Open the new place file, **File > Publish to Roblox As**, pick Phantom
Party and its place, **Overwrite**. Use **Restart servers** on the Creator
Dashboard to move running servers over.

## Soft launch

Keep it private for a day or two and play the real thing:

- From the Roblox app, alone: you should get practice rounds and hear sound.
- With 2 to 12 friends (**Publish settings > Manage Audience > Playtest**):
  play several rounds on both maps, try every role, revive someone, pick up a
  dropped blaster, fill the Truth Bell, chat in a round from near and far.
- Open a crate, buy a coin item, trade with a friend, claim pass tiers,
  leave and rejoin: everything should still be there.
- Buy one cheap pass and check it arrives and stays after rejoining.
- Try a phone: the round buttons sit at the bottom right.

## 8. Release it

**Publish settings > Manage Audience > Public**. Watch **Analytics** for the
first week: the funnel (Joined, Role revealed, Finished a round, Second
round, Equipped an item), next-day return, and session length. Fix the
biggest drop first, then promote it.
