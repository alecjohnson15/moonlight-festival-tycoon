-- The Crate Vault. Crates are opened with coins earned by playing, never
-- with Robux. Each crate shows its odds for every rarity and every item it
-- can hold before you open it, and how many opens are left until the
-- guaranteed pull.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateConfig = require(Shared.Config.Crates)
local Items = require(Shared.Config.Items)
local Format = require(Shared.Format)
local CrateRules = require(Shared.Rules.Crates)
local Corner = require(script.Parent.Corner)
local Hud = require(script.Parent.Hud)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Crates = {}

local gui = Ui.screen("Crates", 3)
local panel, body = Ui.panel(gui, "Crate Vault", 580, 410)
local chosen = CrateConfig.List[1].Id
local opening = false

local left = Ui.make("Frame", { Size = UDim2.new(0, 170, 1, 0), BackgroundTransparency = 1 }, body)
Ui.list(left, 8)
local right = Ui.make("Frame", {
	Position = UDim2.fromOffset(182, 0),
	Size = UDim2.new(1, -182, 1, 0),
	BackgroundTransparency = 1,
}, body)

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local draw: () -> ()

local function reveal(result: { [string]: any }, crate: CrateConfig.Crate)
	opening = true
	local overlay = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.Colors.Panel,
		ZIndex = 10,
	}, right)
	Ui.round(overlay, 10)
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.fromOffset(170, 170),
		BackgroundColor3 = Ui.Colors.Card,
		ZIndex = 11,
	}, overlay)
	Ui.round(frame, 12)
	local stroke = Ui.stroke(frame, Ui.Colors.Dim, 3)
	local name = Ui.label(overlay, "", {
		Position = UDim2.fromOffset(0, 200),
		Size = UDim2.new(1, 0, 0, 30),
		Font = Ui.Title,
		TextSize = 24,
		ZIndex = 11,
	})
	local rarity = Ui.label(overlay, "", {
		Position = UDim2.fromOffset(0, 232),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 14,
		ZIndex = 11,
	})
	-- A quick shuffle through the crate's items, then the one you got.
	local pool = {}
	for _, list in crate.Pools do
		for _, itemId in list do
			table.insert(pool, itemId)
		end
	end
	local random = Random.new()
	-- With Reduce motion on, no flashing shuffle: a short pause instead.
	local steps = if Ui.ReduceMotion then 0 else 14
	if Ui.ReduceMotion then
		task.wait(0.6)
	end
	for step = 1, steps do
		local itemId = pool[random:NextInteger(1, #pool)]
		local item = Items.get(itemId)
		for _, child in frame:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
		Ui.picture(frame, itemId).ZIndex = 12
		name.Text = item and item.Name or ""
		stroke.Color = Ui.rarityColor(item and item.Rarity or "Common")
		Sounds.play("CrateRoll", nil, 0.9 + step * 0.03)
		task.wait(0.05 + step * 0.012)
	end
	for _, child in frame:GetChildren() do
		if child:IsA("ViewportFrame") then
			child:Destroy()
		end
	end
	local item = Items.get(result.Item)
	Ui.picture(frame, result.Item).ZIndex = 12
	local color = Ui.rarityColor(result.Rarity)
	stroke.Color = color
	stroke.Thickness = 5
	name.Text = item and item.Name or result.Item
	name.TextColor3 = color
	rarity.Text = `{string.upper(result.Rarity)}  ·  {Items.KIND_NAMES[item and item.Kind or ""] or ""}`
	rarity.TextColor3 = color
	local scale = Ui.make("UIScale", { Scale = 0.6 }, frame)
	Ui.pop(scale, 1, 0.4)
	Sounds.play("CrateReveal")
	Corner.note("From the crate", `{item and item.Name or result.Item} ({result.Rarity})`, color)
	local row = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 262),
		Size = UDim2.fromOffset(240, 34),
		BackgroundTransparency = 1,
		ZIndex = 11,
	}, overlay)
	Ui.list(row, 8, true)
	local wear = Ui.button(row, "Wear it", Ui.Colors.Good, { Size = UDim2.fromOffset(116, 32), ZIndex = 12 })
	local again = Ui.button(row, "Done", Ui.Colors.Accent, { Size = UDim2.fromOffset(116, 32), ZIndex = 12 })
	wear.Activated:Connect(function()
		State.request("Equip", result.Item)
		overlay:Destroy()
		opening = false
		draw()
	end)
	again.Activated:Connect(function()
		overlay:Destroy()
		opening = false
		draw()
	end)
end

draw = function()
	if opening then
		return
	end
	clear(left)
	clear(right)
	local profile = State.Profile
	for index, crate in CrateConfig.List do
		local selected = crate.Id == chosen
		local button = Ui.make("TextButton", {
			Size = UDim2.new(1, 0, 0, 74),
			BackgroundColor3 = if selected then Ui.Colors.CardHover else Ui.Colors.Card,
			AutoButtonColor = true,
			Text = "",
			LayoutOrder = index,
		}, left)
		Ui.round(button, 10)
		Ui.stroke(button, Color3.fromHex(crate.Color), if selected then 3 else 1.5)
		Ui.label(button, crate.Name, {
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.new(1, -16, 0, 20),
			Font = Ui.Title,
			TextSize = 16,
			TextColor3 = Color3.fromHex(crate.Color),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.label(button, crate.Season and `Season: {crate.Season}` or "Always in the vault", {
			Position = UDim2.fromOffset(8, 28),
			Size = UDim2.new(1, -16, 0, 14),
			TextSize = 11,
			TextColor3 = Ui.Colors.Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.label(button, `{Format.whole(crate.Price)} coins`, {
			Position = UDim2.fromOffset(8, 48),
			Size = UDim2.new(1, -16, 0, 18),
			Font = Ui.Title,
			TextSize = 15,
			TextColor3 = Ui.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		button.Activated:Connect(function()
			chosen = crate.Id
			Sounds.play("Click")
			draw()
		end)
	end
	Ui.label(left, "Crates are opened with coins you earn by playing. They can't be bought with Robux.", {
		Size = UDim2.new(1, 0, 0, 60),
		TextSize = 11,
		TextColor3 = Ui.Colors.Dim,
		LayoutOrder = 10,
	})

	local crate = CrateConfig.get(chosen) :: CrateConfig.Crate
	local odds = Ui.make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -90),
		BackgroundTransparency = 1,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Ui.Colors.Accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
	}, right)
	Ui.list(odds, 6)
	for index, line in CrateRules.odds(crate) do
		local color = Ui.rarityColor(line.Rarity)
		local block = Ui.make("Frame", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Ui.Colors.Card,
			LayoutOrder = index,
		}, odds)
		Ui.round(block, 8)
		Ui.pad(block, 8, 5)
		Ui.list(block, 2)
		Ui.label(block, `{line.Rarity}: {line.Percent}%`, {
			Font = Ui.Title,
			TextSize = 14,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		})
		local names = {}
		for _, itemId in line.Items do
			local item = Items.get(itemId)
			table.insert(names, item and item.Name or itemId)
		end
		Ui.label(block, table.concat(names, ", "), {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 11,
			TextColor3 = Ui.Colors.Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
		})
	end
	local pity = (profile and profile.Pity and profile.Pity[crate.Id]) or 0
	local leftToPity = math.max(1, crate.Pity - pity)
	Ui.label(
		right,
		`Guaranteed {crate.PityRarity} or better within {leftToPity} open{if leftToPity == 1 then "" else "s"}.`,
		{
			Position = UDim2.new(0, 0, 1, -84),
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 12,
			TextColor3 = Ui.Colors.Gold,
		}
	)
	local coins = profile and profile.Coins or 0
	local canOpen = coins >= crate.Price
	local open = Ui.button(
		right,
		if canOpen
			then `Open for {Format.whole(crate.Price)} coins`
			else `Need {Format.whole(crate.Price - coins)} more coins`,
		if canOpen then Ui.Colors.Gold else Ui.Colors.Track,
		{
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.fromOffset(250, 44),
			TextSize = 18,
		}
	)
	open.Activated:Connect(function()
		if not canOpen or opening then
			Sounds.play("Deny")
			return
		end
		opening = true
		local result = State.request("OpenCrate", crate.Id)
		opening = false
		if result.Ok then
			reveal(result, crate)
		else
			Sounds.play("Deny")
			draw()
		end
	end)
end

function Crates.open()
	Ui.show(panel)
	draw()
end

function Crates.start()
	Hud.onMenu("Crates", function()
		if Ui.isOpen(panel) then
			Ui.hide(panel)
		else
			Crates.open()
		end
	end)
	State.on("Profile", function()
		if Ui.isOpen(panel) then
			draw()
		end
	end)
end

return Crates
