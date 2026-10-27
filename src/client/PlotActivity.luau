-- Makes every plot look busy: goods travel along the production chain and
-- visitors walk to the stall and the attractions, at rates the server
-- publishes as attributes. On the player's own plot, rides also show a
-- countdown and each round's takings. All of it is cosmetic and exists only
-- on this client; the server decides and pays for everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Layout = require(Shared.Config.Layout)
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Format)

-- Shown rates are capped so a busy plot stays readable and cheap to draw.
local MAX_GOODS_PER_SECOND = 1.5
local MAX_VISITORS_PER_SECOND = 0.6
local MAX_VISITORS_PER_PLOT = 10
local GOODS_SPEED = 10
local WALK_SPEED = 7
local STALL_PAUSE = 1.2
local ATTRACTION_PAUSE = 2.5
local PAYOUT_SECONDS = 1.5

type Mover = {
	Instance: PVInstance,
	Plot: BasePart,
	IsVisitor: boolean,
	Points: { Vector3 },
	Pauses: { number },
	Index: number,
	Position: Vector3,
	Wait: number,
	Speed: number,
}

local PlotActivity = {}

local player = Players.LocalPlayer
local random = Random.new()
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

local function makeBit(size: Vector3, color: Color3, shape: Enum.PartType, parent: Instance): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function addMover(mover: Mover)
	mover.Instance:PivotTo(CFrame.new(mover.Position))
	mover.Instance.Parent = folder
	table.insert(movers, mover)
	if mover.IsVisitor then
		visitorCount[mover.Plot] = (visitorCount[mover.Plot] or 0) + 1
	end
end

local function spawnGood(plot: BasePart, item: string, points: { Vector3 })
	local themed = Theme.Items[item]
	local color = if themed then Color3.fromHex(themed.Color) else Color3.new(1, 1, 1)
	local part = makeBit(Vector3.new(1.2, 1.2, 1.2), color, Enum.PartType.Ball, folder)
	addMover({
		Instance = part,
		Plot = plot,
		IsVisitor = false,
		Points = points,
		Pauses = {},
		Index = 2,
		Position = points[1],
		Wait = 0,
		Speed = GOODS_SPEED,
	})
end

local function spawnVisitor(plot: BasePart, stallId: string?, attractionIds: { string })
	local colors = Theme.VisitorColors
	local model = Instance.new("Model")
	local body = makeBit(
		Vector3.new(1.4, 2.6, 1.4),
		Color3.fromHex(colors[random:NextInteger(1, #colors)]),
		Enum.PartType.Block,
		model
	)
	local head = makeBit(Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(240, 220, 200), Enum.PartType.Ball, model)
	head.CFrame = body.CFrame * CFrame.new(0, 1.9, 0)
	model.PrimaryPart = body

	local half = Layout.PlotSize / 2
	local lift = 1.3
	local points = { onPlot(plot, random:NextNumber(-14, 14), half - 1, lift) }
	local pauses = { 0 }
	if stallId then
		table.insert(points, frontOf(plot, stallId, lift))
		table.insert(pauses, STALL_PAUSE)
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
		Wait = 0,
		Speed = WALK_SPEED,
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
		for _ = 1, due(kitchen, kitchenTakes, dt, MAX_GOODS_PER_SECOND) do
			spawnGood(plot, item, { frontOf(plot, kitchen.Name, lift), behind(plot, stall.Name, lift) })
		end
	end

	local visitors = plot:GetAttribute("VisitorsPerSecond") or 0
	for _ = 1, due(plot, visitors, dt, MAX_VISITORS_PER_SECOND) do
		if (visitorCount[plot] or 0) < MAX_VISITORS_PER_PLOT then
			spawnVisitor(plot, stall.Name, attractionIds)
		end
	end
end

local function moveAll(dt: number)
	for index = #movers, 1, -1 do
		local mover = movers[index]
		if mover.Wait > 0 then
			mover.Wait -= dt
			continue
		end
		local target = mover.Points[mover.Index]
		local offset = target - mover.Position
		local step = mover.Speed * dt
		if step >= offset.Magnitude then
			mover.Position = target
			mover.Wait = mover.Pauses[mover.Index] or 0
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
		if facing.Magnitude > 0.01 then
			mover.Instance:PivotTo(CFrame.lookAt(mover.Position, mover.Position + facing))
		else
			mover.Instance:PivotTo(CFrame.new(mover.Position))
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

local function onHeartbeat(dt: number)
	local plots = Workspace:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			local built = plot:FindFirstChild("Built")
			if plot:IsA("BasePart") and built then
				animatePlot(plot, built, dt)
				if plot:GetAttribute("OwnerUserId") == player.UserId then
					updateRides(built)
				end
			end
		end
	end
	moveAll(dt)
end

function PlotActivity.start()
	playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	folder = Instance.new("Folder")
	folder.Name = "PlotActivity"
	folder.Parent = Workspace
	RunService.Heartbeat:Connect(onHeartbeat)
end

return PlotActivity
