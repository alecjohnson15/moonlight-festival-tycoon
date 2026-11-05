-- The menus besides the wardrobe: the Boutique (Sparkles and Robux), the
-- Style Pass board, the profile card with today's challenges, the closet of
-- saved outfits, and settings. Each is a window (client/Ui); the kiosks in
-- Glow Plaza and the HUD buttons open them. Every price and reward is shown
-- before anything is bought.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Wardrobe = require(Config.Wardrobe)
local Poses = require(Config.Poses)
local Entrances = require(Config.Entrances)
local Catalog = require(Config.Catalog)
local Season = require(Config.Season)
local Quests = require(Config.Quests)
local Words = require(Config.Words)
local GameConfig = require(Config.Game)
local Palette = require(Config.Palette)
local Progress = require(Shared.Progress)
local Pieces = require(Shared.Build.Pieces)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = Ui.Colors
local make = Ui.make

local Menus = {}

local windows: { [string]: Ui.Window } = {}
local renderers: { [string]: () -> () } = {}
local shopTab = "Pieces"
local robuxPrices: { [string]: number } = {}

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		child:Destroy()
	end
end

local function rewardText(reward: any): string
	if reward.Sparkles then
		return Ui.sparkles(reward.Sparkles)
	elseif reward.Piece then
		local piece = Wardrobe.get(reward.Piece)
		return if piece then piece.Name else reward.Piece
	elseif reward.Pose then
		local pose = Poses.get(reward.Pose)
		return `Pose: {if pose then pose.Name else reward.Pose}`
	elseif reward.Entrance then
		local entrance = Entrances.get(reward.Entrance)
		return `Walk-in: {if entrance then entrance.Name else reward.Entrance}`
	end
	return ""
end

local function piecePicture(parent: GuiObject, piece: any)
	local viewport = make("ViewportFrame", {
		Size = UDim2.new(1, -8, 1, -44),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 190, 220),
		LightDirection = Vector3.new(-1, -1, -1),
	}, parent)
	local ok, model =
		pcall(Pieces.preview, piece, Palette.resolve(piece.Main), Palette.resolve(piece.Accent), piece.Finish)
	if not ok then
		return
	end
	model.Parent = viewport
	local cframe, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z) * 0.75 + 0.2
	local camera = make("Camera", {
		FieldOfView = 40,
		CFrame = CFrame.lookAt(
			cframe.Position + Vector3.new(radius * 0.9, radius * 0.7, -radius * 2.2),
			cframe.Position
		),
	}, viewport)
	viewport.CurrentCamera = camera
end

------------------------------------------------------------------------------
-- Boutique

local function shopItems(kind: string): { any }
	local list = {}
	local source = if kind == "Piece" then Wardrobe.Pieces elseif kind == "Pose" then Poses.List else Entrances.List
	for _, item in source do
		if item.Price > 0 and not item.Pass and not item.Season then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		if a.Price == b.Price then
			return a.Name < b.Name
		end
		return a.Price < b.Price
	end)
	return list
end

local function robuxPrice(item: any): string
	local id = if item.Kind == "GamePass" then item.PassId else item.ProductId
	if not id or id == 0 then
		return "Coming soon"
	end
	if item.Id == Season.Pass and os.time() >= Season.Ends then
		return "Season over"
	end
	local known = robuxPrices[item.Id]
	if known then
		return `R$ {known}`
	end
	task.spawn(function()
		local infoType = if item.Kind == "GamePass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, infoType)
		if ok and info and info.PriceInRobux then
			robuxPrices[item.Id] = info.PriceInRobux
			if windows.Shop.isOpen() and shopTab == "Robux" then
				renderers.Shop()
			end
		end
	end)
	return "R$ ..."
end

local function renderShop()
	local body = windows.Shop.Body:FindFirstChild("Content") :: ScrollingFrame
	clear(body)
	if shopTab == "Robux" then
		Ui.list(body, false, 8)
		for index, item in Catalog do
			local owned = item.Kind == "GamePass" and State.hasPass(item.Id)
			local row = make("Frame", {
				Size = UDim2.new(1, -10, 0, 74),
				BackgroundColor3 = C.Panel2,
				LayoutOrder = index,
			}, body)
			Ui.corner(row, 10)
			Ui.label(row, {
				Text = item.Name,
				Font = Ui.Fonts.Title,
				TextSize = 17,
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.new(1, -140, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if item.Kind == "GamePass" then C.Gold else C.Aqua,
			})
			Ui.label(row, {
				Text = item.Includes,
				TextSize = 12,
				TextColor3 = C.Muted,
				Position = UDim2.fromOffset(10, 28),
				Size = UDim2.new(1, -140, 0, 42),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
			local price = robuxPrice(item)
			local available = price ~= "Coming soon" and price ~= "Season over"
			Ui.button(
				row,
				if owned then "Owned ✓" else price,
				if owned then C.Green elseif available then C.Pink else C.Panel3,
				function()
					if not owned and available then
						Remotes.RequestPurchase:FireServer(item.Id)
					end
				end,
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(116, 40),
					TextSize = 15,
				}
			)
		end
		return
	end

	local kind = if shopTab == "Pieces" then "Piece" elseif shopTab == "Poses" then "Pose" else "Entrance"
	Ui.grid(body, Vector2.new(if kind == "Piece" then 112 else 150, if kind == "Piece" then 140 else 76), 8)
	for index, item in shopItems(kind) do
		local owned = State.owns(kind, item.Id)
		local cell = Ui.button(body, "", C.Panel2, function()
			if not owned then
				Remotes.ShopBuy:FireServer({ Kind = kind, Id = item.Id })
			end
		end, { LayoutOrder = index })
		if kind == "Piece" then
			piecePicture(cell, item)
		end
		Ui.label(cell, {
			Text = item.Name,
			TextSize = 12,
			Position = UDim2.new(0, 4, 1, if kind == "Piece" then -40 else -62),
			Size = UDim2.new(1, -8, 0, 20),
		})
		Ui.label(cell, {
			Text = if owned then "Owned ✓" else Ui.sparkles(item.Price),
			TextSize = 13,
			Font = Ui.Fonts.Title,
			TextColor3 = if owned then C.Green else C.Gold,
			Position = UDim2.new(0, 4, 1, -22),
			Size = UDim2.new(1, -8, 0, 18),
		})
	end
end

------------------------------------------------------------------------------
-- Style Pass

local function renderPass()
	local body = windows.Pass.Body
	clear(body)
	local profile = State.Profile
	if not profile then
		return
	end
	local pass = Progress.passFor(profile.Pass, Season)
	local tier = Progress.tier(Season, pass.Xp)
	local premium = State.hasPass(Season.Pass)
	local now = os.time()
	local open = Progress.seasonOpen(Season, now)
	local ended = now >= Season.Ends
	local daysLeft = math.max(0, math.ceil((Season.Ends - now) / 86400))
	local status = if open
		then `Tier {tier} of {#Season.Tiers} · {daysLeft} days left · XP from walking, voting and challenges`
		elseif ended then "This season is over. Claim any rewards you reached; they're yours to keep."
		else "The season hasn't started yet. Come back soon!"

	Ui.label(body, {
		Text = Season.Name,
		Font = Ui.Fonts.Title,
		TextSize = 20,
		TextColor3 = C.Gold,
		Size = UDim2.new(1, -170, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Ui.label(body, {
		Text = status,
		TextSize = 12,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, -170, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	if not premium and not ended then
		Ui.button(body, "Get Style Pass", C.Gold, function()
			Remotes.RequestPurchase:FireServer(Season.Pass)
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 2),
			Size = UDim2.fromOffset(160, 38),
			TextSize = 16,
			TextColor3 = C.Dark,
		})
	end
	local track = make("Frame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = C.Panel3,
	}, body)
	Ui.corner(track, 6)
	local into = pass.Xp - tier * Season.XpPerTier
	local fill = make("Frame", {
		Size = UDim2.fromScale(if tier >= #Season.Tiers then 1 else math.clamp(into / Season.XpPerTier, 0, 1), 1),
		BackgroundColor3 = C.Gold,
	}, track)
	Ui.corner(fill, 6)

	local scroller = Ui.scroller(body, {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 1, -70),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
	})
	local row = make("Frame", {
		Size = UDim2.new(0, 0, 1, -10),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, scroller)
	Ui.list(row, true, 8)
	for index, rewards in Season.Tiers do
		local reached = tier >= index
		local column = make("Frame", {
			Size = UDim2.new(0, 120, 1, 0),
			BackgroundColor3 = if reached then C.Panel2 else C.Dark,
			LayoutOrder = index,
		}, row)
		Ui.corner(column, 10)
		Ui.label(column, {
			Text = `Tier {index}`,
			Font = Ui.Fonts.Title,
			TextSize = 15,
			TextColor3 = if reached then C.Gold else C.Muted,
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 4),
		})
		for trackIndex, trackName in { "Free", "Premium" } do
			local reward = rewards[trackName]
			local claimed = pass[trackName][tostring(index)] == true
			local box = make("Frame", {
				Position = UDim2.new(0, 6, if trackIndex == 1 then 0 else 0.5, if trackIndex == 1 then 30 else 8),
				Size = UDim2.new(1, -12, 0.5, -26),
				BackgroundColor3 = if trackName == "Premium" then Color3.fromRGB(80, 56, 20) else C.Panel3,
			}, column)
			Ui.corner(box, 8)
			Ui.label(box, {
				Text = trackName,
				TextSize = 10,
				TextColor3 = if trackName == "Premium" then C.Gold else C.Muted,
				Size = UDim2.new(1, 0, 0, 14),
				Position = UDim2.fromOffset(0, 2),
			})
			Ui.label(box, {
				Text = rewardText(reward),
				TextSize = 12,
				Size = UDim2.new(1, -8, 1, -46),
				Position = UDim2.fromOffset(4, 16),
			})
			local canClaim = reached and not claimed and (trackName == "Free" or premium)
			local text = if claimed
				then "Claimed ✓"
				elseif canClaim then "Claim"
				elseif not reached then "Locked"
				else "Style Pass"
			Ui.button(box, text, if canClaim then C.Pink elseif claimed then C.Green else C.Panel, function()
				if canClaim then
					Remotes.ClaimTier:FireServer({ Tier = index, Track = trackName })
				elseif reached and trackName == "Premium" and not premium then
					Remotes.RequestPurchase:FireServer(Season.Pass)
				end
			end, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -4),
				Size = UDim2.new(1, -10, 0, 24),
				TextSize = 12,
			})
		end
	end
end

------------------------------------------------------------------------------
-- Profile and challenges

local function renderProfile()
	local body = windows.Profile.Body
	clear(body)
	local profile = State.Profile
	if not profile then
		return
	end
	local scroller = Ui.scroller(body)
	local list = make("Frame", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, scroller)
	Ui.list(list, false, 8)
	Ui.label(list, {
		Text = `{profile.Rank} · Style Score {profile.StyleScore}`,
		Font = Ui.Fonts.Title,
		TextSize = 22,
		TextColor3 = Palette.resolve(profile.RankColor or "Snow"),
		Size = UDim2.new(1, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	})
	local stats = profile.Stats
	local grid = make("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, list)
	Ui.grid(grid, Vector2.new(112, 52), 8)
	for index, pair in
		{
			{ "Crowns", stats.Crowns },
			{ "Matchups won", stats.Wins },
			{ "Walks", stats.Walks },
			{ "Shows", stats.Shows },
			{ "Votes", stats.Votes },
			{ "Good taste", stats.Taste },
			{ "Themes nailed", stats.Nailed },
			{ "Best finish", if stats.BestFinish > 0 then `#{stats.BestFinish}` else "-" },
		}
	do
		local cell = make("Frame", { BackgroundColor3 = C.Panel2, LayoutOrder = index }, grid)
		Ui.corner(cell, 8)
		Ui.label(cell, {
			Text = tostring(pair[2]),
			Font = Ui.Fonts.Title,
			TextSize = 20,
			Size = UDim2.new(1, 0, 0, 26),
			Position = UDim2.fromOffset(0, 4),
		})
		Ui.label(cell, {
			Text = pair[1],
			TextSize = 11,
			TextColor3 = C.Muted,
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.fromOffset(0, 30),
		})
	end

	Ui.label(list, {
		Text = "Today's challenges",
		Font = Ui.Fonts.Title,
		TextSize = 18,
		TextColor3 = C.Pink,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 3,
	})
	local quests = profile.Quests or {}
	local byId = {}
	for _, quest in Quests do
		byId[quest.Id] = quest
	end
	for index, id in quests.Ids or {} do
		local quest = byId[id]
		if quest then
			local progress = (quests.Progress or {})[index] or 0
			local done = (quests.Done or {})[index] == true
			local row = make("Frame", {
				Size = UDim2.new(1, 0, 0, 46),
				BackgroundColor3 = C.Panel2,
				LayoutOrder = 3 + index,
			}, list)
			Ui.corner(row, 8)
			Ui.label(row, {
				Text = if done then `✓ {quest.Text}` else quest.Text,
				TextSize = 13,
				Position = UDim2.fromOffset(10, 4),
				Size = UDim2.new(1, -150, 0, 20),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if done then C.Green else C.Text,
			})
			Ui.label(row, {
				Text = `{Ui.sparkles(quest.Sparkles)} · {quest.Xp} XP`,
				TextSize = 12,
				TextColor3 = C.Gold,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 4),
				Size = UDim2.fromOffset(140, 20),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			local track = make("Frame", {
				Position = UDim2.fromOffset(10, 28),
				Size = UDim2.new(1, -20, 0, 10),
				BackgroundColor3 = C.Panel3,
			}, row)
			Ui.corner(track, 5)
			local fill = make("Frame", {
				Size = UDim2.fromScale(math.clamp(progress / quest.Goal, 0, 1), 1),
				BackgroundColor3 = if done then C.Green else C.Pink,
			}, track)
			Ui.corner(fill, 5)
		end
	end
	local streak = profile.Streak or { Count = 0 }
	Ui.label(list, {
		Text = `Login streak: {streak.Count} day{if streak.Count == 1 then "" else "s"}. Come back tomorrow for more Sparkles!`,
		TextSize = 13,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 20,
	})

	-- The voting rules in plain words, as promised in docs/design.md.
	Ui.label(list, {
		Text = "How voting works",
		Font = Ui.Fonts.Title,
		TextSize = 18,
		TextColor3 = C.Aqua,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 21,
	})
	Ui.label(list, {
		Text = table.concat({
			"• You can't vote in your own matchup.",
			"• Voting opens a few seconds after both walkers start down the runway.",
			"• One vote each per matchup. You can change it until voting closes.",
			"• Nobody sees who's ahead until voting closes.",
			"• If lots of a walker's friends, or lots of brand-new accounts, vote for them, the extra votes count for less, so a big group can't decide alone.",
			"• Three judges vote too. They count most when few people are watching.",
			"• Your first 10 walks can only raise your Style Score.",
		}, "\n"),
		TextSize = 12,
		TextColor3 = C.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 22,
	})
end

------------------------------------------------------------------------------
-- Closet

local function nextWord(list: { string }, index: number): number
	return index % #list + 1
end

local function renderCloset()
	local body = windows.Closet.Body
	clear(body)
	local profile = State.Profile
	if not profile then
		return
	end
	local size = if State.hasPass("big_closet") then GameConfig.Looks.ClosetSlots else GameConfig.Looks.FreeSlots
	local looks = profile.Looks or {}
	Ui.label(body, {
		Text = `{#looks} of {size} outfits saved`,
		Font = Ui.Fonts.Title,
		TextSize = 17,
		Size = UDim2.new(1, -230, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Ui.button(body, "Save what I'm wearing", C.Pink, function()
		Remotes.Looks:FireServer({ Action = "Save" })
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(220, 34),
		TextSize = 15,
	})
	local scroller = Ui.scroller(body, {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, if size < GameConfig.Looks.ClosetSlots then -90 else -44),
	})
	local list = make("Frame", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, scroller)
	Ui.list(list, false, 6)
	for index, saved in looks do
		local name = saved.Name or { 1, 1 }
		local row = make("Frame", {
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundColor3 = C.Panel2,
			LayoutOrder = index,
		}, list)
		Ui.corner(row, 8)
		local first = Words.First[name[1]] or "Lovely"
		local second = Words.Second[name[2]] or "Look"
		Ui.button(row, first, C.Panel3, function()
			Remotes.Looks:FireServer({
				Action = "Rename",
				Index = index,
				Name = { nextWord(Words.First, name[1]), name[2] },
			})
		end, { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(100, 32), TextSize = 14 })
		Ui.button(row, second, C.Panel3, function()
			Remotes.Looks:FireServer({
				Action = "Rename",
				Index = index,
				Name = { name[1], nextWord(Words.Second, name[2]) },
			})
		end, { Position = UDim2.fromOffset(114, 8), Size = UDim2.fromOffset(100, 32), TextSize = 14 })
		local actions = make("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(250, 32),
			BackgroundTransparency = 1,
		}, row)
		Ui.list(actions, true, 6, Enum.HorizontalAlignment.Right)
		Ui.button(actions, "Wear", C.Pink, function()
			Remotes.Looks:FireServer({ Action = "Wear", Index = index })
		end, { Size = UDim2.fromOffset(70, 32), TextSize = 14, LayoutOrder = 1 })
		Ui.button(actions, "Replace", C.Violet, function()
			Remotes.Looks:FireServer({ Action = "Save", Index = index })
		end, { Size = UDim2.fromOffset(86, 32), TextSize = 14, LayoutOrder = 2 })
		Ui.button(actions, "✕", C.Red, function()
			Remotes.Looks:FireServer({ Action = "Delete", Index = index })
		end, { Size = UDim2.fromOffset(36, 32), TextSize = 14, LayoutOrder = 3 })
	end
	if #looks == 0 then
		Ui.label(list, {
			Text = "No outfits yet. Dress up in the wardrobe, then save your favourites here.",
			TextColor3 = C.Muted,
			Size = UDim2.new(1, 0, 0, 40),
		})
	end
	if size < GameConfig.Looks.ClosetSlots then
		Ui.button(body, `Big Closet: save {GameConfig.Looks.ClosetSlots} outfits`, C.Gold, function()
			Remotes.RequestPurchase:FireServer("big_closet")
		end, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 38),
			TextSize = 15,
			TextColor3 = C.Dark,
		})
	end
end

------------------------------------------------------------------------------
-- Settings

local function renderSettings()
	local body = windows.Settings.Body
	clear(body)
	local profile = State.Profile
	local settings = if profile
		then profile.Settings
		else { Music = true, Effects = true, WatchOnly = false, ReducedMotion = false }
	Ui.list(body, false, 10)
	for index, entry in
		{
			{ "Music", "Music", "Songs and the crowd" },
			{ "Effects", "Effects", "Sound effects, sparkles and flashes" },
			{ "WatchOnly", "Watch only", "Sit out shows and just vote" },
			{ "ReducedMotion", "Reduced motion", "No camera flashes, and camera cuts instead of swoops" },
		}
	do
		local key = entry[1]
		local on = settings[key] == true
		local row = make("Frame", {
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = C.Panel2,
			LayoutOrder = index,
		}, body)
		Ui.corner(row, 10)
		Ui.label(row, {
			Text = entry[2],
			Font = Ui.Fonts.Title,
			TextSize = 18,
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -110, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.label(row, {
			Text = entry[3],
			TextSize = 12,
			TextColor3 = C.Muted,
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -110, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Ui.button(row, if on then "On" else "Off", if on then C.Green else C.Panel3, function()
			Remotes.Settings:FireServer({ [key] = not on })
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(80, 34),
		})
	end
	Ui.label(body, {
		Text = "Catwalk Clash keeps only your game progress. Names on saved outfits come from word lists, so nobody types anything others can see.",
		TextSize = 12,
		TextColor3 = C.Muted,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 10,
	})
end

------------------------------------------------------------------------------

function Menus.open(name: string)
	local window = windows[name]
	if window then
		window.open()
	end
end

function Menus.toggle(name: string)
	local window = windows[name]
	if window then
		if window.isOpen() then
			window.close()
		else
			window.open()
		end
	end
end

local function register(name: string, window: Ui.Window, renderer: () -> ())
	windows[name] = window
	renderers[name] = renderer
	window.onOpen(renderer)
end

function Menus.mount()
	local shop = Ui.window("Boutique", "Boutique", Vector2.new(640, 470), C.Aqua)
	local pickShop = Ui.tabs(shop.Body, { "Pieces", "Poses", "Walk-ins", "Robux" }, function(name)
		shopTab = name
		renderShop()
	end, C.Aqua)
	local content = Ui.scroller(shop.Body, {
		Name = "Content",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40),
	})
	content.Name = "Content"
	register("Shop", shop, function()
		pickShop(shopTab)
	end)
	register("Pass", Ui.window("StylePass", "Style Pass", Vector2.new(680, 440), C.Gold), renderPass)
	register("Profile", Ui.window("Profile", "My Style", Vector2.new(520, 500), C.Violet), renderProfile)
	register("Closet", Ui.window("Closet", "My Closet", Vector2.new(560, 440), C.Pink), renderCloset)
	register("Settings", Ui.window("Settings", "Settings", Vector2.new(440, 400), C.Panel3), renderSettings)

	State.onProfile(function()
		for name, window in windows do
			if window.isOpen() then
				renderers[name]()
			end
		end
	end)
end

return Menus
