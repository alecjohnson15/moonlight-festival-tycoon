-- The leads notebook: what this player saw and heard this round, newest
-- first, each with its kind, room and how long ago. A small "Leads" pill
-- under the Truth Bell shows how many there are and opens the list (N, or
-- up on a controller's D-pad). Leads come from the server (EvidenceService)
-- and are only ever this player's own; the list says plainly that a lead
-- isn't proof.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Format = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Format)
local Hud = require(script.Parent.Hud)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Leads = {}

type Lead = { Family: string, Text: string, Room: string, At: number, Lifetime: number }

-- Each kind of lead has a short word and a colour, so the list reads at a
-- glance without relying on the colour alone.
local KINDS = {
	Witness = { Word = "SEEN", Color = Color3.fromRGB(255, 205, 90) },
	Commotion = { Word = "HEARD", Color = Color3.fromRGB(127, 224, 255) },
	Footprints = { Word = "TRAIL", Color = Color3.fromRGB(190, 150, 255) },
	Tampering = { Word = "TAMPER", Color = Color3.fromRGB(255, 140, 90) },
}

local leads: { Lead } = {}
local unread = 0

local pill = Ui.button(Hud.top(), "Leads", Ui.Colors.Card, {
	Size = UDim2.fromOffset(150, 26),
	TextSize = 13,
	LayoutOrder = 4,
	Visible = false,
})
Ui.stroke(pill, Color3.fromRGB(190, 150, 255), 1.5)

local gui = Ui.screen("Leads", 3)
local panel = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 128),
	Size = UDim2.fromOffset(330, 250),
	BackgroundColor3 = Ui.Colors.Panel,
	BackgroundTransparency = 0.06,
	Visible = false,
}, gui)
Ui.round(panel, 12)
Ui.stroke(panel, Color3.fromRGB(190, 150, 255), 2)
Ui.fitScale(panel)
Ui.label(panel, "LEADS", {
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.new(1, -60, 0, 22),
	Font = Ui.Title,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local close = Ui.button(panel, "X", Ui.Colors.Bad, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 6),
	Size = UDim2.fromOffset(32, 28),
	TextSize = 14,
})
Ui.label(panel, "Leads, not proof. A glimpse can be wrong, so compare notes.", {
	Position = UDim2.fromOffset(12, 30),
	Size = UDim2.new(1, -24, 0, 16),
	TextSize = 11,
	TextColor3 = Ui.Colors.Dim,
	TextXAlignment = Enum.TextXAlignment.Left,
})
local list = Ui.make("ScrollingFrame", {
	Position = UDim2.fromOffset(8, 52),
	Size = UDim2.new(1, -16, 1, -60),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, panel)
Ui.list(list, 4)
local empty = Ui.label(list, "Nothing yet. Stay near others and keep your eyes open.", {
	Size = UDim2.new(1, -6, 0, 40),
	TextSize = 12,
	TextColor3 = Ui.Colors.Dim,
	LayoutOrder = 0,
})

local rows: { Frame } = {}

local function age(lead: Lead): string
	return `{Format.clock(math.max(0, math.floor(State.now() - lead.At)))} ago`
end

local function live(): boolean
	return State.Round.InRound and State.Round.State == "Playing" and State.Me ~= "Out"
end

local function prune()
	local now = State.now()
	local keep = {}
	for _, lead in leads do
		if now - lead.At < lead.Lifetime then
			table.insert(keep, lead)
		end
	end
	leads = keep
end

local function redraw()
	for _, row in rows do
		row:Destroy()
	end
	rows = {}
	empty.Visible = #leads == 0
	for index = #leads, 1, -1 do
		local lead = leads[index]
		local kind = KINDS[lead.Family] or KINDS.Commotion
		local row = Ui.make("Frame", {
			Size = UDim2.new(1, -6, 0, 46),
			BackgroundColor3 = Ui.Colors.Card,
			LayoutOrder = #leads - index + 1,
		}, list)
		Ui.round(row, 8)
		local chip = Ui.make("Frame", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(58, 18),
			BackgroundColor3 = kind.Color,
		}, row)
		Ui.round(chip, 6)
		Ui.label(chip, kind.Word, {
			Size = UDim2.fromScale(1, 1),
			Font = Ui.Title,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(24, 16, 38),
		})
		Ui.label(row, age(lead), {
			Name = "Age",
			Position = UDim2.fromOffset(6, 26),
			Size = UDim2.fromOffset(58, 14),
			TextSize = 10,
			TextColor3 = Ui.Colors.Dim,
		})
		Ui.label(row, lead.Text, {
			Position = UDim2.fromOffset(70, 4),
			Size = UDim2.new(1, -76, 1, -8),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
		rows[index] = row
	end
end

local function refreshPill()
	pill.Visible = live()
	pill.Text = if unread > 0 then `Leads: {#leads} ({unread} new)` else `Leads: {#leads}`
	if not pill.Visible then
		panel.Visible = false
	end
end

function Leads.toggle()
	if not live() then
		return
	end
	panel.Visible = not panel.Visible
	if panel.Visible then
		unread = 0
		redraw()
	end
	refreshPill()
	Sounds.play("Click")
end

local function clear()
	leads = {}
	unread = 0
	redraw()
	refreshPill()
end

function Leads.start()
	pill.Activated:Connect(Leads.toggle)
	close.Activated:Connect(Leads.toggle)
	State.on("Lead", function(message)
		if typeof(message) ~= "table" or typeof(message.Text) ~= "string" then
			return
		end
		table.insert(leads, {
			Family = message.Family,
			Text = message.Text,
			Room = message.Room,
			At = message.At or State.now(),
			Lifetime = message.Lifetime or 75,
		})
		while #leads > 8 do
			table.remove(leads, 1)
		end
		if not panel.Visible then
			unread += 1
		else
			redraw()
		end
		Sounds.play("Page")
		refreshPill()
	end)
	State.on("Role", clear)
	State.on("Round", function()
		if State.Round.State ~= "Playing" then
			clear()
		end
		refreshPill()
	end)
	State.on("Me", refreshPill)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.N or input.KeyCode == Enum.KeyCode.DPadUp then
			Leads.toggle()
		end
	end)
	-- Ages tick on, and old leads drop off.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 then
			return
		end
		elapsed = 0
		local before = #leads
		prune()
		if #leads ~= before then
			unread = math.min(unread, #leads)
			redraw()
			refreshPill()
		elseif panel.Visible then
			for index, row in rows do
				local label = row:FindFirstChild("Age") :: TextLabel?
				if label and leads[index] then
					label.Text = age(leads[index])
				end
			end
		end
	end)
	refreshPill()
end

return Leads
