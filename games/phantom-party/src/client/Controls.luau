-- The player's moves in a round, on keys and on buttons:
--   Phantom:   1 draws or hides the blade, click tags, E throws.
--   Guardian:  1 draws or hides the blaster, click zaps where you aim.
--   Saboteur:  F cuts the lights.
--   Medic:     hold E beside a dazed guest to revive them.
-- On a phone the same moves are buttons beside the jump button, and the
-- blaster aims where the camera looks. Every move is only a request; the
-- server decides what happens.
--
-- Also opens the right panel when a lobby shop's prompt is used, and hides
-- prompts that aren't for this player's role (the dropped blaster from the
-- Shadows, revives from everyone but the Medic).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.Combat)
local Roles = require(Shared.Config.Roles)
local Hud = require(script.Parent.Hud)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Action = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Action") :: RemoteEvent

local Controls = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local gui = Ui.screen("Controls", 2)
local bar = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(0, 64),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
Ui.list(bar, 8, true).VerticalAlignment = Enum.VerticalAlignment.Bottom
Ui.fitScale(bar)
local hint = Ui.label(gui, "", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -84),
	Size = UDim2.fromOffset(420, 18),
	TextSize = 13,
	TextColor3 = Ui.Colors.Dim,
	TextStrokeTransparency = 0.5,
	Visible = false,
})

type Slot = { Button: TextButton, Shade: Frame, Key: TextLabel, ReadyAt: number, Length: number }
local slots: { [string]: Slot } = {}

local function slot(name: string, text: string, key: string, color: Color3, order: number, press: () -> ()): Slot
	local button = Ui.button(bar, text, color, {
		Size = UDim2.fromOffset(84, 56),
		TextSize = 14,
		LayoutOrder = order,
		Visible = false,
	})
	Ui.stroke(button, Color3.fromRGB(20, 12, 30), 2)
	local shade = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = 2,
	}, button)
	Ui.round(shade, 8)
	local keyLabel = Ui.label(button, key, {
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.fromOffset(30, 12),
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 3,
	})
	button.Activated:Connect(press)
	local made = { Button = button, Shade = shade, Key = keyLabel, ReadyAt = 0, Length = 1 }
	slots[name] = made
	return made
end

local function root(): BasePart?
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

-- Where the player is aiming: the mouse on a computer, the middle of the
-- screen on a phone.
local function aimPoint(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	if not Ui.isTouch() then
		return mouse.Hit.Position
	end
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y * 0.45)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * 500
end

local function kit()
	return State.Kit
end

local function toggleDraw()
	if not State.playing() then
		return
	end
	local current = kit()
	if not current.Blade and not current.Blaster then
		return
	end
	if current.Drawn then
		Action:FireServer("Holster")
	else
		if current.Blade and State.left(current.BladeFrom or 0) > 0 then
			return
		end
		Action:FireServer("Draw")
		Sounds.play("Draw")
	end
end

local function swing()
	local part = root()
	if not part or kit().Drawn ~= "Blade" then
		return
	end
	Action:FireServer("Swing", part.CFrame.LookVector)
	Sounds.play("Swing", part.Position)
end

local function throw()
	local part = root()
	local target = aimPoint()
	if not part or not target or kit().Drawn ~= "Blade" or kit().Throwing then
		return
	end
	if State.left(kit().ThrowReady or 0) > 0 then
		return
	end
	local direction = target - (part.Position + Vector3.new(0, 1, 0))
	Action:FireServer("Throw", part.Position, direction)
end

local function zap()
	local part = root()
	local target = aimPoint()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not part or not target or kit().Drawn ~= "Blaster" then
		return
	end
	if State.left(kit().ShotReady or 0) > 0 then
		Sounds.play("Deny")
		return
	end
	local from = if head and head:IsA("BasePart") then head.Position else part.Position
	Action:FireServer("Fire", from, target - from)
end

local function blackout()
	if (kit().Blackouts or 0) <= 0 or State.left(kit().BlackoutReady or 0) > 0 then
		return
	end
	Action:FireServer("Blackout")
end

local function use()
	local drawn = kit().Drawn
	if drawn == "Blade" then
		swing()
	elseif drawn == "Blaster" then
		zap()
	end
end

slot("Draw", "Draw", "1", Ui.Colors.Accent, 1, toggleDraw)
slot("Use", "Tag", "Click", Ui.Colors.Bad, 2, use)
slot("Throw", "Throw", "E", Color3.fromRGB(255, 120, 60), 3, throw)
slot("Blackout", "Lights out", "F", Color3.fromRGB(120, 80, 200), 4, blackout)

local function refresh()
	local current = kit()
	local role = State.Role
	local playing = State.playing()
	local blade = current.Blade == true
	local blaster = current.Blaster == true
	local drawn = current.Drawn
	slots.Draw.Button.Visible = playing and (blade or blaster)
	slots.Draw.Button.Text = if drawn then "Hide" elseif blade then "Blade" else "Blaster"
	slots.Use.Button.Visible = playing and drawn ~= nil
	slots.Use.Button.Text = if drawn == "Blaster" then "Zap" else "Tag"
	slots.Use.Key.Text = if Ui.isTouch() then "" else "Click"
	slots.Throw.Button.Visible = playing and drawn == "Blade"
	slots.Blackout.Button.Visible = playing and role == "Saboteur"
	slots.Blackout.Button.Text = `Lights out x{current.Blackouts or 0}`
	slots.Draw.ReadyAt, slots.Draw.Length = current.BladeFrom or 0, 8
	slots.Throw.ReadyAt, slots.Throw.Length = current.ThrowReady or 0, CombatConfig.Throw.Cooldown
	slots.Use.ReadyAt, slots.Use.Length =
		if drawn == "Blaster" then current.ShotReady or 0 else 0, CombatConfig.Blaster.Cooldown
	slots.Blackout.ReadyAt, slots.Blackout.Length = current.BlackoutReady or 0, CombatConfig.Blackout.Cooldown
	bar.Visible = playing
	local text = ""
	if playing and role == "Medic" then
		text = `Hold E by a dazed guest to revive them ({current.Revives or 0} left)`
	elseif playing and role == "Guest" then
		text = "Grab clue pages to fill the Truth Bell. Stick together!"
	elseif playing and role == "Saboteur" then
		text = "Cut the lights so the Phantom can strike. You can't tag anyone."
	elseif playing and blade and State.left(current.BladeFrom or 0) > 0 then
		text = "Your blade is ready in a moment. Blend in!"
	end
	hint.Text = text
	hint.Visible = text ~= ""
	if Ui.isTouch() then
		bar.AnchorPoint = Vector2.new(1, 1)
		bar.Position = UDim2.new(1, -140, 1, -20)
	else
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0.5, 0, 1, -14)
	end
end

-- Prompts ----------------------------------------------------------------

local STATION_MENUS = { Shop = "Shop", Wardrobe = "Items", Crates = "Crates", Trade = "Trade", Pass = "Pass" }
local revivePrompts: { [Model]: ProximityPrompt } = {}

local function shadow(): boolean
	return State.Role ~= nil and Roles.team(State.Role) == "Shadows"
end

local function fixPrompt(prompt: ProximityPrompt)
	if prompt:GetAttribute("GuestsOnly") then
		prompt.Enabled = not shadow() and State.Me == "Alive"
	end
end

local function refreshPrompts()
	for _, prompt in Workspace:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			fixPrompt(prompt)
		end
	end
end

local function syncRevives()
	local wanted = State.Role == "Medic" and State.playing() and (kit().Revives or 0) > 0
	local round = Workspace:FindFirstChild("Round")
	local seen = {}
	if wanted and round then
		for _, model in round:GetDescendants() do
			if model:IsA("Model") and model:GetAttribute("Pid") and model:GetAttribute("Dazed") then
				seen[model] = true
				if not revivePrompts[model] then
					local part = model:FindFirstChild("HumanoidRootPart")
					if part then
						local prompt = Instance.new("ProximityPrompt")
						prompt.ActionText = "Revive"
						prompt.ObjectText = model.Name
						prompt.HoldDuration = CombatConfig.Revive.HoldSeconds
						prompt.MaxActivationDistance = CombatConfig.Revive.Range
						prompt.RequiresLineOfSight = false
						prompt.KeyboardKeyCode = Enum.KeyCode.E
						prompt.Triggered:Connect(function()
							Action:FireServer("Revive", model:GetAttribute("Pid"))
						end)
						prompt.Parent = part
						revivePrompts[model] = prompt
					end
				end
			end
		end
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if character and character:GetAttribute("Pid") and character:GetAttribute("Dazed") and other ~= player then
				seen[character] = true
				if not revivePrompts[character] then
					local part = character:FindFirstChild("HumanoidRootPart")
					if part then
						local prompt = Instance.new("ProximityPrompt")
						prompt.ActionText = "Revive"
						prompt.ObjectText = other.DisplayName
						prompt.HoldDuration = CombatConfig.Revive.HoldSeconds
						prompt.MaxActivationDistance = CombatConfig.Revive.Range
						prompt.RequiresLineOfSight = false
						prompt.KeyboardKeyCode = Enum.KeyCode.E
						prompt.Triggered:Connect(function()
							Action:FireServer("Revive", character:GetAttribute("Pid"))
						end)
						prompt.Parent = part
						revivePrompts[character] = prompt
					end
				end
			end
		end
	end
	for model, prompt in revivePrompts do
		if not seen[model] then
			prompt:Destroy()
			revivePrompts[model] = nil
		end
	end
end

function Controls.start()
	State.on("Kit", refresh)
	State.on("Role", function()
		refresh()
		refreshPrompts()
	end)
	State.on("Me", function()
		refresh()
		refreshPrompts()
	end)
	State.on("Round", refresh)
	Workspace.DescendantAdded:Connect(function(item)
		if item:IsA("ProximityPrompt") then
			fixPrompt(item)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local station = prompt:GetAttribute("Station")
		local menu = station and STATION_MENUS[station]
		if menu then
			Hud.open(menu)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not State.playing() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			use()
		elseif input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.Q then
			toggleDraw()
		elseif input.KeyCode == Enum.KeyCode.E then
			if kit().Drawn == "Blade" then
				throw()
			end
		elseif input.KeyCode == Enum.KeyCode.F then
			blackout()
		end
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		for _, each in slots do
			local left = State.left(each.ReadyAt)
			each.Shade.Size = UDim2.fromScale(1, math.clamp(left / math.max(each.Length, 0.1), 0, 1))
		end
		elapsed += dt
		if elapsed > 0.5 then
			elapsed = 0
			syncRevives()
		end
	end)
	refresh()
end

return Controls
