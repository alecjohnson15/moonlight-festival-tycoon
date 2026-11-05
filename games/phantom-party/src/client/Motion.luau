-- Moves what the builders mark to move, on this client only, so it costs
-- no network traffic: models tagged Spin turn (the carousel, the swing
-- ride), ones tagged Float bob and turn (the plaza's giant mask, the
-- crates in the vault), the ferris wheel tagged Wheel turns with its
-- gondolas hanging level, and pickups (coins, clue pages, a dropped
-- blaster) spin and bob so they catch the eye. Lights tagged Flicker
-- flicker. Anything far from the camera is left alone.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NEAR = 320
local FLICKER_STEP = 1 / 20

type Spinner = { Base: CFrame, Seconds: number }
type Floater = { Base: CFrame, Height: number, Seconds: number, Spin: number, Axis: Vector3, Phase: number }
type Wheel =
	{ Hub: CFrame, Seconds: number, Rim: Model?, Gondolas: { { Model: Model, Angle: number, Radius: number } } }
type Pickup = { Base: CFrame, Turn: CFrame, Phase: number }

local Motion = {}

local spinners: { [Model]: Spinner } = {}
local floaters: { [Model]: Floater } = {}
local wheels: { [Model]: Wheel } = {}
local pickups: { [Instance]: Pickup } = {}
local flickers: { [Light]: number } = {}
local sinceFlicker = 0

local function watch(tag: string, added: (any) -> (), removed: (any) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(added, instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(removed)
end

local function phaseOf(base: CFrame): number
	return (base.X * 0.37 + base.Z * 0.23) % 10
end

local function addSpinner(model: Instance)
	if model:IsA("Model") then
		spinners[model] = { Base = model:GetPivot(), Seconds = model:GetAttribute("SpinSeconds") or 20 }
	end
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

local function addWheel(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local hub = model:GetPivot()
	local gondolas = {}
	for _, child in model:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Angle") then
			local offset = hub:PointToObjectSpace(child:GetPivot().Position)
			table.insert(gondolas, {
				Model = child,
				Angle = child:GetAttribute("Angle"),
				Radius = Vector2.new(offset.Y, offset.Z).Magnitude,
			})
		end
	end
	local rim = model:FindFirstChild("Rim")
	wheels[model] = {
		Hub = hub,
		Seconds = model:GetAttribute("SpinSeconds") or 40,
		Rim = if rim and rim:IsA("Model") then rim else nil,
		Gondolas = gondolas,
	}
	if rim and rim:IsA("Model") then
		rim.WorldPivot = hub
	end
end

local function addPickup(item: Instance)
	local base: CFrame
	if item:IsA("BasePart") then
		base = item.CFrame
	elseif item:IsA("Model") then
		base = item:GetPivot()
	else
		return
	end
	pickups[item] = { Base = CFrame.new(base.Position), Turn = base.Rotation, Phase = phaseOf(base) }
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

	for model, spin in spinners do
		if near(spin.Base.Position, camera) then
			model:PivotTo(spin.Base * CFrame.Angles(0, now / spin.Seconds * math.pi * 2, 0))
		end
	end

	for model, float in floaters do
		if near(float.Base.Position, camera) then
			local t = now + float.Phase
			local bob = math.sin(t / float.Seconds * math.pi * 2) * float.Height / 2
			local turn = if float.Spin ~= 0 then t / float.Spin * math.pi * 2 else 0
			model:PivotTo(float.Base * CFrame.new(0, bob, 0) * CFrame.fromAxisAngle(float.Axis, turn))
		end
	end

	for _, wheel in wheels do
		if near(wheel.Hub.Position, camera) then
			-- The wheel's axle runs along the hub's X axis.
			local turn = now / wheel.Seconds * math.pi * 2
			if wheel.Rim then
				wheel.Rim:PivotTo(wheel.Hub * CFrame.Angles(turn, 0, 0))
			end
			for _, gondola in wheel.Gondolas do
				local angle = gondola.Angle + turn
				local spot = wheel.Hub
					* CFrame.new(0, math.sin(angle) * gondola.Radius, math.cos(angle) * gondola.Radius)
				gondola.Model:PivotTo(CFrame.new(spot.Position) * wheel.Hub.Rotation)
			end
		end
	end

	for item, pickup in pickups do
		if near(pickup.Base.Position, camera) then
			local t = now + pickup.Phase
			local frame = pickup.Base
				* CFrame.new(0, math.sin(t * 2.4) * 0.25, 0)
				* CFrame.Angles(0, t * 2.5, 0)
				* pickup.Turn
			if item:IsA("BasePart") then
				item.CFrame = frame
			elseif item:IsA("Model") then
				item:PivotTo(frame)
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
	watch("Spin", addSpinner, function(model)
		spinners[model] = nil
	end)
	watch("Float", addFloater, function(model)
		floaters[model] = nil
	end)
	watch("Wheel", addWheel, function(model)
		wheels[model] = nil
	end)
	watch("Pickup", addPickup, function(item)
		pickups[item] = nil
	end)
	watch("DroppedBlaster", addPickup, function(item)
		pickups[item] = nil
	end)
	watch("Flicker", addFlicker, function(light)
		flickers[light] = nil
	end)
	RunService.RenderStepped:Connect(onRenderStep)
end

return Motion
