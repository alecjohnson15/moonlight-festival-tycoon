-- Game passes (Config/Catalog). Checks which passes each player owns when
-- they join, opens a purchase prompt only when the player asks for one (and
-- only for a pass that is set up and not already owned), and tells the
-- other services when what a player owns changes. Adapted from the
-- tycoon's PurchaseService; this game sells passes only.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Profile = require(ReplicatedStorage.Shared.Profile)
local Lib = script.Parent.Parent.Lib
local RateLimiter = require(Lib.RateLimiter)
local Net = require(Lib.Net)

local PassService = {}

local passById: { [string]: Catalog.Pass } = {}
local passByPassId: { [number]: Catalog.Pass } = {}
local owned: { [Player]: { [string]: boolean } } = {}
local checked: { [Player]: boolean } = {}
local callbacks: { (Player) -> () } = {}
local promptLimiter = RateLimiter.new(1)

for _, pass in Catalog do
	passById[pass.Id] = pass
	if pass.PassId ~= 0 then
		passByPassId[pass.PassId] = pass
	end
end

local function changed(player: Player)
	for _, callback in callbacks do
		task.spawn(callback, player)
	end
end

-- Runs callback(player) when the player's passes have been checked on
-- joining, and again whenever they buy one.
function PassService.onChanged(callback: (Player) -> ())
	table.insert(callbacks, callback)
end

function PassService.ready(player: Player): boolean
	return checked[player] == true
end

function PassService.owns(player: Player, passId: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[passId] == true
end

-- Everything the player's passes grant, in shared/Profile's shape.
function PassService.grants(player: Player): Profile.Grants
	local grants = Profile.noGrants()
	for id in owned[player] or {} do
		local pass = passById[id]
		if pass then
			for _, role in pass.Grants.Roles or {} do
				grants.Roles[role] = true
			end
			for _, cosmetic in pass.Grants.Cosmetics or {} do
				grants.Cosmetics[cosmetic] = true
			end
			for _, decor in pass.Grants.Decor or {} do
				grants.Decor[decor] = true
			end
			if pass.Grants.Premium then
				grants.Premium = true
			end
		end
	end
	return grants
end

local function check(player: Player)
	local passes = {}
	owned[player] = passes
	for passId, pass in passByPassId do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
		if ok and result then
			passes[pass.Id] = true
		elseif not ok then
			warn(`Could not check game pass {passId} for {player.UserId}: {result}`)
		end
	end
	if player.Parent then
		checked[player] = true
		changed(player)
	end
end

local function onRequest(player: Player, passId: unknown)
	if typeof(passId) ~= "string" or not promptLimiter:allow(player) then
		return
	end
	local pass = passById[passId]
	if not pass or PassService.owns(player, passId) then
		return
	end
	if pass.PassId == 0 then
		Net.notice(player, "That pass is coming soon.", "Info")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.PassId)
end

function PassService.init()
	Net.remote("RequestPurchase").OnServerEvent:Connect(onRequest)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passByPassId[passId]
		local passes = owned[player]
		if purchased and pass and passes and not passes[pass.Id] then
			passes[pass.Id] = true
			Net.notice(player, `Thank you! {pass.Name} is yours.`, "Good")
			changed(player)
		end
	end)
	Players.PlayerAdded:Connect(check)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		checked[player] = nil
		promptLimiter:forget(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
end

return PassService
