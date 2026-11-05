-- Trading cosmetics between players, from the Trading Hall or anywhere in
-- the lobby. One player asks, the other says yes, and both put up to eight
-- items on the table. When both accept, a short countdown runs; any change
-- to either side stops it, so nobody can swap an item out at the last
-- second. Then the server checks every item again and moves them all at
-- once, or none of them, and saves both players straight away.
--
-- Only items from crates and the coin shop can be traded. Moon Pass and
-- Robux items stay with the account that earned or bought them, and
-- nothing can be traded for Robux or coins: items for items only.
--
-- One known gap: the two saves are separate, so if the server crashed in
-- the instant between them, one side could keep an old copy. The trade log
-- in each save records every trade, so support can put that right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local TradeRules = require(Shared.Rules.Trade)
local Match = require(script.Parent.Parent.Lib.Match)
local RateLimiter = require(script.Parent.Parent.Lib.RateLimiter)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local ProfileService = require(script.Parent.ProfileService)

local TradeRemote = ReplicatedStorage.Remotes.Trade :: RemoteEvent

local REQUEST_SECONDS = 20
local LOG_LENGTH = 25

local TradeService = {}

local sessions: { [Player]: TradeRules.Session } = {}
local requests: { [Player]: { [Player]: number } } = {}
local requestLimiter = RateLimiter.new(2)
local changeLimiter = RateLimiter.new(0.2)

-- Whether a player can trade now: loaded, and not in a live round.
local function free(player: Player): boolean
	if not DataService.get(player) then
		return false
	end
	if Match.live() then
		local participant = Match.get(player)
		if participant and participant.State ~= "Out" then
			return false
		end
	end
	return true
end

local function view(session: TradeRules.Session, player: Player): { [string]: any }
	local mine, theirs = TradeRules.side(session, player)
	local me = DataService.get(player)
	local them = theirs and DataService.get(theirs.Id)
	local function items(side, holder)
		local list = {}
		for _, uid in side.Offer do
			table.insert(list, { Uid = uid, Item = holder and holder.Items[uid] })
		end
		return list
	end
	local partner = (theirs :: any).Id :: Player
	local endsAt = nil
	if session.CountdownEnds then
		endsAt = Workspace:GetServerTimeNow() + math.max(0, session.CountdownEnds - os.clock())
	end
	return {
		With = { UserId = partner.UserId, Name = partner.DisplayName },
		Mine = items(mine, me),
		Theirs = items(theirs, them),
		MineAccepted = (mine :: any).Accepted,
		TheirsAccepted = (theirs :: any).Accepted,
		State = session.State,
		EndsAt = endsAt,
	}
end

local function update(session: TradeRules.Session)
	for _, side in { session.A, session.B } do
		local player = side.Id :: Player
		if player.Parent then
			TradeRemote:FireClient(player, "Update", view(session, player))
		end
	end
end

local function close(session: TradeRules.Session, reason: string)
	TradeRules.cancel(session)
	for _, side in { session.A, session.B } do
		local player = side.Id :: Player
		if sessions[player] == session then
			sessions[player] = nil
		end
		if player.Parent then
			TradeRemote:FireClient(player, "Closed", reason)
		end
	end
end

local function itemsOf(holder, uids: { string }): { string }
	local list = {}
	for _, uid in uids do
		table.insert(list, holder.Items[uid])
	end
	return list
end

local function log(holder, with: number, gave: { string }, got: { string })
	table.insert(holder.TradeLog, { With = with, Gave = gave, Got = got, Time = os.time() })
	while #holder.TradeLog > LOG_LENGTH do
		table.remove(holder.TradeLog, 1)
	end
end

local function complete(session: TradeRules.Session)
	local a, b = session.A.Id :: Player, session.B.Id :: Player
	local dataA, dataB = DataService.get(a), DataService.get(b)
	if not dataA or not dataB or not free(a) or not free(b) then
		close(session, "Someone left")
		return
	end
	local aGives = itemsOf(dataA, session.A.Offer)
	local bGives = itemsOf(dataB, session.B.Offer)
	local ok, err = TradeRules.execute(session, dataA, dataB)
	if not ok then
		close(session, if err == "Missing" then "An item is gone" else "Trade failed")
		return
	end
	log(dataA, b.UserId, aGives, bGives)
	log(dataB, a.UserId, bGives, aGives)
	dataA.Stats.Trades += 1
	dataB.Stats.Trades += 1
	sessions[a] = nil
	sessions[b] = nil
	DataService.saveNow(a)
	DataService.saveNow(b)
	TradeRemote:FireClient(a, "Done", { Gave = aGives, Got = bGives, With = b.DisplayName })
	TradeRemote:FireClient(b, "Done", { Gave = bGives, Got = aGives, With = a.DisplayName })
	for _, player in { a, b } do
		ProfileService.push(player)
		ProfileService.refreshOutfit(player)
	end
	AnalyticsService.traded(a, #aGives, #bGives)
end

local function open(a: Player, b: Player)
	local session = TradeRules.new(a, b)
	sessions[a] = session
	sessions[b] = session
	for _, player in { a, b } do
		TradeRemote:FireClient(player, "Open", view(session, player))
	end
end

local function onTrade(player: Player, action: unknown, ...: any)
	if typeof(action) ~= "string" then
		return
	end
	local session = sessions[player]
	if action == "Request" then
		local targetId = ...
		if typeof(targetId) ~= "number" or not requestLimiter:allow(player) then
			return
		end
		local target = Players:GetPlayerByUserId(targetId)
		if not target or target == player or sessions[target] or session then
			TradeRemote:FireClient(player, "Denied", "They're busy right now.")
			return
		end
		if not free(player) or not free(target) then
			TradeRemote:FireClient(player, "Denied", "Trading opens when you're both back in the lobby.")
			return
		end
		-- Asking someone who already asked you opens the trade.
		local mine = requests[player]
		if mine and mine[target] and os.clock() - mine[target] < REQUEST_SECONDS then
			mine[target] = nil
			open(target, player)
			return
		end
		requests[target] = requests[target] or {}
		requests[target][player] = os.clock()
		TradeRemote:FireClient(target, "Incoming", { UserId = player.UserId, Name = player.DisplayName })
		TradeRemote:FireClient(player, "Sent", { UserId = target.UserId, Name = target.DisplayName })
	elseif action == "Respond" then
		local fromId, accept = ...
		local from = typeof(fromId) == "number" and Players:GetPlayerByUserId(fromId)
		local mine = requests[player]
		if not from or not mine or not mine[from] then
			return
		end
		local asked = mine[from]
		mine[from] = nil
		if accept ~= true then
			TradeRemote:FireClient(from, "Denied", `{player.DisplayName} said no thanks.`)
			return
		end
		if os.clock() - asked > REQUEST_SECONDS or session or sessions[from] or not free(player) or not free(from) then
			TradeRemote:FireClient(player, "Denied", "That request has expired.")
			return
		end
		open(from, player)
	elseif session then
		if not changeLimiter:allow(player) and action ~= "Cancel" then
			return
		end
		if action == "Offer" then
			local uids = ...
			local data = DataService.get(player)
			if typeof(uids) ~= "table" or not data then
				return
			end
			local clean = {}
			for _, uid in uids do
				if typeof(uid) == "string" then
					table.insert(clean, uid)
				end
			end
			local ok, err = TradeRules.setOffer(session, player, clean, data)
			if not ok then
				TradeRemote:FireClient(
					player,
					"Denied",
					if err == "TooMany" then "Eight items at most." else "That item can't be traded."
				)
			end
			update(session)
		elseif action == "Accept" then
			local ok = TradeRules.accept(session, player, os.clock())
			if ok then
				update(session)
			end
		elseif action == "Unaccept" then
			TradeRules.unaccept(session, player)
			update(session)
		elseif action == "Cancel" then
			close(session, `{player.DisplayName} closed the trade.`)
		end
	end
end

function TradeService.init()
	TradeRemote.OnServerEvent:Connect(onTrade)
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			close(session, "They left the game.")
		end
		requests[player] = nil
		for _, list in requests do
			list[player] = nil
		end
		requestLimiter:forget(player)
		changeLimiter:forget(player)
	end)
	-- A round starting pulls traders into the map: close their trades.
	Match.on("State", function(state)
		if state == "Reveal" then
			local seen = {}
			for player, session in sessions do
				if not seen[session] and not free(player) then
					seen[session] = true
					close(session, "The round is starting.")
				end
			end
		end
	end)
end

function TradeService.start()
	while true do
		task.wait(0.25)
		local seen = {}
		for _, session in sessions do
			if not seen[session] then
				seen[session] = true
				if TradeRules.due(session, os.clock()) then
					complete(session)
				end
			end
		end
	end
end

return TradeService
