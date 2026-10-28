-- The map PlotService generates for an empty place: a row of plots, the
-- plaza along their front and the spawn in its middle, built with Lune's
-- Roblox library for the scenery tests.

local Loader = require("./RobloxLoader")
local Layout = require("../src/shared/Config/Layout")

local roblox = Loader.roblox
local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame

local Map = {}

function Map.plot(cframe: any, index: number?): any
	local plot = Instance.new("Part")
	plot.Name = `Plot{index or 1}`
	plot.Size = Vector3.new(Layout.PlotSize, 1, Layout.PlotSize)
	plot.CFrame = cframe
	return plot
end

function Map.build(): { Plots: { any }, Plaza: any, Spawn: any }
	local plots = {}
	for i = 1, Layout.PlotCount do
		table.insert(plots, Map.plot(CFrame.new(Layout.plotX(i), 0, 0), i))
	end
	local plazaZ = Layout.PlotSize / 2 + Layout.PlazaDepth / 2
	local plaza = Instance.new("Part")
	plaza.Name = "Plaza"
	plaza.Size = Vector3.new(Layout.PlazaWidth, 1, Layout.PlazaDepth)
	plaza.CFrame = CFrame.new(0, 0, plazaZ)
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 1, plazaZ)
	return { Plots = plots, Plaza = plaza, Spawn = spawn }
end

return Map
