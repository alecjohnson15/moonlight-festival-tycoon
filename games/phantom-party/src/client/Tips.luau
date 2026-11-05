-- First-time tips (Config/Tips): one short banner at a time, the first time
-- a player meets each thing, in the words for their keyboard, touch screen
-- or controller. A banner never blocks play and fades on its own; once
-- shown, the server saves it so it never shows again.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local TipRules = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Rules.Tips)
local TipConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Tips)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Tips = {}

local gui = Ui.screen("Tips", 3)
local banner = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -112),
	Size = UDim2.fromOffset(440, 54),
	BackgroundColor3 = Ui.Colors.Panel,
	BackgroundTransparency = 0.08,
	Visible = false,
	Active = false,
}, gui)
Ui.round(banner, 12)
Ui.stroke(banner, Ui.Colors.Gold, 2)
Ui.fitScale(banner)
Ui.label(banner, "TIP", {
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.new(0, 36, 1, 0),
	Font = Ui.Title,
	TextSize = 16,
	TextColor3 = Ui.Colors.Gold,
})
local words = Ui.label(banner, "", {
	Position = UDim2.fromOffset(50, 4),
	Size = UDim2.new(1, -60, 1, -8),
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
})

-- Tips already shown, this session and before (from the save).
local seen: { [string]: boolean } = {}
local queue: { string } = {}
local showing = false
local loaded = false

local function input(): string
	local last = UserInputService:GetLastInputType().Name
	if string.sub(last, 1, 7) == "Gamepad" then
		return "Gamepad"
	elseif Ui.isTouch() then
		return "Touch"
	end
	return "Keyboard"
end

local function place()
	-- Above the round buttons: higher on a phone, where they sit lower right.
	banner.Position = if Ui.isTouch() then UDim2.new(0.5, 0, 1, -150) else UDim2.new(0.5, 0, 1, -112)
end

local function showNext()
	if showing or #queue == 0 then
		return
	end
	local id = table.remove(queue, 1) :: string
	local tip = nil
	for _, each in TipConfig.List do
		if each.Id == id then
			tip = each
		end
	end
	if not tip then
		return
	end
	showing = true
	place()
	words.Text = TipRules.text(tip, input())
	banner.Visible = true
	banner.BackgroundTransparency = 0.08
	task.spawn(function()
		local result = State.request("TipSeen", id)
		if not result.Ok then
			task.wait(0.5)
			State.request("TipSeen", id)
		end
	end)
	task.delay(TipConfig.Seconds, function()
		if not State.setting("ReduceMotion", false) then
			TweenService:Create(banner, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.wait(0.3)
		end
		banner.Visible = false
		showing = false
		showNext()
	end)
end

-- Something happened that a tip may be about.
function Tips.moment(when: string)
	if not loaded then
		return
	end
	local tip = TipRules.next(seen, State.Role, when)
	if tip then
		seen[tip.Id] = true
		table.insert(queue, tip.Id)
		showNext()
	end
end

function Tips.start()
	State.on("Profile", function()
		local profile = State.Profile
		if profile and typeof(profile.Tips) == "table" then
			for id, done in profile.Tips do
				if done then
					seen[id] = true
				end
			end
			loaded = true
		end
	end)
	local started = false
	State.on("Round", function()
		local playing = State.Round.State == "Playing" and State.Round.InRound
		if playing and not started then
			started = true
			Tips.moment("Start")
		elseif not playing then
			started = false
			queue = {}
		end
	end)
	State.on("Kit", function()
		if State.Kit.Drawn then
			Tips.moment("Drawn")
		end
	end)
	State.on("Hit", function(message)
		if typeof(message) == "table" and message.Result == "Tagged" then
			Tips.moment("Tagged")
		end
	end)
	State.on("Census", function()
		if State.Role == "Medic" and State.playing() and (State.Census.Dazed or 0) > 0 then
			Tips.moment("SomeoneDazed")
		end
	end)
	State.on("Lead", function()
		Tips.moment("Lead")
	end)
	State.on("Bell", function()
		if State.Bell.Room and State.playing() then
			Tips.moment("BellHint")
		end
	end)
	State.on("Me", function()
		if State.Me == "Out" then
			Tips.moment("Out")
		end
	end)
	-- The Phantom's blade becomes ready a few seconds in.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		local kit = State.Kit
		if State.Role == "Phantom" and State.playing() and kit.Blade and not kit.Drawn then
			if State.left(kit.BladeFrom or 0) <= 0 then
				Tips.moment("BladeReady")
			end
		end
	end)
end

return Tips
