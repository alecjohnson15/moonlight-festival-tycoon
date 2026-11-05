-- One place that moves the camera, so the wardrobe's turntable, the runway
-- shots and the crowning don't fight. A shot is a function that returns
-- where the camera should be this frame; the highest-priority active shot
-- wins, and the camera eases toward it. With no shot active, the player's
-- normal camera comes back.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local State = require(script.Parent.State)

local Camera = {}

Camera.Priority = {
	Wardrobe = 1,
	Show = 2,
	Crown = 3,
}

type Shot = { Priority: number, Get: (number) -> CFrame, Ease: number, Fov: number? }

local shots: { [string]: Shot } = {}
local active = false
local player = Players.LocalPlayer
local savedFov = 70

local function top(): Shot?
	local best: Shot? = nil
	for _, shot in shots do
		if not best or shot.Priority > best.Priority then
			best = shot
		end
	end
	return best
end

-- Starts (or replaces) a shot. ease is how fast it follows (0 to 1 a frame
-- at 60 FPS; 1 snaps).
function Camera.set(name: string, priority: number, get: (number) -> CFrame, ease: number?, fov: number?)
	shots[name] = { Priority = priority, Get = get, Ease = ease or 0.12, Fov = fov }
end

-- A fixed shot from one point looking at another.
function Camera.fixed(name: string, priority: number, from: Vector3, at: Vector3, ease: number?, fov: number?)
	local cframe = CFrame.lookAt(from, at)
	Camera.set(name, priority, function()
		return cframe
	end, ease, fov)
end

function Camera.clear(name: string)
	shots[name] = nil
end

function Camera.isActive(name: string): boolean
	return shots[name] ~= nil
end

local function restore(camera: Camera)
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = savedFov
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function Camera.start()
	RunService:BindToRenderStep("CatwalkCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local shot = top()
		if not shot then
			if active then
				active = false
				restore(camera)
			end
			return
		end
		if not active then
			active = true
			savedFov = camera.FieldOfView
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local goal = shot.Get(dt)
		-- Reduced motion (Settings): cut straight to each shot.
		local settings = State.Profile and State.Profile.Settings
		local reduced = settings ~= nil and settings.ReducedMotion == true
		local alpha = if reduced then 1 else 1 - (1 - shot.Ease) ^ (dt * 60)
		camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(alpha, 0, 1))
		if shot.Fov then
			camera.FieldOfView += (shot.Fov - camera.FieldOfView) * math.clamp(alpha, 0, 1)
		end
	end)
end

return Camera
