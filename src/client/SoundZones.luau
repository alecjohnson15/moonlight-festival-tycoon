-- Picks the ambience for where the player is. The theme marks places with
-- invisible boxes tagged SoundZone, each naming the sound to play inside in
-- its Ambience attribute: the festival's crowd, the graveyard's choir, the
-- arena's drums. Where boxes overlap the higher Priority wins, then the
-- smaller box; outside them all the general ambience plays. A box's place
-- is kept once seen, so one that streams out still counts.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Sounds = require(script.Parent.Sounds)

local CHECK_EVERY = 0.5
local GENERAL = "Ambience"

type Zone = { CFrame: CFrame, Half: Vector3, Ambience: string, Priority: number, Volume: number }

local SoundZones = {}

local zones: { [Instance]: Zone } = {}

local function add(part: Instance)
	local ambience = part:GetAttribute("Ambience")
	if not part:IsA("BasePart") or type(ambience) ~= "string" or zones[part] then
		return
	end
	local size = part.Size
	zones[part] = {
		CFrame = part.CFrame,
		Half = size / 2,
		Ambience = ambience,
		Priority = part:GetAttribute("Priority") or 0,
		Volume = size.X * size.Y * size.Z,
	}
end

-- The ambience to play at position.
local function ambienceAt(position: Vector3): string
	local best: Zone? = nil
	for _, zone in zones do
		local offset = zone.CFrame:PointToObjectSpace(position)
		local half = zone.Half
		if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
			if
				not best
				or zone.Priority > best.Priority
				or (zone.Priority == best.Priority and zone.Volume < best.Volume)
			then
				best = zone
			end
		end
	end
	return if best then best.Ambience else GENERAL
end

function SoundZones.start()
	for _, part in CollectionService:GetTagged("SoundZone") do
		add(part)
	end
	CollectionService:GetInstanceAddedSignal("SoundZone"):Connect(add)

	task.spawn(function()
		while true do
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				Sounds.setAmbience(ambienceAt(root.Position))
			end
			task.wait(CHECK_EVERY)
		end
	end)
end

return SoundZones
