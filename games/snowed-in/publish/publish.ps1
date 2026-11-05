<#
.SYNOPSIS
Puts this game on Roblox with an Open Cloud API key.

.DESCRIPTION
Uploads the game's sounds, makes its game passes (and developer products),
writes every new id into the game's Config files, builds the place file with
Rojo, sets the experience's name, description, server size and devices, and
publishes the place. publish\manifest.json says what to make; it comes from
the game's Config (`lune run publish/make_manifest` writes it again).

Everything made is written to publish\ids.json the moment Roblox returns its
id, so running the script again carries on where it stopped and never makes
a sound, pass or product twice. Passes and products that already exist on
the experience with the same name are reused, not made again.

In PowerShell, from anywhere:

  $env:ROBLOX_API_KEY = "<the key>"
  powershell -ExecutionPolicy Bypass -File games\<game>\publish\publish.ps1 -UniverseId <id> -PlaceId <id>

Steps, run in this order (-Steps picks some, -DryRun shows what each would do
without calling Roblox or changing a file):
  check     the key works and the place belongs to the experience
  sounds    upload the assets\audio files that have no id yet
  passes    make the game passes that have no id yet
  products  make the developer products that have no id yet
  wire      write the ids into Config\Catalog.luau and Config\Sounds.luau
  build     rojo build the place into publish\<game>.rbxl
  settings  set the name, description, server size and devices
  publish   publish the place file as the live version

The key needs these API systems for the experience: universe-places (write),
universe (write), universe.place (write), game-pass (read, write), asset
(read, write), and developer-product (read, write) for a game that sells
developer products. The key is only read from ROBLOX_API_KEY and is never
written to a file.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string]$UniverseId,
	[Parameter(Mandatory = $true)][string]$PlaceId,
	[string[]]$Steps = @("check", "sounds", "passes", "products", "wire", "build", "settings", "publish"),
	# Publish this place file instead of building one (skips build).
	[string]$PlaceFile = "",
	[switch]$DryRun,
	[string]$ApiBase = "https://apis.roblox.com"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 1

$known = @("check", "sounds", "passes", "products", "wire", "build", "settings", "publish")
$Steps = @($Steps | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
foreach ($step in $Steps) {
	if ($known -notcontains $step) { throw "Unknown step '$step'. Steps: $($known -join ', ')" }
}
if ($UniverseId -notmatch '^\d+$') { throw "UniverseId should be the number after /experiences/ in the Creator Hub address." }
if ($PlaceId -notmatch '^\d+$') { throw "PlaceId should be the start place's number (Places tab, ... > Copy Place ID)." }

$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
$curlExe = if ($env:OS -eq "Windows_NT") { "curl.exe" } else { "curl" }
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("roblox-publish-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null

function Read-Utf8([string]$path) { return [System.IO.File]::ReadAllText($path, $utf8) }
function Write-Utf8([string]$path, [string]$text) { [System.IO.File]::WriteAllText($path, $text, $utf8) }
function In-Root([string]$relative) { return Join-Path $root ($relative -replace '/', [System.IO.Path]::DirectorySeparatorChar) }
function Say([string]$text) { Write-Host $text }
function Heading([string]$text) { Write-Host ""; Write-Host "== $text" -ForegroundColor Cyan }
function Has([string]$step) { return $Steps -contains $step }

$manifest = (Read-Utf8 (In-Root "publish/manifest.json")) | ConvertFrom-Json
# An empty list can come out of the manifest as {} instead of [].
function Entries($value, [string]$key) { return @(@($value) | Where-Object { $_ -and $_.$key }) }
$soundList = Entries $manifest.sounds "name"
$passList = Entries $manifest.passes "id"
$productList = Entries $manifest.products "id"
$statePath = In-Root "publish/ids.json"

$key = $env:ROBLOX_API_KEY
if (-not $key -and -not $DryRun) { throw 'Set the key first: $env:ROBLOX_API_KEY = "<the key>"' }

# ---- ids.json -------------------------------------------------------------

$state = [ordered]@{
	universeId = $UniverseId
	placeId = $PlaceId
	sounds = [ordered]@{}
	passes = [ordered]@{}
	products = [ordered]@{}
	versions = @()
}
if (Test-Path $statePath) {
	$saved = (Read-Utf8 $statePath) | ConvertFrom-Json
	if ($saved.universeId -and "$($saved.universeId)" -ne $UniverseId) {
		throw "publish\ids.json holds ids for experience $($saved.universeId), not $UniverseId. Move it aside to start a new experience."
	}
	foreach ($group in @("sounds", "passes", "products")) {
		if ($saved.$group) {
			foreach ($entry in $saved.$group.PSObject.Properties) { $state[$group][$entry.Name] = "$($entry.Value)" }
		}
	}
	if ($saved.versions) { $state.versions = @($saved.versions) }
}

function Save-State {
	if ($DryRun) { return }
	Write-Utf8 $statePath ((ConvertTo-Json -InputObject $state -Depth 6) + "`n")
}

# ---- Talking to Roblox ----------------------------------------------------

# Calls Open Cloud with curl (everything goes through files, so names and
# descriptions keep their characters on Windows PowerShell 5). Retries rate
# limits and server errors with a growing wait.
function Invoke-Api([string]$Method, [string]$Path, [string[]]$Extra = @()) {
	$out = Join-Path $tmp "response.json"
	$wait = 2
	for ($try = 1; $try -le 5; $try++) {
		if (Test-Path $out) { Remove-Item $out }
		$curlArgs = @("-sS", "-X", $Method, "$ApiBase$Path", "-H", "x-api-key: $key", "-o", $out, "-w", "%{http_code}") + $Extra
		$code = & $curlExe @curlArgs
		if ($LASTEXITCODE -ne 0) { throw "curl couldn't reach Roblox ($Method $Path, curl exit $LASTEXITCODE)." }
		$status = [int]("$code".Trim())
		$text = ""
		if (Test-Path $out) { $text = Read-Utf8 $out }
		$body = $null
		if ($text) { try { $body = $text | ConvertFrom-Json } catch { $body = $null } }
		if (($status -eq 429 -or $status -ge 500) -and $try -lt 5) {
			Say "   Roblox said $status; trying again in $wait s."
			Start-Sleep -Seconds $wait
			$wait = $wait * 2
			continue
		}
		return [pscustomobject]@{ Status = $status; Text = $text; Body = $body }
	}
}

function Fail-Text($response) {
	$text = "$($response.Text)"
	if ($text.Length -gt 400) { $text = $text.Substring(0, 400) + "..." }
	return "HTTP $($response.Status): $text"
}

function Text-File([string]$name, [string]$text) {
	$path = Join-Path $tmp $name
	Write-Utf8 $path $text
	return $path
}

# Every existing pass or product on the experience, by name, so a rerun
# after a lost ids.json (or a pass made by hand) reuses it.
function Get-Existing([string]$listPath, [string]$listField, [string]$idField) {
	$found = @{}
	$token = ""
	do {
		$query = "?pageSize=50"
		if ($token) { $query += "&pageToken=$([uri]::EscapeDataString($token))" }
		$r = Invoke-Api "GET" "$listPath$query"
		if ($r.Status -ne 200) { throw "Couldn't list what's on the experience. $(Fail-Text $r)" }
		foreach ($item in @($r.Body.$listField)) {
			if ($item -and $item.name) { $found[$item.name] = "$($item.$idField)" }
		}
		$token = "$($r.Body.nextPageToken)"
	} while ($token)
	return $found
}

function Make-Items([string]$group, $items, [string]$createPath, [string]$listPath, [string]$listField, [string]$idField) {
	$missing = @($items | Where-Object { -not $state[$group].Contains($_.id) })
	Say "$(@($items).Count - $missing.Count) of $(@($items).Count) already made."
	if ($missing.Count -eq 0) { return }
	if ($DryRun) {
		foreach ($item in $missing) { Say "   would make $($item.id): $($item.name), $($item.price) Robux" }
		return
	}
	$existing = Get-Existing $listPath $listField $idField
	foreach ($item in $missing) {
		if ($existing.ContainsKey($item.name)) {
			$state[$group][$item.id] = $existing[$item.name]
			Save-State
			Say "   $($item.id): already on Roblox as $($existing[$item.name])"
			continue
		}
		$icon = In-Root $item.icon
		if (-not (Test-Path $icon)) { throw "Missing icon $($item.icon)" }
		$form = @(
			"-F", "name=<$(Text-File 'name.txt' $item.name)",
			"-F", "description=<$(Text-File 'description.txt' $item.description)",
			"-F", "price=$($item.price)",
			"-F", "isForSale=true",
			"-F", "imageFile=@$icon;type=image/png"
		)
		$r = Invoke-Api "POST" $createPath $form
		$id = $null
		if ($r.Status -eq 200 -and $r.Body) { $id = $r.Body.$idField }
		if (-not $id) { throw "Roblox didn't make $($item.id). $(Fail-Text $r)" }
		$state[$group][$item.id] = "$id"
		Save-State
		Say "   $($item.id): $id"
		Start-Sleep -Milliseconds 400
	}
}

# ---- The steps --------------------------------------------------------------

$creator = $null
try {
	Say "$($manifest.game): experience $UniverseId, place $PlaceId$(if ($DryRun) { ' (dry run: nothing is sent or changed)' })"

	if ((Has "check") -or (Has "sounds")) {
		Heading "check"
		if ($DryRun) {
			Say "would check the key can see the experience and its place"
		} else {
			$r = Invoke-Api "GET" "/cloud/v2/universes/$UniverseId"
			if ($r.Status -ne 200) {
				throw "The key can't see experience $UniverseId. Check the id, and that the key lists this experience and allows this computer's IP. $(Fail-Text $r)"
			}
			if ($r.Body.user) { $creator = @{ userId = ("$($r.Body.user)" -replace '^users/', '') } }
			elseif ($r.Body.group) { $creator = @{ groupId = ("$($r.Body.group)" -replace '^groups/', '') } }
			Say "Experience: $($r.Body.displayName) (owner $($r.Body.user)$($r.Body.group))"
			$r = Invoke-Api "GET" "/cloud/v2/universes/$UniverseId/places/$PlaceId"
			if ($r.Status -ne 200) { throw "Place $PlaceId isn't in experience $UniverseId. $(Fail-Text $r)" }
			Say "Place: $($r.Body.displayName)"
		}
	}

	if (Has "sounds") {
		Heading "sounds"
		$sounds = $soundList
		$missing = @($sounds | Where-Object { -not $state.sounds.Contains($_.name) })
		Say "$($sounds.Count - $missing.Count) of $($sounds.Count) already uploaded."
		foreach ($sound in $missing) {
			$file = In-Root $sound.file
			if (-not (Test-Path $file)) { throw "Missing sound file $($sound.file)" }
			if ($DryRun) { Say "   would upload $($sound.file) as '$($sound.displayName)'"; continue }
			$request = [ordered]@{
				assetType = "Audio"
				displayName = $sound.displayName
				description = $sound.description
				creationContext = @{ creator = $creator }
			}
			$requestFile = Text-File "request.json" (ConvertTo-Json -InputObject $request -Depth 5)
			$r = Invoke-Api "POST" "/assets/v1/assets" @("-F", "request=<$requestFile;type=application/json", "-F", "fileContent=@$file;type=audio/ogg")
			if ($r.Status -ne 200 -or -not $r.Body) {
				Write-Warning "Stopped uploading at $($sound.file): $(Fail-Text $r)"
				Write-Warning "The game plays its stand-in sounds for the rest. Run the script again later to carry on (Roblox limits audio uploads per 30 days)."
				break
			}
			$operation = $r.Body
			$assetId = $null
			for ($poll = 0; $poll -lt 30; $poll++) {
				if ($operation.done) {
					if ($operation.response) { $assetId = $operation.response.assetId }
					break
				}
				Start-Sleep -Seconds 2
				$operationId = $operation.operationId
				if (-not $operationId) { $operationId = ("$($operation.path)" -replace '^operations/', '') }
				$r = Invoke-Api "GET" "/assets/v1/operations/$operationId"
				if ($r.Status -ne 200) { break }
				$operation = $r.Body
			}
			if (-not $assetId) {
				Write-Warning "No id came back for $($sound.file): $(Fail-Text $r). Run the script again later to carry on."
				break
			}
			$state.sounds[$sound.name] = "$assetId"
			Save-State
			Say "   $($sound.name): $assetId"
		}
	}

	if (Has "passes") {
		Heading "passes"
		Make-Items "passes" $passList "/game-passes/v1/universes/$UniverseId/game-passes" `
			"/game-passes/v1/universes/$UniverseId/game-passes/creator" "gamePasses" "gamePassId"
	}

	if ((Has "products") -and $productList.Count -gt 0) {
		Heading "products"
		Make-Items "products" $productList "/developer-products/v2/universes/$UniverseId/developer-products" `
			"/developer-products/v2/universes/$UniverseId/developer-products/creator" "developerProducts" "productId"
	}

	if (Has "wire") {
		Heading "wire"
		$catalogPath = In-Root $manifest.catalogFile
		$text = Read-Utf8 $catalogPath
		$before = $text
		foreach ($group in @("passes", "products")) {
			foreach ($entry in $state[$group].GetEnumerator()) {
				$pattern = '(Id = "' + [regex]::Escape($entry.Key) + '",(?:(?!\bId = ")[\s\S])*?\b(?:PassId|ProductId) = )\d+'
				$match = [regex]::Match($text, $pattern)
				if (-not $match.Success) { throw "Can't find $($entry.Key)'s PassId or ProductId in $($manifest.catalogFile)." }
				$text = $text.Substring(0, $match.Index) + $match.Groups[1].Value + $entry.Value + $text.Substring($match.Index + $match.Length)
			}
		}
		if ($text -ne $before) {
			if (-not $DryRun) { Write-Utf8 $catalogPath $text }
			Say "$($manifest.catalogFile): $($state.passes.Count) pass and $($state.products.Count) product ids"
		} else {
			Say "$($manifest.catalogFile): nothing new"
		}
		$soundsPath = In-Root $manifest.soundsFile
		$text = Read-Utf8 $soundsPath
		$before = $text
		foreach ($entry in $state.sounds.GetEnumerator()) {
			$pattern = '(?m)^(\s*' + [regex]::Escape($entry.Key) + ' = \{ Id = )"[^"]*"'
			$match = [regex]::Match($text, $pattern)
			if (-not $match.Success) { throw "Can't find sound $($entry.Key) in $($manifest.soundsFile)." }
			$text = $text.Substring(0, $match.Index) + $match.Groups[1].Value + '"rbxassetid://' + $entry.Value + '"' + $text.Substring($match.Index + $match.Length)
		}
		if ($text -ne $before) {
			if (-not $DryRun) { Write-Utf8 $soundsPath $text }
			Say "$($manifest.soundsFile): $($state.sounds.Count) sound ids"
		} else {
			Say "$($manifest.soundsFile): nothing new"
		}
	}

	$place = $PlaceFile
	if ((Has "build") -and -not $PlaceFile) {
		Heading "build"
		$place = In-Root "publish/$($manifest.placeFile)"
		if ($DryRun) {
			Say "would run: rojo build default.project.json -o publish\$($manifest.placeFile)"
		} else {
			if (-not (Get-Command rojo -ErrorAction SilentlyContinue)) {
				throw "Rojo isn't installed. Run 'rokit install' in the game's folder (rokit.toml pins Rojo 7.7.1), or build the place elsewhere and pass -PlaceFile."
			}
			& rojo build (In-Root "default.project.json") -o $place
			if ($LASTEXITCODE -ne 0) { throw "rojo build failed." }
			Say "Built $place"
		}
	}

	if (Has "settings") {
		Heading "settings"
		$placeBody = [ordered]@{
			displayName = $manifest.place.displayName
			description = $manifest.place.description
			serverSize = [int]$manifest.place.serverSize
		}
		$deviceBody = [ordered]@{}
		foreach ($entry in $manifest.devices.PSObject.Properties) { $deviceBody[$entry.Name] = [bool]$entry.Value }
		if ($DryRun) {
			Say "would set name '$($placeBody.displayName)', server size $($placeBody.serverSize), devices: $(($deviceBody.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key -replace 'Enabled$', '' }) -join ', ')"
		} else {
			$file = Text-File "place.json" (ConvertTo-Json -InputObject $placeBody)
			$r = Invoke-Api "PATCH" "/cloud/v2/universes/$UniverseId/places/${PlaceId}?updateMask=displayName,description,serverSize" `
				@("-H", "Content-Type: application/json", "--data-binary", "@$file")
			if ($r.Status -eq 200) { Say "Name, description and server size ($($placeBody.serverSize)) set." }
			else { Write-Warning "Couldn't set the name, description and server size; set them on the Creator Hub. $(Fail-Text $r)" }
			$mask = ($deviceBody.Keys | ForEach-Object { $_ }) -join ","
			$file = Text-File "universe.json" (ConvertTo-Json -InputObject $deviceBody)
			$r = Invoke-Api "PATCH" "/cloud/v2/universes/${UniverseId}?updateMask=$mask" @("-H", "Content-Type: application/json", "--data-binary", "@$file")
			if ($r.Status -eq 200) { Say "Devices set." }
			else { Write-Warning "Couldn't set the devices; tick them on the Creator Hub. $(Fail-Text $r)" }
		}
	}

	if (Has "publish") {
		Heading "publish"
		if (-not $place) { $place = In-Root "publish/$($manifest.placeFile)" }
		if ($DryRun) {
			Say "would publish $place as the live version of place $PlaceId"
		} else {
			if (-not (Test-Path $place)) { throw "No place file at $place. Run the build step or pass -PlaceFile." }
			$r = Invoke-Api "POST" "/universes/v1/$UniverseId/places/$PlaceId/versions?versionType=Published" `
				@("-H", "Content-Type: application/octet-stream", "--data-binary", "@$place")
			if ($r.Status -ne 200 -or -not $r.Body.versionNumber) { throw "Roblox didn't take the place file. $(Fail-Text $r)" }
			$state.versions = @($state.versions) + @([ordered]@{ version = $r.Body.versionNumber; at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") })
			Save-State
			Say "Published version $($r.Body.versionNumber). Players get it in new servers."
		}
	}

	Heading "ids"
	foreach ($group in @("passes", "products", "sounds")) {
		foreach ($entry in $state[$group].GetEnumerator()) { Say "$($entry.Key) $($entry.Value)" }
	}
	Say ""
	if ($DryRun) { Say "Dry run: nothing was sent to Roblox and no file changed." } else { Say "Saved in $statePath" }
	$left = @($soundList | Where-Object { -not $state.sounds.Contains($_.name) }).Count
	if ($left -gt 0) { Say "$left sound(s) still to upload: run the script again later with -Steps sounds,wire,build,publish." }
} finally {
	Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
