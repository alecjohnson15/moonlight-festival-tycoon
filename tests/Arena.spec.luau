-- The PvP arena: the weapons' balance (paid weapons may only be slightly
-- better than the best free ones), the geometry that decides who a hit
-- reaches, and the theme's arena dressing and loaner bonker.

local TestKit = require("./TestKit")
local Loader = require("./RobloxLoader")
local Arena = require("../src/shared/Config/Arena")
local Cosmetics = require("../src/shared/Config/Cosmetics")
local Layout = require("../src/shared/Config/Layout")
local Weapons = require("../src/shared/Config/Weapons")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local roblox = Loader.roblox
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame
local Combat = Loader.require("src/shared/Combat")
local ArenaLook = Loader.require("src/shared/Themes/MoonlightFestival/Arena")
local Scenery = Loader.require("src/shared/Themes/MoonlightFestival/Scenery")

local STATS = { "Damage", "Cooldown", "Reach", "Arc", "Knockback" }
local FLAIRS = {
	Pumpkin = true,
	Dust = true,
	Lightning = true,
	Sparkles = true,
	Claws = true,
	Crescent = true,
	Ghosts = true,
	Souls = true,
	Water = true,
	Foxfire = true,
}

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- Seconds of swinging it takes to knock out a full-health player.
local function secondsToKnockOut(weapon): number
	return (math.ceil(Arena.Health / weapon.Damage) - 1) * weapon.Cooldown
end

describe("arena weapons", function()
	it("are all complete and sensible", function()
		local count = 0
		for id, weapon in Weapons do
			count += 1
			assert(Weapons.Styles[weapon.Style], `{id} has unknown style {weapon.Style}`)
			assert(Weapons.Tiers[weapon.Tier], `{id} has unknown tier {weapon.Tier}`)
			for _, stat in STATS do
				assert(type(weapon[stat]) == "number" and weapon[stat] > 0, `{id} has no {stat}`)
			end
			assert(weapon.Arc < 90, `{id} hits behind its holder`)
			local special = weapon.Special
			assert(Weapons.Specials[special.Kind], `{id} has unknown special {special.Kind}`)
			assert(special.Cooldown > weapon.Cooldown * 4, `{id}'s special is nearly as quick as a swing`)
			assert(special.Damage < Arena.Health, `{id}'s special knocks out in one go`)
		end
		assert(Weapons.bonker and Weapons.bonker.Tier == "Starter", "the arena has no Starter bonker to lend")
		expect(count > 5).toBe(true)
	end)

	it("fight for every cosmetic weapon, with the paid edge only on Legendary ones", function()
		for _, cosmetic in Cosmetics do
			if cosmetic.Weapon then
				local weapon = rawget(Weapons, cosmetic.Weapon)
				assert(weapon, `{cosmetic.Id} names weapon {cosmetic.Weapon}, which has no arena stats`)
				local legendary = cosmetic.Line == "Legendary"
				assert(
					(weapon.Tier == "Premium") == legendary,
					`{cosmetic.Id} is {cosmetic.Line} but fights at the {weapon.Tier} tier`
				)
			end
		end
	end)

	it("hit harder tier by tier, and every style is close to as quick to win with", function()
		local tiers = Weapons.Tiers
		assert(tiers.Starter < tiers.Earned and tiers.Earned < tiers.Elite, "free tiers don't get stronger in order")
		local times = {}
		for name, style in Weapons.Styles do
			times[name] = secondsToKnockOut({ Damage = style.Damage * tiers.Elite, Cooldown = style.Cooldown })
		end
		local fastest, slowest = math.huge, 0
		for _, seconds in times do
			fastest, slowest = math.min(fastest, seconds), math.max(slowest, seconds)
		end
		assert(slowest <= fastest * 1.5, `styles are unbalanced: {fastest} to {slowest} seconds to knock out`)
	end)

	it("give paid weapons only one small edge over the best free weapons", function()
		local edge = Weapons.PremiumEdge
		assert(edge >= 1 and edge <= 1.15, `the premium edge of {edge} is more than slight`)
		expect(Weapons.Tiers.Premium).toBe(Weapons.Tiers.Elite)
		for id, weapon in Weapons do
			if weapon.Tier ~= "Premium" then
				expect(weapon.Edge).toBe(nil)
				continue
			end
			assert(table.find(STATS, weapon.Edge), `premium {id} has no edge, or an unknown one`)
			local style = Weapons.Styles[weapon.Style]
			local elite = {}
			for _, stat in STATS do
				elite[stat] = style[stat] * (if stat == "Damage" then Weapons.Tiers.Elite else 1)
				local expected = elite[stat]
				if stat == weapon.Edge then
					expected = if stat == "Cooldown" then expected / edge else expected * edge
				end
				assert(near(weapon[stat], expected), `premium {id} has {stat} {weapon[stat]}, not {expected}`)
			end
			assert(
				near(weapon.Special.Damage, Weapons.Specials[weapon.Special.Kind].Damage * Weapons.Tiers.Elite),
				`premium {id}'s special hits harder than Elite`
			)
			-- At most one fewer swing to win than the Elite version.
			local hits = math.ceil(Arena.Health / weapon.Damage)
			assert(hits >= math.ceil(Arena.Health / elite.Damage) - 1, `premium {id} wins in far fewer hits`)
		end
	end)

	it("give paid skins nothing extra, since a skin names an existing weapon", function()
		for id in Weapons do
			assert(string.match(id, "^[%l_]+$"), `weapon id {id} must be lower_snake_case`)
		end
	end)
end)

describe("arena combat", function()
	local origin = Vector3.new(0, 3, 0)
	local forward = Vector3.new(0, 0, -1)
	local function fighter(id: string, x: number, y: number, z: number)
		return { Id = id, Position = Vector3.new(x, y, z) }
	end

	it("hits the nearest fighter in front and in reach", function()
		local fighters = {
			fighter("far", 0, 3, -7),
			fighter("near", 1, 3, -4),
			fighter("behind", 0, 3, 2),
			fighter("aside", 5, 3, 0),
			fighter("out of reach", 0, 3, -12),
		}
		expect(Combat.swingTarget(origin, forward, fighters, 8, 60, 6).Id).toBe("near")
		expect(Combat.swingTarget(origin, forward, { fighters[3], fighters[4] }, 8, 60, 6)).toBe(nil)
		expect(Combat.swingTarget(origin, forward, { fighters[5] }, 8, 60, 6)).toBe(nil)
		-- Too far above, as on top of the wall.
		expect(Combat.swingTarget(origin, forward, { fighter("up", 0, 12, -3) }, 8, 60, 6)).toBe(nil)
		-- Standing on the same spot counts as in front.
		expect(Combat.swingTarget(origin, forward, { fighter("on top", 0.2, 3, 0.3) }, 8, 60, 6).Id).toBe("on top")
	end)

	it("finds everyone round a point and along a path, nearest first", function()
		local fighters =
			{ fighter("a", 0, 3, -10), fighter("b", 1, 3, -3), fighter("c", 6, 3, -6), fighter("d", 0, 3, 5) }
		local around = Combat.within(origin, fighters, 7, 6)
		expect(#around).toBe(2)
		local path = Combat.along(origin, Vector3.new(0, 3, -20), fighters, 5, 6)
		expect(#path).toBe(2)
		expect(path[1].Id).toBe("b")
		expect(path[2].Id).toBe("a")
	end)

	it("throws a target away from the hit and up", function()
		local velocity = Combat.knockback(origin, Vector3.new(3, 3, 0), forward, 50, 20)
		assert(near(velocity.X, 50) and near(velocity.Y, 20) and near(velocity.Z, 0), "not thrown sideways and up")
		local same = Combat.knockback(origin, origin, forward, 50, 20)
		assert(near(same.Z, -50), "a target on the same spot isn't thrown forward")
	end)

	it("knows who is in the arena", function()
		local centre = Vector3.new(0, 2, 180)
		expect(Combat.isInside(centre, 31, 30, Vector3.new(10, 5, 185))).toBe(true)
		expect(Combat.isInside(centre, 31, 30, Vector3.new(0, 3, 140))).toBe(false)
		expect(Combat.isInside(centre, 31, 30, Vector3.new(0, 40, 180))).toBe(false)
		expect(Combat.isInside(centre, 31, 30, Vector3.new(0, -2, 180))).toBe(false)
	end)

	it("only lets an action through once its cooldown has passed", function()
		expect(Combat.ready(10, 9.5, 0.8, 0.1)).toBe(false)
		expect(Combat.ready(10, 9.25, 0.8, 0.1)).toBe(true)
		expect(Combat.ready(10, -math.huge, 8, 0.1)).toBe(true)
	end)
end)

-- The stage ArenaService makes behind the plaza PlotService makes.
local PLAZA_BACK = Layout.PlotSize / 2 + 40
local CENTRE = Vector3.new(0, Arena.Height, PLAZA_BACK + Arena.Distance)

local function makeStage(): any
	local model = Instance.new("Model")
	model.Name = "Arena"
	local stage = Instance.new("Part")
	stage.Name = "Stage"
	stage.Shape = roblox.Enum.PartType.Cylinder
	stage.Size = Vector3.new(Arena.Height + 1, Arena.Radius * 2, Arena.Radius * 2)
	stage.CFrame = CFrame.new(CENTRE.X, (Arena.Height - 1) / 2, CENTRE.Z) * CFrame.Angles(0, 0, math.pi / 2)
	stage.Parent = model
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Parent = model
	return stage
end

local function partsIn(root: any): { any }
	local parts = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- The corners of a part's box, in world space.
local function corners(part: any): { any }
	local half = part.Size / 2
	local list = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(list, part.CFrame * Vector3.new(x * half.X, y * half.Y, z * half.Z))
			end
		end
	end
	return list
end

describe("arena look", function()
	it("names, colours and draws every weapon's special", function()
		for id in Weapons do
			local look = ArenaLook.Specials[id]
			assert(look and look.Name ~= "", `the theme has no special move look for {id}`)
			assert(
				string.match(look.Color, "^#%x%x%x%x%x%x$") and string.match(look.Accent, "^#%x%x%x%x%x%x$"),
				`{id}'s colours must be #RRGGBB`
			)
			assert(FLAIRS[look.Flair], `{id} has unknown flair {look.Flair}`)
		end
		for _, sound in ArenaLook.Sounds do
			assert(
				sound.Id == "" or string.match(sound.Id, "^rbxassetid://%d+$"),
				'arena sounds must be rbxassetid://<number> or ""'
			)
		end
	end)

	it("dresses the stage without blocking the fight, the ramp or the way back in", function()
		local stage = makeStage()
		local model = ArenaLook.dress(stage, Instance.new("Folder"))
		local parts = partsIn(model)
		local lights = 0
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("Light") then
				lights += 1
			end
		end
		print(`  the arena has {#parts} parts and {lights} lights`)
		assert(#parts < 700, `the arena has {#parts} parts`)
		assert(lights <= 16, `the arena has {lights} lights`)

		-- The way in: the ramp, and the ground in front of it where knocked-out
		-- players are put.
		local entranceZ = CENTRE.Z - Arena.Radius
		local outsideZ = entranceZ - Arena.RampLength - Arena.ExitDistance - 3
		for _, part in parts do
			assert(part.Anchored, `{part.Name} is not anchored`)
			if part.CanCollide then
				for _, corner in corners(part) do
					local where = `a solid {part.ClassName} reaching ({corner.X}, {corner.Z})`
					local across = Vector3.new(corner.X - CENTRE.X, 0, corner.Z - CENTRE.Z).Magnitude
					assert(across > Arena.Radius - 3 or corner.Y > CENTRE.Y + 12, `{where} is in the fight`)
					local inDoorway = math.abs(corner.X - CENTRE.X) < Arena.EntranceWidth / 2
						and corner.Z < entranceZ + 2
						and corner.Z > outsideZ
					assert(not inDoorway, `{where} blocks the entrance`)
				end
			end
		end
	end)

	it("keeps the woods out of the arena and the ground in front of it", function()
		local plots = {}
		for i = 1, Layout.PlotCount do
			local plot = Instance.new("Part")
			plot.Size = Vector3.new(Layout.PlotSize, 1, Layout.PlotSize)
			plot.CFrame = CFrame.new((i - (Layout.PlotCount + 1) / 2) * Layout.PlotSpacing, 0, 0)
			table.insert(plots, plot)
		end
		local plaza = Instance.new("Part")
		plaza.Size = Vector3.new(Layout.PlotCount * Layout.PlotSpacing, 1, 40)
		plaza.CFrame = CFrame.new(0, 0, Layout.PlotSize / 2 + 20)
		local folder = Instance.new("Folder")
		Scenery.world({ Plots = plots, Plaza = plaza, Spawns = {}, Arena = makeStage() }, folder)
		local front = CENTRE.Z - Arena.Radius - Arena.RampLength - Arena.ExitDistance - 2
		for _, part in partsIn(folder) do
			local at = part.CFrame.Position
			if part.Transparency < 1 and at.Y < 20 then
				local across = Vector3.new(at.X - CENTRE.X, 0, at.Z - CENTRE.Z).Magnitude
				local inFront = math.abs(at.X - CENTRE.X) < 8 and at.Z > front and at.Z < CENTRE.Z
				assert(across > Arena.Radius + 6 and not inFront, `scenery at ({at.X}, {at.Z}) is on the arena`)
			end
		end
	end)

	it("lends a bonker that can be held and swung", function()
		local tool = ArenaLook.bonker()
		expect(tool.ClassName).toBe("Tool")
		expect(tool:GetAttribute("Weapon")).toBe("bonker")
		expect(tool.CanBeDropped).toBe(false)
		local handle = tool:FindFirstChild("Handle")
		assert(handle and handle:IsA("BasePart"), "the bonker has no Handle")
		local welded = {}
		for _, part in partsIn(tool) do
			assert(
				not part.Anchored and not part.CanCollide and part.Massless,
				`{part.Name} would weigh down or snag its holder`
			)
			local weld = part:FindFirstChildOfClass("Weld")
			if weld then
				expect(weld.Part0).toBe(handle)
				welded[weld.Part1] = true
			end
		end
		for _, part in partsIn(tool) do
			assert(part == handle or welded[part], `{part.Name} isn't welded to the Handle`)
		end
	end)
end)

return nil
