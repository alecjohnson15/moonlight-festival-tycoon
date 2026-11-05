-- The end of a run: whether the train came, how far the team got, the
-- milestones the team reached, the team's best (most monsters bopped, most
-- friends thawed), what this player did themselves, what they earned
-- (snowflakes, Expedition Pass XP and any rewards it opened) and the next
-- thing to play for. A loss still pays, so 'snowed under' is progress too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Milestones = require(Shared.Milestones)
local Corner = require(script.Parent.Corner)
local UI = require(script.Parent.UI)

local Results = {}

local window: UI.Window

local function line(parent: Instance, text: string, order: number, props: { [string]: any }?)
	local label = UI.label(parent, text, {
		TextSize = 15,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

local function show(data: any)
	UI.clear(window.Body)
	if not window.Body:FindFirstChildOfClass("UIListLayout") then
		UI.list(window.Body, 8)
	end
	local body = window.Body
	if data.Won then
		window.Title.Text = "🚂 RESCUED!"
		window.Title.TextColor3 = UI.Colors.Good
		line(body, `The train found Pinehollow after {data.Night} nights. Everyone's going home!`, 1)
	else
		window.Title.Text = "❄ SNOWED UNDER"
		window.Title.TextColor3 = UI.Colors.Ice
		local why = if data.Night >= Balance.LastNight
			then "The blizzard won: the radio was never fixed."
			else "The hearth went out."
		line(body, `{why} You made it to night {data.Night}.`, 1)
	end
	line(body, `📻 Radio parts fixed: {data.Parts} of 4`, 2)
	line(body, `🪵 Gathered: {data.Gathered}   ·   🧱 Built: {data.Built}`, 3)
	if data.BeatYeti then
		line(body, "🦶 You chased off the Old Yeti!", 4, { TextColor3 = UI.Colors.Gold })
	end
	if data.TopKnockouts then
		line(body, `⭐ Most monsters bopped: {data.TopKnockouts} ({data.TopKnockoutsCount})`, 6)
	end
	if data.TopThaws then
		line(body, `⭐ Best friend: {data.TopThaws} thawed {data.TopThawsCount} frozen teammates`, 7)
	end
	if type(data.Milestones) == "table" and #data.Milestones > 0 then
		local names = {}
		for _, id in data.Milestones do
			local milestone = Milestones.ById[id]
			if milestone then
				table.insert(names, milestone.Text)
			end
		end
		line(body, `★ Milestones: {table.concat(names, "  ·  ")}`, 5, { TextColor3 = UI.Colors.Gold, TextSize = 13 })
	end
	local mine = if type(data.Mine) == "table" then data.Mine else {}
	local did = {}
	local function add(count: any, words: string)
		if type(count) == "number" and count > 0 then
			table.insert(did, `{math.floor(count)} {words}`)
		end
	end
	add(data.Knockouts, "monsters bopped")
	add(mine.Gathered, "things dropped off")
	add(mine.Fed, "flame fed to the hearth")
	add(mine.Built, "things built")
	add(mine.Repaired, "repairs")
	add(mine.Thaws, "friends thawed")
	add(mine.Freed, "radio parts freed")
	add(mine.Fitted, "radio parts fitted")
	line(
		body,
		if #did > 0 then `Your run: {table.concat(did, " · ")}.` else "Your run: you were there for the finish!",
		8,
		{ TextColor3 = UI.Colors.Muted }
	)
	line(body, `+{data.Flakes} ❄ snowflakes   ·   +{data.Xp} pass XP`, 9, {
		Font = UI.Title,
		TextSize = 20,
		TextColor3 = UI.Colors.Ice,
	})
	if type(data.Given) == "table" and #data.Given > 0 then
		line(body, `🎁 Unlocked: {table.concat(data.Given, ", ")}`, 10, { TextColor3 = UI.Colors.Gold })
	end
	if data.Late then
		line(
			body,
			`You joined late, so the win bonus needs {Balance.Rewards.WinMinNights} nights. Stay for the next run!`,
			11,
			{
				TextSize = 13,
				TextColor3 = UI.Colors.Muted,
			}
		)
	end
	if type(data.NextGoal) == "string" and data.NextGoal ~= "" then
		line(body, `Next: {data.NextGoal}`, 12, { TextColor3 = UI.Colors.Warm })
	end
	line(body, "A new run starts in a moment. Spend snowflakes in the Shop!", 13, {
		TextSize = 12,
		TextColor3 = UI.Colors.Muted,
	})
	window.open()
	Corner.banner(if data.Won then "RESCUED!" else "SNOWED UNDER", if data.Won then UI.Colors.Good else UI.Colors.Ice)
end

function Results.mount()
	local gui = UI.screen("Results", 6)
	window = UI.window(gui, "Results", "", Vector2.new(520, 400))
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Results").OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			show(data)
		end
	end)
	local State = ReplicatedStorage:WaitForChild("State")
	State:GetAttributeChangedSignal("Phase"):Connect(function()
		if State:GetAttribute("Phase") == "Day" and window.isOpen() then
			window.close()
		end
	end)
end

return Results
