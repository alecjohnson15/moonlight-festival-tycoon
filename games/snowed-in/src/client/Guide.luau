-- The guide: one goal at a time on the corner card nearest the corner, and
-- a marker over where to go with how far it is, so a new player never has
-- to wonder what to do next. It reads the same attributes as the HUD and
-- picks the most urgent thing: being frozen, carrying a radio part home,
-- getting too cold, a hearth about to go out, a full backpack, a friend to
-- thaw, the night's fight, and by day the next step of the run (chop wood,
-- drop it off, feed the fire, then go and find the radio's parts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Map = require(Shared.Config.Map)
local Radio = require(Shared.Radio)
local Corner = require(script.Parent.Corner)
local UI = require(script.Parent.UI)

local State = ReplicatedStorage:WaitForChild("State") :: Configuration

local Guide = {}

export type Goal = {
	Title: string,
	Text: string,
	Target: Vector3?,
	Place: string?,
}

local player = Players.LocalPlayer

local function at(point: { number }): Vector3
	return Vector3.new(point[1], 0, point[2])
end

local HEARTH = at(Map.Hearth)
local STOCKPILE = at(Map.Stockpile)
local WORKBENCH = at(Map.Workbench)
local RADIO = at(Map.RadioTower)

local card: Frame
local titleLabel: TextLabel
local textLabel: TextLabel
local marker: Part
local markerWords: TextLabel
local shown = ""
-- What the player has done this run, for the first day's steps.
local fed = false
local droppedOff = false

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function stock(id: string): number
	return State:GetAttribute(`Stock_{id}`) or 0
end

local function pack(id: string): number
	return player:GetAttribute(`Pack_{id}`) or 0
end

-- The closest gatherable thing of a kind that is standing now.
local function nearestNode(kind: string, from: Vector3): Vector3?
	local town = Workspace:FindFirstChild("Town")
	local nodes = town and town:FindFirstChild("Nodes")
	if not nodes then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, model in nodes:GetChildren() do
		if model:GetAttribute("Node") == kind and model:IsA("Model") then
			local position = model:GetPivot().Position
			local distance = (position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = position, distance
			end
		end
	end
	return best
end

local function frozenFriend(from: Vector3): (Player?, Vector3?)
	local best, bestAt, bestDistance = nil, nil, math.huge
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("Frozen") == true then
			local character = other.Character
			local otherRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if otherRoot then
				local distance = (otherRoot.Position - from).Magnitude
				if distance < bestDistance then
					best, bestAt, bestDistance = other, otherRoot.Position, distance
				end
			end
		end
	end
	return best, bestAt
end

local function loosePart(): (string?, Vector3?)
	local folder = Workspace:FindFirstChild("RadioParts")
	if not folder then
		return nil, nil
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("State") == "Loose" then
			return model:GetAttribute("PartName"), model:GetPivot().Position
		end
	end
	return nil, nil
end

-- The nearest landmark whose radio part is still frozen there.
local function frozenPart(from: Vector3): any
	local best, bestDistance = nil, math.huge
	for _, landmark in Map.Landmarks do
		if (State:GetAttribute(`Part_{landmark.Part}`) or "Frozen") == "Frozen" then
			local distance = (at(landmark.At) - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = landmark, distance
			end
		end
	end
	return best
end

-- The most urgent thing for this player to do now.
function Guide.goal(): Goal?
	local phase = State:GetAttribute("Phase") or "Waiting"
	local night = State:GetAttribute("Night") or 0
	local me = root()
	local from = if me then me.Position else HEARTH
	local touch = UI.touch()
	local hold = if touch then "Tap and hold" else "Hold E"

	if phase == "Waiting" then
		return { Title = "Welcome to Pinehollow!", Text = "The run starts when a player joins." }
	elseif phase == "Intermission" then
		if (player:GetAttribute("Role") or "") == "" then
			return { Title = "Pick a role", Text = "Choose how you'll help the team survive the blizzard." }
		end
		return {
			Title = "Get ready",
			Text = "Keep the hearth burning for 10 nights, and fix the radio so the rescue train can find you.",
		}
	elseif phase == "Rescue" or phase == "Won" or phase == "Lost" then
		return nil
	end

	if player:GetAttribute("Frozen") == true then
		return { Title = "Frozen!", Text = "Hang on: a friend can thaw you, or you'll wake up by the hearth." }
	end
	local carrying = player:GetAttribute("Carrying") or ""
	if carrying ~= "" then
		return {
			Title = "Take it to the radio",
			Text = "Carry the part to the radio tower. Monsters chase whoever carries it!",
			Target = RADIO,
			Place = "Radio tower",
		}
	end
	local warmth = player:GetAttribute("Warmth") or 100
	if warmth < 35 then
		local food = player:GetAttribute("Food") or ""
		return {
			Title = "You're freezing!",
			Text = if food ~= ""
				then `Eat something ({if touch then "tap your food" else "press G"}) or get back to the hearth.`
				else "Get back to the hearth's warm glow, or stand by a campfire or lantern.",
			Target = HEARTH,
			Place = "Hearth",
		}
	end

	local flame = State:GetAttribute("Flame") or 0
	local max = State:GetAttribute("MaxFlame") or 100
	local fuel = stock("Wood") + stock("Coal")
	if flame / max < 0.3 then
		if fuel > 0 then
			return {
				Title = "The hearth is low!",
				Text = `{hold} at the hearth to feed it from the stockpile.`,
				Target = HEARTH,
				Place = "Hearth",
			}
		elseif pack("Wood") + pack("Coal") > 0 then
			return {
				Title = "The hearth is low!",
				Text = "Drop your wood at the stockpile, then feed the hearth.",
				Target = STOCKPILE,
				Place = "Stockpile",
			}
		end
		local pine = nearestNode("Pine", from)
		return {
			Title = "The hearth is low!",
			Text = `Chop pines for wood ({hold:lower()} on a tree), quick!`,
			Target = pine,
			Place = "Pine",
		}
	end

	local used = player:GetAttribute("PackUsed") or 0
	local size = player:GetAttribute("PackSize") or 20
	if used >= size then
		return {
			Title = "Backpack full",
			Text = "Drop it off at the stockpile so the team can use it.",
			Target = STOCKPILE,
			Place = "Stockpile",
		}
	end

	local friend, friendAt = frozenFriend(from)
	if friend and friendAt then
		return {
			Title = `Thaw {friend.DisplayName}!`,
			Text = `{hold} on their block of ice to thaw them out.`,
			Target = friendAt,
			Place = friend.DisplayName,
		}
	end

	if phase == "Dusk" or phase == "Night" then
		local radius = State:GetAttribute("HearthRadius") or 30
		local far = (Vector3.new(from.X, 0, from.Z) - HEARTH).Magnitude > radius + 30
		local tip = State:GetAttribute("TonightTip")
		local name = State:GetAttribute("TonightName")
		local fight = if touch
			then "Stay near the hearth and tap to swing at monsters before they put out the fire."
			else "Stay near the hearth and click to swing at monsters before they put out the fire."
		return {
			Title = if phase == "Dusk"
				then (if type(name) == "string" and name ~= "" then `Tonight: {name}` else "Night is coming!")
				else `Survive night {night}!`,
			Text = if type(tip) == "string" and tip ~= "" then tip else fight,
			Target = if far then HEARTH else nil,
			Place = "Hearth",
		}
	end

	-- Daytime: the next step of the run.
	if used >= size * 0.6 or (used >= 8 and not droppedOff) then
		return {
			Title = "Drop it off",
			Text = "Empty your backpack at the stockpile.",
			Target = STOCKPILE,
			Place = "Stockpile",
		}
	end
	if not fed and fuel > 0 and flame / max < 0.85 then
		return {
			Title = "Feed the hearth",
			Text = `{hold} at the hearth to burn wood from the stockpile. If it goes out, the run is over!`,
			Target = HEARTH,
			Place = "Hearth",
		}
	end
	local name, loose = loosePart()
	if name and loose then
		return {
			Title = `Grab the {name}!`,
			Text = "It's lying in the snow. Pick it up and carry it to the radio tower.",
			Target = loose,
			Place = name,
		}
	end
	-- The first day's team goal: the first hearth upgrade, which pushes the
	-- blizzard back (a milestone a few minutes in).
	local level = State:GetAttribute("HearthLevel") or 1
	local nextLevel = Balance.Hearth.Levels[level + 1]
	if level == 1 and nextLevel and night <= 1 then
		local needWood = (nextLevel.Cost.Wood or 0) - stock("Wood")
		local needStone = (nextLevel.Cost.Stone or 0) - stock("Stone")
		local needs =
			`The team needs {math.max(0, needWood)} more wood and {math.max(0, needStone)} more stone to grow the hearth.`
		if needWood > pack("Wood") then
			return {
				Title = "Grow the hearth: wood",
				Text = `{hold} on a pine tree. {needs}`,
				Target = nearestNode("Pine", from),
				Place = "Pine",
			}
		elseif needStone > pack("Stone") then
			return {
				Title = "Grow the hearth: stone",
				Text = `{hold} on a boulder (most are at the quarry). {needs}`,
				Target = nearestNode("Rock", from),
				Place = "Boulder",
			}
		elseif needWood > 0 or needStone > 0 then
			return {
				Title = "Drop it off",
				Text = "Empty your backpack at the stockpile: that's enough to grow the hearth!",
				Target = STOCKPILE,
				Place = "Stockpile",
			}
		end
		return {
			Title = "Grow the hearth!",
			Text = `{hold} on "Build up the hearth" at the hearth. It pushes the blizzard back and warms a wider circle.`,
			Target = HEARTH,
			Place = "Hearth",
		}
	end
	if stock("Wood") < 15 and fuel < 25 then
		return {
			Title = "Chop some wood",
			Text = `{hold} on a pine tree. Wood keeps the hearth burning and builds walls.`,
			Target = nearestNode("Pine", from),
			Place = "Pine",
		}
	end
	local landmark = frozenPart(from)
	local help = State:GetAttribute("RadioHelp") == true
	if landmark and (night >= 1 or fed or help) then
		return {
			Title = `Find the {landmark.PartName}`,
			Text = `At the {landmark.Name}. {Radio.hint(landmark)}`,
			Target = at(landmark.At),
			Place = landmark.Name,
		}
	end
	return {
		Title = "Get ready for the night",
		Text = if touch
			then "Craft at the workbench, build walls and lanterns (Build button), and cook at the pot."
			else "Craft at the workbench, build walls and lanterns (press B), and cook at the pot.",
		Target = if (from - WORKBENCH).Magnitude > 60 then WORKBENCH else nil,
		Place = "Workbench",
	}
end

local function makeMarker()
	marker = Instance.new("Part")
	marker.Name = "GuideMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	local board = Instance.new("BillboardGui")
	board.AlwaysOnTop = true
	board.Size = UDim2.fromOffset(160, 54)
	board.StudsOffset = Vector3.new(0, 8, 0)
	board.LightInfluence = 0
	board.Parent = marker
	markerWords = UI.label(board, "", {
		Size = UDim2.fromScale(1, 1),
		Font = UI.Title,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = UI.Colors.Warm,
		TextStrokeTransparency = 0.3,
	})
	marker.Parent = Workspace
end

local function refresh()
	local goal = Guide.goal()
	if not goal then
		card.Visible = false
		shown = ""
		marker.Parent = nil
		return
	end
	local key = goal.Title .. goal.Text
	titleLabel.Text = goal.Title
	textLabel.Text = goal.Text
	if key ~= shown then
		shown = key
		Corner.pop(card)
	end
	local me = root()
	if goal.Target and me then
		local distance = (Vector3.new(me.Position.X, 0, me.Position.Z) - Vector3.new(goal.Target.X, 0, goal.Target.Z)).Magnitude
		if distance > 14 then
			marker.Position = goal.Target
			markerWords.Text = `⬇\n{goal.Place or ""} · {math.floor(distance)}m`
			marker.Parent = Workspace
			return
		end
	end
	marker.Parent = nil
end

function Guide.mount()
	card = Corner.card(Corner.Order.Goal, UI.Colors.Warm)
	titleLabel = Corner.title(card, { TextColor3 = UI.Colors.Warm })
	textLabel = Corner.line(card)
	makeMarker()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, data)
		if type(data) ~= "table" then
			return
		end
		if kind == "Feed" and data.By == player.UserId then
			fed = true
		elseif kind == "Deposit" and data.By == player.UserId then
			droppedOff = true
		end
	end)
	State:GetAttributeChangedSignal("Phase"):Connect(function()
		if State:GetAttribute("Phase") == "Intermission" then
			fed, droppedOff = false, false
		end
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.4)
		end
	end)
end

return Guide
