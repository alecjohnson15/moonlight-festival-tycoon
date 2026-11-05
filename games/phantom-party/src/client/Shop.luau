-- The Mask Boutique: two tabs.
--   Coins: cosmetics at a fixed coin price. What you click is what you get.
--   Robux: the game passes, each saying exactly what it gives. Nothing for
--          Robux is random, and nothing gives coins or crates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Items = require(Shared.Config.Items)
local ShopConfig = require(Shared.Config.Shop)
local Format = require(Shared.Format)
local Corner = require(script.Parent.Corner)
local Hud = require(script.Parent.Hud)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local RequestPurchase = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestPurchase") :: RemoteEvent

local Shop = {}

local gui = Ui.screen("Shop", 3)
local panel, body = Ui.panel(gui, "Mask Boutique", 560, 400)
local tab = "Coins"
local content: Frame
local pick: (string) -> ()

local function owns(itemId: string): boolean
	local profile = State.Profile
	if not profile then
		return false
	end
	if (profile.Extra or {})[itemId] then
		return true
	end
	for _, owned in profile.Items do
		if owned == itemId then
			return true
		end
	end
	return Items.get(itemId) ~= nil and Items.get(itemId).Default == true
end

local function coinsTab(holder: Frame)
	local grid = Ui.grid(holder, Vector2.new(120, 170))
	for index, offer in ShopConfig.Offers do
		local item = Items.get(offer.Item)
		if item then
			local cell = Ui.make("Frame", { BackgroundTransparency = 1, LayoutOrder = index }, grid)
			local card = Ui.itemCard(cell, offer.Item, 120)
			card.Size = UDim2.fromOffset(120, 132)
			Ui.label(cell, Items.KIND_NAMES[item.Kind] or item.Kind, {
				Position = UDim2.fromOffset(0, 132),
				Size = UDim2.new(1, 0, 0, 12),
				TextSize = 10,
				TextColor3 = Ui.rarityColor(item.Rarity),
			})
			local have = owns(offer.Item)
			local button = Ui.button(
				cell,
				if have then "Owned" else `{Format.whole(offer.Price)} coins`,
				if have then Ui.Colors.Track else Ui.Colors.Gold,
				{ Position = UDim2.fromOffset(0, 146), Size = UDim2.new(1, 0, 0, 24), TextSize = 13 }
			)
			button.Activated:Connect(function()
				if have then
					return
				end
				local result = State.request("Buy", offer.Item)
				if result.Ok then
					Sounds.play("CrateReveal")
					Corner.note("Bought!", `{item.Name} is yours and you're wearing it.`, Ui.Colors.Good)
				else
					Sounds.play("Deny")
					Corner.note(
						"Can't buy that yet",
						if result.Error == "NeedCoins"
							then "Not enough coins. Play rounds to earn more!"
							else "Try again in a moment.",
						Ui.Colors.Bad
					)
				end
				pick(tab)
			end)
		end
	end
end

local function robuxTab(holder: Frame)
	local list = Ui.make("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Ui.Colors.Accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
	}, holder)
	Ui.list(list, 8)
	local owned = {}
	for _, id in (State.Profile and State.Profile.Passes) or {} do
		owned[id] = true
	end
	for index, product in Catalog do
		local row = Ui.make("Frame", {
			Size = UDim2.new(1, -10, 0, 92),
			BackgroundColor3 = Ui.Colors.Card,
			LayoutOrder = index,
		}, list)
		Ui.round(row, 10)
		local picture = Ui.make("Frame", {
			Size = UDim2.fromOffset(80, 80),
			Position = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Ui.Colors.Panel,
		}, row)
		Ui.round(picture, 8)
		if product.Items[1] then
			Ui.picture(picture, product.Items[1])
		else
			Ui.label(
				picture,
				if product.Perk == "MoonPass" then "MOON\nPASS" elseif product.Perk == "VIP" then "VIP" else "EMOTES",
				{
					Size = UDim2.fromScale(1, 1),
					Font = Ui.Title,
					TextSize = 18,
					TextColor3 = Ui.Colors.Gold,
				}
			)
		end
		Ui.label(row, product.Name, {
			Position = UDim2.fromOffset(94, 6),
			Size = UDim2.new(1, -220, 0, 20),
			Font = Ui.Title,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.Gold,
		})
		Ui.label(row, product.Description, {
			Position = UDim2.fromOffset(94, 28),
			Size = UDim2.new(1, -220, 0, 58),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Ui.Colors.Dim,
		})
		local have = owned[product.Id] == true
		local ready = product.PassId ~= 0
		local button = Ui.button(
			row,
			if have then "Owned" elseif ready then `R$ {product.Price}` else "Soon",
			if have or not ready then Ui.Colors.Track else Ui.Colors.Robux,
			{
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(104, 36),
			}
		)
		button.Activated:Connect(function()
			if have or not ready then
				return
			end
			RequestPurchase:FireServer(product.Id)
		end)
	end
end

content, pick = Ui.tabs(body, { "Coins", "Robux" }, function(name)
	tab = name
	local holder = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, content)
	if name == "Coins" then
		coinsTab(holder)
	else
		robuxTab(holder)
	end
end)

function Shop.open(which: string?)
	Ui.show(panel)
	pick(which or tab)
end

function Shop.start()
	Hud.onMenu("Shop", function()
		if Ui.isOpen(panel) then
			Ui.hide(panel)
		else
			Shop.open()
		end
	end)
	State.on("Profile", function()
		if Ui.isOpen(panel) then
			pick(tab)
		end
	end)
end

return Shop
