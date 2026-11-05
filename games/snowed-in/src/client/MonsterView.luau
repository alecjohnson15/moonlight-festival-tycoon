-- Draws the blizzard's monsters. The server moves them as numbers
-- (shared/EnemySim) and sends where they all are ten times a second
-- (shared/Codec); this glides each one between snapshots, hops it as it
-- walks, lunges it as it attacks and floats the wisps. Models come from a
-- pool per kind (shared/World/Monsters), so a night of sixty monsters
-- builds each model once, and every part moves in one BulkMoveTo a frame.
--
-- Monsters are only pictures on the client: they can't be touched or
-- clicked, and nothing here decides a hit. Rangers see a health bar over
-- every monster; everyone sees a boss's health at the top of the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Codec = require(Shared.Codec)
local Enemies = require(Shared.Config.Enemies)
local Monsters = require(Shared.World.Monsters)
local UI = require(script.Parent.UI)

local MonsterView = {}

-- Seconds between the server's snapshots.
local INTERVAL = 0.1
-- How far away a monster stops being drawn every frame.
local FAR = 360

type Pooled = {
	Model: Model,
	Parts: { BasePart },
	Offsets: { CFrame },
	Bar: BillboardGui?,
	Fill: Frame?,
}

type View = {
	Id: number,
	Kind: string,
	Pooled: Pooled,
	FromX: number,
	FromZ: number,
	FromHeading: number,
	ToX: number,
	ToZ: number,
	ToHeading: number,
	Received: number,
	Action: string,
	Health: number,
	Phase: number,
	-- Set when it has left the snapshot: it sinks into the snow and goes.
	Leaving: number?,
	-- When it was last hit, for a little jolt.
	HitAt: number,
}

local player = Players.LocalPlayer
local folder: Folder
local pools: { [string]: { Pooled } } = {}
local views: { [number]: View } = {}
local bossBar: Frame
local bossFill: Frame
local bossWords: TextLabel
local seesHealth = false

local function lerpAngle(a: number, b: number, t: number): number
	local difference = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + difference * t
end

local function build(kind: string): Pooled
	local def = Enemies.ById[kind]
	local builder = (Monsters :: any)[kind] or Monsters.Frostling
	local model = builder(nil) :: Model
	local feet = model.PrimaryPart
	if def and def.Scale ~= 1 and feet then
		-- Grow it from its feet, so it still stands on the snow.
		feet.PivotOffset = CFrame.new(0, -feet.Size.Y / 2, 0)
		model:ScaleTo(def.Scale)
	end
	local parts, offsets = {}, {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			table.insert(parts, part)
			table.insert(offsets, part.CFrame)
		end
	end
	local pooled: Pooled = { Model = model, Parts = parts, Offsets = offsets }
	local rootPart = model.PrimaryPart
	if rootPart then
		local size = model:GetExtentsSize()
		local bar = Instance.new("BillboardGui")
		bar.Size = UDim2.fromOffset(60, 7)
		bar.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1.5, 0)
		bar.AlwaysOnTop = true
		bar.MaxDistance = 140
		bar.Enabled = false
		bar.Adornee = rootPart
		bar.Parent = model
		local track = UI.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(14, 22, 36),
			BorderSizePixel = 0,
		}, bar)
		UI.corner(track, 3)
		local fill = UI.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(143, 216, 255),
			BorderSizePixel = 0,
		}, track)
		UI.corner(fill, 3)
		pooled.Bar = bar
		pooled.Fill = fill
	end
	return pooled
end

local function take(kind: string): Pooled
	local pool = pools[kind]
	if pool and #pool > 0 then
		return table.remove(pool) :: Pooled
	end
	return build(kind)
end

local function give(kind: string, pooled: Pooled)
	pooled.Model.Parent = nil
	pools[kind] = pools[kind] or {}
	table.insert(pools[kind], pooled)
end

local function onSnapshot(data: buffer)
	if typeof(data) ~= "buffer" then
		return
	end
	local time = os.clock()
	local seen = {}
	for _, entry in Codec.decode(data) do
		seen[entry.Id] = true
		local view = views[entry.Id]
		if view and view.Kind ~= entry.Kind then
			give(view.Kind, view.Pooled)
			views[entry.Id] = nil
			view = nil
		end
		if not view or view.Leaving then
			if view then
				give(view.Kind, view.Pooled)
			end
			local pooled = take(entry.Kind)
			pooled.Model.Parent = folder
			views[entry.Id] = {
				Id = entry.Id,
				Kind = entry.Kind,
				Pooled = pooled,
				FromX = entry.X,
				FromZ = entry.Z,
				FromHeading = entry.Heading,
				ToX = entry.X,
				ToZ = entry.Z,
				ToHeading = entry.Heading,
				Received = time,
				Action = entry.Action,
				Health = entry.Health,
				Phase = math.random() * 10,
				HitAt = 0,
			}
		else
			-- Start the glide from wherever it is drawn now.
			local t = math.clamp((time - view.Received) / INTERVAL, 0, 1)
			view.FromX = view.FromX + (view.ToX - view.FromX) * t
			view.FromZ = view.FromZ + (view.ToZ - view.FromZ) * t
			view.FromHeading = lerpAngle(view.FromHeading, view.ToHeading, t)
			view.ToX, view.ToZ, view.ToHeading = entry.X, entry.Z, entry.Heading
			view.Received = time
			view.Action = entry.Action
			if entry.Health < view.Health - 0.001 then
				view.HitAt = time
			end
			view.Health = entry.Health
		end
	end
	for id, view in views do
		if not seen[id] and not view.Leaving then
			view.Leaving = time
		end
	end
end

local cframes: { CFrame } = {}
local parts: { BasePart } = {}

local function step()
	local time = os.clock()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	table.clear(cframes)
	table.clear(parts)
	local boss: View? = nil
	for id, view in views do
		local t = math.clamp((time - view.Received) / INTERVAL, 0, 1)
		local x = view.FromX + (view.ToX - view.FromX) * t
		local z = view.FromZ + (view.ToZ - view.FromZ) * t
		local heading = lerpAngle(view.FromHeading, view.ToHeading, math.min(1, t * 1.5))
		local y = Monsters.Hover[view.Kind] or 0
		local pitch = 0
		local forward = 0
		local clock = time * 1 + view.Phase
		if view.Kind == "IceWisp" then
			y += math.sin(clock * 2.4) * 0.8
		elseif view.Action == "Walk" then
			y += math.abs(math.sin(clock * 9)) * 0.45
			pitch = -0.06
		elseif view.Action == "Attack" then
			local swing = math.max(0, math.sin(clock * 7))
			forward = swing * 1.4
			pitch = -swing * 0.25
		else
			y += math.sin(clock * 2) * 0.12
		end
		if time - view.HitAt < 0.15 then
			forward -= 0.8
		end
		if view.Leaving then
			local gone = (time - view.Leaving) / 0.35
			if gone >= 1 then
				give(view.Kind, view.Pooled)
				views[id] = nil
				continue
			end
			y -= gone * 4
		end
		local def = Enemies.ById[view.Kind]
		if def and def.Boss and not view.Leaving then
			boss = view
		end
		local pooled = view.Pooled
		local bar = pooled.Bar
		if bar and pooled.Fill then
			bar.Enabled = seesHealth and view.Health < 0.999 and not view.Leaving
			pooled.Fill.Size = UDim2.fromScale(view.Health, 1)
		end
		local base = CFrame.new(x, y, z)
			* CFrame.Angles(0, heading, 0)
			* CFrame.new(0, 0, -forward)
			* CFrame.Angles(pitch, 0, 0)
		local far = (Vector3.new(x, eye.Y, z) - eye).Magnitude > FAR
		if far and (time * 4 + id) % 1 > 0.25 then
			-- Far away: move it only every few frames.
			continue
		end
		for index, part in pooled.Parts do
			table.insert(parts, part)
			table.insert(cframes, base * pooled.Offsets[index])
		end
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if boss then
		local def = Enemies.ById[boss.Kind]
		bossBar.Visible = true
		bossFill.Size = UDim2.fromScale(boss.Health, 1)
		bossWords.Text = `{def.Name}`
	else
		bossBar.Visible = false
	end
end

-- Where a monster is drawn now, if it is.
function MonsterView.position(id: number): Vector3?
	local view = views[id]
	if not view then
		return nil
	end
	return Vector3.new(view.ToX, 0, view.ToZ)
end

-- Every monster drawn now: { Position, Kind }.
function MonsterView.all(): { { Position: Vector3, Kind: string } }
	local list = {}
	for _, view in views do
		if not view.Leaving then
			table.insert(list, { Position = Vector3.new(view.ToX, 0, view.ToZ), Kind = view.Kind })
		end
	end
	return list
end

function MonsterView.count(): number
	local count = 0
	for _, view in views do
		if not view.Leaving then
			count += 1
		end
	end
	return count
end

function MonsterView.start()
	folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = Workspace

	local gui = UI.screen("BossBar", 1)
	bossBar = UI.panel(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 152),
		Size = UDim2.fromOffset(340, 34),
		Visible = false,
	})
	UI.scale(bossBar)
	UI.onRescale(function()
		-- Just under the night counter.
		bossBar.Position = UDim2.new(0.5, 0, 0, 14 + 84 * UI.factor)
	end)
	bossWords = UI.label(bossBar, "", {
		Font = UI.Title,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.new(1, 0, 0, 16),
		TextColor3 = UI.Colors.Ice,
	})
	local _, fill = UI.bar(bossBar, UI.Colors.Ice, {
		Position = UDim2.fromOffset(10, 18),
		Size = UDim2.new(1, -20, 0, 10),
	})
	bossFill = fill

	local function role()
		seesHealth = player:GetAttribute("Role") == "Ranger"
	end
	player:GetAttributeChangedSignal("Role"):Connect(role)
	role()

	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Snapshot").OnClientEvent:Connect(onSnapshot)
	RunService.RenderStepped:Connect(step)
end

return MonsterView
