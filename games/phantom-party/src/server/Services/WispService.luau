-- The plaza's wisp hunt (Rules/Wisps): something to do for anyone not
-- standing in the round. While a round plays, a few glowing wisps float at
-- the plaza's Wisps spots; touching one catches it, it comes back elsewhere
-- a few seconds later, and the moon over the fountain grows brighter. Every
-- Wisps.Goal caught together sets off fireworks over the plaza. It pays no
-- coins or XP (only a count in the player's stats), and nothing here
-- reaches the round.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Game = require(Shared.Config.Game)
local Wisps = require(Shared.Rules.Wisps)
local Match = require(script.Parent.Parent.Lib.Match)
local DataService = require(script.Parent.DataService)
local LobbyService = require(script.Parent.LobbyService)

local Fx = ReplicatedStorage.Remotes.Fx :: RemoteEvent

local WispService = {}

local spots: { BasePart } = {}
local folder: Folder? = nil
local moon: Part? = nil
local count = 0
local generation = 0
local random = Random.new()

-- Everyone in the plaza right now (not standing in a round).
local function plaza(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if Wisps.canCatch(Match.chatState(player)) then
			table.insert(list, player)
		end
	end
	return list
end

local function setMoon()
	if moon then
		local size = 3 + count * 0.6
		moon.Size = Vector3.new(size, size, size)
		local light = moon:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 0.5 + count * 0.4
		end
	end
end

local function freeSpot(): BasePart?
	local taken = {}
	for _, wisp in (folder :: Folder):GetChildren() do
		taken[wisp:GetAttribute("Spot")] = true
	end
	local free = {}
	for index in spots do
		if not taken[index] then
			table.insert(free, index)
		end
	end
	if #free == 0 then
		return nil
	end
	local index = free[random:NextInteger(1, #free)]
	local spot = spots[index]
	spot:SetAttribute("Index", index)
	return spot
end

local function catch(player: Player, position: Vector3)
	local data = DataService.get(player)
	if data then
		data.Stats.Wisps += 1
	end
	local celebrate
	count, celebrate = Wisps.add(count)
	setMoon()
	for _, other in plaza() do
		Fx:FireClient(other, "Wisp", position, count, Wisps.Goal, celebrate)
	end
end

local function spawnWisp(round: number)
	if not folder or round ~= generation then
		return
	end
	local spot = freeSpot()
	if not spot then
		return
	end
	local wisp = Instance.new("Part")
	wisp.Name = "Wisp"
	wisp.Shape = Enum.PartType.Ball
	wisp.Size = Vector3.new(1.6, 1.6, 1.6)
	wisp.Material = Enum.Material.Neon
	wisp.Color = Color3.fromRGB(180, 230, 255)
	wisp.Transparency = 0.2
	wisp.Anchored = true
	wisp.CanCollide = false
	wisp.CanQuery = false
	wisp.CFrame = spot.CFrame
	wisp:SetAttribute("Spot", spot:GetAttribute("Index"))
	wisp:AddTag("Wisp")
	local light = Instance.new("PointLight")
	light.Color = wisp.Color
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = wisp
	local taken = false
	wisp.Touched:Connect(function(part)
		if taken then
			return
		end
		local character = part:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or not Wisps.canCatch(Match.chatState(player)) then
			return
		end
		taken = true
		local position = wisp.Position
		wisp:Destroy()
		catch(player, position)
		task.delay(random:NextNumber(Wisps.Respawn[1], Wisps.Respawn[2]), spawnWisp, round)
	end)
	wisp.Parent = folder
end

local function begin()
	generation += 1
	if folder then
		folder:ClearAllChildren()
	end
	for _ = 1, Wisps.Out do
		spawnWisp(generation)
	end
end

local function finish()
	generation += 1
	if folder then
		folder:ClearAllChildren()
	end
end

function WispService.init()
	Match.on("State", function(state)
		if state == "Playing" then
			begin()
		elseif state ~= "Reveal" then
			finish()
		end
	end)
end

function WispService.start()
	local lobby = LobbyService.model()
	local found = lobby and lobby:FindFirstChild("Wisps")
	if not lobby or not found then
		return
	end
	for _, spot in found:GetChildren() do
		if spot:IsA("BasePart") then
			table.insert(spots, spot)
		end
	end
	local holder = Instance.new("Folder")
	holder.Name = "WispHunt"
	holder.Parent = lobby
	folder = holder
	local at = Game.LobbyOrigin
	local orb = Instance.new("Part")
	orb.Name = "WispMoon"
	orb.Shape = Enum.PartType.Ball
	orb.Material = Enum.Material.Neon
	orb.Color = Color3.fromRGB(200, 235, 255)
	orb.Transparency = 0.25
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CFrame = CFrame.new(at[1], at[2] + 30, at[3])
	local light = Instance.new("PointLight")
	light.Color = orb.Color
	light.Range = 40
	light.Parent = orb
	orb.Parent = lobby
	moon = orb
	setMoon()
	if Match.State == "Playing" then
		begin()
	end
end

return WispService
