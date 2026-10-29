-- Starts the server services in dependency order. Each service connects its
-- hooks in init() and runs its loops in start(), so no player is handled
-- before every service is listening.

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
	"PurchaseService",
	"CosmeticService",
}

local services = {}
for _, name in ORDER do
	local service = require(Services:FindFirstChild(name))
	service.init()
	table.insert(services, service)
end

for _, service in services do
	if service.start then
		task.spawn(service.start)
	end
end
