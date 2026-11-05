-- Gives each player one of the cabins round the hearth while they are in
-- the server, with their name on it and the decorations they chose
-- (shared/World/CabinDecor), which stay with their save from run to run.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CabinDecor = require(ReplicatedStorage.Shared.World.CabinDecor)
local DataService = require(script.Parent.DataService)
local ProfileService = require(script.Parent.ProfileService)
local WorldService = require(script.Parent.WorldService)

local CabinService = {}

local owners: { [number]: Player } = {}

local function nameplate(cabin: Model, text: string)
	local plate = cabin:FindFirstChild("NamePlate")
	local label = plate and plate:FindFirstChild("Owner", true) :: TextLabel?
	if label then
		label.Text = text
	end
end

local function cabinOf(player: Player): (number?, Model?)
	for index, owner in owners do
		if owner == player then
			return index, WorldService.get().Cabins[index]
		end
	end
	return nil, nil
end

local function dressCabin(player: Player)
	local _, cabin = cabinOf(player)
	local save = DataService.get(player)
	if cabin and save then
		CabinDecor.apply(cabin, save.Cabin)
	end
end

local function assign(player: Player)
	if cabinOf(player) then
		return
	end
	for index, cabin in WorldService.get().Cabins do
		if not owners[index] then
			owners[index] = player
			player:SetAttribute("Cabin", index)
			cabin:SetAttribute("Owner", player.UserId)
			nameplate(cabin, `{player.DisplayName}'s Cabin`)
			dressCabin(player)
			return
		end
	end
end

local function release(player: Player)
	local index, cabin = cabinOf(player)
	if index and cabin then
		owners[index] = nil
		cabin:SetAttribute("Owner", 0)
		nameplate(cabin, "Free cabin")
		CabinDecor.apply(cabin, {})
	end
end

function CabinService.init()
	for _, cabin in WorldService.get().Cabins do
		CabinDecor.apply(cabin, {})
	end
	DataService.onLoaded(function(player)
		assign(player)
	end)
	ProfileService.onChanged(dressCabin)
	Players.PlayerRemoving:Connect(release)
end

return CabinService
