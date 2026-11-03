-- The showcase build (showcase.project.json): the festival dressed for store
-- screenshots in Studio, from Plan. Every player who joins is maxed out:
-- every building on its best-looking path, every earned item worn, a full
-- trophy shelf and lots of coins, on the plot beside the courtyard. Three
-- neighbouring plots are staged on the other paths, with visitors, their own
-- festivals and Ghost Catcher booths, and the Moonlight Parade comes round
-- early and often.
--
-- Saves stay in memory, so nothing here can reach a real save, and the
-- server only loads this module in Studio. The live game's project leaves it
-- out. Its client half (Client.luau) hides the screen for clean shots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Layout = require(Shared.Config.Layout)
local ParadeConfig = require(Shared.Config.Parade)
local Plan = require(Shared.ShowcasePlan)
local Server = script.Parent
local Funnel = require(Server.Lib.Funnel)
local Migrations = require(Server.Lib.Migrations)
local ActivityService = require(Server.Services.ActivityService)
local AttractionService = require(Server.Services.AttractionService)
local DataService = require(Server.Services.DataService)
local FestivalService = require(Server.Services.FestivalService)
local PlotService = require(Server.Services.PlotService)
local ProductionService = require(Server.Services.ProductionService)

local Showcase = {}

local function plotAt(index: number): BasePart?
	local plots = Workspace:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild(`Plot{index}`)
	return if plot and plot:IsA("BasePart") then plot else nil
end

-- Maxes the player's save as it loads and gives them their plot, before any
-- other service sees the save.
local function onLoaded(player: Player, data)
	Plan.fill(data, Plan.Player, Balance.Upgrades)
	-- Past every onboarding step, so the showcase logs none.
	data.Onboarding = #Funnel.Steps

	local plot = plotAt(Plan.Player.Index)
	if not plot or plot:GetAttribute("OwnerUserId") ~= nil then
		return
	end
	PlotService.claim(player, plot)
	-- Respawns land on the plot; a character already in the world goes there
	-- now.
	local character = player.Character
	if character then
		local offset = Layout.ArrivalOffset
		character:PivotTo(plot.CFrame * CFrame.new(offset.X, 4, offset.Z))
	end
end

function Showcase.init()
	DataService.keepInMemory()
	ParadeConfig.FirstSeconds = Plan.ParadeFirstSeconds
	ParadeConfig.IntervalSeconds = Plan.ParadeIntervalSeconds
	DataService.onLoaded(onLoaded)
end

-- Every service has built the map by now, and no save has loaded yet.
function Showcase.start()
	for _, neighbour in Plan.Neighbours do
		local plot = plotAt(neighbour.Index)
		if plot then
			local save = Migrations.new()
			Plan.fill(save, neighbour, Balance.Upgrades)
			PlotService.stage(plot, save.Owned, neighbour.Owner :: string)
			ProductionService.stage(plot, save.Owned)
			AttractionService.stage(plot, save.Owned)
			ActivityService.stage(plot)
			FestivalService.stage(plot, save)
		end
	end
end

return Showcase
