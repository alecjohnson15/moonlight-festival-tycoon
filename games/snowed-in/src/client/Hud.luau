-- The always-on screen: the night counter and the clock at the top middle,
-- with the hearth's flame and the radio's four parts under it; the team's
-- stockpile in the top left; and the player's own warmth, backpack, food
-- pocket and role ability in the bottom left (top left under the stockpile
-- on a phone, where the thumbstick lives). Being frozen tints the screen
-- ice blue with a countdown, and getting cold frosts its edges.
--
-- Everything here reads attributes the server keeps on
-- ReplicatedStorage.State (the run) and on the player (their survivor), so
-- the HUD can never disagree with the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Map = require(Shared.Config.Map)
local Recipes = require(Shared.Config.Recipes)
local Resources = require(Shared.Config.Resources)
local Roles = require(Shared.Config.Roles)
local Sounds = require(script.Parent.Sounds)
local UI = require(script.Parent.UI)

local State = ReplicatedStorage:WaitForChild("State") :: Configuration
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Hud = {}

local player = Players.LocalPlayer

local PART_ICONS = { Frozen = "🧊", Loose = "❗", Carried = "🏃", Fitted = "✅" }

local gui: ScreenGui
local clockTitle: TextLabel
local clockTime: TextLabel
local flameFill: Frame
local flameWords: TextLabel
local radioChips: { [string]: TextLabel } = {}
local radioWords: TextLabel
local stockLabels: { [string]: TextLabel } = {}
local pantryLabel: TextLabel
local warmthFill: Frame
local warmthWords: TextLabel
local packWords: TextLabel
local foodSlots: { TextButton } = {}
local abilityButton: TextButton
local abilityShade: Frame
local abilityWords: TextLabel
local roleBadge: TextLabel
local frozenCover: Frame
local frozenWords: TextLabel
local frost: { Frame } = {}
local buffWords: TextLabel
local playerPanel: Frame
local lastWarmth = 100

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function clockText(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- The words at the top: which night, and what the clock is counting to.
local function phaseWords(): (string, string)
	local phase = State:GetAttribute("Phase") or "Waiting"
	local night = State:GetAttribute("Night") or 0
	local ends = State:GetAttribute("PhaseEnds") or 0
	local left = if ends > 0 then clockText(ends - now()) else ""
	local nights = Balance.Nights
	local overtime = night > nights
	local count = if overtime then `OVERTIME · NIGHT {night}` else `NIGHT {math.max(night, 1)} OF {nights}`
	if phase == "Waiting" then
		return "SNOWED IN", "Waiting for players..."
	elseif phase == "Intermission" then
		return "PICK YOUR ROLE", `The run starts in {left}`
	elseif phase == "Day" then
		local title = if night == 0
			then "DAY 1"
			elseif overtime then `OVERTIME · DAY {night + 1}`
			else `DAY {night + 1}`
		return title, `Night falls in {left}`
	elseif phase == "Dusk" then
		return `NIGHT {night + 1} OF {nights}`, `The monsters come in {left}`
	elseif phase == "Night" then
		return count, `Dawn in {left}`
	elseif phase == "Dawn" then
		return `NIGHT {night} SURVIVED`, `Sunrise in {left}`
	elseif phase == "Rescue" then
		return "THE TRAIN IS HERE", "All aboard!"
	elseif phase == "Won" then
		return "RESCUED!", `Next run in {left}`
	elseif phase == "Lost" then
		return "SNOWED UNDER", `Next run in {left}`
	end
	return "SNOWED IN", ""
end

local function buildClock()
	local panel = UI.panel(gui, {
		Name = "Clock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(300, 84),
	})
	UI.scale(panel)
	clockTitle = UI.label(panel, "", {
		Font = UI.Title,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = UI.Colors.Text,
	})
	clockTime = UI.label(panel, "", {
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 27),
		Size = UDim2.new(1, 0, 0, 16),
		TextColor3 = UI.Colors.Ice,
	})
	local _, fill, words = UI.bar(panel, UI.Colors.Ember, {
		Position = UDim2.fromOffset(12, 46),
		Size = UDim2.new(1, -24, 0, 15),
	})
	flameFill, flameWords = fill, words
	local row = UI.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 63),
		Size = UDim2.new(1, -24, 0, 18),
	}, panel)
	radioWords = UI.label(row, "Radio 0/4", {
		TextSize = 12,
		Size = UDim2.new(0, 84, 1, 0),
		TextColor3 = UI.Colors.Muted,
	})
	for index, landmark in Map.Landmarks do
		local chip = UI.label(row, "🧊", {
			TextSize = 13,
			Font = Enum.Font.SourceSans,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0.4,
			BackgroundColor3 = UI.Colors.Track,
			Position = UDim2.fromOffset(84 + (index - 1) * 46, 0),
			Size = UDim2.fromOffset(42, 18),
		})
		UI.corner(chip, 9)
		chip.Text = `🧊 {landmark.PartName:sub(1, 3)}`
		radioChips[landmark.Part] = chip
	end
end

local function buildStock()
	local panel = UI.panel(gui, {
		Name = "Stockpile",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(196, 92),
	})
	UI.scale(panel)
	UI.label(panel, "STOCKPILE", {
		Font = UI.Title,
		TextSize = 13,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 16),
		TextColor3 = UI.Colors.Warm,
	})
	for index, resource in Resources.List do
		local column = (index - 1) % 3
		local line = (index - 1) // 3
		local label = UI.label(panel, "", {
			TextSize = 14,
			Font = UI.Body,
			Position = UDim2.fromOffset(10 + column * 62, 22 + line * 22),
			Size = UDim2.fromOffset(60, 20),
		})
		stockLabels[resource.Id] = label
	end
	pantryLabel = UI.label(panel, "", {
		TextSize = 12,
		Position = UDim2.fromOffset(10, 68),
		Size = UDim2.new(1, -20, 0, 18),
		TextColor3 = UI.Colors.Muted,
	})
end

local function buildPlayerPanel()
	playerPanel = UI.panel(gui, {
		Name = "Survivor",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.fromOffset(270, 110),
	})
	UI.scale(playerPanel)
	roleBadge = UI.label(playerPanel, "", {
		Font = UI.Title,
		TextSize = 14,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -96, 0, 18),
	})
	local _, fill, words = UI.bar(playerPanel, UI.Colors.Warm, {
		Position = UDim2.fromOffset(10, 24),
		Size = UDim2.new(1, -96, 0, 16),
	})
	warmthFill, warmthWords = fill, words
	packWords = UI.label(playerPanel, "", {
		TextSize = 12,
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(1, -96, 0, 30),
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	buffWords = UI.label(playerPanel, "", {
		TextSize = 11,
		Position = UDim2.fromOffset(10, 92),
		Size = UDim2.new(1, -96, 0, 14),
		TextColor3 = UI.Colors.Good,
	})
	for index = 1, Balance.FoodPocket do
		local slot = UI.button(playerPanel, "", {
			Position = UDim2.fromOffset(10 + (index - 1) * 40, 72),
			Size = UDim2.fromOffset(36, 22),
			BackgroundColor3 = UI.Colors.Track,
			TextSize = 14,
			Font = Enum.Font.SourceSans,
		})
		slot.Activated:Connect(function()
			local id = slot:GetAttribute("Meal")
			if id then
				Remotes.Eat:FireServer(id)
			end
		end)
		foodSlots[index] = slot
	end
	UI.label(playerPanel, if UI.touch() then "tap to eat" else "G: eat", {
		TextSize = 10,
		Position = UDim2.fromOffset(10 + Balance.FoodPocket * 40, 76),
		Size = UDim2.fromOffset(60, 14),
		TextColor3 = UI.Colors.Muted,
	})

	abilityButton = UI.button(playerPanel, "", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(76, 92),
		BackgroundColor3 = UI.Colors.Ice,
		TextSize = 30,
		Font = Enum.Font.SourceSans,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, function()
		Remotes.Ability:FireServer()
	end)
	UI.pad(abilityButton, 6)
	abilityWords = UI.label(abilityButton, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 11,
		TextColor3 = Color3.fromRGB(20, 30, 48),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		ZIndex = 4,
	})
	abilityShade = UI.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		ZIndex = 3,
	}, abilityButton)
	UI.corner(abilityShade, 8)
end

local function buildFrost()
	-- Four frosted edges that thicken as the player gets cold.
	local edges = {
		{ Vector2.new(0, 0), UDim2.fromScale(1, 0.22), 90 },
		{ Vector2.new(0, 1), UDim2.fromScale(1, 0.22), -90 },
		{ Vector2.new(0, 0), UDim2.fromScale(0.16, 1), 0 },
		{ Vector2.new(1, 0), UDim2.fromScale(0.16, 1), 180 },
	}
	for _, edge in edges do
		local frame = UI.new("Frame", {
			AnchorPoint = edge[1],
			Position = UDim2.fromScale(edge[1].X, edge[1].Y),
			Size = edge[2],
			BackgroundColor3 = Color3.fromRGB(190, 230, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, gui)
		UI.new("UIGradient", {
			Rotation = edge[3],
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, frame)
		table.insert(frost, frame)
	end
	frozenCover = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(150, 210, 255),
		BackgroundTransparency = 0.55,
		Visible = false,
		ZIndex = 0,
	}, gui)
	frozenWords = UI.label(frozenCover, "", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(460, 90),
		Font = UI.Title,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(20, 50, 90),
		TextStrokeTransparency = 0.8,
	})
end

-- Moves the player's panel out of the thumbstick's way on a phone.
local function arrange()
	if UI.touch() then
		playerPanel.AnchorPoint = Vector2.new(0, 0)
		playerPanel.Position = UDim2.fromOffset(8, 14 + 92 * UI.factor)
	else
		playerPanel.AnchorPoint = Vector2.new(0, 1)
		playerPanel.Position = UDim2.new(0, 8, 1, -8)
	end
end

local function refreshStock()
	for _, resource in Resources.List do
		stockLabels[resource.Id].Text = `{resource.Icon} {State:GetAttribute(`Stock_{resource.Id}`) or 0}`
	end
	local meals = {}
	for _, meal in Recipes.Meals do
		local count = State:GetAttribute(`Pantry_{meal.Id}`) or 0
		if count > 0 then
			table.insert(meals, `{meal.Icon}{count}`)
		end
	end
	pantryLabel.Text = if #meals > 0 then `Cook pot: {table.concat(meals, "  ")}` else "Cook pot: empty"
end

local function refreshFlame()
	local flame = State:GetAttribute("Flame") or 0
	local max = State:GetAttribute("MaxFlame") or 100
	local level = State:GetAttribute("HearthLevel") or 1
	UI.setBar(flameFill, flame / max)
	flameFill.BackgroundColor3 = if flame / max < 0.25 then UI.Colors.Bad else UI.Colors.Ember
	flameWords.Text = `🔥 Hearth {math.floor(flame)} / {max}   ·   Level {level}`
end

local function refreshRadio()
	local fitted = 0
	for _, landmark in Map.Landmarks do
		local state = State:GetAttribute(`Part_{landmark.Part}`) or "Frozen"
		local chip = radioChips[landmark.Part]
		chip.Text = `{PART_ICONS[state] or "🧊"} {landmark.PartName:sub(1, 3)}`
		chip.BackgroundColor3 = if state == "Fitted" then UI.Colors.Good else UI.Colors.Track
		if state == "Fitted" then
			fitted += 1
		end
	end
	radioWords.Text = if State:GetAttribute("Called")
		then "📻 Train called!"
		else `📻 Radio {fitted}/{#Map.Landmarks}`
	radioWords.TextColor3 = if State:GetAttribute("Called") then UI.Colors.Good else UI.Colors.Muted
end

local function refreshPlayer()
	local roleId = player:GetAttribute("Role") or ""
	local role = Roles.ById[roleId]
	roleBadge.Text = if role then `{role.Icon} {role.Name}` else "No role yet"
	roleBadge.TextColor3 = if role then Color3.fromHex(role.Color) else UI.Colors.Muted
	abilityButton.Text = if role then role.Icon else "?"
	abilityButton.Visible = role ~= nil

	local used = player:GetAttribute("PackUsed") or 0
	local size = player:GetAttribute("PackSize") or Balance.Backpack
	local inside = {}
	for _, resource in Resources.List do
		local count = player:GetAttribute(`Pack_{resource.Id}`) or 0
		if count > 0 then
			table.insert(inside, `{resource.Icon}{count}`)
		end
	end
	packWords.Text = `🎒 {used}/{size}  {table.concat(inside, " ")}`
	packWords.TextColor3 = if used >= size then UI.Colors.Bad else UI.Colors.Text

	local food = string.split(player:GetAttribute("Food") or "", ",")
	for index, slot in foodSlots do
		local meal = Recipes.MealById[food[index] or ""]
		slot.Text = if meal then meal.Icon else ""
		slot:SetAttribute("Meal", if meal then meal.Id else nil)
		slot.BackgroundColor3 = if meal then UI.Colors.Card else UI.Colors.Track
	end
end

local function step()
	local title, timer = phaseWords()
	clockTitle.Text = title
	clockTime.Text = timer
	local phase = State:GetAttribute("Phase")
	clockTitle.TextColor3 = if phase == "Night" or phase == "Dusk" then UI.Colors.Ice else UI.Colors.Text

	local warmth = player:GetAttribute("Warmth") or 100
	UI.setBar(warmthFill, warmth / Balance.Warmth.Max)
	warmthFill.BackgroundColor3 = if warmth < 30
		then UI.Colors.Ice
		elseif warmth < 60 then Color3.fromRGB(255, 220, 140)
		else UI.Colors.Warm
	warmthWords.Text = `{if warmth < 30 then "🥶" else "🌡️"} Warmth {math.floor(warmth)}`
	local cold = math.clamp((45 - warmth) / 45, 0, 1)
	for _, frame in frost do
		frame.BackgroundTransparency = 1 - cold * 0.75
	end
	if warmth < 30 and lastWarmth >= 30 then
		Sounds.play("Chill")
	end
	lastWarmth = warmth

	local ready = player:GetAttribute("AbilityReady") or 0
	local role = Roles.ById[player:GetAttribute("Role") or ""]
	if role then
		local wait = ready - now()
		local key = if UI.touch() then "" else "Q: "
		if wait > 0 then
			abilityShade.Size = UDim2.fromScale(1, math.clamp(wait / role.Ability.Cooldown, 0, 1))
			abilityWords.Text = `{role.Ability.Name}\n{math.ceil(wait)}s`
		else
			abilityShade.Size = UDim2.fromScale(1, 0)
			abilityWords.Text = `{key}{role.Ability.Name}`
		end
	end

	local buffs = {}
	if (player:GetAttribute("ShieldUntil") or 0) > now() then
		table.insert(buffs, "🧣 Toasty")
	end
	if (player:GetAttribute("SpeedUntil") or 0) > now() then
		table.insert(buffs, "💨 Quick")
	end
	local volley = player:GetAttribute("Volley") or 0
	if volley > 0 then
		table.insert(buffs, `🏹 x2 hits: {volley}`)
	end
	buffWords.Text = table.concat(buffs, "   ")

	local frozen = player:GetAttribute("Frozen") == true
	frozenCover.Visible = frozen
	if frozen then
		local wake = (player:GetAttribute("WakeAt") or 0) - now()
		frozenWords.Text = `You're frozen solid!\nA friend can thaw you, or you wake up by the hearth in {math.max(
			0,
			math.ceil(wake)
		)}s`
	end
end

local function bounce(frame: GuiObject)
	local scale = frame:FindFirstChildOfClass("UIScale") or UI.new("UIScale", {}, frame)
	scale.Scale = 1.08
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function Hud.mount()
	gui = UI.screen("Hud", 1)
	buildFrost()
	buildClock()
	buildStock()
	buildPlayerPanel()
	UI.onRescale(arrange)
	UserInputService.LastInputTypeChanged:Connect(arrange)

	State.AttributeChanged:Connect(function(name)
		if name:sub(1, 6) == "Stock_" or name:sub(1, 7) == "Pantry_" then
			refreshStock()
		elseif name == "Flame" or name == "MaxFlame" or name == "HearthLevel" then
			refreshFlame()
		elseif name:sub(1, 5) == "Part_" or name == "Called" or name == "Parts" then
			refreshRadio()
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if name == "PackUsed" then
			bounce(packWords)
		end
		refreshPlayer()
	end)
	refreshStock()
	refreshFlame()
	refreshRadio()
	refreshPlayer()
	RunService.Heartbeat:Connect(step)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonY then
			Remotes.Ability:FireServer()
		elseif input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.ButtonX then
			Remotes.Eat:FireServer()
		end
	end)
end

return Hud
