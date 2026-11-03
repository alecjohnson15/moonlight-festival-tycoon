-- Starts the server services in dependency order. Each service connects its
-- hooks in init() and runs its loops in start(), so no player is handled
-- before every service is listening.

local RunService = game:GetService("RunService")

local Services = script.Services

local ORDER = {
	"DataService",
	"EconomyService",
	"PlotService",
	"ArenaService",
	"WorldService",
	"ProductionService",
	"AttractionService",
	"UpgradeService",
	"ActivityService",
	"FestivalService",
	"ParadeService",
	"PurchaseService",
	"CosmeticService",
	"AnalyticsService",
}

-- The showcase build (showcase.project.json) adds a Showcase module beside
-- the services, which dresses the festival for store screenshots. It goes
-- first, so it is listening before any save loads, and only runs in Studio.
-- The live game's project leaves it out.
local modules = {}
local showcase = script:FindFirstChild("Showcase")
if showcase and RunService:IsStudio() then
	table.insert(modules, showcase)
end
for _, name in ORDER do
	table.insert(modules, Services:FindFirstChild(name))
end

local services = {}
for _, module in modules do
	local service = require(module)
	service.init()
	table.insert(services, service)
end

for _, service in services do
	if service.start then
		task.spawn(service.start)
	end
end
