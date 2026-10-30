-- Brings visitors to every claimed plot and runs its attractions and vendors.
-- Walkthroughs, showpieces and vendors earn on every tick and rides pay when
-- each round ends. Earnings does the maths; coins only change through
-- EconomyService.
--
-- Attributes for clients: the plot carries VisitorsPerSecond, each attraction
-- carries the visitors it serves, and a ride carries NextRoundAt (server time)
-- plus LastPayout and PayoutAt when a round pays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Theme = require(Shared.Config.Theme)
local Earnings = require(Shared.Earnings)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)

local AttractionService = {}

-- Seconds into the current round of each ride, per player. Rounds restart
-- when a player rejoins; nothing here is saved.
local clocks: { [Player]: { [string]: number } } = {}
-- Fractions of a coin earned between ticks, so odd rates aren't lost.
local carry: { [Player]: number } = {}

-- upgrade is the attraction with its boosts applied (see Earnings.effective).
local function caption(upgrade, attraction: Earnings.Attraction, visitors: number): string
	local strings = Theme.Strings
	if upgrade.Type == "Walkthrough" then
		return strings.WalkthroughVisitors:format(Format.rate(attraction.Visitors))
	elseif upgrade.Type == "Ride" then
		local riders = Earnings.ridersPerRound(upgrade, visitors)
		return strings.RideRound:format(Format.rate(riders), Format.rate(upgrade.RoundSeconds))
	end
	return strings.ShowpieceDraw:format(Format.rate(upgrade.Draw or 0))
end

-- rideClocks holds how far into its round each ride is.
local function show(plot: BasePart, owned: { [string]: boolean }, rideClocks: { [string]: number })
	local visitors = Earnings.visitorsPerSecond(owned, Balance)
	if plot:GetAttribute("VisitorsPerSecond") ~= visitors then
		plot:SetAttribute("VisitorsPerSecond", visitors)
	end

	local effective = Earnings.effective(owned, Balance)
	for id, attraction in Earnings.attractions(owned, Balance) do
		local upgrade = effective[id]
		PlotService.updateStation(plot, id, caption(upgrade, attraction, visitors), {
			VisitorsPerSecond = attraction.Visitors,
		})
		-- Set once per round rather than every tick, so it doesn't jitter.
		local station = PlotService.station(plot, id)
		if upgrade.Type == "Ride" and station and station:GetAttribute("NextRoundAt") == nil then
			local remaining = upgrade.RoundSeconds - (rideClocks[id] or 0)
			station:SetAttribute("NextRoundAt", Workspace:GetServerTimeNow() + remaining)
		end
	end
end

-- Updates the player's attraction labels straight away, such as after a purchase.
function AttractionService.refresh(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.plotOf(player)
	if data and plot then
		show(plot, data.Owned, clocks[player] or {})
	end
end

-- Brings visitors to a staged plot (PlotService.stage) and labels its
-- attractions once, paying nobody.
function AttractionService.stage(plot: BasePart, owned: { [string]: boolean })
	show(plot, owned, {})
end

local function tick(player: Player, plot: BasePart, owned: { [string]: boolean }, elapsed: number)
	-- Rides pay per round below; everything else earns continuously.
	local steady = 0
	for _, attraction in Earnings.attractions(owned, Balance) do
		if attraction.Type ~= "Ride" then
			steady += attraction.CoinsPerSecond
		end
	end
	for _, vendor in Earnings.vendors(owned, Balance) do
		steady += vendor.CoinsPerSecond
	end
	local earned = steady * elapsed + (carry[player] or 0)
	local whole = math.floor(earned)
	carry[player] = earned - whole
	if whole > 0 then
		EconomyService.addCoins(player, whole)
	end

	local rideClocks = clocks[player]
	if not rideClocks then
		rideClocks = {}
		clocks[player] = rideClocks
	end
	for _, payout in Earnings.stepRides(rideClocks, owned, Balance, elapsed) do
		if payout.Coins > 0 then
			EconomyService.addCoins(player, payout.Coins)
		end
		local station = PlotService.station(plot, payout.Id)
		if station then
			station:SetAttribute("LastPayout", payout.Coins)
			station:SetAttribute("PayoutAt", Workspace:GetServerTimeNow())
			-- Cleared so show() starts the next round's countdown.
			station:SetAttribute("NextRoundAt", nil)
		end
	end

	show(plot, owned, rideClocks)
end

function AttractionService.init()
	PlotService.onClaimed(AttractionService.refresh)
	Players.PlayerRemoving:Connect(function(player)
		clocks[player] = nil
		carry[player] = nil
	end)
end

function AttractionService.start()
	while true do
		local elapsed = task.wait(Balance.IncomeTickSeconds)
		for _, player in Players:GetPlayers() do
			local data = DataService.get(player)
			local plot = PlotService.plotOf(player)
			if data and plot then
				tick(player, plot, data.Owned, elapsed)
			end
		end
	end
end

return AttractionService
