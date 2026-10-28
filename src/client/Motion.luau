-- Moves what the theme marks to move: models tagged Float bob and turn, ghost
-- trains tagged Train run round their tracks, and lights tagged Flicker
-- flicker. The server builds them still; all of the motion is drawn on this
-- client only, so it costs no network traffic. Anything far from the camera is
-- left alone.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NEAR = 350
local FLICKER_STEP = 1 / 20

type Floater = { Base: CFrame, Height: number, Seconds: number, Spin: number, Axis: Vector3, Phase: number }

local Motion = {}

local floaters: { [Model]: Floater } = {}
local trains: { [Model]: { Model } } = {}
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
		-- Spread out by position, so neighbouring plots don't move in step.
		Phase = (base.X * 0.37 + base.Z * 0.23) % 10,
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

	for model, cars in trains do
		local centre = model:GetAttribute("TrackCentre")
		if centre and near(centre.Position, camera) then
			local radiusX, radiusZ = model:GetAttribute("RadiusX") or 1, model:GetAttribute("RadiusZ") or 1
			local lap, gap = model:GetAttribute("LapSeconds") or 10, model:GetAttribute("Gap") or 0.5
			local lead = now / lap * math.pi * 2
			for index, car in cars do
				local angle = lead - (index - 1) * gap
				local spot =
					centre:PointToWorldSpace(Vector3.new(math.cos(angle) * radiusX, 0, math.sin(angle) * radiusZ))
				local heading =
					centre:VectorToWorldSpace(Vector3.new(-math.sin(angle) * radiusX, 0, math.cos(angle) * radiusZ))
				car:PivotTo(CFrame.lookAt(spot, spot + heading))
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
	watch("Train", addTrain, function(model)
		trains[model] = nil
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
		if current:HasTag("Float") or current:HasTag("Train") then
			return true
		end
		current = current.Parent
	end
	return false
end

return Motion
