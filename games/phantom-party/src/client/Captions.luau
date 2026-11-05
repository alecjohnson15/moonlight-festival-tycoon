-- Captions for sounds (Config/Captions), at the bottom middle of the screen,
-- while the player has Captions on in Settings. A sound from a spot in the
-- world says which way it came from ("left", "behind"), so a player who
-- can't hear it still knows a blade swished nearby. A few lines at most,
-- each gone after a few seconds; nothing here blocks a tap.

local Workspace = game:GetService("Workspace")

local CaptionConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Captions)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Captions = {}

local gui = Ui.screen("Captions", 2)
local stack = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -64),
	Size = UDim2.fromOffset(360, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	Active = false,
}, gui)
Ui.list(stack, 2).HorizontalAlignment = Enum.HorizontalAlignment.Center
Ui.fitScale(stack)

local lines: { TextLabel } = {}
local order = 0
-- When each caption last showed, so one sound played twice reads once.
local shownAt: { [string]: number } = {}

-- Which way a spot is from the camera, in a word or two.
local function direction(position: Vector3): string?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local offset = position - camera.CFrame.Position
	local distance = offset.Magnitude
	if distance > CaptionConfig.Range then
		return nil
	end
	if distance < 8 then
		return "close by"
	end
	local flat = Vector3.new(offset.X, 0, offset.Z).Unit
	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	local ahead = flat:Dot(Vector3.new(look.X, 0, look.Z).Unit)
	local side = flat:Dot(Vector3.new(right.X, 0, right.Z).Unit)
	if ahead > 0.7 then
		return "ahead"
	elseif ahead < -0.7 then
		return "behind"
	end
	return if side > 0 then "to the right" else "to the left"
end

function Captions.show(name: string, position: Vector3?)
	if not State.setting("Captions", false) then
		return
	end
	local text = CaptionConfig.Text[name]
	if not text then
		return
	end
	if position then
		local way = direction(position)
		if not way then
			return
		end
		text = `{text}, {way}`
	end
	local now = os.clock()
	if shownAt[text] and now - shownAt[text] < 0.75 then
		return
	end
	shownAt[text] = now
	order += 1
	local label = Ui.label(stack, `[{text}]`, {
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		TextSize = 15,
		TextWrapped = false,
		LayoutOrder = order,
	})
	Ui.pad(label, 8, 2)
	Ui.round(label, 6)
	table.insert(lines, label)
	while #lines > CaptionConfig.MaxLines do
		table.remove(lines, 1):Destroy()
	end
	task.delay(CaptionConfig.Seconds, function()
		local index = table.find(lines, label)
		if index then
			table.remove(lines, index)
		end
		label:Destroy()
	end)
end

function Captions.start()
	Sounds.listen(Captions.show)
	-- Above the thumbstick and jump button on a phone.
	stack.Position = if Ui.isTouch() then UDim2.new(0.5, 0, 1, -104) else UDim2.new(0.5, 0, 1, -64)
end

return Captions
