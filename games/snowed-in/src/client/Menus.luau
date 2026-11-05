-- The menus: picking a role, the workbench, the cook pot, the shop, the
-- wardrobe, the cabin, the Expedition Pass and the settings, with a column
-- of buttons down the left side to open the ones that aren't tied to a
-- place in town. Every menu only asks: the server decides (and answers with
-- a corner note), and the menus redraw from the profile summary the server
-- sends whenever it changes. Nothing here is random and nothing is sold for
-- Robux except game passes, each of which says exactly what it gives.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Catalog = require(Shared.Config.Catalog)
local Cosmetics = require(Shared.Config.Cosmetics)
local Decor = require(Shared.Config.Decor)
local Expedition = require(Shared.Config.Expedition)
local Recipes = require(Shared.Config.Recipes)
local Resources = require(Shared.Config.Resources)
local Roles = require(Shared.Config.Roles)
local WeaponConfig = require(Shared.Config.Weapons)
local Profile = require(Shared.Profile)
local Stock = require(Shared.Stock)
local Wearables = require(Shared.World.Wearables)
local Diagnostics = require(script.Parent.Diagnostics)
local Settings = require(script.Parent.Settings)
local Sounds = require(script.Parent.Sounds)
local UI = require(script.Parent.UI)

local State = ReplicatedStorage:WaitForChild("State") :: Configuration
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Menus = {}

local SLOT_ICONS = { Hat = "🎩", Back = "🎒", Trail = "✨", Pet = "🐾" }
local SPOT_ICONS = { Roof = "🏠", Door = "🚪", Porch = "💡", Yard = "⛄", Flag = "🚩", Window = "🪟" }

local player = Players.LocalPlayer
local gui: ScreenGui
local profile: any = nil
local windows: { [string]: UI.Window } = {}
local tabs: { [string]: string } = {}
local redraws: { [string]: () -> () } = {}
local flakeLabel: TextLabel
local roleAutoOpened = false

local function owns(kind: string, id: string): boolean
	if not profile then
		return false
	end
	return profile[kind] and profile[kind][id] == true
end

-- The game pass that gives an item, if one does.
local function passFor(id: string): any
	for _, pass in Catalog do
		local grants = pass.Grants
		for _, list in { grants.Roles, grants.Cosmetics, grants.Decor } do
			if list and table.find(list, id) then
				return pass
			end
		end
	end
	return nil
end

local function stock(): Stock.Counts
	local counts = {}
	for _, resource in Resources.List do
		counts[resource.Id] = State:GetAttribute(`Stock_{resource.Id}`) or 0
	end
	return counts
end

local function costText(cost: Stock.Counts): string
	local parts = {}
	for _, resource in Resources.List do
		local amount = cost[resource.Id]
		if amount and amount > 0 then
			table.insert(parts, `{resource.Icon}{amount}`)
		end
	end
	return if #parts > 0 then table.concat(parts, "  ") else "Free"
end

-- A picture of a wearable in a little 3D window, or its slot's icon.
local function picture(parent: Instance, id: string, slot: string, size: number)
	local model = if slot ~= "Trail" then Wearables.build(nil, id, slot) else nil
	if not model then
		local item = Cosmetics.ById[id]
		local swatch = UI.label(parent, SLOT_ICONS[slot] or "❄", {
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(8, 8),
			TextSize = math.floor(size * 0.6),
			Font = Enum.Font.SourceSans,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0.2,
			BackgroundColor3 = if item then Color3.fromHex(item.Color) else UI.Colors.Card,
		})
		UI.corner(swatch, 8)
		return
	end
	local view = UI.new("ViewportFrame", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = UI.Colors.PanelLight,
		BackgroundTransparency = 0.2,
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
	}, parent)
	UI.corner(view, 8)
	model.Parent = view
	local cframe, extents = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = extents.Magnitude * 1.3 + 0.5
	camera.CFrame =
		CFrame.lookAt(cframe.Position + Vector3.new(distance * 0.5, distance * 0.35, -distance * 0.8), cframe.Position)
	camera.Parent = view
	view.CurrentCamera = camera
end

-- One row in a menu: a picture or icon, a name, a line about it and a
-- button.
local function row(
	parent: Instance,
	order: number,
	icon: string,
	title: string,
	blurb: string,
	action: string
): (Frame, TextButton)
	return UI.card(parent, icon, title, blurb, action, order)
end

local function setButton(button: TextButton, text: string, enabled: boolean, color: Color3?)
	button.Text = text
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then color or UI.Colors.Warm else UI.Colors.Locked
	button.TextColor3 = if enabled then Color3.fromRGB(40, 24, 10) else UI.Colors.Text
end

local function tabBar(window: UI.Window, name: string, list: { string })
	UI.withTabs(window)
	for index, tab in list do
		local button = UI.button(window.Tabs, tab, {
			Size = UDim2.fromOffset(104, 30),
			LayoutOrder = index,
			TextSize = 14,
		}, function()
			tabs[name] = tab
			Sounds.play("Click")
			redraws[name]()
		end)
		button.Name = tab
	end
	tabs[name] = list[1]
end

local function paintTabs(window: UI.Window, name: string)
	for _, button in window.Tabs:GetChildren() do
		if button:IsA("TextButton") then
			button.BackgroundColor3 = if button.Name == tabs[name] then UI.Colors.Warm else UI.Colors.Card
			button.TextColor3 = if button.Name == tabs[name] then Color3.fromRGB(40, 24, 10) else UI.Colors.Text
		end
	end
end

local function body(window: UI.Window): ScrollingFrame
	UI.clear(window.Body)
	if not window.Body:FindFirstChildOfClass("UIListLayout") then
		UI.list(window.Body, 6)
	end
	return window.Body
end

local function note(parent: Instance, text: string, order: number)
	UI.label(parent, text, {
		TextSize = 12,
		TextColor3 = UI.Colors.Muted,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})
end

-- Roles --------------------------------------------------------------------

local function drawRoles()
	local window = windows.Roles
	local list = body(window)
	local current = player:GetAttribute("Role") or ""
	local phase = State:GetAttribute("Phase")
	local playing = phase == "Day" or phase == "Dusk" or phase == "Night" or phase == "Dawn"
	note(
		list,
		"Every role helps in its own way. Teams with different roles do best! Press Q to use your role's ability.",
		0
	)
	for index, role in Roles.List do
		local perks = table.concat(role.Perks, " · ")
		local blurb = `{role.Blurb}\n{perks}\n{role.Ability.Name} (Q): {role.Ability.Blurb}`
		local _, button = UI.card(list, role.Icon, role.Name, blurb, "", index, 112)
		local unlocked = role.Price == 0 or owns("Roles", role.Id)
		if role.Id == current then
			setButton(button, "Your role", false)
		elseif not unlocked then
			local pass = passFor(role.Id)
			if profile and profile.Flakes >= role.Price then
				setButton(button, `Unlock: {role.Price} ❄`, true, UI.Colors.Ice)
				button.Activated:Connect(function()
					Remotes.Shop:FireServer(role.Id)
				end)
			else
				setButton(button, `{role.Price} ❄ or pass`, true, UI.Colors.Gold)
				button.Activated:Connect(function()
					if pass then
						Remotes.RequestPurchase:FireServer(pass.Id)
					end
				end)
			end
		elseif playing and current ~= "" then
			setButton(button, "Next run", false)
		else
			setButton(button, "Choose", true, UI.Colors.Good)
			button.Activated:Connect(function()
				Sounds.play("Click")
				Remotes.PickRole:FireServer(role.Id)
				task.delay(0.3, function()
					if (player:GetAttribute("Role") or "") == role.Id then
						window.close()
					end
				end)
			end)
		end
	end
end

-- The workbench -------------------------------------------------------------

local function hasWeapon(id: string): boolean
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA("Tool") and tool:GetAttribute("Weapon") == id then
					return true
				end
			end
		end
	end
	return false
end

local function drawWorkbench()
	local window = windows.Workbench
	paintTabs(window, "Workbench")
	local list = body(window)
	local counts = stock()
	local level = State:GetAttribute("HearthLevel") or 1
	if tabs.Workbench == "Team" then
		note(list, "Upgrades help the whole team for the rest of the run. Paid for from the stockpile.", 0)
		for index, upgrade in Recipes.Upgrades do
			local done = State:GetAttribute(`Upgrade_{upgrade.Id}`) == true
			local _, button = row(list, index, "🛠️", upgrade.Name, `{upgrade.Blurb}\n{costText(upgrade.Cost)}`, "")
			if done then
				setButton(button, "Made ✔", false)
			elseif level < upgrade.Needs then
				setButton(button, `Hearth level {upgrade.Needs}`, false)
			elseif not Stock.canAfford(counts, upgrade.Cost) then
				setButton(button, "Need more", false)
			else
				setButton(button, "Make it", true)
				button.Activated:Connect(function()
					Remotes.Craft:FireServer(upgrade.Id)
				end)
			end
		end
	else
		note(list, "Weapons are yours for the run. Everyone starts with a torch.", 0)
		for index, recipe in Recipes.Weapons do
			local weapon = WeaponConfig.ById[recipe.Id]
			local _, button = row(list, index, "🔥", weapon.Name, `{weapon.Blurb}\n{costText(recipe.Cost)}`, "")
			if hasWeapon(recipe.Id) then
				setButton(button, "Yours ✔", false)
			elseif level < recipe.Needs then
				setButton(button, `Hearth level {recipe.Needs}`, false)
			elseif not Stock.canAfford(counts, recipe.Cost) then
				setButton(button, "Need more", false)
			else
				setButton(button, "Make it", true)
				button.Activated:Connect(function()
					Remotes.Craft:FireServer(recipe.Id)
				end)
			end
		end
	end
	local levels = Balance.Hearth.Levels
	if level < #levels then
		note(
			list,
			`Build up the hearth (press R at the hearth) for bigger warmth, less fog and better recipes. Next level: {costText(
				levels[level + 1].Cost
			)}`,
			100
		)
	end
end

-- The cook pot -------------------------------------------------------------

local function drawCook()
	local window = windows.Cook
	local list = body(window)
	local counts = stock()
	local role = player:GetAttribute("Role") or ""
	note(list, "Meals warm you up. Take one from the pot, then press G (or tap it) to eat when you're cold.", 0)
	for index, meal in Recipes.Meals do
		local extras = {}
		if meal.ShieldSeconds then
			table.insert(extras, `cold slows for {meal.ShieldSeconds}s`)
		end
		if meal.SpeedSeconds then
			table.insert(extras, `walk faster for {meal.SpeedSeconds}s`)
		end
		local extra = if #extras > 0 then ", " .. table.concat(extras, ", ") else ""
		local inPot = State:GetAttribute(`Pantry_{meal.Id}`) or 0
		local blurb = `{meal.Blurb} +{meal.Warmth} warmth{extra}. Makes {meal.Portions}. In the pot: {inPot}\n{costText(
			meal.Cost
		)}`
		local _, button = row(list, index, meal.Icon, meal.Name, blurb, "")
		if meal.Role and meal.Role ~= role then
			setButton(button, `{meal.Role} only`, false)
		elseif not Stock.canAfford(counts, meal.Cost) then
			setButton(button, "Need more", false)
		else
			setButton(button, "Cook it", true)
			button.Activated:Connect(function()
				Remotes.Cook:FireServer(meal.Id)
			end)
		end
	end
end

-- The shop ------------------------------------------------------------------

local function itemButton(button: TextButton, item: any, kind: string)
	if owns(kind, item.Id) then
		setButton(button, "Owned ✔", false)
		return
	end
	local source = item.Source
	if source == "Shop" then
		local afford = profile ~= nil and profile.Flakes >= item.Price
		setButton(button, `{item.Price} ❄`, afford, UI.Colors.Ice)
		if afford then
			button.Activated:Connect(function()
				Remotes.Shop:FireServer(item.Id)
			end)
		end
	elseif source == "Pass" or source == "Pack" then
		local pass = passFor(item.Id)
		setButton(button, "Game pass", pass ~= nil, UI.Colors.Gold)
		if pass then
			button.Activated:Connect(function()
				Remotes.RequestPurchase:FireServer(pass.Id)
			end)
		end
	else
		setButton(button, Profile.howToGet(item), false)
	end
end

local function drawShop()
	local window = windows.Shop
	paintTabs(window, "Shop")
	local list = body(window)
	local tab = tabs.Shop
	if tab == "Outfits" then
		note(list, "Snowflakes are earned by playing: nights survived, radio parts fixed, monsters bopped.", 0)
		for index, item in Cosmetics.List do
			if item.Source ~= "Starter" then
				local card, button =
					row(list, index, "", item.Name, `{item.Blurb}\n{item.Slot} · {Profile.howToGet(item)}`, "")
				picture(card, item.Id, item.Slot, 48)
				itemButton(button, item, "Cosmetics")
			end
		end
	elseif tab == "Cabin" then
		note(list, "Decorations for your cabin. They stay with you from run to run.", 0)
		for index, item in Decor.List do
			if item.Source ~= "Starter" then
				local spot = Decor.SpotNames[item.Spot] or item.Spot
				local card, button = row(
					list,
					index,
					SPOT_ICONS[item.Spot] or "🏠",
					item.Name,
					`{item.Blurb}\n{spot} · {Profile.howToGet(item)}`,
					""
				)
				local swatch = UI.new("Frame", {
					BackgroundColor3 = Color3.fromHex(item.Color),
					Position = UDim2.fromOffset(40, 44),
					Size = UDim2.fromOffset(14, 14),
				}, card)
				UI.corner(swatch, 7)
				itemButton(button, item, "Decor")
			end
		end
	elseif tab == "Roles" then
		note(list, "Scout, Builder and Cook are free. Ranger and Medic can be earned with snowflakes.", 0)
		for index, role in Roles.List do
			if role.Price > 0 then
				local _, button =
					row(list, index, role.Icon, role.Name, `{role.Blurb}\n{table.concat(role.Perks, " · ")}`, "")
				if owns("Roles", role.Id) then
					setButton(button, "Owned ✔", false)
				else
					local afford = profile ~= nil and profile.Flakes >= role.Price
					setButton(button, `{role.Price} ❄`, afford, UI.Colors.Ice)
					if afford then
						button.Activated:Connect(function()
							Remotes.Shop:FireServer(role.Id)
						end)
					end
				end
			end
		end
	else
		note(
			list,
			"Game passes are one-time Robux purchases. Each one says exactly what you get. Nothing is random, and the roles can also be earned by playing.",
			0
		)
		for index, pass in Catalog do
			local owned = profile ~= nil and profile.Passes and profile.Passes[pass.Id]
			local _, button = row(list, index, "🎟️", pass.Name, pass.Includes, "")
			if owned then
				setButton(button, "Owned ✔", false)
			else
				setButton(button, `R$ {pass.SuggestedRobux}`, true, UI.Colors.Good)
				button.Activated:Connect(function()
					Remotes.RequestPurchase:FireServer(pass.Id)
				end)
			end
		end
	end
end

-- The wardrobe --------------------------------------------------------------

local function drawWardrobe()
	local window = windows.Wardrobe
	paintTabs(window, "Wardrobe")
	local list = body(window)
	local slot = tabs.Wardrobe
	local equipped = profile and profile.Equipped and profile.Equipped[slot]
	local _, none = row(list, 0, "🚫", "Nothing", `Wear no {slot:lower()}.`, "")
	if not equipped then
		setButton(none, "Wearing", false)
	else
		setButton(none, "Take off", true)
		none.Activated:Connect(function()
			Remotes.Equip:FireServer(slot, "")
		end)
	end
	local any = false
	for index, item in Cosmetics.List do
		if item.Slot == slot and owns("Cosmetics", item.Id) then
			any = true
			local card, button = row(list, index, "", item.Name, item.Blurb, "")
			picture(card, item.Id, item.Slot, 48)
			if equipped == item.Id then
				setButton(button, "Wearing", false)
			else
				setButton(button, "Wear it", true, UI.Colors.Good)
				button.Activated:Connect(function()
					Remotes.Equip:FireServer(slot, item.Id)
				end)
			end
		end
	end
	if not any then
		note(list, "Nothing here yet. Get some in the shop or from the Expedition Pass!", 100)
	end
end

-- The cabin -------------------------------------------------------------------

local function drawCabin()
	local window = windows.Cabin
	paintTabs(window, "Cabin")
	local list = body(window)
	local spot = tabs.Cabin
	local cabin = player:GetAttribute("Cabin")
	note(
		list,
		if cabin
			then `Your cabin is number {cabin}, in the ring around the hearth. Everyone can see how you decorate it, and it stays decorated next time you play.`
			else "You get a cabin when you join a server.",
		0
	)
	local chosen = profile and profile.Cabin and profile.Cabin[spot]
	for index, item in Decor.List do
		if item.Spot == spot and owns("Decor", item.Id) then
			local card, button = row(list, index, SPOT_ICONS[item.Spot] or "🏠", item.Name, item.Blurb, "")
			local swatch = UI.new("Frame", {
				BackgroundColor3 = Color3.fromHex(item.Color),
				Position = UDim2.fromOffset(40, 44),
				Size = UDim2.fromOffset(14, 14),
			}, card)
			UI.corner(swatch, 7)
			local current = chosen == item.Id or (chosen == nil and item.Source == "Starter")
			if current then
				setButton(button, "On my cabin", false)
			else
				setButton(button, "Put it up", true, UI.Colors.Good)
				button.Activated:Connect(function()
					Remotes.Decorate:FireServer(spot, item.Id)
				end)
			end
		end
	end
	note(list, "More decorations in the shop's Cabin tab and on the Expedition Pass.", 100)
end

-- The Expedition Pass ------------------------------------------------------

local function rewardText(reward: any): (string, string)
	if reward.Flakes then
		return "❄", `{reward.Flakes} snowflakes`
	end
	local item: any = Cosmetics.ById[reward.Item] or Decor.ById[reward.Item]
	if not item then
		return "🎁", reward.Item or ""
	end
	local icon = if item.Slot then SLOT_ICONS[item.Slot] else SPOT_ICONS[item.Spot]
	return icon or "🎁", item.Name
end

local function drawPass()
	local window = windows.Pass
	local list = body(window)
	local xp = if profile then profile.Xp else 0
	local tier = Profile.tier(xp)
	local premium = profile ~= nil and profile.Premium
	local into = xp % Expedition.TierXp
	local header = UI.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 54),
		LayoutOrder = 0,
	}, list)
	UI.label(header, `Tier {tier} of {#Expedition.Tiers}  ·  {xp} XP`, {
		Font = UI.Title,
		TextSize = 16,
		Size = UDim2.new(1, -150, 0, 20),
	})
	local _, fill, words = UI.bar(header, UI.Colors.Ice, {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -150, 0, 16),
	})
	UI.setBar(fill, if tier >= #Expedition.Tiers then 1 else into / Expedition.TierXp)
	words.Text = if tier >= #Expedition.Tiers
		then `Every tier done! +{Expedition.BonusFlakes} ❄ every {Expedition.TierXp} XP`
		else `{into} / {Expedition.TierXp} XP to tier {tier + 1}`
	local buy = UI.button(header, if premium then "Premium ✔" else "Get Premium", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.fromOffset(140, 40),
		BackgroundColor3 = if premium then UI.Colors.Locked else UI.Colors.Gold,
	})
	if not premium then
		buy.Activated:Connect(function()
			Remotes.RequestPurchase:FireServer("ExpeditionPremium")
		end)
	end
	note(
		list,
		`You earn XP by playing ({Balance.Rewards.XpPerFlake} XP for every snowflake a run earns). Every reward is shown here before you unlock it.`,
		1
	)
	local strip = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 200),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		LayoutOrder = 2,
	}, list)
	UI.list(strip, 6, true)
	for index, entry in Expedition.Tiers do
		local column = UI.new("Frame", {
			BackgroundColor3 = if index <= tier then UI.Colors.PanelLight else UI.Colors.Card,
			Size = UDim2.fromOffset(104, 188),
			LayoutOrder = index,
		}, strip)
		UI.corner(column, 8)
		UI.label(column, `Tier {index}`, {
			Font = UI.Title,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(1, 0, 0, 18),
			TextColor3 = if index <= tier then UI.Colors.Good else UI.Colors.Text,
		})
		for line, track in { { "Free", entry.Free }, { "Premium", entry.Premium } } do
			local icon, name = rewardText(track[2])
			local claimed = if track[1] == "Free"
				then profile and profile.ClaimedFree >= index
				else profile and profile.ClaimedPremium >= index
			local box = UI.new("Frame", {
				BackgroundColor3 = if track[1] == "Premium" then Color3.fromRGB(70, 56, 24) else UI.Colors.Track,
				Position = UDim2.fromOffset(6, 26 + (line - 1) * 80),
				Size = UDim2.new(1, -12, 0, 74),
			}, column)
			UI.corner(box, 6)
			UI.label(box, `{icon}`, {
				Font = Enum.Font.SourceSans,
				TextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 2),
				Size = UDim2.new(1, 0, 0, 26),
			})
			UI.label(box, name, {
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(2, 28),
				Size = UDim2.new(1, -4, 0, 28),
			})
			UI.label(box, if claimed then "✔ Got it" elseif track[1] == "Premium" then "Premium" else "Free", {
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 14),
				TextColor3 = if claimed then UI.Colors.Good else UI.Colors.Muted,
			})
		end
	end
end

-- Settings and stats --------------------------------------------------------

local SFX_STEPS = { 1, 0.5, 0 }

local function drawSettings()
	local window = windows.Settings
	local list = body(window)
	local values = Settings.get()
	local _, music = row(list, 1, "🎵", "Music and wind", "The songs and the blizzard's howl.", "")
	setButton(
		music,
		if values.Music then "On" else "Off",
		true,
		if values.Music then UI.Colors.Good else UI.Colors.Locked
	)
	music.Activated:Connect(function()
		Settings.set("Music", not values.Music)
		drawSettings()
	end)
	local _, sfx = row(list, 2, "🔊", "Effects volume", "Chops, hits, horns and everything else.", "")
	setButton(
		sfx,
		`{math.floor(values.Sfx * 100 + 0.5)}%`,
		true,
		if values.Sfx > 0 then UI.Colors.Good else UI.Colors.Locked
	)
	sfx.Activated:Connect(function()
		local index = 1
		for at, step in SFX_STEPS do
			if math.abs(step - values.Sfx) < 0.05 then
				index = at
			end
		end
		Settings.set("Sfx", SFX_STEPS[index % #SFX_STEPS + 1])
		drawSettings()
	end)
	local _, motion = row(list, 3, "🌀", "Reduce motion", "No camera shake, fewer particles and gentler flashes.", "")
	setButton(
		motion,
		if values.ReduceMotion then "On" else "Off",
		true,
		if values.ReduceMotion then UI.Colors.Good else UI.Colors.Locked
	)
	motion.Activated:Connect(function()
		Settings.set("ReduceMotion", not values.ReduceMotion)
		drawSettings()
	end)
	local stats = profile and profile.Stats
	if stats then
		note(
			list,
			`Runs: {stats.Runs}  ·  Rescued: {stats.Wins}  ·  Best night: {stats.BestNight}  ·  Monsters bopped: {stats.Knockouts}  ·  Radio parts: {stats.Parts}`,
			4
		)
	end
	local keys = if UI.touch()
		then "Tap the ability button for your role's power. Hold on things in town to use them."
		else "WASD move · Hold E use · Click swing · Q ability · G eat · B build · R turn while building · X take down your build"
	note(list, keys, 5)
	note(list, Diagnostics.line(), 6)
end

-- The column of buttons ------------------------------------------------------

local function sideButtons()
	local column = UI.new("Frame", {
		Name = "Side",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(64, 330),
	}, gui)
	UI.scale(column)
	local function arrange()
		-- On a phone the buttons go down the right edge, clear of the
		-- thumbstick; elsewhere down the left.
		if UI.touch() then
			column.AnchorPoint = Vector2.new(1, 0)
			column.Position = UDim2.new(1, -8, 0, 10)
		else
			column.AnchorPoint = Vector2.new(0, 0.5)
			column.Position = UDim2.new(0, 8, 0.5, 0)
		end
	end
	UI.onRescale(arrange)
	UserInputService.LastInputTypeChanged:Connect(arrange)
	UI.list(column, 6)
	local flakes = UI.panel(column, { Size = UDim2.fromOffset(64, 28), LayoutOrder = 0 })
	flakeLabel = UI.label(flakes, "❄ 0", {
		Font = UI.Title,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = UI.Colors.Ice,
	})
	local entries = {
		{ "Roles", "🧭", "Role" },
		{ "Shop", "🛒", "Shop" },
		{ "Wardrobe", "🧣", "Outfit" },
		{ "Cabin", "🏠", "Cabin" },
		{ "Pass", "🎟️", "Pass" },
		{ "Settings", "⚙️", "More" },
	}
	for index, entry in entries do
		local button = UI.button(column, "", {
			Size = UDim2.fromOffset(64, 44),
			BackgroundColor3 = UI.Colors.Panel,
			LayoutOrder = index,
		}, function()
			Sounds.play("Click")
			Menus.toggle(entry[1])
		end)
		UI.stroke(button)
		UI.label(button, entry[2], {
			Font = Enum.Font.SourceSans,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 2),
			Size = UDim2.new(1, 0, 0, 24),
		})
		UI.label(button, entry[3], {
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 14),
		})
	end
end

-- Opening and closing --------------------------------------------------------

function Menus.open(name: string)
	local window = windows[name]
	if not window then
		return
	end
	redraws[name]()
	window.open()
end

function Menus.toggle(name: string)
	local window = windows[name]
	if window and window.isOpen() then
		window.close()
	else
		Menus.open(name)
	end
end

local function redrawOpen()
	for name, window in windows do
		if window.isOpen() then
			redraws[name]()
		end
	end
end

local function maybeAskRole()
	local phase = State:GetAttribute("Phase")
	local role = player:GetAttribute("Role") or ""
	if role ~= "" then
		roleAutoOpened = false
		return
	end
	if phase == "Waiting" or phase == "Won" or phase == "Lost" or phase == "Rescue" then
		return
	end
	if not roleAutoOpened and not UI.anyOpen() then
		roleAutoOpened = true
		Menus.open("Roles")
	end
end

function Menus.mount()
	gui = UI.screen("Menus", 5)
	local size = Vector2.new(580, 440)
	windows.Roles = UI.window(gui, "Roles", "Pick your role", size)
	windows.Workbench = UI.window(gui, "Workbench", "🛠️ Workbench", size)
	tabBar(windows.Workbench, "Workbench", { "Team", "Weapons" })
	windows.Cook = UI.window(gui, "Cook", "🍲 Cook pot", size)
	windows.Shop = UI.window(gui, "Shop", "🛒 Shop", size)
	tabBar(windows.Shop, "Shop", { "Outfits", "Cabin", "Roles", "Passes" })
	windows.Wardrobe = UI.window(gui, "Wardrobe", "🧣 Wardrobe", size)
	tabBar(windows.Wardrobe, "Wardrobe", Cosmetics.Slots)
	windows.Cabin = UI.window(gui, "Cabin", "🏠 My cabin", size)
	tabBar(windows.Cabin, "Cabin", Decor.Spots)
	windows.Pass = UI.window(gui, "Pass", "🎟️ Expedition Pass", size)
	windows.Settings = UI.window(gui, "Settings", "⚙️ Settings and stats", size)
	redraws.Roles = drawRoles
	redraws.Workbench = drawWorkbench
	redraws.Cook = drawCook
	redraws.Shop = drawShop
	redraws.Wardrobe = drawWardrobe
	redraws.Cabin = drawCabin
	redraws.Pass = drawPass
	redraws.Settings = drawSettings
	-- The cabin tabs are long words; let them fit.
	for _, button in windows.Cabin.Tabs:GetChildren() do
		if button:IsA("TextButton") then
			button.Size = UDim2.fromOffset(82, 30)
			button.TextSize = 12
		end
	end
	sideButtons()

	Remotes.Profile.OnClientEvent:Connect(function(summary)
		if type(summary) ~= "table" then
			return
		end
		profile = summary
		flakeLabel.Text = `❄ {summary.Flakes}`
		redrawOpen()
	end)
	Remotes.Open.OnClientEvent:Connect(function(name)
		if type(name) == "string" and windows[name] then
			Menus.open(name)
		end
	end)
	State.AttributeChanged:Connect(function(name)
		if
			name:sub(1, 6) == "Stock_"
			or name:sub(1, 7) == "Pantry_"
			or name:sub(1, 8) == "Upgrade_"
			or name == "HearthLevel"
		then
			for _, menu in { "Workbench", "Cook" } do
				if windows[menu].isOpen() then
					redraws[menu]()
				end
			end
		elseif name == "Phase" then
			maybeAskRole()
		end
	end)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		if windows.Roles.isOpen() then
			drawRoles()
		end
		maybeAskRole()
	end)
	player:GetAttributeChangedSignal("Flakes"):Connect(function()
		flakeLabel.Text = `❄ {player:GetAttribute("Flakes") or 0}`
	end)
	-- A new weapon from the workbench lands in the backpack.
	player.DescendantAdded:Connect(function(added)
		if added:IsA("Tool") and windows.Workbench.isOpen() then
			drawWorkbench()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			UI.closeAll()
		end
	end)
	task.delay(2, maybeAskRole)
end

return Menus
