-- The emote menu (the Emotes button or G). Moves play the dances and
-- gestures every Roblox character already has, through the default Animate
-- script, so they replicate on their own. Reactions put a bubble over your
-- head; Suspect points one at another player. Party emotes, from the Party
-- Emotes pass, are effects only: they never hide you or move you.
--
-- Everyone who could hear you speak (in a round, the people near you) sees
-- your bubbles and effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteConfig = require(Shared.Config.Emotes)
local Corner = require(script.Parent.Corner)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)
local Shop = require(script.Parent.Shop)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local EmoteRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Emote") :: RemoteEvent

local player = Players.LocalPlayer

local Emotes = {}

local gui = Ui.screen("Emotes", 3)
local panel, body, heading = Ui.panel(gui, "Emotes", 470, 330)
local lastUsed = 0
local picking: EmoteConfig.Emote? = nil

local CONFETTI = {
	Color3.fromRGB(255, 92, 112),
	Color3.fromRGB(255, 205, 90),
	Color3.fromRGB(96, 214, 128),
	Color3.fromRGB(80, 160, 255),
	Color3.fromRGB(176, 103, 255),
}

local function headOf(character: Model?): BasePart?
	if not character then
		return nil
	end
	local head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local function rootOf(character: Model?): BasePart?
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- A speech bubble over a character for a few seconds.
local function bubble(character: Model?, text: string, color: Color3?)
	local head = headOf(character)
	if not head then
		return
	end
	local old = head:FindFirstChild("EmoteBubble")
	if old then
		old:Destroy()
	end
	local board = Ui.make("BillboardGui", {
		Name = "EmoteBubble",
		Size = UDim2.fromOffset(160, 44),
		StudsOffset = Vector3.new(0, 3.2, 0),
		AlwaysOnTop = false,
		MaxDistance = 90,
		LightInfluence = 0,
	}, head)
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(255, 250, 240),
	}, board)
	Ui.round(frame, 14)
	Ui.stroke(frame, color or Ui.Colors.Accent, 2)
	Ui.pad(frame, 12, 4)
	Ui.label(frame, text, {
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		Font = Ui.Title,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(40, 28, 62),
	})
	local scale = Ui.make("UIScale", { Scale = 0.3 }, frame)
	Ui.pop(scale, 1)
	task.delay(EmoteConfig.BubbleSeconds, function()
		if board.Parent then
			board:Destroy()
		end
	end)
end

-- A small red question mark over the suspected player.
local function suspectMark(character: Model?)
	local head = headOf(character)
	if not head then
		return
	end
	local board = Ui.make("BillboardGui", {
		Size = UDim2.fromOffset(40, 40),
		StudsOffset = Vector3.new(0, 4.6, 0),
		MaxDistance = 90,
		LightInfluence = 0,
	}, head)
	Ui.label(board, "?", {
		Size = UDim2.fromScale(1, 1),
		Font = Ui.Title,
		TextSize = 34,
		TextColor3 = Color3.fromRGB(255, 92, 112),
		TextStrokeTransparency = 0.2,
	})
	task.delay(EmoteConfig.BubbleSeconds, function()
		board:Destroy()
	end)
end

-- Party effects ------------------------------------------------------------

local function spotlight(root: BasePart)
	local base = root.Position - Vector3.new(0, 3, 0)
	local cone = Effects.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(30, 7, 7),
		CFrame = CFrame.new(base + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 240, 200),
		Transparency = 0.75,
	})
	local disc = Effects.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 9, 9),
		CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 240, 200),
		Transparency = 0.4,
	})
	Ui.make("PointLight", { Brightness = 3, Range = 16, Color = Color3.fromRGB(255, 240, 200) }, disc)
	task.delay(2.6, function()
		Effects.fade(cone, 0.6)
		Effects.fade(disc, 0.6)
	end)
	Sounds.play("Fanfare", root.Position)
end

local function confetti(root: BasePart, count: number, up: number)
	local random = Random.new()
	for index = 1, count do
		local piece = Effects.part({
			Size = Vector3.new(0.5, 0.08, 0.3),
			CFrame = CFrame.new(root.Position + Vector3.new(0, 2, 0)),
			Color = CONFETTI[(index % #CONFETTI) + 1],
			Material = Enum.Material.SmoothPlastic,
		})
		local goal = root.Position
			+ Vector3.new(random:NextNumber(-7, 7), random:NextNumber(up * 0.6, up), random:NextNumber(-7, 7))
		local rise = TweenService:Create(piece, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(goal) * CFrame.Angles(random:NextNumber(0, 6), random:NextNumber(0, 6), 0),
		})
		rise:Play()
		rise.Completed:Connect(function()
			local fall = TweenService:Create(piece, TweenInfo.new(1.6, Enum.EasingStyle.Sine), {
				CFrame = CFrame.new(goal - Vector3.new(random:NextNumber(-2, 2), up + 2, random:NextNumber(-2, 2)))
					* CFrame.Angles(random:NextNumber(0, 6), random:NextNumber(0, 6), 0),
				Transparency = 1,
			})
			fall:Play()
			fall.Completed:Connect(function()
				piece:Destroy()
			end)
		end)
	end
end

local function puff(root: BasePart)
	for index = 1, 10 do
		local angle = index / 10 * math.pi * 2
		local ball = Effects.part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.2,
			CFrame = CFrame.new(root.Position + Vector3.new(math.cos(angle) * 1.5, -1, math.sin(angle) * 1.5)),
			Color = if index % 2 == 0 then Color3.fromRGB(230, 220, 255) else Color3.fromRGB(255, 190, 240),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.3,
		})
		TweenService:Create(ball, TweenInfo.new(1.1), {
			CFrame = CFrame.new(root.Position + Vector3.new(math.cos(angle) * 4, 1.5, math.sin(angle) * 4)),
		}):Play()
		Effects.fade(ball, 1.1, Vector3.one * 4.5)
	end
	Effects.sparkleRing(root.Position, Color3.fromRGB(255, 205, 90), 12)
end

local function halo(character: Model)
	local head = headOf(character)
	if not head then
		return
	end
	local stars = {}
	for index = 1, 6 do
		local star = Effects.part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.5,
			Color = Color3.fromRGB(255, 225, 120),
		})
		stars[index] = star
	end
	local started = os.clock()
	task.spawn(function()
		while os.clock() - started < 3 and head.Parent do
			local t = os.clock() - started
			for index, star in stars do
				local angle = t * 3 + index / #stars * math.pi * 2
				star.CFrame = CFrame.new(head.Position + Vector3.new(math.cos(angle) * 1.6, 1.4, math.sin(angle) * 1.6))
			end
			task.wait()
		end
		for _, star in stars do
			Effects.fade(star, 0.3)
		end
	end)
end

local function playEffect(character: Model?, effect: string)
	local root = rootOf(character)
	if not character or not root then
		return
	end
	if effect == "spotlight" then
		spotlight(root)
	elseif effect == "cannon" then
		confetti(root, 40, 14)
		Sounds.play("Pop", root.Position, 0.8)
	elseif effect == "puff" then
		puff(root)
		Sounds.play("Pop", root.Position, 1.2)
	elseif effect == "halo" then
		halo(character)
		Sounds.play("Revive", root.Position, 1.6)
	elseif effect == "applause" then
		bubble(character, "Bravo! Bravo!", Ui.Colors.Gold)
		confetti(root, 16, 8)
		Sounds.play("Fanfare", root.Position, 1.2)
	end
end

-- Draws an emote someone did (you, or another player the server passed on).
local function show(from: Player, emote: EmoteConfig.Emote, target: Player?)
	local character = from.Character
	if emote.Bubble then
		bubble(character, emote.Bubble)
	elseif emote.Target and target then
		bubble(character, `I suspect {target.DisplayName}!`, Color3.fromRGB(255, 92, 112))
		suspectMark(target.Character)
	elseif emote.Effect then
		playEffect(character, emote.Effect)
	end
end

local function playAnimation(name: string)
	local character = player.Character
	local animate = character and character:FindFirstChild("Animate")
	local play = animate and animate:FindFirstChild("PlayEmote")
	if play and play:IsA("BindableFunction") then
		pcall(function()
			play:Invoke(name)
		end)
	end
end

local function canEmote(): boolean
	if State.Me == "Dazed" then
		Corner.note("You're dazed", "Wait for a Medic or the timer.", Ui.Colors.Bad, 3)
		return false
	end
	if State.Me == "Out" and State.Round.InRound and State.Round.State == "Playing" then
		Corner.note("You're out this round", "You can emote again in the plaza.", Ui.Colors.Dim, 3)
		return false
	end
	return true
end

local draw: () -> ()

local function use(emote: EmoteConfig.Emote, target: Player?)
	if os.clock() - lastUsed < EmoteConfig.Cooldown or not canEmote() then
		return
	end
	lastUsed = os.clock()
	if emote.Anim then
		playAnimation(emote.Anim)
	end
	show(player, emote, target)
	EmoteRemote:FireServer(emote.Id, target and target.UserId)
	Ui.hide(panel)
end

local function clear()
	for _, child in body:GetChildren() do
		child:Destroy()
	end
end

-- Pick who to suspect: the players near you.
local function drawTargets(emote: EmoteConfig.Emote)
	heading.Text = "Who do you suspect?"
	local myRoot = rootOf(player.Character)
	local list = Ui.make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, body)
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(140, 40),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	local near = {}
	for _, other in Players:GetPlayers() do
		local root = rootOf(other.Character)
		if other ~= player and root and myRoot then
			table.insert(near, { Player = other, Distance = (root.Position - myRoot.Position).Magnitude })
		end
	end
	table.sort(near, function(a, b)
		return a.Distance < b.Distance
	end)
	for index, entry in near do
		local button = Ui.button(list, entry.Player.DisplayName, Ui.Colors.Card, { TextSize = 14, LayoutOrder = index })
		button.Activated:Connect(function()
			picking = nil
			use(emote, entry.Player)
		end)
	end
	if #near == 0 then
		Ui.label(list, "Nobody's around.", { TextColor3 = Ui.Colors.Dim })
	end
	local back = Ui.button(body, "Back", Ui.Colors.Track, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(100, 34),
	})
	back.Activated:Connect(function()
		picking = nil
		draw()
	end)
end

draw = function()
	clear()
	if picking then
		drawTargets(picking)
		return
	end
	heading.Text = "Emotes"
	local hasPass = State.Profile and State.Profile.Perks and State.Profile.Perks.Emotes == true
	local grid = Ui.make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Ui.Colors.Accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, body)
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(104, 46),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for index, emote in EmoteConfig.List do
		local locked = emote.Pass == true and not hasPass
		local color = if emote.Pass
			then Color3.fromRGB(150, 70, 190)
			elseif emote.Anim then Color3.fromRGB(70, 120, 200)
			else Color3.fromRGB(200, 90, 140)
		local button = Ui.button(grid, if locked then `🔒 {emote.Name}` else emote.Name, color, {
			TextSize = 13,
			TextWrapped = true,
			LayoutOrder = index,
		})
		if locked then
			button.BackgroundTransparency = 0.45
		end
		button.Activated:Connect(function()
			if locked then
				Sounds.play("Deny")
				Corner.note(
					"Party Emotes",
					"These five come with the Party Emotes pass in the boutique.",
					Ui.Colors.Accent,
					4
				)
				Ui.hide(panel)
				Shop.open("Robux")
				return
			end
			if emote.Target then
				picking = emote
				draw()
				return
			end
			use(emote)
		end)
	end
end

function Emotes.open()
	picking = nil
	Ui.show(panel)
	draw()
end

local function toggle()
	if Ui.isOpen(panel) then
		Ui.hide(panel)
	else
		Emotes.open()
	end
end

function Emotes.start()
	Hud.onMenu("Emotes", toggle)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.G then
			toggle()
		end
	end)
	EmoteRemote.OnClientEvent:Connect(function(from: Player, emoteId: string, target: Player?)
		local emote = EmoteConfig.get(emoteId)
		if emote and from and from.Parent then
			show(from, emote, target)
		end
	end)
	State.on("Profile", function()
		if Ui.isOpen(panel) and not picking then
			draw()
		end
	end)
end

return Emotes
