-- Ghost Catcher (Config/Activity). Every claimed plot gets a booth at the
-- back of its walkway, with a pad in front of it. The owner steps on the pad
-- to start a round: wisps appear one after another down the middle of the
-- plot, and walking through one catches it, for a few seconds of the plot's
-- income. The server places the wisps, decides every catch from where the
-- owner's character is, and pays; the client only draws them, from what the
-- Activity remote tells it. Rounds are CooldownSeconds apart, and each
-- player's best round and number of rounds are saved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Activity = require(Shared.Activity)
local Balance = require(Shared.Config.Balance)
local Config = require(Shared.Config.Activity)
local Layout = require(Shared.Config.Layout)
local Theme = require(Shared.Config.Theme)
local Earnings = require(Shared.Earnings)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)

local Remote = ReplicatedStorage.Remotes.Activity :: RemoteEvent

local PAD_COLOR = Theme.Activity.Color
local TRIGGER_HEIGHT = 3

type Round = {
	Plot: BasePart,
	StartedAt: number,
	Wisps: { Activity.Wisp },
	Caught: { [number]: boolean },
	Count: number,
	Earned: number,
	Income: number,
}

local ActivityService = {}

local rounds: { [Player]: Round } = {}
local endedCallbacks: { (Player, number) -> () } = {}
local booths: { [Player]: Folder } = {}
local random = Random.new()

local function floorOf(plot: BasePart, x: number, z: number): CFrame
	return plot.CFrame * CFrame.new(x, plot.Size.Y / 2, z)
end

local function setReady(player: Player, readyAt: number)
	local folder = booths[player]
	local booth = folder and folder:FindFirstChild("Booth")
	if booth then
		booth:SetAttribute("ReadyAt", readyAt)
		booth:SetAttribute("Playing", nil)
	end
end

local function start(player: Player)
	local plot = PlotService.plotOf(player)
	local data = DataService.get(player)
	local folder = booths[player]
	local booth = folder and folder:FindFirstChild("Booth")
	if rounds[player] or not plot or not data or not booth then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now < (booth:GetAttribute("ReadyAt") or 0) then
		return
	end

	local pad = Layout.Activity.Pad
	local wisps = Activity.schedule(Config, function()
		return random:NextNumber()
	end, pad)
	local startedAt = now + Config.LeadSeconds
	rounds[player] = {
		Plot = plot,
		StartedAt = startedAt,
		Wisps = wisps,
		Caught = {},
		Count = 0,
		Earned = 0,
		Income = Earnings.perSecond(data.Owned, Balance),
	}
	booth:SetAttribute("Playing", true)
	Remote:FireClient(player, { Kind = "Start", StartedAt = startedAt, Wisps = wisps })
end

local function finish(player: Player, round: Round)
	rounds[player] = nil
	local perfect = round.Count == #round.Wisps
	if perfect then
		local bonus = Activity.perfectReward(Config, round.Income)
		if EconomyService.addCoins(player, bonus) then
			round.Earned += bonus
		end
	end
	local data = DataService.get(player)
	local best = round.Count
	if data then
		data.Activity.Rounds += 1
		data.Activity.Best = math.max(data.Activity.Best, round.Count)
		best = data.Activity.Best
	end
	setReady(player, Workspace:GetServerTimeNow() + Config.CooldownSeconds)
	Remote:FireClient(player, {
		Kind = "End",
		Caught = round.Count,
		Total = #round.Wisps,
		Earned = round.Earned,
		Best = best,
		Perfect = perfect,
	})
	for _, callback in endedCallbacks do
		task.spawn(callback, player, round.Count)
	end
end

-- Checks every round in play for catches, and ends the ones that are over.
local function step()
	local now = Workspace:GetServerTimeNow()
	for player, round in rounds do
		local t = now - round.StartedAt
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local plot = round.Plot
			local at = plot.CFrame:PointToObjectSpace(root.Position)
			local y = at.Y - plot.Size.Y / 2
			for index, wisp in round.Wisps do
				if not round.Caught[index] and Activity.catches(Config, wisp, t, at.X, y, at.Z) then
					round.Caught[index] = true
					round.Count += 1
					local reward = Activity.wispReward(Config, round.Income)
					if EconomyService.addCoins(player, reward) then
						round.Earned += reward
					end
					Remote:FireClient(player, { Kind = "Caught", Index = index, Reward = reward })
				end
			end
		end
		if t > Config.RoundSeconds then
			finish(player, round)
		end
	end
end

-- A booth and its pad on a plot, and the invisible column over the pad
-- that's stepped on.
local function makeBooth(plot: BasePart): (Folder, BasePart)
	local spec = Layout.Activity
	local folder = Instance.new("Folder")
	folder.Name = "Activity"
	local booth =
		Theme.Activity.booth(floorOf(plot, spec.X, spec.Z), Vector3.new(spec.Size[1], spec.Size[2], spec.Size[3]))
	booth:SetAttribute("ReadyAt", 0)
	booth:AddTag("ActivityBooth")
	booth.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	booth.Parent = folder

	-- A round glowing pad on a dark rim, like the buy pads, with the same
	-- invisible column over it that's stepped on.
	local size = Layout.ButtonSize
	local floor = floorOf(plot, spec.Pad.X, spec.Pad.Z)
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local function disc(name: string, height: number, width: number, cframe: CFrame, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(height, width, width)
		part.CFrame = cframe * upright
		part.Color = color
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = folder
		return part
	end
	local pad = disc("Pad", 0.6, size - 0.6, floor * CFrame.new(0, 0.3, 0), PAD_COLOR)
	pad.Material = Enum.Material.Neon
	disc("Rim", 0.4, size, floor * CFrame.new(0, 0.2, 0), Color3.fromHex(Theme.Palette.ButtonRim))
	local trigger = disc("Trigger", TRIGGER_HEIGHT, size, floor * CFrame.new(0, TRIGGER_HEIGHT / 2 - 0.5, 0), PAD_COLOR)
	trigger.Transparency = 1
	trigger.CanTouch = true
	trigger.CanQuery = false
	folder.Parent = plot
	return folder, trigger
end

-- The booth and its pad on a newly claimed plot.
local function buildBooth(player: Player)
	local plot = PlotService.plotOf(player)
	if not plot or booths[player] then
		return
	end
	local folder, trigger = makeBooth(plot)
	trigger.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and Players:GetPlayerFromCharacter(character) == player then
			start(player)
		end
	end)
	booths[player] = folder
end

-- Puts a booth on a staged plot (PlotService.stage), which nobody plays.
function ActivityService.stage(plot: BasePart)
	local _, trigger = makeBooth(plot)
	trigger:Destroy()
end

local function forget(player: Player)
	rounds[player] = nil
	local folder = booths[player]
	if folder then
		folder:Destroy()
		booths[player] = nil
	end
end

-- Runs callback(player, caught) when one of their rounds ends.
function ActivityService.onRoundEnded(callback: (Player, number) -> ())
	table.insert(endedCallbacks, callback)
end

function ActivityService.init()
	PlotService.onClaimed(buildBooth)
	Players.PlayerRemoving:Connect(forget)
	RunService.Heartbeat:Connect(step)
end

return ActivityService
