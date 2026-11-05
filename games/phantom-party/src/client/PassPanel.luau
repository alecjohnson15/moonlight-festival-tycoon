-- The Moon Pass: 30 tiers climbed with XP from every round. Each tier has a
-- free reward everyone can claim and, for Moon Pass Premium owners, a named
-- cosmetic on some tiers. Every reward on both tracks is shown up front, so
-- buying the premium track is buying exactly what's listed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local CrateConfig = require(Shared.Config.Crates)
local Items = require(Shared.Config.Items)
local Pass = require(Shared.Config.Pass)
local Format = require(Shared.Format)
local Corner = require(script.Parent.Corner)
local Hud = require(script.Parent.Hud)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local RequestPurchase = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestPurchase") :: RemoteEvent

local PassPanel = {}

local COLUMN = 92
local CELL = 84

local gui = Ui.screen("Pass", 3)
local panel, body = Ui.panel(gui, "Moon Pass", 640, 420)
local scrollTo: number? = nil

local function product()
	for _, entry in Catalog do
		if entry.Perk == "MoonPass" then
			return entry
		end
	end
	return nil
end

local function clear()
	for _, child in body:GetChildren() do
		child:Destroy()
	end
end

-- What a reward says, for the note after claiming it.
local function describe(result: { [string]: any }): string
	if result.Item then
		local item = Items.get(result.Item)
		local name = item and item.Name or result.Item
		if result.Crate then
			local crate = CrateConfig.get(result.Crate)
			return `{crate and crate.Name or "A crate"} gave you {name}!`
		end
		return `{name} is yours.`
	elseif result.Coins then
		return `+{Format.whole(result.Coins)} coins`
	end
	return "Claimed."
end

local function claimed(result: { [string]: any })
	Sounds.play("CrateReveal")
	local color = if result.Rarity then Ui.rarityColor(result.Rarity) else Ui.Colors.Gold
	Corner.note(`Tier {result.Tier} reward`, describe(result), color)
end

-- One reward square: an item's picture, a crate or a pile of coins.
local function rewardCell(parent: Instance, reward: Pass.Reward?, order: number): Frame
	local cell = Ui.make("Frame", {
		Size = UDim2.fromOffset(CELL, CELL),
		BackgroundColor3 = Ui.Colors.Card,
		LayoutOrder = order,
	}, parent)
	Ui.round(cell, 8)
	if not reward then
		cell.BackgroundTransparency = 0.6
		return cell
	end
	if reward.Item then
		local item = Items.get(reward.Item)
		Ui.picture(cell, reward.Item)
		Ui.stroke(cell, Ui.rarityColor(item and item.Rarity or "Common"), 2)
		Ui.label(cell, item and item.Name or reward.Item, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 2, 1, -2),
			Size = UDim2.new(1, -4, 0, 22),
			TextSize = 10,
			TextWrapped = true,
			TextStrokeTransparency = 0.4,
			ZIndex = 3,
		})
	elseif reward.Crate then
		local crate = CrateConfig.get(reward.Crate)
		local color = if crate then Color3.fromHex(crate.Color) else Ui.Colors.Accent
		Ui.stroke(cell, color, 2)
		local box = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(40, 34),
			BackgroundColor3 = color,
		}, cell)
		Ui.round(box, 6)
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0, 8, 1, 0),
			BackgroundColor3 = Ui.Colors.Gold,
			BorderSizePixel = 0,
		}, box)
		Ui.label(cell, crate and crate.Name or "Crate", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 2, 1, -2),
			Size = UDim2.new(1, -4, 0, 26),
			TextSize = 10,
			TextColor3 = color,
		})
	elseif reward.Coins then
		Ui.stroke(cell, Ui.Colors.Gold, 1.5)
		local coin = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = Ui.Colors.Gold,
		}, cell)
		Ui.round(coin, 17)
		Ui.stroke(coin, Color3.fromRGB(200, 140, 40), 3)
		Ui.label(cell, `+{Format.whole(reward.Coins)}`, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -6),
			Size = UDim2.new(1, 0, 0, 20),
			Font = Ui.Title,
			TextSize = 15,
			TextColor3 = Ui.Colors.Gold,
		})
	end
	return cell
end

-- Marks a cell as claimed, ready to claim or still locked.
local function mark(cell: Frame, how: string, onClaim: (() -> ())?)
	if how == "Claimed" then
		local shade = Ui.make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			ZIndex = 4,
		}, cell)
		Ui.round(shade, 8)
		Ui.label(shade, "✓", {
			Size = UDim2.fromScale(1, 1),
			Font = Ui.Title,
			TextSize = 34,
			TextColor3 = Ui.Colors.Good,
			ZIndex = 5,
		})
	elseif how == "Ready" and onClaim then
		local button = Ui.button(cell, "Claim", Ui.Colors.Good, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromOffset(60, 22),
			TextSize = 12,
			ZIndex = 6,
		})
		button.Activated:Connect(onClaim)
	elseif how == "Locked" then
		local shade = Ui.make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.6,
			ZIndex = 4,
		}, cell)
		Ui.round(shade, 8)
		Ui.label(shade, "LOCKED", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.fromOffset(60, 12),
			TextSize = 9,
			TextColor3 = Ui.Colors.Dim,
			ZIndex = 5,
		})
	end
end

local draw: () -> ()

local function claim(track: string, tier: number)
	local result = State.request("Claim", track, tier)
	if result.Ok then
		claimed(result)
	else
		Sounds.play("Deny")
	end
end

draw = function()
	clear()
	local profile = State.Profile
	if not profile then
		Ui.label(body, "Loading your pass...", { Size = UDim2.fromScale(1, 1) })
		return
	end
	local pass = profile.Pass
	local premium = profile.Perks and profile.Perks.MoonPass == true
	local tier = pass.Tier or 0

	-- Season, tier and the bar to the next tier.
	Ui.label(body, Pass.SeasonName, {
		Size = UDim2.new(1, -200, 0, 20),
		Font = Ui.Title,
		TextSize = 17,
		TextColor3 = Ui.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local tierLine = if tier >= Pass.Tiers
		then `Tier {tier} of {Pass.Tiers}: the whole pass!`
		else `Tier {tier} of {Pass.Tiers} · {pass.Into}/{pass.PerTier} XP to tier {tier + 1}`
	Ui.label(body, tierLine, {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, -200, 0, 16),
		TextSize = 12,
		TextColor3 = Ui.Colors.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local track = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, -200, 0, 10),
		BackgroundColor3 = Ui.Colors.Track,
	}, body)
	Ui.round(track, 5)
	local fill = Ui.make("Frame", {
		Size = UDim2.fromScale(math.clamp(pass.Into / math.max(1, pass.PerTier), 0, 1), 1),
		BackgroundColor3 = Ui.Colors.Gold,
	}, track)
	Ui.round(fill, 5)

	local ready = pass.Ready or 0
	local claimAll = Ui.button(
		body,
		if ready > 0 then `Claim all ({ready})` else "Nothing to claim",
		if ready > 0 then Ui.Colors.Good else Ui.Colors.Track,
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(180, 34) }
	)
	claimAll.Activated:Connect(function()
		if ready <= 0 then
			return
		end
		local result = State.request("ClaimAll")
		if result.Ok then
			Sounds.play("CrateReveal")
			local items = 0
			local coins = 0
			for _, one in result.Results or {} do
				if one.Ok then
					if one.Item then
						items += 1
					end
					coins += one.Coins or 0
				end
			end
			local parts = {}
			if items > 0 then
				table.insert(parts, `{items} item{if items == 1 then "" else "s"}`)
			end
			if coins > 0 then
				table.insert(parts, `{Format.whole(coins)} coins`)
			end
			Corner.note("Pass rewards claimed", table.concat(parts, " and "), Ui.Colors.Gold)
		else
			Sounds.play("Deny")
		end
	end)

	-- Track labels down the left.
	local labels = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(0, 62, 1, -116),
		BackgroundTransparency = 1,
	}, body)
	Ui.label(labels, "TIER", {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 11,
		TextColor3 = Ui.Colors.Dim,
	})
	Ui.label(labels, "FREE", {
		Position = UDim2.fromOffset(0, 24 + CELL / 2 - 9),
		TextSize = 13,
		Font = Ui.Title,
	})
	Ui.label(labels, "PREMIUM", {
		Position = UDim2.fromOffset(0, 24 + CELL + 8 + CELL / 2 - 9),
		TextSize = 12,
		Font = Ui.Title,
		TextColor3 = Ui.Colors.Gold,
	})

	local strip = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(66, 64),
		Size = UDim2.new(1, -66, 0, 24 + CELL * 2 + 8 + 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Ui.Colors.Gold,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
	}, body)
	Ui.list(strip, COLUMN - CELL, true)

	for number = 1, Pass.Tiers do
		local reached = tier >= number
		local column = Ui.make("Frame", {
			Size = UDim2.fromOffset(CELL, 24 + CELL * 2 + 8),
			BackgroundTransparency = 1,
			LayoutOrder = number,
		}, strip)
		local head = Ui.make("Frame", {
			Size = UDim2.fromOffset(CELL, 20),
			BackgroundColor3 = if reached then Ui.Colors.Gold else Ui.Colors.Track,
		}, column)
		Ui.round(head, 6)
		Ui.label(head, tostring(number), {
			Size = UDim2.fromScale(1, 1),
			Font = Ui.Title,
			TextSize = 14,
			TextColor3 = if reached then Ui.Colors.Panel else Ui.Colors.Dim,
		})
		local cells = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.fromOffset(CELL, CELL * 2 + 8),
			BackgroundTransparency = 1,
		}, column)
		Ui.list(cells, 8)

		local key = tostring(number)
		local free = rewardCell(cells, Pass.freeReward(number), 1)
		if pass.Free[key] then
			mark(free, "Claimed")
		elseif reached then
			mark(free, "Ready", function()
				scrollTo = strip.CanvasPosition.X
				claim("Free", number)
			end)
		end

		local premiumReward = Pass.Premium[number]
		local paid = rewardCell(cells, premiumReward, 2)
		if premiumReward then
			if pass.Premium[key] then
				mark(paid, "Claimed")
			elseif not premium then
				mark(paid, "Locked")
			elseif reached then
				mark(paid, "Ready", function()
					scrollTo = strip.CanvasPosition.X
					claim("Premium", number)
				end)
			end
		end
	end

	-- Opens near the tier you're on, or where you were when you claimed.
	task.defer(function()
		local x = scrollTo or math.max(0, (tier - 2) * COLUMN)
		scrollTo = nil
		strip.CanvasPosition = Vector2.new(x, 0)
	end)

	local entry = product()
	if premium then
		Ui.label(body, "You have Moon Pass Premium. Every premium reward you reach is yours to claim.", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 34),
			TextSize = 12,
			TextColor3 = Ui.Colors.Gold,
		})
	elseif entry then
		local ready2 = entry.PassId ~= 0
		Ui.label(
			body,
			"Premium adds nine named cosmetics, all shown above. Tiers you've already reached unlock at once.",
			{
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, -200, 0, 40),
				TextSize = 12,
				TextColor3 = Ui.Colors.Dim,
				TextXAlignment = Enum.TextXAlignment.Left,
			}
		)
		local buy = Ui.button(
			body,
			if ready2 then `Get Premium · R$ {entry.Price}` else "Premium soon",
			if ready2 then Ui.Colors.Robux else Ui.Colors.Track,
			{ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, -2), Size = UDim2.fromOffset(190, 36) }
		)
		buy.Activated:Connect(function()
			if ready2 then
				RequestPurchase:FireServer(entry.Id)
			end
		end)
	end
end

function PassPanel.open()
	Ui.show(panel)
	draw()
end

function PassPanel.start()
	Hud.onMenu("Pass", function()
		if Ui.isOpen(panel) then
			Ui.hide(panel)
		else
			PassPanel.open()
		end
	end)
	State.on("Profile", function()
		if Ui.isOpen(panel) then
			draw()
		end
	end)
end

return PassPanel
