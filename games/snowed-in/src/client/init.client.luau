-- Client entry point. The client draws the HUD and the guide, the corner
-- notes, the menus, build mode's preview, the monsters (from the server's
-- snapshots), the effects and sounds, the sky, the pets and the rescue
-- train. It never decides anything: gathering, building, crafting, hits,
-- warmth, purchases and rewards are all the server's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local BuildMode = require(script.BuildMode)
local Corner = require(script.Corner)
local Diagnostics = require(script.Diagnostics)
local Effects = require(script.Effects)
local Guide = require(script.Guide)
local Hud = require(script.Hud)
local Markers = require(script.Markers)
local Menus = require(script.Menus)
local MonsterView = require(script.MonsterView)
local Pets = require(script.Pets)
local Prompts = require(script.Prompts)
local Results = require(script.Results)
local Settings = require(script.Settings)
local Sky = require(script.Sky)
local Sounds = require(script.Sounds)
local UI = require(script.UI)
local Weapons = require(script.Weapons)

-- The game has its own health-free survival HUD; hide Roblox's health bar.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

UI.mount()
Sounds.start()
Settings.onChanged(function(values)
	if values.Music ~= Sounds.musicOn() then
		Sounds.setMusic(values.Music)
	end
	Sounds.setEffects(values.Sfx)
end)
Settings.start()
Diagnostics.start()
Corner.mount()
Hud.mount()
Guide.mount()
MonsterView.start()
Effects.start()
Weapons.start()
BuildMode.mount()
Menus.mount()
Results.mount()
Markers.start()
Pets.start()
Prompts.start()
Sky.start()

local remotes = ReplicatedStorage:WaitForChild("Remotes")
remotes:WaitForChild("Notice").OnClientEvent:Connect(function(text, kind)
	if type(text) ~= "string" then
		return
	end
	if kind == "Big" then
		Corner.banner(text)
	else
		Corner.note(text, kind)
		if kind == "Bad" then
			Sounds.play("Deny")
		else
			Sounds.play("Notice")
		end
	end
end)
