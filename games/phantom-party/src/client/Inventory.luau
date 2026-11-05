-- Your items, one tab per kind: blades, blasters, masks, knockout effects
-- and trails. Tap one to wear it. Copies you own more than once show a
-- count, ready to trade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Hud = require(script.Parent.Hud)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Inventory = {}

local TABS = { "Masks", "Blades", "Blasters", "Effects", "Trails" }
local KIND_OF = { Masks = "Mask", Blades = "Blade", Blasters = "Blaster", Effects = "Effect", Trails = "Trail" }

local gui = Ui.screen("Inventory", 3)
local panel, body = Ui.panel(gui, "Your Items", 560, 400)
local tab = "Masks"
local content: Frame
local pick: (string) -> ()

-- Every item of a kind the player has, with how many copies.
function Inventory.owned(kind: string): { { Id: string, Count: number } }
	local profile = State.Profile
	local counts: { [string]: number } = {}
	local default = Items.DEFAULTS[kind]
	if default then
		counts[default] = 1
	end
	if profile then
		for itemId in profile.Extra or {} do
			local item = Items.get(itemId)
			if item and item.Kind == kind then
				counts[itemId] = math.max(counts[itemId] or 0, 1)
			end
		end
		for _, itemId in profile.Items do
			local item = Items.get(itemId)
			if item and item.Kind == kind then
				counts[itemId] = (counts[itemId] or 0) + (if item.Default then 0 else 1)
			end
		end
	end
	local list = {}
	for itemId, count in counts do
		table.insert(list, { Id = itemId, Count = count })
	end
	table.sort(list, function(a, b)
		local ra = Items.rank((Items.get(a.Id) :: any).Rarity)
		local rb = Items.rank((Items.get(b.Id) :: any).Rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.Id < b.Id
	end)
	return list
end

local function draw(holder: Frame, kind: string)
	local outfit = State.Profile and State.Profile.Outfit or Items.DEFAULTS
	local list = Inventory.owned(kind)
	local note = Ui.label(holder, "", {
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 12,
		TextColor3 = Ui.Colors.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	note.Text = if kind == "Blade"
		then "Your blade shows when you're the Phantom. Skins only change the look."
		elseif kind == "Blaster" then "Your blaster shows when you're the Guardian or the Hero."
		elseif kind == "Effect" then "What a knockout looks like when you make one."
		else "Everyone sees these, every round."
	local area = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 1, -20),
		BackgroundTransparency = 1,
	}, holder)
	local grid = Ui.grid(area, Vector2.new(100, 122))
	for index, entry in list do
		local item = Items.get(entry.Id)
		if item then
			local card = Ui.itemCard(grid, entry.Id, 100)
			card.LayoutOrder = index
			local wearing = outfit[kind] == entry.Id
			if wearing then
				local stroke = card:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = Ui.Colors.Gold
					stroke.Thickness = 3
				end
				Ui.label(card, "WEARING", {
					Position = UDim2.fromOffset(4, 4),
					Size = UDim2.fromOffset(60, 12),
					TextSize = 10,
					TextColor3 = Ui.Colors.Gold,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 3,
				})
			end
			if entry.Count > 1 then
				Ui.label(card, `x{entry.Count}`, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -4, 0, 4),
					Size = UDim2.fromOffset(30, 14),
					TextSize = 12,
					Font = Ui.Title,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 3,
				})
			end
			card.Activated:Connect(function()
				if wearing then
					return
				end
				local result = State.request("Equip", entry.Id)
				Sounds.play(if result.Ok then "Click" else "Deny")
			end)
		end
	end
end

content, pick = Ui.tabs(body, TABS, function(name)
	tab = name
	local holder = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, content)
	draw(holder, KIND_OF[name])
end)

function Inventory.open()
	Ui.show(panel)
	pick(tab)
end

function Inventory.start()
	Hud.onMenu("Items", function()
		if Ui.isOpen(panel) then
			Ui.hide(panel)
		else
			Inventory.open()
		end
	end)
	State.on("Profile", function()
		if Ui.isOpen(panel) then
			pick(tab)
		end
	end)
end

return Inventory
