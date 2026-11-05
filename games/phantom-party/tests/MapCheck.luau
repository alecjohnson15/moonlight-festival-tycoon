-- A rough walk-through of a built map, for tests/Maps.spec: which points
-- are inside solid parts, where a character can stand, and which standing
-- spots a character can walk, climb a step, jump or drop between, starting
-- from a spawn. Secret passages join their two ends.
--
-- Assumptions (stated so a failure can be judged): a character is 2 studs
-- wide and 5 tall; it can step or jump up at most MAX_CLIMB studs between
-- neighbouring 2-stud cells and drop any distance; only parts with
-- CanCollide count as solid, and marker folders (Spawns, Coins, Clues,
-- Rooms, Passages) never do. Wedges count as their full box, which can
-- only make the map look more blocked than it is. Ladders and trusses
-- aren't climbed: a spot reached only by one shows as unreachable.

local MapCheck = {}

MapCheck.CELL = 2
MapCheck.STEP = 0.5
MapCheck.HEIGHT = 5
MapCheck.MAX_CLIMB = 4

local MARKERS = { Spawns = true, Coins = true, Clues = true, Rooms = true, Passages = true, Wisps = true }

export type Solid = {
	Name: string,
	X: number,
	Y: number,
	Z: number,
	R: { number },
	Half: { number },
	Shape: string,
	Min: { number },
	Max: { number },
}

local function inMarker(item: any, model: any): boolean
	local parent = item.Parent
	while parent and parent ~= model do
		if MARKERS[parent.Name] then
			return true
		end
		parent = parent.Parent
	end
	return false
end

-- Every solid part, as plain numbers so the checks run fast.
function MapCheck.solids(model: any): { Solid }
	local list = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.CanCollide and not inMarker(item, model) then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = item.CFrame:GetComponents()
			local size = item.Size
			local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
			-- The box's reach along each world axis.
			local ex = math.abs(r00) * hx + math.abs(r01) * hy + math.abs(r02) * hz
			local ey = math.abs(r10) * hx + math.abs(r11) * hy + math.abs(r12) * hz
			local ez = math.abs(r20) * hx + math.abs(r21) * hy + math.abs(r22) * hz
			local shape = "Block"
			if item.ClassName == "Part" then
				local name = tostring(item.Shape)
				if string.find(name, "Cylinder") then
					shape = "Cylinder"
				elseif string.find(name, "Ball") then
					shape = "Ball"
				end
			end
			table.insert(list, {
				Name = item:GetFullName(),
				X = x,
				Y = y,
				Z = z,
				R = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				Half = { hx, hy, hz },
				Shape = shape,
				Min = { x - ex, y - ey, z - ez },
				Max = { x + ex, y + ey, z + ez },
			})
		end
	end
	return list
end

-- Whether a point is inside a solid (a hair inside its surface).
function MapCheck.contains(solid: Solid, px: number, py: number, pz: number): boolean
	local min, max = solid.Min, solid.Max
	if px < min[1] or px > max[1] or py < min[2] or py > max[2] or pz < min[3] or pz > max[3] then
		return false
	end
	local r = solid.R
	local dx, dy, dz = px - solid.X, py - solid.Y, pz - solid.Z
	local lx = r[1] * dx + r[4] * dy + r[7] * dz
	local ly = r[2] * dx + r[5] * dy + r[8] * dz
	local lz = r[3] * dx + r[6] * dy + r[9] * dz
	local half = solid.Half
	local skin = 0.05
	if solid.Shape == "Ball" then
		local radius = math.min(half[1], half[2], half[3]) - skin
		return lx * lx + ly * ly + lz * lz < radius * radius
	elseif solid.Shape == "Cylinder" then
		local radius = math.min(half[2], half[3]) - skin
		return math.abs(lx) < half[1] - skin and ly * ly + lz * lz < radius * radius
	end
	return math.abs(lx) < half[1] - skin and math.abs(ly) < half[2] - skin and math.abs(lz) < half[3] - skin
end

export type Grid = {
	Solids: { Solid },
	Bins: { [number]: { Solid } },
	MinX: number,
	MinZ: number,
	MinY: number,
	MaxY: number,
	Width: number,
	Depth: number,
	-- Per cell: the heights a character can stand at.
	Spots: { [number]: { number } },
	-- Per cell and sample: solid or not (only for cells asked about).
	Columns: { [number]: { boolean } },
}

local function cellIndex(grid: Grid, cx: number, cz: number): number
	return cz * grid.Width + cx
end

function MapCheck.solidAt(grid: Grid, px: number, py: number, pz: number): boolean
	local cx = math.floor((px - grid.MinX) / MapCheck.CELL)
	local cz = math.floor((pz - grid.MinZ) / MapCheck.CELL)
	for _, solid in grid.Bins[cellIndex(grid, cx, cz)] or {} do
		if MapCheck.contains(solid, px, py, pz) then
			return true
		end
	end
	return false
end

local function column(grid: Grid, cx: number, cz: number): { boolean }
	local index = cellIndex(grid, cx, cz)
	local found = grid.Columns[index]
	if found then
		return found
	end
	found = {}
	local px = grid.MinX + (cx + 0.5) * MapCheck.CELL
	local pz = grid.MinZ + (cz + 0.5) * MapCheck.CELL
	local samples = math.ceil((grid.MaxY - grid.MinY) / MapCheck.STEP)
	for sample = 0, samples do
		found[sample] = MapCheck.solidAt(grid, px, grid.MinY + sample * MapCheck.STEP, pz)
	end
	grid.Columns[index] = found
	return found
end

-- Builds the grid over the map's solids.
function MapCheck.grid(model: any): Grid
	local solids = MapCheck.solids(model)
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, solid in solids do
		minX, minY, minZ = math.min(minX, solid.Min[1]), math.min(minY, solid.Min[2]), math.min(minZ, solid.Min[3])
		maxX, maxY, maxZ = math.max(maxX, solid.Max[1]), math.max(maxY, solid.Max[2]), math.max(maxZ, solid.Max[3])
	end
	local cell = MapCheck.CELL
	local grid: Grid = {
		Solids = solids,
		Bins = {},
		MinX = minX - cell,
		MinZ = minZ - cell,
		MinY = minY - 1,
		MaxY = maxY + MapCheck.HEIGHT + 1,
		Width = math.ceil((maxX - minX) / cell) + 3,
		Depth = math.ceil((maxZ - minZ) / cell) + 3,
		Spots = {},
		Columns = {},
	}
	for _, solid in solids do
		local x0 = math.floor((solid.Min[1] - grid.MinX) / cell)
		local x1 = math.floor((solid.Max[1] - grid.MinX) / cell)
		local z0 = math.floor((solid.Min[3] - grid.MinZ) / cell)
		local z1 = math.floor((solid.Max[3] - grid.MinZ) / cell)
		for cx = math.max(0, x0), math.min(grid.Width - 1, x1) do
			for cz = math.max(0, z0), math.min(grid.Depth - 1, z1) do
				local index = cellIndex(grid, cx, cz)
				grid.Bins[index] = grid.Bins[index] or {}
				table.insert(grid.Bins[index], solid)
			end
		end
	end
	return grid
end

-- The heights in a cell where a character can stand: solid underfoot and
-- clear for its full height above.
local function spots(grid: Grid, cx: number, cz: number): { number }
	local index = cellIndex(grid, cx, cz)
	if grid.Spots[index] then
		return grid.Spots[index]
	end
	local samples = column(grid, cx, cz)
	local clear = math.ceil(MapCheck.HEIGHT / MapCheck.STEP)
	local found = {}
	for sample = 0, #samples - clear do
		if samples[sample] and not samples[sample + 1] then
			local free = true
			for above = 1, clear do
				if samples[sample + above] then
					free = false
					break
				end
			end
			if free then
				table.insert(found, grid.MinY + (sample + 1) * MapCheck.STEP)
			end
		end
	end
	grid.Spots[index] = found
	return found
end

-- Whether a character can go straight up or down a cell between two
-- heights with its head clear.
local function clearBetween(grid: Grid, cx: number, cz: number, low: number, high: number): boolean
	local samples = column(grid, cx, cz)
	local from = math.floor((low - grid.MinY) / MapCheck.STEP) + 1
	local to = math.ceil((high + MapCheck.HEIGHT - grid.MinY) / MapCheck.STEP)
	for sample = from, math.min(to, #samples) do
		if samples[sample] then
			return false
		end
	end
	return true
end

-- The cell and standing height nearest below a point (a spawn or a page),
-- within reach feet: nil if there's no floor under it.
function MapCheck.standAt(grid: Grid, px: number, py: number, pz: number, reach: number): (number?, number?)
	local cx = math.floor((px - grid.MinX) / MapCheck.CELL)
	local cz = math.floor((pz - grid.MinZ) / MapCheck.CELL)
	local best = nil
	for _, height in spots(grid, cx, cz) do
		if height <= py + 0.5 and py - height <= reach and (best == nil or height > best) then
			best = height
		end
	end
	if best == nil then
		return nil, nil
	end
	return cellIndex(grid, cx, cz), best
end

-- Whether a character can cross from one cell's centre to the next at a
-- height, checking points along the way so a wall thinner than a cell
-- still blocks.
local function crossable(grid: Grid, ax: number, az: number, bx: number, bz: number, height: number): boolean
	local fromX = grid.MinX + (ax + 0.5) * MapCheck.CELL
	local fromZ = grid.MinZ + (az + 0.5) * MapCheck.CELL
	local toX = grid.MinX + (bx + 0.5) * MapCheck.CELL
	local toZ = grid.MinZ + (bz + 0.5) * MapCheck.CELL
	for step = 1, 7 do
		local t = step / 8
		local px = fromX + (toX - fromX) * t
		local pz = fromZ + (toZ - fromZ) * t
		for lift = 0.5, MapCheck.HEIGHT - 0.5, 1 do
			if MapCheck.solidAt(grid, px, height + lift, pz) then
				return false
			end
		end
	end
	return true
end

local function key(index: number, height: number): string
	return `{index}@{math.floor(height * 2 + 0.5)}`
end

-- Every standing spot reachable from a start, with passage ends joined.
-- Returns a set of keys; MapCheck.reached tells if a spot is in it.
function MapCheck.flood(grid: Grid, startIndex: number, startHeight: number, links: { { any } }?): { [string]: boolean }
	local seen: { [string]: boolean } = {}
	local queue = { { startIndex, startHeight } }
	seen[key(startIndex, startHeight)] = true
	local head = 1
	local jumps: { [string]: { { number } } } = {}
	for _, pair in links or {} do
		local a, b = pair[1], pair[2]
		jumps[key(a[1], a[2])] = jumps[key(a[1], a[2])] or {}
		table.insert(jumps[key(a[1], a[2])], b)
		jumps[key(b[1], b[2])] = jumps[key(b[1], b[2])] or {}
		table.insert(jumps[key(b[1], b[2])], a)
	end
	while head <= #queue do
		local current = queue[head]
		head += 1
		local index, height = current[1], current[2]
		local cx, cz = index % grid.Width, index // grid.Width
		for _, offset in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, nz = cx + offset[1], cz + offset[2]
			if nx >= 0 and nz >= 0 and nx < grid.Width and nz < grid.Depth then
				local nIndex = cellIndex(grid, nx, nz)
				for _, nHeight in spots(grid, nx, nz) do
					local rise = nHeight - height
					if rise <= MapCheck.MAX_CLIMB and not seen[key(nIndex, nHeight)] then
						-- Room to move across: clear in the next cell from the
						-- lower spot to the higher one plus head room, and in
						-- this cell up to the higher one.
						local high = math.max(height, nHeight)
						if
							clearBetween(grid, nx, nz, nHeight, high)
							and clearBetween(grid, cx, cz, height, high)
							and crossable(grid, cx, cz, nx, nz, high)
						then
							seen[key(nIndex, nHeight)] = true
							table.insert(queue, { nIndex, nHeight })
						end
					end
				end
			end
		end
		for _, other in jumps[key(index, height)] or {} do
			if not seen[key(other[1], other[2])] then
				seen[key(other[1], other[2])] = true
				table.insert(queue, other)
			end
		end
	end
	return seen
end

function MapCheck.reached(seen: { [string]: boolean }, index: number, height: number): boolean
	return seen[key(index, height)] == true
end

return MapCheck
