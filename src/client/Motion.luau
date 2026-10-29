-- Moves what the theme marks to move: models tagged Float bob and turn,
-- ones tagged Patrol glide out and back, ones tagged Pop jump up now and
-- then, ghost trains tagged Train run round their tracks (each car by its
-- Order, so a path can add cars to the end), big wheels tagged Wheel turn
-- with their gondolas hanging level, and lights tagged Flicker flicker. The
-- server builds them still; all of the motion is drawn on this client only,
-- so it costs no network traffic. Anything far from the camera is left
-- alone.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NEAR = 350
local FLICKER_STEP = 1 / 20

type Floater = { Base: CFrame, Height: number, Seconds: number, Spin: number, Axis: Vector3, Phase: number }
type Patroller = { Base: CFrame, Offset: Vector3, Seconds: number, Phase: number }
type Popper = { Base: CFrame, Height: number, Seconds: number, Phase: number }

local Motion = {}

local floaters: { [Model]: Floater } = {}
local patrollers: { [Model]: Patroller } = {}
local poppers: { [Model]: Popper } = {}
local trains: { [Model]: { Model } } = {}
local wheels: { [Model]: { Rim: Model?, Gondolas: { Model } } } = {}
local flickers: { [Light]: number } = {}
local sinceFlicker = 0

-- Calls added for everything with the tag, now and later, and removed when
-- it goes, such as when it streams out.
local function watch(tag: string, added: (any) -> (), removed: (any) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(added, instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(removed)
end

-- Spread out by position, so neighbouring plots don't move in step.
local function phaseOf(base: CFrame): number
	return (base.X * 0.37 + base.Z * 0.23) % 10
end

local function addFloater(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local base = model:GetPivot()
	floaters[model] = {
		Base = base,
		Height = model:GetAttribute("FloatHeight") or 0,
		Seconds = math.max(model:GetAttribute("FloatSeconds") or 1, 0.1),
		Spin = model:GetAttribute("SpinSeconds") or 0,
		Axis = model:GetAttribute("SpinAxis") or Vector3.yAxis,
		Phase = phaseOf(base),
	}
end

local function addPatroller(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local base = model:GetPivot()
	patrollers[model] = {
		Base = base,
		Offset = model:GetAttribute("PatrolOffset") or Vector3.zero,
		Seconds = math.max(model:GetAttribute("PatrolSeconds") or 8, 0.5),
		Phase = phaseOf(base),
	}
end

local function addPopper(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local base = model:GetPivot()
	poppers[model] = {
		Base = base,
		Height = model:GetAttribute("PopHeight") or 1,
		Seconds = math.max(model:GetAttribute("PopSeconds") or 5, 1),
		Phase = phaseOf(base),
	}
end

local function addTrain(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local cars = {}
	for _, car in model:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("Order") then
			table.insert(cars, car)
		end
	end
	table.sort(cars, function(a, b)
		return a:GetAttribute("Order") < b:GetAttribute("Order")
	end)
	trains[model] = cars
end

local function addWheel(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local gondolas = {}
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Seat") then
			table.insert(gondolas, child)
		end
	end
	local rim = model:FindFirstChild("Rim")
	wheels[model] = { Rim = if rim and rim:IsA("Model") then rim else nil, Gondolas = gondolas }
end

local function addFlicker(light: Instance)
	if light:IsA("Light") then
		flickers[light] = light.Brightness
	end
end

local function near(position: Vector3, camera: Camera): boolean
	return (position - camera.CFrame.Position).Magnitude < NEAR
end

local function onRenderStep(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = Workspace:GetServerTimeNow()

	for model, float in floaters do
		if near(float.Base.Position, camera) then
			local t = now + float.Phase
			local bob = math.sin(t / float.Seconds * math.pi * 2) * float.Height / 2
			local turn = if float.Spin ~= 0 then t / float.Spin * math.pi * 2 else 0
			model:PivotTo(float.Base * CFrame.new(0, bob, 0) * CFrame.fromAxisAngle(float.Axis, turn))
		end
	end

	for model, patrol in patrollers do
		if near(patrol.Base.Position, camera) then
			-- Out and back, easing at each end, turned the way it's going.
			local turn = (now + patrol.Phase) / patrol.Seconds * math.pi * 2
			local along = (1 - math.cos(turn)) / 2
			local heading = patrol.Offset * (if math.sin(turn) >= 0 then 1 else -1)
			local spot = patrol.Base * CFrame.new(patrol.Offset * along + Vector3.new(0, math.sin(turn * 4) * 0.2, 0))
			local facing = patrol.Base:VectorToWorldSpace(heading)
			model:PivotTo(
				if facing.Magnitude > 0.01 then CFrame.lookAt(spot.Position, spot.Position - facing) else spot
			)
		end
	end

	for model, pop in poppers do
		if near(pop.Base.Position, camera) then
			-- Up fast, a moment's stare, then back down to wait.
			local t = (now + pop.Phase) % pop.Seconds
			local up = if t < 0.15 then t / 0.15 elseif t < 0.9 then 1 elseif t < 1.3 then 1 - (t - 0.9) / 0.4 else 0
			model:PivotTo(pop.Base * CFrame.new(0, pop.Height * math.sin(up * math.pi / 2), 0))
		end
	end

	for model, cars in trains do
		local centre = model:GetAttribute("TrackCentre")
		if centre and near(centre.Position, camera) then
			local radiusX, radiusZ = model:GetAttribute("RadiusX") or 1, model:GetAttribute("RadiusZ") or 1
			local lap, gap = model:GetAttribute("LapSeconds") or 10, model:GetAttribute("Gap") or 0.5
			local lead = now / lap * math.pi * 2
			for index, car in cars do
				local angle = lead - ((car:GetAttribute("Order") or index) - 1) * gap
				local spot =
					centre:PointToWorldSpace(Vector3.new(math.cos(angle) * radiusX, 0, math.sin(angle) * radiusZ))
				local heading =
					centre:VectorToWorldSpace(Vector3.new(-math.sin(angle) * radiusX, 0, math.cos(angle) * radiusZ))
				car:PivotTo(CFrame.lookAt(spot, spot + heading))
			end
		end
	end

	for model, wheel in wheels do
		local centre = model:GetAttribute("Centre")
		if centre and near(centre.Position, camera) then
			local radius = model:GetAttribute("Radius") or 1
			local turn = -now / (model:GetAttribute("LapSeconds") or 60) * math.pi * 2
			if wheel.Rim then
				wheel.Rim:PivotTo(centre * CFrame.Angles(0, 0, turn))
			end
			local count = #wheel.Gondolas
			for _, gondola in wheel.Gondolas do
				local angle = turn + (gondola:GetAttribute("Seat") or 0) / count * math.pi * 2
				local spot =
					centre:PointToWorldSpace(Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0))
				gondola:PivotTo(CFrame.new(spot) * centre.Rotation)
			end
		end
	end

	sinceFlicker += dt
	if sinceFlicker >= FLICKER_STEP then
		sinceFlicker = 0
		for light, brightness in flickers do
			local parent = light.Parent
			if parent and parent:IsA("BasePart") and near(parent.Position, camera) then
				local seed = parent.Position.X + parent.Position.Z
				light.Brightness = brightness * (1 + math.noise(now * 4, seed) * 0.6)
			end
		end
	end
end

function Motion.start()
	watch("Float", addFloater, function(model)
		floaters[model] = nil
	end)
	watch("Patrol", addPatroller, function(model)
		patrollers[model] = nil
	end)
	watch("Pop", addPopper, function(model)
		poppers[model] = nil
	end)
	watch("Train", addTrain, function(model)
		trains[model] = nil
	end)
	watch("Wheel", addWheel, function(model)
		wheels[model] = nil
	end)
	watch("Flicker", addFlicker, function(light)
		flickers[light] = nil
	end)
	RunService.RenderStepped:Connect(onRenderStep)
end

-- Whether something moves on its own here, so other effects leave its
-- position alone.
function Motion.moves(instance: Instance): boolean
	local current: Instance? = instance
	while current do
		if
			current:HasTag("Float")
			or current:HasTag("Patrol")
			or current:HasTag("Pop")
			or current:HasTag("Train")
			or current:HasTag("Wheel")
		then
			return true
		end
		current = current.Parent
	end
	return false
end

return Motion
