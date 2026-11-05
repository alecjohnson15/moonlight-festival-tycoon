# Publishing Catwalk Clash with the API key

`publish.ps1` does every Roblox step the API allows, in one go, from any
Windows PC with Rojo: it uploads the 20 sounds, makes the 10 game
passes and the 3 developer products (with the icons in
`assets/marketing/passes`),
writes their ids into `Config/Catalog.luau` and `Config/Sounds.luau`, builds
the place, sets the name, description, server size and devices, and
publishes it to the experience.

## What it needs

1. An experience on the [Creator Dashboard](https://create.roblox.com/dashboard/creations):
   **Create Experience** (an empty one is fine). Its **universe id** is the
   number after `/experiences/` in the address bar; the **place id** is on
   the **Places** tab, **⋯ > Copy Place ID**.
2. An Open Cloud key from [API Keys](https://create.roblox.com/dashboard/credentials),
   **Create API Key**, with **Add API System** for each of these, picking
   this experience where it asks:
   - **universe-places**: write (publishes the place)
   - **universe**: write (devices)
   - **universe.place**: write (name, description, server size)
   - **game-pass**: read and write
   - **developer-product**: read and write (the Sparkles packs)
   - **asset**: read and write (the sounds)

   One key can list all three games. Under **Accepted IP Addresses** add
   `0.0.0.0/0` (or the PC's address), set an expiry a few days out, then
   **Save & Generate Key**. Delete it when publishing is done.
3. Rojo on the PC (`rokit install` in this game's folder installs the
   pinned version), or a place file built elsewhere with the ids wired in
   (`-PlaceFile`).

## Running it

From this game's folder (`games/catwalk-clash`), in PowerShell:

```powershell
$env:ROBLOX_API_KEY = "<the key>"
powershell -ExecutionPolicy Bypass -File publish\publish.ps1 -UniverseId <universe id> -PlaceId <place id>
```

Try it first with `-DryRun`: it says what each step would do and sends
nothing. `-Steps sounds,wire,build,publish` runs only some steps.

Every id Roblox hands back goes into `publish\ids.json` straight away, so a
second run carries on where the first stopped and never makes anything
twice. Passes and products already on the experience with the same name are
reused. If Roblox's audio limit stops the sound uploads (100 per 30 days on
an account that isn't ID-verified), the game plays its built-in stand-in
sounds for the rest; run the script again later. Afterwards, commit
`publish/ids.json` and the two Config files so the next build keeps the
ids.

## What's left by hand

The API can't do these; they're in `docs/launch.md`: the content rating
questionnaire, the genre, the icon and thumbnails, the audience (it stays
private until you open it), and anything under **Avatar** or **Security**
in the experience settings.

`publish/manifest.json` is the list the script reads. It's generated from
Config by `lune run tools/make_manifest`, and `tests/Publish.spec` fails if
the two drift apart.
