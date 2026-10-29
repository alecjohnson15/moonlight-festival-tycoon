-- The arena on this client. While the player is in the arena it shows a panel
-- with their weapon's special move and how soon it is ready, and binds the
-- special to E, the gamepad's X button, or a button on touch screens. It
-- shows a message on walking in and out, and on knocking someone out or being
-- knocked out.
--
-- It also plays out what the server reports about each fight (see
-- ArenaService): the effects are drawn by ArenaEffects, and when this player
-- is hit or uses a leap or a charge, this client moves their character, since
-- it is the one that moves it. The server has already decided every hit.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Config.Arena)
local Theme = require(Shared.Config.Theme)
local Weapons = require(Shared.Config.Weapons)
local ArenaEffects = require(script.Parent.ArenaEffects)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ArenaAction = Remotes:WaitForChild("ArenaAction") :: RemoteEvent
local ArenaEffect = Remotes:WaitForChild("ArenaEffect") :: RemoteEvent

local ACTION = "ArenaSpecial"
local PANEL = Color3.fromRGB(26, 18, 40)
local TEXT = Color3.fromRGB(255, 244, 214)
local FONT = Enum.Font.FredokaOne
local TOAST_SECONDS = 2.6

local Strings = Theme.Strings

local ArenaClient = {}

local player = Players.LocalPlayer
local lastSpecial = -math.huge
local knockedOutAt = -math.huge
local bound = false
local boundName = ""

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local gui = make("ScreenGui", { Name = "Arena", ResetOnSpawn = false })

-- The panel under the cash counter: the special move's name, its key, and a
-- bar that fills as it gets ready.
local panel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 102),
	Size = UDim2.fromOffset(250, 46),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.15,
	Visible = false,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
local stroke = make("UIStroke", { Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)
local moveLabel = make("TextLabel", {
	Position = UDim2.fromOffset(10, 4),
	Size = UDim2.new(1, -20, 0, 22),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = TEXT,
}, panel)
local track = make("Frame", {
	Position = UDim2.new(0, 10, 1, -14),
	Size = UDim2.new(1, -20, 0, 8),
	BackgroundColor3 = Color3.fromRGB(60, 50, 80),
}, panel)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
local fill = make("Frame", { Size = UDim2.fromScale(0, 1) }, track)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

local toast = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(520, 44),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = TEXT,
	TextStrokeTransparency = 0.2,
	TextTransparency = 1,
	TextStrokeColor3 = Color3.fromRGB(40, 10, 60),
}, gui)
local toastScale = make("UIScale", {}, toast)
local toastShown = 0

local function say(text: string, color: Color3?)
	toast.Text = text
	toast.TextColor3 = color or TEXT
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.2
	toastScale.Scale = 1.25
	TweenService:Create(toastScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	toastShown = os.clock()
	local shownAt = toastShown
	task.delay(TOAST_SECONDS, function()
		if toastShown == shownAt then
			TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function parts(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid, if root and root:IsA("BasePart") then root else nil
end

-- The weapon id of the Tool this player is holding, if it is a weapon.
local function heldWeapon(): string?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("Weapon")
	return if type(id) == "string" and rawget(Weapons, id) then id else nil
end

local function onSpecial(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and heldWeapon() then
		ArenaAction:FireServer("Special")
	end
	return Enum.ContextActionResult.Sink
end

local function bind(on: boolean)
	if on and not bound then
		ContextActionService:BindAction(ACTION, onSpecial, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
		ContextActionService:SetPosition(ACTION, UDim2.new(1, -170, 1, -150))
		boundName = ""
	elseif not on and bound then
		ContextActionService:UnbindAction(ACTION)
	end
	bound = on
end

-- Keeps the panel showing the held weapon's special and its cooldown.
local function onRenderStep()
	if not panel.Visible then
		return
	end
	local id = heldWeapon()
	if not id then
		moveLabel.Text = Strings.ArenaEquip
		fill.Size = UDim2.fromScale(0, 1)
		return
	end
	local look = ArenaEffects.look(id)
	local cooldown = Weapons[id].Special.Cooldown
	local ready = math.clamp((os.clock() - lastSpecial) / cooldown, 0, 1)
	moveLabel.Text = if ready >= 1
		then `{look.Name} [{Strings.ArenaSpecialKey}]  {Strings.ArenaReady}`
		else `{look.Name} [{Strings.ArenaSpecialKey}]`
	fill.Size = UDim2.fromScale(ready, 1)
	fill.BackgroundColor3 = if ready >= 1 then look.Color else look.Color:Lerp(Color3.new(0.3, 0.3, 0.3), 0.5)
	stroke.Color = look.Color
	if bound and boundName ~= look.Name then
		boundName = look.Name
		ContextActionService:SetTitle(ACTION, look.Name)
	end
end

local function onInArena()
	local inside = player:GetAttribute("InArena") == true
	if inside == panel.Visible then
		return
	end
	panel.Visible = inside
	bind(inside)
	-- After a knockout, the message saying who did it stays up instead.
	if inside or os.clock() - knockedOutAt > Arena.KnockedOutSeconds + 1 then
		say(if inside then Strings.ArenaEntered else Strings.ArenaLeft)
	end
end

-- Throws this player's character, as the server asked.
local function throwSelf(velocity: Vector3)
	local humanoid, root = parts()
	if humanoid and root then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = velocity
	end
end

-- Knocked out: tumble for a moment, then get up again just before the server
-- puts this player outside the entrance.
local function tumble(velocity: Vector3)
	local humanoid, root = parts()
	if not humanoid or not root then
		return
	end
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-4, 4), math.random(-8, 8))
	ArenaEffects.shake(0.8, 0.6)
	task.delay(Arena.KnockedOutSeconds - 0.15, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			root.AssemblyAngularVelocity = Vector3.zero
			root.AssemblyLinearVelocity = Vector3.zero
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- This player's own leap, charge or spin for their special move.
local function moveSelf(weaponId: string, ahead: Vector3)
	local humanoid, root = parts()
	local weapon = rawget(Weapons, weaponId)
	if not humanoid or not root or not weapon then
		return
	end
	local move = weapon.Special
	if move.Kind == "Slam" then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		root.AssemblyLinearVelocity = ahead * 12 + Vector3.new(0, 55, 0)
		task.delay(move.Delay * 0.55, function()
			if root.Parent then
				root.AssemblyLinearVelocity = Vector3.new(0, -90, 0)
			end
		end)
	elseif move.Kind == "Dash" then
		local speed = move.Distance / move.Seconds
		local started = os.clock()
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if os.clock() - started > move.Seconds or not root.Parent then
				connection:Disconnect()
				root.AssemblyLinearVelocity = ahead * 8
				return
			end
			root.AssemblyLinearVelocity = Vector3.new(ahead.X * speed, root.AssemblyLinearVelocity.Y, ahead.Z * speed)
		end)
	elseif move.Kind == "Spin" then
		local _, yaw = root.CFrame:ToOrientation()
		humanoid.AutoRotate = false
		local started = os.clock()
		local connection
		connection = RunService.Heartbeat:Connect(function()
			local t = (os.clock() - started) / move.Seconds
			if t >= 1 or not root.Parent then
				connection:Disconnect()
				humanoid.AutoRotate = true
				return
			end
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw + t * math.pi * 6, 0)
		end)
	end
end

local function characterOf(someone: Instance?): Model?
	if typeof(someone) == "Instance" and someone:IsA("Player") then
		return someone.Character
	end
	return nil
end

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function onEffect(kind: string, who: Player, ...)
	local args = { ... }
	if kind == "Hit" then
		local attacker, weaponId, velocity = args[1], args[2], args[3]
		local root = rootOf(characterOf(who))
		if root then
			ArenaEffects.hit(root.Position, weaponId)
		end
		if who == player then
			throwSelf(velocity)
			ArenaEffects.shake(0.3, 0.2)
		elseif attacker == player then
			ArenaEffects.shake(0.15, 0.1)
		end
	elseif kind == "KnockOut" then
		local attacker, weaponId, throw = args[1], args[2], args[3]
		local character = characterOf(who)
		if character then
			ArenaEffects.knockOut(character, weaponId, Arena.KnockedOutSeconds)
		end
		if who == player then
			knockedOutAt = os.clock()
			tumble(throw)
			local name = if typeof(attacker) == "Instance" then attacker.DisplayName else "?"
			say(Strings.ArenaKnockedOutBy:format(name), Color3.fromRGB(255, 150, 150))
		elseif attacker == player then
			local streak = player:GetAttribute("ArenaStreak") or 0
			local text = Strings.ArenaYouKnockedOut:format(who.DisplayName)
			if streak >= 2 then
				text ..= "  " .. Strings.ArenaStreak:format(streak)
			end
			say(text, Color3.fromRGB(255, 220, 110))
		end
	elseif kind == "Special" then
		local weaponId, start, ahead = args[1], args[2], args[3]
		local character = characterOf(who)
		if character then
			ArenaEffects.special(character, weaponId, start, ahead)
		end
		if who == player then
			lastSpecial = os.clock()
			moveSelf(weaponId, ahead)
		end
	elseif kind == "Impact" then
		local weaponId, at = args[1], args[2]
		ArenaEffects.impact(weaponId, at)
	end
end

function ArenaClient.start()
	gui.Parent = player:WaitForChild("PlayerGui")
	ArenaEffects.start()
	player:GetAttributeChangedSignal("InArena"):Connect(onInArena)
	ArenaEffect.OnClientEvent:Connect(onEffect)
	RunService.RenderStepped:Connect(onRenderStep)
end

return ArenaClient
