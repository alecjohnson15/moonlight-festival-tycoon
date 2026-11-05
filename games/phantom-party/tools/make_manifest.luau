-- Writes publish/manifest.json, the list publish/publish.ps1 reads, from
-- Config (see tools/PublishManifest). Run it from the game's folder after
-- changing a pass, price or sound: `lune run tools/make_manifest`.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local PublishManifest = require("./PublishManifest")

fs.writeFile(PublishManifest.PATH, serde.encode("json", PublishManifest.build(), true) .. "\n")
print(`Wrote {PublishManifest.PATH}`)
