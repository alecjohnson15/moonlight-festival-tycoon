-- What the server's events look like on this client: blaster beams, the
-- Phantom's thrown blade flying, knockout bursts in the attacker's chosen
-- effect, revive sparkles, coins and pages being picked up, a page torn up,
-- the Saboteur's blackout (when the Phantom alone sees everyone's outline)
-- and the Truth Bell lighting the Phantom up. Also spins stars over anyone
-- who's dazed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Gear = require(Shared.Look.Gear)
local Atmosphere = require(script.Parent.Atmosphere)
local Corner = require(script.Parent.Corner)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx") :: RemoteEvent

local Effects = {}

local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "Effects"
folder.Parent = Workspace
local flights: { [number]: { Model: Model, Landed: Vector3? } } = {}

local function part(props: { [string]: any }): Part
	local made = Instance.new("Part")
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Material = Enum.Material.Neon
	for key, value in props do
		(made :: any)[key] = value
	end
	made.Parent = folder
	return made
end

local function fade(item: BasePart, seconds: number, grow: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	TweenService:Create(item, TweenInfo.new(seconds), goal):Play()
	task.delay(seconds + 0.05, function()
		item:Destroy()
	end)
end

local function lookOf(itemId: string?): { [string]: any }
	local item = itemId and Items.get(itemId)
	return if item then item.Look else {}
end

-- A blaster's beam, from the muzzle to wherever it hit.
local function beam(from: Vector3, to: Vector3, skin: string?)
	local look = lookOf(skin)
	local color = Color3.fromHex(look.Beam or "#BFE3FF")
	local length = (to - from).Magnitude
	local ray = part({
		Size = Vector3.new(0.35, 0.35, length),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = color,
		Transparency = 0.1,
	})
	fade(ray, 0.35, Vector3.new(0.05, 0.05, length))
	local flash = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, CFrame = CFrame.new(to), Color = color })
	fade(flash, 0.3, Vector3.one * 3)
	Sounds.play("Zap", from)
end

-- The thrown blade: flies straight, spinning, until the server says where
-- it landed, then fades.
local function throwStart(id: number, start: Vector3, direction: Vector3, speed: number, range: number, skin: string?)
	local ok, model = pcall(Gear.bladeModel, skin or "blade_shadow")
	if not ok then
		return
	end
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored = true
			piece.CanCollide = false
			piece.CanQuery = false
		end
	end
	model.Parent = folder
	local pieces = {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			table.insert(pieces, { Part = piece, Offset = piece.CFrame })
		end
	end
	local flight = { Model = model, Landed = nil :: Vector3? }
	flights[id] = flight
	Sounds.play("Throw", start)
	local travelled = 0
	local spin = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		travelled += speed * dt
		spin += dt * 20
		local limit = range
		if flight.Landed then
			limit = math.min(range, (flight.Landed - start).Magnitude)
		end
		local position = start + direction * math.min(travelled, limit)
		local frame = CFrame.lookAt(position, position + direction)
			* CFrame.Angles(-math.pi / 2, 0, 0)
			* CFrame.Angles(spin, 0, 0)
		for _, entry in pieces do
			entry.Part.CFrame = frame * entry.Offset
		end
		if (flight.Landed and travelled >= limit) or travelled > range + 30 then
			connection:Disconnect()
			flights[id] = nil
			task.delay(0.3, function()
				model:Destroy()
			end)
		end
	end)
end

local function throwEnd(id: number, landed: Vector3)
	local flight = flights[id]
	if flight then
		flight.Landed = landed
	end
end

-- A knockout: pieces of the attacker's effect fly out of a flash.
local function burst(position: Vector3, effectId: string?)
	local look = lookOf(effectId or "fx_poof")
	local style = look.Style or "smoke"
	local colors = look.Colors or { "#D8D2E8" }
	local flash = part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		CFrame = CFrame.new(position),
		Color = Color3.fromHex(colors[1]),
		Transparency = 0.2,
	})
	fade(flash, 0.4, Vector3.one * 8)
	Sounds.play("Tag", position)
	local random = Random.new()
	for index = 1, 14 do
		local ok, piece = pcall(Gear.burstPiece, style, colors, index)
		if ok then
			local velocity = Vector3.new(
				random:NextNumber(-1, 1),
				random:NextNumber(0.6, 1.4),
				random:NextNumber(-1, 1)
			).Unit * random:NextNumber(10, 22)
			local turn = CFrame.Angles(random:NextNumber(0, 6), random:NextNumber(0, 6), 0)
			local partsOf = {}
			for _, inside in piece:GetDescendants() do
				if inside:IsA("BasePart") then
					inside.Anchored = true
					inside.CanCollide = false
					inside.CanQuery = false
					table.insert(partsOf, { Part = inside, Offset = inside.CFrame })
				end
			end
			piece.Parent = folder
			local floaty = style == "bubbles" or style == "ghosts" or style == "smoke"
			local life = 0
			local connection
			connection = RunService.RenderStepped:Connect(function(dt)
				life += dt
				velocity += Vector3.new(0, if floaty then 4 else -40, 0) * dt
				local at = position + velocity * life
				local frame = CFrame.new(at) * turn * CFrame.Angles(life * 6, life * 4, 0)
				for _, entry in partsOf do
					entry.Part.CFrame = frame * entry.Offset
					entry.Part.Transparency = math.max(entry.Part.Transparency, life / 1.1)
				end
				if life > 1.1 then
					connection:Disconnect()
					piece:Destroy()
				end
			end)
		end
	end
end

local function sparkleRing(position: Vector3, color: Color3, count: number)
	for index = 1, count do
		local angle = index / count * math.pi * 2
		local dot = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 2, -1, math.sin(angle) * 2)),
			Color = color,
		})
		TweenService:Create(dot, TweenInfo.new(0.8), {
			CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 3, 3, math.sin(angle) * 3)),
			Transparency = 1,
		}):Play()
		task.delay(0.85, function()
			dot:Destroy()
		end)
	end
end

-- Highlights ---------------------------------------------------------------

local function outline(character: Instance, color: Color3, fill: number, seconds: number)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = fill
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = folder
	task.delay(seconds, function()
		highlight:Destroy()
	end)
end

local function blackout(seconds: number, seeAll: boolean)
	Atmosphere.blackout(seconds)
	Sounds.play("Blackout")
	if seeAll then
		local round = Workspace:FindFirstChild("Round")
		for _, other in Players:GetPlayers() do
			if other ~= player and other.Character and other.Character:GetAttribute("Pid") then
				outline(other.Character, Color3.fromRGB(255, 77, 109), 1, seconds)
			end
		end
		if round then
			for _, model in round:GetDescendants() do
				if model:IsA("Model") and model:GetAttribute("Dummy") then
					outline(model, Color3.fromRGB(255, 77, 109), 1, seconds)
				end
			end
		end
		Corner.note("Lights out!", "You can see everyone's outline. Strike now!", Color3.fromRGB(255, 77, 109), 5)
	elseif State.Round.InRound then
		Corner.note("Lights out!", "Someone cut the lights. Stay close to the others.", Ui.Colors.Accent, 5)
	end
end

local function reveal(character: Instance?, seconds: number)
	if not character then
		return
	end
	outline(character, Color3.fromRGB(255, 77, 109), 0.4, seconds)
	-- A word as well as a colour, for anyone who can't tell red apart.
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(130, 34)
		tag.StudsOffset = Vector3.new(0, 3.4, 0)
		tag.AlwaysOnTop = true
		tag.Adornee = head
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = "PHANTOM!"
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeColor3 = Color3.fromRGB(120, 0, 30)
		label.TextStrokeTransparency = 0
		label.Parent = tag
		tag.Parent = folder
		task.delay(seconds, function()
			tag:Destroy()
		end)
	end
	Sounds.play("Bell")
	Corner.note("The Truth Bell rings!", "The Phantom is glowing red. Look!", Color3.fromRGB(255, 77, 109), 6)
end

-- Dazed stars -------------------------------------------------------------

local stars: { [Model]: BillboardGui } = {}

local function syncStars()
	local seen = {}
	local function check(model: Model)
		if model:GetAttribute("Dazed") then
			seen[model] = true
			if not stars[model] then
				local head = model:FindFirstChild("Head")
				if head then
					local gui = Instance.new("BillboardGui")
					gui.Size = UDim2.fromOffset(70, 30)
					gui.StudsOffset = Vector3.new(0, 2.2, 0)
					gui.AlwaysOnTop = false
					gui.Adornee = head
					local label = Instance.new("TextLabel")
					label.Name = "Stars"
					label.BackgroundTransparency = 1
					label.Size = UDim2.fromScale(1, 1)
					label.Text = "★  ★  ★"
					label.TextScaled = true
					label.Font = Enum.Font.FredokaOne
					label.TextColor3 = Color3.fromRGB(255, 225, 90)
					label.TextStrokeTransparency = 0.4
					label.Parent = gui
					gui.Parent = folder
					stars[model] = gui
				end
			end
		end
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			check(other.Character)
		end
	end
	local round = Workspace:FindFirstChild("Round")
	if round then
		for _, model in round:GetDescendants() do
			if model:IsA("Model") and model:GetAttribute("Dummy") then
				check(model)
			end
		end
	end
	for model, gui in stars do
		if not seen[model] then
			gui:Destroy()
			stars[model] = nil
		end
	end
end

-- Events ------------------------------------------------------------------

local handlers = {}

handlers.Beam = beam
handlers.Throw = throwStart
handlers.ThrowEnd = throwEnd

function handlers.Burst(position: Vector3, effectId: string?, how: string?)
	burst(position, effectId)
	if how == "Misfire" then
		Sounds.play("Misfire", position)
	end
end

-- Someone else's swing nearby (the server never says whose).
function handlers.Swing(position: Vector3)
	Sounds.play("Swing", position)
end

-- A blade drawn close by: the warning before a tag.
function handlers.Draw(position: Vector3)
	Sounds.play("Draw", position)
end

function handlers.Revive(position: Vector3)
	sparkleRing(position, Color3.fromRGB(77, 255, 154), 10)
	Sounds.play("Revive", position)
end

function handlers.Coin(position: Vector3, count: number, cap: number)
	sparkleRing(position, Ui.Colors.Gold, 5)
	Sounds.play("Coin", nil, 1 + math.min(count, 20) * 0.01)
	if count == cap then
		Corner.note("Coin pouch full!", `You've got {cap} candy coins this round.`, Ui.Colors.Gold, 4)
	end
end

function handlers.Page(position: Vector3, mine: boolean)
	sparkleRing(position, Color3.fromRGB(180, 220, 255), 6)
	Sounds.play("Page", position)
	if mine then
		Corner.note("Clue page!", "The Truth Bell is filling up.", Color3.fromRGB(180, 220, 255), 3)
	end
end

function handlers.Torn(position: Vector3)
	Sounds.play("Torn", position)
	for index = 1, 8 do
		local shred = part({
			Size = Vector3.new(0.4, 0.05, 0.5),
			CFrame = CFrame.new(position) * CFrame.Angles(index, index * 2, 0),
			Color = Color3.fromRGB(255, 244, 214),
			Material = Enum.Material.SmoothPlastic,
		})
		TweenService:Create(shred, TweenInfo.new(1.2), {
			CFrame = CFrame.new(position + Vector3.new(math.cos(index) * 3, -1.5, math.sin(index) * 3))
				* CFrame.Angles(index * 3, 0, index),
			Transparency = 1,
		}):Play()
		task.delay(1.3, function()
			shred:Destroy()
		end)
	end
end

handlers.Blackout = blackout
handlers.Reveal = reveal

-- A wisp caught in the plaza; every Goal together sets off fireworks.
function handlers.Wisp(position: Vector3, count: number, goal: number, celebrate: boolean)
	sparkleRing(position, Color3.fromRGB(180, 230, 255), 6)
	Sounds.play("Pop", position)
	State.fire("Wisp", count, goal)
	if celebrate then
		Sounds.play("Fanfare")
		Corner.note("The plaza moon is glowing!", "Everyone in the plaza caught the wisps together.", Ui.Colors.Gold, 5)
		local moon = Vector3.new(0, 30, 0)
		for index = 1, 8 do
			task.delay(index * 0.25, function()
				local spot = moon + Vector3.new(math.random(-24, 24), math.random(-4, 10), math.random(-24, 24))
				sparkleRing(spot, Color3.fromHSV(math.random(), 0.6, 1), 10)
			end)
		end
	end
end

function handlers.Notice(text: string)
	Corner.note(text, nil, Ui.Colors.Gold, 5)
end

-- Shared with the emotes.
Effects.part = part
Effects.fade = fade
Effects.burst = burst
Effects.sparkleRing = sparkleRing

-- Footprints and torn pages fade on each client as they age.
local function fadeFootprint(mark: Instance)
	if not mark:IsA("BasePart") then
		return
	end
	local seconds = mark:GetAttribute("Fade")
	if typeof(seconds) == "number" then
		TweenService:Create(mark, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
		}):Play()
	end
end

function Effects.start()
	CollectionService:GetInstanceAddedSignal("Footprint"):Connect(fadeFootprint)
	for _, mark in CollectionService:GetTagged("Footprint") do
		fadeFootprint(mark)
	end
	Fx.OnClientEvent:Connect(function(kind, ...)
		local handler = handlers[kind]
		if handler then
			handler(...)
		end
	end)
	local elapsed = 0
	local spin = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		spin += dt * 120
		if elapsed > 0.25 then
			elapsed = 0
			syncStars()
		end
		for _, gui in stars do
			local label = gui:FindFirstChild("Stars") :: TextLabel?
			if label then
				label.Rotation = math.sin(math.rad(spin)) * 12
			end
		end
	end)
end

return Effects
