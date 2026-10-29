-- Moves what the theme marks to move: models tagged Float bob and turn,
-- ones tagged Patrol glide out and back, ones tagged Pop jump up now and
-- then, ghost trains tagged Train run round their tracks (each car by its
-- Order, so a path can add cars to the end, and the lead car wailing once
-- its sound is uploaded), big wheels tagged Wheel turn with their gondolas
-- hanging level, lights tagged Flicker flicker, and heads tagged Watcher
-- turn to follow the player while they're within the head's WatchRadius,
-- with a whisper as they come near. The server builds them still; all of
-- the motion is drawn on this client only, so it costs no network traffic.
-- Anything far from the camera is left alone.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Sounds = require(script.Parent.Sounds)

local NEAR = 350
local FLICKER_STEP = 1 / 20
-- How far a watching head turns either way, how fast it follows, and how
-- long before it whispers again.
local WATCH_TURN = math.rad(75)
local WATCH_RATE = 2.5
local WHISPER_EVERY = 30

type Floater = { Base: CFrame, Height: number, Seconds: number, Spin: number, Axis: Vector3, Phase: number }
type Patroller = { Base: CFrame, Offset: Vector3, Seconds: number, Phase: number }
type Popper = { Base: CFrame, Height: number, Seconds: number, Phase: number }
type Watcher = { Base: CFrame, Radius: number, Turn: number, Near: boolean, WhisperedAt: number }

local Motion = {}

local floaters: { [Model]: Floater } = {}
local patrollers: { [Model]: Patroller } = {}
local poppers: { [Model]: Popper } = {}
local trains: { [Model]: { Model } } = {}
local wails: { [Model]: Sound } = {}
local wheels: { [Model]: { Rim: Model?, Gondolas: { Model } } } = {}
local flickers: { [Light]: number } = {}
local watchers: { [Model]: Watcher } = {}
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
	local body = cars[1] and cars[1]:GetAttribute("Order") == 1 and cars[1]:FindFirstChildWhichIsA("BasePart", true)
	if body and not wails[model] then
		wails[model] = Sounds.attach("TrainWail", body, 60)
	end
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

local function addWatcher(model: Instance)
	if not model:IsA("Model") then
		return
	end
	watchers[model] = {
		Base = model:GetPivot(),
		Radius = model:GetAttribute("WatchRadius") or 20,
		Turn = 0,
		Near = false,
		WhisperedAt = -math.huge,
	}
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

	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for model, watcher in watchers do
		if near(watcher.Base.Position, camera) then
			-- Turns towards the player while they're close, as far as a neck
			-- would, and slowly back once they've gone.
			local target = 0
			local close = false
			if root and root:IsA("BasePart") then
				local offset = watcher.Base:PointToObjectSpace(root.Position)
				close = Vector3.new(offset.X, 0, offset.Z).Magnitude < watcher.Radius
				if close then
					target = math.clamp(math.atan2(-offset.X, -offset.Z), -WATCH_TURN, WATCH_TURN)
				end
			end
			if close and not watcher.Near and os.clock() - watcher.WhisperedAt > WHISPER_EVERY then
				watcher.WhisperedAt = os.clock()
				Sounds.play("ReaperWhisper")
			end
			watcher.Near = close
			watcher.Turn += (target - watcher.Turn) * math.min(dt * WATCH_RATE * (if close then 1 else 0.4), 1)
			model:PivotTo(watcher.Base * CFrame.Angles(0, watcher.Turn, 0))
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
		local wail = wails[model]
		if wail then
			wails[model] = nil
			wail:Destroy()
		end
	end)
	watch("Wheel", addWheel, function(model)
		wheels[model] = nil
	end)
	watch("Flicker", addFlicker, function(light)
		flickers[light] = nil
	end)
	watch("Watcher", addWatcher, function(model)
		watchers[model] = nil
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
