-- Each role's ability (Config/Roles), on Q or the ability button. The server
-- checks the cooldown, which it keeps in the player's "AbilityReady"
-- attribute (a server time) so the button can count down.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Lib = script.Parent.Parent.Lib
local Net = require(Lib.Net)
local BuildService = require(script.Parent.BuildService)
local GameLoop = require(script.Parent.GameLoop)
local PlayerService = require(script.Parent.PlayerService)

local AbilityService = {}

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function others(player: Player, radius: number, frozen: boolean): { Player }
	local root = Net.root(player)
	local found = {}
	if not root then
		return found
	end
	for _, other in Players:GetPlayers() do
		local otherRoot = Net.root(other)
		if
			otherRoot
			and PlayerService.isFrozen(other) == frozen
			and flat(root.Position, otherRoot.Position) <= radius
		then
			table.insert(found, other)
		end
	end
	return found
end

local function onAbility(player: Player)
	local role = PlayerService.role(player)
	if not role or not GameLoop.isPlaying() or PlayerService.isFrozen(player) then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now < (player:GetAttribute("AbilityReady") or 0) then
		return
	end
	local root = Net.root(player)
	if not root then
		return
	end
	local ability = role.Ability
	local position = root.Position
	local used = true
	if ability.Id == "Flare" then
		Net.fx(
			"Flare",
			{ Player = player.UserId, Position = position, Radius = ability.Radius, Seconds = ability.Seconds }
		)
	elseif ability.Id == "QuickFix" then
		local count = BuildService.repairNear(position, ability.Radius :: number, ability.Amount :: number)
		if count == 0 then
			Net.notice(player, "Nothing near you needs fixing.", "Info")
			used = false
		else
			Net.notice(player, `Quick Fix patched up {count} buildings!`, "Good")
		end
	elseif ability.Id == "Cocoa" then
		for _, other in others(player, ability.Radius :: number, false) do
			PlayerService.warm(other, ability.Amount :: number)
			if other ~= player then
				Net.notice(other, `{player.DisplayName} poured you some hot cocoa!`, "Good")
			end
		end
		Net.fx("Cocoa", { Position = position, Radius = ability.Radius })
	elseif ability.Id == "Volley" then
		PlayerService.startVolley(player, ability.Amount :: number)
		Net.fx("Volley", { Player = player.UserId })
	elseif ability.Id == "HeatPack" then
		local thawed = others(player, ability.Radius :: number, true)
		if #thawed == 0 then
			Net.notice(player, "No frozen friends nearby.", "Info")
			used = false
		end
		for _, other in thawed do
			PlayerService.thaw(other, player)
		end
		if #thawed > 0 then
			Net.fx("HeatPack", { Position = position, Radius = ability.Radius })
		end
	end
	if used then
		player:SetAttribute("AbilityReady", now + ability.Cooldown)
	end
end

function AbilityService.init()
	Net.remote("Ability").OnServerEvent:Connect(onAbility)
	GameLoop.onPhase(function(phase)
		if phase == "Intermission" then
			for _, player in Players:GetPlayers() do
				player:SetAttribute("AbilityReady", 0)
			end
		end
	end)
end

return AbilityService
