-- Makes every plot look busy: goods travel along the production chain and
-- visitors in costume walk to the stall and the attractions, at rates the
-- server publishes as attributes. On the way, a visitor may stop at one of
-- the places a path has marked (Kit.stop): they turn to face it, sit, jump
-- or cheer while they wait, and leave carrying what it gave them. A path can
-- also make a building's goods glow as they leave it (GoodsGlow). On the player's own plot, buy buttons glow and
-- pulse when the player can pay for them and turn red when they can't, and
-- rides show a countdown and each round's takings. All of it is cosmetic and
-- exists only on this client; the server decides and pays for everything.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Layout = require(Shared.Config.Layout)
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Format)
local Kit = require(Shared.Kit)
local Sounds = require(script.Parent.Sounds)

-- Shown rates are capped so a busy plot stays readable and cheap to draw.
local MAX_GOODS_PER_SECOND = 1.5
local MAX_VISITORS_PER_SECOND = 0.6
local MAX_VISITORS_PER_PLOT = 10
local GOODS_SPEED = 10
local WALK_SPEED = 7
local STALL_PAUSE = 1.2
local ATTRACTION_PAUSE = 2.5
local PAYOUT_SECONDS = 1.5
local AFFORDABLE = Color3.fromRGB(76, 175, 80)
local AFFORDABLE_PEAK = Color3.fromRGB(190, 255, 150)
local UNAFFORDABLE = Color3.fromRGB(150, 50, 50)
local PRICE_READY = Color3.fromRGB(255, 214, 102)
local PRICE_SHORT = Color3.fromRGB(255, 160, 160)
local PULSES_PER_SECOND = 1.2
-- Walkers hop along; floaters (ghosts) hover and bob.
local HOPS_PER_SECOND = 2.5
local HOP_HEIGHT = 0.3
local HOVER_HEIGHT = 0.6
-- Movers further than this from the camera keep moving but aren't redrawn.
local DRAW_DISTANCE = 250
-- A visitor stop's chance of being used, when it doesn't say.
local STOP_CHANCE = 0.6
-- Where a visitor holds what they carry, from their feet.
local HAND = CFrame.new(0.75, 1.5, -0.45)

-- What a visitor does on reaching one of their points.
type Arrival = { Pose: string?, Carry: string?, Facing: Vector3 }

type Mover = {
	Instance: Model,
	Plot: BasePart,
	IsVisitor: boolean,
	Points: { Vector3 },
	Pauses: { number },
	Index: number,
	Position: Vector3,
	Facing: CFrame,
	Wait: number,
	Speed: number,
	Gait: string?,
	Phase: number,
	-- By point index, what to do there.
	Arrivals: { [number]: Arrival }?,
	Pose: string?,
	PoseAt: number,
	Carrying: boolean?,
}

local PlotActivity = {}

local player = Players.LocalPlayer
local random = Random.new()
local crowdRandom = Kit.random(random:NextInteger(1, 2 ^ 30))
local upgradesById = {}
for _, upgrade in Balance.Upgrades do
	upgradesById[upgrade.Id] = upgrade
end

local folder: Folder
local playerGui: PlayerGui
local movers: { Mover } = {}
local visitorCount: { [BasePart]: number } = {}
-- Fractional goods or visitors owed to each station or plot, between frames.
local owed: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local rideStatus: { [Instance]: BillboardGui } = {}
-- Each plot's visitor stops, found again whenever stops come or go.
local stopsByPlot: { [BasePart]: { Attachment } } = {}
local lastPayoutAt: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

-- A point above the plot's surface, from plot-local X and Z.
local function onPlot(plot: BasePart, x: number, z: number, lift: number): Vector3
	return (plot.CFrame * CFrame.new(x, plot.Size.Y / 2 + lift, z)).Position
end

-- Just in front of (towards the plaza) or behind a station's slot.
local function frontOf(plot: BasePart, id: string, lift: number): Vector3
	local slot = Layout.Slots[id]
	return onPlot(plot, slot.X, slot.Z + slot.Size[3] / 2 + 2, lift)
end

local function behind(plot: BasePart, id: string, lift: number): Vector3
	local slot = Layout.Slots[id]
	return onPlot(plot, slot.X, slot.Z - slot.Size[3] / 2 - 1, lift)
end

local function beside(plot: BasePart, id: string, lift: number): Vector3
	local slot = Layout.Slots[id]
	return onPlot(plot, slot.X + slot.Size[1] / 2 + 2, slot.Z, lift)
end

local function anchorOf(station: Instance): BasePart?
	if station:IsA("BasePart") then
		return station
	elseif station:IsA("Model") then
		return station.PrimaryPart or station:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function addMover(mover: Mover)
	mover.Instance:PivotTo(mover.Facing)
	mover.Instance.Parent = folder
	table.insert(movers, mover)
	if mover.IsVisitor then
		visitorCount[mover.Plot] = (visitorCount[mover.Plot] or 0) + 1
	end
end

local function spawnGood(plot: BasePart, item: string, points: { Vector3 }, glow: Color3?)
	local model = Theme.Crowd.good(item)
	if glow then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Material = Enum.Material.Neon
				part.Color = part.Color:Lerp(glow, 0.6)
			end
		end
	end
	addMover({
		Instance = model,
		Plot = plot,
		IsVisitor = false,
		Points = points,
		Pauses = {},
		Index = 2,
		Position = points[1],
		Facing = CFrame.new(points[1]),
		Wait = 0,
		Speed = GOODS_SPEED,
		Phase = 0,
		PoseAt = 0,
	})
end

local function stopsOn(plot: BasePart): { Attachment }
	local cached = stopsByPlot[plot]
	if cached then
		return cached
	end
	local list = {}
	for _, stop in CollectionService:GetTagged("VisitorStop") do
		if stop:IsA("Attachment") and stop:IsDescendantOf(plot) then
			table.insert(list, stop)
		end
	end
	stopsByPlot[plot] = list
	return list
end

-- Sends a visitor to a stop and back out: round the front of the building
-- it belongs to, so they don't walk through it.
local function addStop(
	plot: BasePart,
	stop: Attachment,
	mover: { Points: { Vector3 }, Pauses: { number }, Arrivals: { [number]: Arrival } }
)
	local built = plot:FindFirstChild("Built")
	local station: Instance? = stop
	while station and station.Parent ~= built do
		station = station.Parent
	end
	local slot = station and Layout.Slots[station.Name]
	if not slot then
		return
	end
	local at = stop.WorldCFrame
	local spot = plot.CFrame:PointToObjectSpace(at.Position)
	local approach = onPlot(plot, spot.X, slot.Z + slot.Size[3] / 2 + 2, 0)
	table.insert(mover.Points, approach)
	table.insert(mover.Pauses, 0)
	table.insert(mover.Points, at.Position)
	table.insert(mover.Pauses, stop:GetAttribute("Pause") or STALL_PAUSE)
	mover.Arrivals[#mover.Points] = {
		Pose = stop:GetAttribute("Pose"),
		Carry = stop:GetAttribute("Carry"),
		Facing = at.LookVector,
	}
	table.insert(mover.Points, approach)
	table.insert(mover.Pauses, 0)
end

local function spawnVisitor(plot: BasePart, stallId: string?, attractionIds: { string })
	-- Visitors in costume, standing on the floor.
	local model = Theme.Crowd.visitor(crowdRandom)
	local half = Layout.PlotSize / 2
	local lift = 0
	local points = { onPlot(plot, random:NextNumber(-14, 14), half - 1, lift) }
	local pauses = { 0 }
	local arrivals = {}
	if stallId then
		table.insert(points, frontOf(plot, stallId, lift))
		table.insert(pauses, STALL_PAUSE)
	end
	local stops = stopsOn(plot)
	if #stops > 0 then
		local stop = stops[random:NextInteger(1, #stops)]
		if stop.Parent and random:NextNumber() < (stop:GetAttribute("Chance") or STOP_CHANCE) then
			addStop(plot, stop, { Points = points, Pauses = pauses, Arrivals = arrivals })
		end
	end
	if #attractionIds > 0 then
		table.insert(points, frontOf(plot, attractionIds[random:NextInteger(1, #attractionIds)], lift))
		table.insert(pauses, ATTRACTION_PAUSE)
	end
	table.insert(points, onPlot(plot, random:NextNumber(-14, 14), half - 1, lift))
	table.insert(pauses, 0)

	addMover({
		Instance = model,
		Plot = plot,
		IsVisitor = true,
		Points = points,
		Pauses = pauses,
		Index = 2,
		Position = points[1],
		Facing = CFrame.new(points[1]),
		Wait = 0,
		Speed = WALK_SPEED,
		Gait = model:GetAttribute("Gait"),
		Phase = random:NextNumber(0, 10),
		Arrivals = arrivals,
		PoseAt = 0,
	})
end

-- Adds rate * dt to what a station or plot is owed and returns how many
-- whole things to spawn now.
local function due(key: Instance, rate: number, dt: number, cap: number): number
	local total = (owed[key] or 0) + math.min(rate, cap) * dt
	local whole = math.floor(total)
	owed[key] = total - whole
	return whole
end

local function animatePlot(plot: BasePart, built: Instance, dt: number)
	local stall: Instance?, kitchen: Instance?
	local growers, attractionIds = {}, {}
	for _, station in built:GetChildren() do
		local kind = station:GetAttribute("Kind")
		if kind == "Stall" then
			stall = stall or station
		elseif kind == "Kitchen" then
			kitchen = kitchen or station
		elseif kind == "Grower" then
			table.insert(growers, station)
		elseif kind == "Attraction" then
			table.insert(attractionIds, station.Name)
		end
	end
	if not stall then
		return
	end

	local lift = 0.8
	local kitchenTakes = kitchen and (kitchen:GetAttribute("InPerSecond") or 0) or 0
	for _, grower in growers do
		local made = grower:GetAttribute("OutPerSecond") or 0
		local item = upgradesById[grower.Name].Makes
		for _ = 1, due(grower, made, dt, MAX_GOODS_PER_SECOND) do
			-- Send the kitchen its share; the rest goes round it to the stall.
			if kitchen and made > 0 and random:NextNumber() < kitchenTakes / made then
				spawnGood(plot, item, { frontOf(plot, grower.Name, lift), behind(plot, kitchen.Name, lift) })
			elseif kitchen then
				spawnGood(plot, item, {
					frontOf(plot, grower.Name, lift),
					beside(plot, kitchen.Name, lift),
					behind(plot, stall.Name, lift),
				})
			else
				spawnGood(plot, item, { frontOf(plot, grower.Name, lift), behind(plot, stall.Name, lift) })
			end
		end
	end
	if kitchen then
		local item = upgradesById[kitchen.Name].Makes
		local glow = nil
		for _, addOn in kitchen:GetChildren() do
			glow = glow or addOn:GetAttribute("GoodsGlow")
		end
		for _ = 1, due(kitchen, kitchenTakes, dt, MAX_GOODS_PER_SECOND) do
			spawnGood(plot, item, { frontOf(plot, kitchen.Name, lift), behind(plot, stall.Name, lift) }, glow)
		end
	end

	local visitors = plot:GetAttribute("VisitorsPerSecond") or 0
	for _ = 1, due(plot, visitors, dt, MAX_VISITORS_PER_SECOND) do
		if (visitorCount[plot] or 0) < MAX_VISITORS_PER_PLOT then
			spawnVisitor(plot, stall.Name, attractionIds)
		end
	end
end

-- How a visitor at a stop sits, jumps or cheers, from where they stand.
local function posed(mover: Mover): CFrame
	local t = os.clock() - mover.PoseAt
	if mover.Pose == "Sit" then
		return CFrame.new(0, -0.5, 0)
	elseif mover.Pose == "Jump" then
		-- One fright, straight up, with a shake.
		local up = if t < 0.5 then math.sin(t / 0.5 * math.pi) * 1.4 else 0
		return CFrame.new(0, up, 0) * CFrame.Angles(0, 0, if t < 0.8 then math.sin(t * 40) * 0.08 else 0)
	elseif mover.Pose == "Cheer" then
		return CFrame.new(0, math.abs(math.sin(t * 7)) * 0.4, 0)
	end
	return CFrame.identity
end

-- Where a mover is drawn: where it is, turned the way it's going, with a hop
-- in its step or a hover, and its pose at a stop.
local function pose(mover: Mover, walking: boolean): CFrame
	local t = os.clock() + mover.Phase
	local at = mover.Facing
	if mover.Pose and not walking then
		at *= posed(mover)
	end
	if mover.Gait == "Float" then
		local bob = math.sin(t * 2.2) * 0.25
		return at * CFrame.new(0, HOVER_HEIGHT + bob, 0) * CFrame.Angles(0, 0, math.sin(t * 1.3) * 0.06)
	elseif mover.Gait == "Hop" and walking then
		local step = math.sin(t * HOPS_PER_SECOND * math.pi)
		return at * CFrame.new(0, math.abs(step) * HOP_HEIGHT, 0) * CFrame.Angles(0, 0, step * 0.1)
	end
	return at
end

-- Turns a visitor to face a stop they've reached, starts their pose and
-- hands them what it gives.
local function arrive(mover: Mover, arrival: Arrival)
	local facing = Vector3.new(arrival.Facing.X, 0, arrival.Facing.Z)
	if facing.Magnitude > 0.01 then
		mover.Facing = CFrame.lookAt(mover.Position, mover.Position + facing)
	end
	mover.Pose = arrival.Pose
	mover.PoseAt = os.clock()
	if arrival.Carry and not mover.Carrying then
		local item = Theme.Crowd.carry(arrival.Carry)
		if item then
			item:PivotTo(mover.Facing * HAND)
			item.Parent = mover.Instance
			mover.Carrying = true
		end
	end
end

local function moveAll(dt: number)
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for index = #movers, 1, -1 do
		local mover = movers[index]
		local walking = mover.Wait <= 0
		if walking then
			local target = mover.Points[mover.Index]
			local offset = target - mover.Position
			local step = mover.Speed * dt
			local arrival = nil
			if step >= offset.Magnitude then
				mover.Position = target
				mover.Wait = mover.Pauses[mover.Index] or 0
				arrival = mover.Arrivals and mover.Arrivals[mover.Index]
				mover.Index += 1
				if mover.Index > #mover.Points then
					mover.Instance:Destroy()
					table.remove(movers, index)
					if mover.IsVisitor then
						visitorCount[mover.Plot] = (visitorCount[mover.Plot] or 1) - 1
					end
					continue
				end
			else
				mover.Position += offset.Unit * step
			end
			local facing = Vector3.new(offset.X, 0, offset.Z)
			mover.Facing = if facing.Magnitude > 0.01
				then CFrame.lookAt(mover.Position, mover.Position + facing)
				else mover.Facing.Rotation + mover.Position
			if arrival then
				mover.Instance:PivotTo(mover.Facing)
				arrive(mover, arrival)
			end
		else
			mover.Wait -= dt
			if mover.Wait <= 0 then
				mover.Pose = nil
			elseif mover.Gait ~= "Float" and not mover.Pose then
				-- Standing still: nothing to redraw.
				continue
			end
		end
		if (mover.Position - eye).Magnitude < DRAW_DISTANCE then
			-- Lands from its hop as soon as it stops.
			mover.Instance:PivotTo(pose(mover, mover.Wait <= 0))
		end
	end
end

local function makeBillboard(anchor: BasePart, height: number, color: Color3): (BillboardGui, TextLabel)
	local billboard = Instance.new("BillboardGui")
	-- Kept through respawns; these are cleaned up when their station goes.
	billboard.ResetOnSpawn = false
	billboard.Adornee = anchor
	billboard.Size = UDim2.fromOffset(180, 32)
	billboard.StudsOffset = Vector3.new(0, height, 0)
	billboard.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
	billboard.Parent = playerGui
	return billboard, label
end

local function showPayout(anchor: BasePart, height: number, coins: number)
	local billboard, label = makeBillboard(anchor, height, Color3.fromRGB(255, 214, 102))
	label.Text = Theme.Strings.Payout:format(Format.rate(coins))
	Sounds.play("Payout")
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = (os.clock() - started) / PAYOUT_SECONDS
		if t >= 1 or not anchor.Parent then
			connection:Disconnect()
			billboard:Destroy()
			return
		end
		billboard.StudsOffset = Vector3.new(0, height + t * 4, 0)
		label.TextTransparency = t
		label.TextStrokeTransparency = 0.3 + t * 0.7
	end)
end

-- Countdown and takings over the rides on the player's own plot.
local function updateRides(built: Instance)
	for _, station in built:GetChildren() do
		if station:GetAttribute("Type") == "Ride" then
			local anchor = anchorOf(station)
			local slot = Layout.Slots[station.Name]
			if anchor and slot then
				local height = slot.Size[2] / 2 + 7
				local billboard = rideStatus[station]
				if not billboard then
					billboard = makeBillboard(anchor, height, Color3.new(1, 1, 1))
					rideStatus[station] = billboard
				end
				local label = billboard:FindFirstChildOfClass("TextLabel") :: TextLabel
				local nextRoundAt = station:GetAttribute("NextRoundAt")
				if nextRoundAt then
					local seconds = math.max(0, math.ceil(nextRoundAt - Workspace:GetServerTimeNow()))
					label.Text = Theme.Strings.RideNext:format(Format.rate(seconds))
				end

				local payoutAt = station:GetAttribute("PayoutAt")
				if payoutAt and payoutAt ~= lastPayoutAt[station] then
					if lastPayoutAt[station] ~= nil then
						showPayout(anchor, height + 2, station:GetAttribute("LastPayout") or 0)
					end
					lastPayoutAt[station] = payoutAt
				elseif not payoutAt then
					lastPayoutAt[station] = 0
				end
			end
		end
	end
	-- Drop countdowns for rides that are gone, such as after the owner left.
	for station, billboard in rideStatus do
		if not station.Parent then
			billboard:Destroy()
			rideStatus[station] = nil
		end
	end
end

local function tintButtons(buttons: Instance)
	local coins = player:GetAttribute("Coins") or 0
	local pulse = (math.sin(os.clock() * PULSES_PER_SECOND * math.pi * 2) + 1) / 2
	for _, button in buttons:GetChildren() do
		local cost = button:GetAttribute("Cost")
		if button:IsA("BasePart") and cost and button:GetAttribute("Sold") == nil then
			local affordable = coins >= cost
			button.Color = if affordable then AFFORDABLE:Lerp(AFFORDABLE_PEAK, pulse) else UNAFFORDABLE
			-- A light under affordable buttons, made here so only the owner
			-- sees it.
			local glow = button:FindFirstChild("Glow") :: PointLight?
			if not glow then
				local light = Instance.new("PointLight")
				light.Name = "Glow"
				light.Color = AFFORDABLE_PEAK
				light.Range = 10
				light.Shadows = false
				light.Parent = button
				glow = light
			end
			local light = glow :: PointLight
			light.Enabled = affordable
			light.Brightness = 1 + pulse * 2
			local billboard = button:FindFirstChild("ButtonLabel")
			local price = billboard and billboard:FindFirstChild("Price")
			if price and price:IsA("TextLabel") then
				price.TextColor3 = if affordable then PRICE_READY else PRICE_SHORT
			end
		end
	end
end

local function onHeartbeat(dt: number)
	local plots = Workspace:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			if plot:IsA("BasePart") then
				local built = plot:FindFirstChild("Built")
				local mine = plot:GetAttribute("OwnerUserId") == player.UserId
				if built then
					animatePlot(plot, built, dt)
					if mine then
						updateRides(built)
					end
				end
				local buttons = plot:FindFirstChild("Buttons")
				if mine and buttons then
					tintButtons(buttons)
				end
			end
		end
	end
	moveAll(dt)
end

function PlotActivity.start()
	playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local function forgetStops()
		table.clear(stopsByPlot)
	end
	CollectionService:GetInstanceAddedSignal("VisitorStop"):Connect(forgetStops)
	CollectionService:GetInstanceRemovedSignal("VisitorStop"):Connect(forgetStops)
	folder = Instance.new("Folder")
	folder.Name = "PlotActivity"
	folder.Parent = Workspace
	RunService.Heartbeat:Connect(onHeartbeat)
end

return PlotActivity
