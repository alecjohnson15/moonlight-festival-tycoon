-- The Moonlight Parade (Config/Parade), the festival's shared moment. Every
-- IntervalSeconds a parade of floats circles the Moonlight Wheel in the
-- courtyard for RunSeconds, letting go of lanterns. Anyone on the server can
-- catch them by running through them, and every catch fills one shared
-- meter. The server picks where the lanterns go, decides every catch from
-- where each character is, and pays; clients draw the parade from the
-- Parade remote and these Workspace attributes (the courtyard itself may not
-- have streamed in on a far away client):
--   ParadeCentre      the middle of the loop, on the courtyard floor
--   ParadeRadiusX, ParadeRadiusZ   the loop's size
--   ParadeAt          server time the next parade starts
--   ParadeLive        true while one is on
--   ParadeStartedAt   server time the one on now started
--   ParadeMeter, ParadeGoal   lanterns caught so far, and needed to fill it
--
-- A catch pays a little of the catcher's income, and a full meter pays
-- everyone who caught one a little more; docs/progression.md has what that
-- does to the pacing. Each player's parades and lanterns are saved, and
-- unlock decorations and colours for their festival (FestivalService).
--
-- The board by the courtyard's way in lists the server's best Ghost Catcher
-- rounds, so there's something to look at between parades.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Config = require(Shared.Config.Parade)
local Theme = require(Shared.Config.Theme)
local Earnings = require(Shared.Earnings)
local Parade = require(Shared.Parade)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local Remote = ReplicatedStorage.Remotes.Parade :: RemoteEvent

local BOARD_SECONDS = 5
local BOARD_LINES = 5

type Route = { Model: Instance, Centre: CFrame, RadiusX: number, RadiusZ: number }

type Running = {
	StartedAt: number,
	Lanterns: { Parade.Lantern },
	Caught: { [number]: boolean },
	Count: number,
	Goal: number,
	Filled: boolean,
	ByPlayer: { [Player]: number },
}

local ParadeService = {}

local route: Route? = nil
local running: Running? = nil
local serverStart = 0
local nextAt = 0
local random = Random.new()
local syncs = RateLimiter.new(2)
local joinedCallbacks: { (Player, { Caught: number, Filled: boolean }) -> () } = {}

local function findRoute(): Route?
	for _, model in CollectionService:GetTagged("ParadeRoute") do
		local centre = model:GetAttribute("RouteCentre")
		if typeof(centre) == "CFrame" then
			return {
				Model = model,
				Centre = centre,
				RadiusX = model:GetAttribute("RouteRadiusX") or 20,
				RadiusZ = model:GetAttribute("RouteRadiusZ") or 20,
			}
		end
	end
	return nil
end

local function startPayload(parade: Running): { [string]: any }
	local caught = {}
	for index in parade.Caught do
		table.insert(caught, index)
	end
	return { Kind = "Start", StartedAt = parade.StartedAt, Lanterns = parade.Lanterns, Caught = caught }
end

local function begin(now: number)
	local count = Parade.lanternCount(Config, #Players:GetPlayers())
	local parade: Running = {
		StartedAt = now,
		Lanterns = Parade.schedule(Config, function()
			return random:NextNumber()
		end, count),
		Caught = {},
		Count = 0,
		Goal = Parade.goal(Config, count),
		Filled = false,
		ByPlayer = {},
	}
	running = parade
	Workspace:SetAttribute("ParadeStartedAt", now)
	Workspace:SetAttribute("ParadeMeter", 0)
	Workspace:SetAttribute("ParadeGoal", parade.Goal)
	Workspace:SetAttribute("ParadeLive", true)
	Remote:FireAllClients(startPayload(parade))
end

local function finish(parade: Running, now: number)
	running = nil
	for player, caught in parade.ByPlayer do
		local data = player.Parent and DataService.get(player)
		if data then
			data.Parade.Joined += 1
			data.Parade.Lanterns += caught
			local bonus = 0
			if parade.Filled then
				data.Parade.Filled += 1
				bonus = Parade.fullReward(Config, Earnings.perSecond(data.Owned, Balance))
				if not EconomyService.addCoins(player, bonus) then
					bonus = 0
				end
			end
			Remote:FireClient(player, { Kind = "Thanks", Caught = caught, Bonus = bonus, Filled = parade.Filled })
			for _, callback in joinedCallbacks do
				task.spawn(callback, player, { Caught = caught, Filled = parade.Filled })
			end
		end
	end
	nextAt = Parade.nextStart(Config, serverStart, now + 1)
	Workspace:SetAttribute("ParadeLive", false)
	Workspace:SetAttribute("ParadeAt", nextAt)
	Remote:FireAllClients({ Kind = "End", Filled = parade.Filled, Count = parade.Count, Goal = parade.Goal })
end

local function catch(parade: Running, player: Player, index: number)
	parade.Caught[index] = true
	parade.Count += 1
	local before = parade.ByPlayer[player] or 0
	parade.ByPlayer[player] = before + 1
	local data = DataService.get(player)
	local reward = 0
	if data then
		reward = Parade.catchReward(Config, Earnings.perSecond(data.Owned, Balance), before)
		if reward > 0 and not EconomyService.addCoins(player, reward) then
			reward = 0
		end
	end
	Workspace:SetAttribute("ParadeMeter", parade.Count)
	Remote:FireAllClients({ Kind = "Caught", Index = index, UserId = player.UserId, Reward = reward })
	if not parade.Filled and parade.Count >= parade.Goal then
		parade.Filled = true
		Remote:FireAllClients({ Kind = "Filled" })
	end
end

local function step()
	local now = Workspace:GetServerTimeNow()
	local parade = running
	local loop = route
	if not loop then
		return
	end
	if not parade then
		if now >= nextAt then
			begin(now)
		end
		return
	end
	local t = now - parade.StartedAt
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local at = loop.Centre:PointToObjectSpace(root.Position)
			for index, lantern in parade.Lanterns do
				if not parade.Caught[index] and Parade.catches(Config, loop, lantern, t, at.X, at.Y, at.Z) then
					catch(parade, player, index)
				end
			end
		end
	end
	if t > Config.RunSeconds then
		finish(parade, now)
	end
end

-- The server's best Ghost Catcher rounds, on the board by the courtyard.
local function writeBoard()
	local loop = route
	local board = loop and loop.Model:FindFirstChild("BestBoard", true)
	local gui = board and board:FindFirstChildWhichIsA("SurfaceGui")
	local text = gui and gui:FindFirstChildWhichIsA("TextLabel")
	if not text then
		return
	end
	local best = {}
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data and data.Activity.Best > 0 then
			table.insert(best, { Name = player.DisplayName, Best = data.Activity.Best })
		end
	end
	table.sort(best, function(a, b)
		return a.Best > b.Best
	end)
	local lines = { Theme.Strings.BestBoardTitle }
	for index = 1, math.min(#best, BOARD_LINES) do
		table.insert(lines, Theme.Strings.BestBoardLine:format(best[index].Name, best[index].Best))
	end
	local wanted = table.concat(lines, "\n")
	if text.Text ~= wanted then
		text.Text = wanted
	end
end

-- Runs callback(player, result) for everyone who caught a lantern, when a
-- parade ends.
function ParadeService.onJoined(callback: (Player, { Caught: number, Filled: boolean }) -> ())
	table.insert(joinedCallbacks, callback)
end

function ParadeService.init()
	route = findRoute()
	if route then
		Workspace:SetAttribute("ParadeCentre", route.Centre)
		Workspace:SetAttribute("ParadeRadiusX", route.RadiusX)
		Workspace:SetAttribute("ParadeRadiusZ", route.RadiusZ)
	else
		warn("No courtyard tagged ParadeRoute, so there will be no Moonlight Parade")
	end
	serverStart = Workspace:GetServerTimeNow()
	nextAt = Parade.nextStart(Config, serverStart, serverStart)
	Workspace:SetAttribute("ParadeAt", nextAt)
	Workspace:SetAttribute("ParadeLive", false)
	-- A player who joins during a parade asks for what's out.
	Remote.OnServerEvent:Connect(function(player, message)
		if type(message) == "table" and message.Kind == "Sync" and running and syncs:allow(player) then
			Remote:FireClient(player, startPayload(running))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		syncs:forget(player)
		if running then
			running.ByPlayer[player] = nil
		end
	end)
	RunService.Heartbeat:Connect(step)
end

function ParadeService.start()
	while true do
		writeBoard()
		task.wait(BOARD_SECONDS)
	end
end

return ParadeService
