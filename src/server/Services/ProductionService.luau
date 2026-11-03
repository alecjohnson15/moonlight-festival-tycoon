-- Runs the production chain on every claimed plot. Each tick it pays for the
-- goods that reached the stall and keeps each station's caption and rate
-- attributes in step with what it is making. Earnings does the maths; coins
-- only change through EconomyService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Theme = require(Shared.Config.Theme)
local Earnings = require(Shared.Earnings)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)

local ProductionService = {}

-- Fractions of a coin earned between ticks, so odd rates aren't lost.
local carry: { [Player]: number } = {}

local function caption(station: Earnings.Station, selling: number): string
	local strings = Theme.Strings
	if station.Kind == "Stall" then
		return strings.StallSelling:format(Format.rate(selling))
	end
	local making = strings.StationMaking:format(Format.rate(station.Out), Theme.Items[station.Makes].DisplayName)
	if (station.Overflow or 0) > 0 then
		return strings.KitchenFull:format(making)
	end
	return making
end

-- OutPerSecond is what a station makes; a kitchen's InPerSecond is what it
-- takes from the growers. Clients animate goods moving at these rates.
local function show(plot: BasePart, chain: Earnings.Chain)
	local selling = 0
	for _, amount in chain.Selling do
		selling += amount
	end
	for id, station in chain.Stations do
		PlotService.updateStation(plot, id, caption(station, selling), {
			OutPerSecond = station.Out,
			InPerSecond = station.In,
		})
	end
end

-- Updates the player's station labels straight away, such as after a purchase.
function ProductionService.refresh(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.plotOf(player)
	if data and plot then
		show(plot, Earnings.chain(data.Owned, Balance))
	end
end

-- Labels a staged plot's stations (PlotService.stage) once, paying nobody.
function ProductionService.stage(plot: BasePart, owned: { [string]: boolean })
	show(plot, Earnings.chain(owned, Balance))
end

function ProductionService.init()
	PlotService.onClaimed(ProductionService.refresh)
	Players.PlayerRemoving:Connect(function(player)
		carry[player] = nil
	end)
end

function ProductionService.start()
	while true do
		local elapsed = task.wait(Balance.IncomeTickSeconds)
		for _, player in Players:GetPlayers() do
			local data = DataService.get(player)
			local plot = PlotService.plotOf(player)
			if data and plot then
				local chain = Earnings.chain(data.Owned, Balance)
				local earned = chain.CoinsPerSecond * elapsed + (carry[player] or 0)
				local whole = math.floor(earned)
				carry[player] = earned - whole
				if whole > 0 then
					EconomyService.addCoins(player, whole)
				end
				show(plot, chain)
			end
		end
	end
end

return ProductionService
