--!strict
-- Theme pack for the working concept. Every player-facing name, colour, sound
-- and the night-time look live here, so switching to a different 2027 theme
-- means copying this folder, changing it and pointing Config/Theme at it.
-- Colours are hex strings so this file stays plain data.
--
-- The pack's other modules build what players see from this data: Props makes
-- a model for each upgrade, Scenery dresses the plots, the plaza and the land
-- around them, and Crowd makes the visitors in costume and the goods they
-- buy. All of it is made from parts in code, so the pack needs no uploaded
-- art. Model, if set on an upgrade, names a model under
-- ReplicatedStorage.Assets to use instead of the built one.

return {
	Name = "Moonlight Festival",

	Strings = {
		PlotOwner = "%s's Haunt",
		ClaimGate = "Touch to claim",
		ClaimHint = "Walk into a free gate to claim your haunted festival",
		Coins = "Coins",
		IncomePerSecond = "+%d / sec",
		VisitorsPerSecond = "%s visitors / sec",
		UpgradeGain = "+%s / sec",
		Free = "Free",

		-- Labels over the stations and attractions on a plot.
		StallSelling = "Selling %s / sec",
		StationMaking = "%s %s / sec",
		KitchenFull = "%s (full)",
		WalkthroughVisitors = "%s visitors / sec",
		ShowpieceDraw = "Draws %s visitors / sec",
		RideRound = "%s riders every %s sec",
		RideNext = "Next ride in %s",
		Payout = "+%s",

		-- Buy pads on a path. A building's first pads for each path say the
		-- choice is for good; later pads show the path and the tier.
		PathChoice = "Pick one: locks the other paths",
		PathTier = "%s %d/%d",

		-- Hover text on the music button in the corner of the screen.
		MusicOn = "Music on",
		MusicOff = "Music off",

		-- The wardrobe, where players put on what they have unlocked or bought.
		WardrobeButton = "Wardrobe",
		WardrobeTitle = "Haunted Wardrobe",
		WardrobeWear = "Wear",
		WardrobeWearing = "Wearing",
		WardrobeLocked = "Locked",
		WardrobeSoon = "Coming soon",
		WardrobeBuy = "Buy",
		WardrobePrice = "R$ %s",
		WardrobeOwns = "Build the %s",
		WardrobeOwnsAll = "Build all of: %s",
		WardrobeCount = "Build %d upgrades",
		WardrobePick = "Pick a path for the %s",
		WardrobeTier = "Reach tier %d on the %s",
		WardrobeFinish = "Finish a path of the %s",
		WardrobePath = "Finish the %s path of the %s",
		WardrobePathTier = "Reach tier %d of the %s path of the %s",
		WardrobeUnlocked = "New flex unlocked: %s!",
		WardrobeNowWearing = "Everyone can see it on you now",
		WardrobeOpenToWear = "Open the Wardrobe to wear it",
		WardrobeArenaEdge = "Arena edge",
		WardrobeNote = "Paid items are looks only, except Legendary weapons, which are a little stronger in the PvP arena. Nothing here changes your coins.",
		WardrobeStudio = "Studio test: paid items are free to try here, and only here.",

		-- The PvP arena. ArenaKOs is the leaderboard column counting each
		-- player's knockouts.
		ArenaSign = "BONK ARENA",
		ArenaRules = "Walk in to fight. Walk out to be safe.",
		ArenaKOs = "KOs",
		ArenaBonker = "Pumpkin Bonker",
		ArenaBonkerTip = "Lent to you while you're in the arena",
		ArenaEquip = "Hold your weapon to fight",
		ArenaEntered = "You're in the Bonk Arena! Anyone in here can bonk you.",
		ArenaLeft = "You left the arena. You're safe out here.",
		ArenaSpecialKey = "E",
		ArenaKnockedOutBy = "%s bonked you out! Walk back in for a rematch.",
		ArenaYouKnockedOut = "You bonked out %s!",
		ArenaStreak = "%d in a row!",
		ArenaReady = "Ready!",
	},

	-- The goods in the production chain, named as a plural for rate labels.
	Items = {
		handmade = { DisplayName = "Witch Apples", Color = "#B3202A" },
		raw = { DisplayName = "Pumpkins", Color = "#E67E22" },
		cooked = { DisplayName = "Pumpkin Pies", Color = "#D9A35B" },
	},

	-- Clothes colours for the visitors in costume walking around plots.
	VisitorColors = { "#5B7DB1", "#9B8EC4", "#4FA37A", "#D9644A", "#E8C547", "#3E8E9E" },

	-- Names for every upgrade in Config/Balance. Path tiers share their
	-- path's colour.
	Upgrades = {
		starter_stall = { DisplayName = "Creepy Treat Stall", Color = "#E8A33D" },
		stall_counter = { DisplayName = "Cobweb Counter", Color = "#C98A2E" },
		stall_boost_2 = { DisplayName = "Glowing Potion Shelf", Color = "#9B59B6" },
		stall_output_1 = { DisplayName = "Toffee Apple Cauldron", Color = "#FF6FB5" },
		stall_output_2 = { DisplayName = "Candy Floss Spinner", Color = "#FF6FB5" },
		stall_output_3 = { DisplayName = "Sugar Skull Molds", Color = "#FF6FB5" },
		stall_output_4 = { DisplayName = "Midnight Fudge Factory", Color = "#FF6FB5" },
		stall_vendor_1 = { DisplayName = "Ghoul Grub Bar", Color = "#5CFF4A" },
		stall_vendor_2 = { DisplayName = "Bat Wing Fries", Color = "#5CFF4A" },
		stall_vendor_3 = { DisplayName = "Slime Slushies", Color = "#5CFF4A" },
		stall_vendor_4 = { DisplayName = "Monster Mega Meals", Color = "#5CFF4A" },
		stall_markup_1 = { DisplayName = "Night Market Banners", Color = "#F2C94C" },
		stall_markup_2 = { DisplayName = "Haunted Price Tags", Color = "#F2C94C" },
		stall_markup_3 = { DisplayName = "Moonlight Auction", Color = "#F2C94C" },
		stall_markup_4 = { DisplayName = "Grand Night Bazaar", Color = "#F2C94C" },

		grower = { DisplayName = "Haunted Pumpkin Patch", Color = "#E07B24" },
		grower_boost = { DisplayName = "Swamp Sprinklers", Color = "#5FAF6A" },
		grower_boost_2 = { DisplayName = "Scarecrow Guards", Color = "#C9A54A" },
		grower_output_1 = { DisplayName = "Glowing Compost", Color = "#E67E22" },
		grower_output_2 = { DisplayName = "Full Moon Fertiliser", Color = "#E67E22" },
		grower_output_3 = { DisplayName = "Vine Monster Helpers", Color = "#E67E22" },
		grower_output_4 = { DisplayName = "Endless Pumpkin Fields", Color = "#E67E22" },
		grower_vendor_1 = { DisplayName = "Pick-Your-Own Patch", Color = "#4FA37A" },
		grower_vendor_2 = { DisplayName = "Wheelbarrow Rides", Color = "#4FA37A" },
		grower_vendor_3 = { DisplayName = "Pumpkin Carving Tables", Color = "#4FA37A" },
		grower_vendor_4 = { DisplayName = "Haunted Hayride", Color = "#4FA37A" },

		kitchen = { DisplayName = "Witch's Pie Kitchen", Color = "#B5651D" },
		kitchen_boost = { DisplayName = "Cauldron Oven", Color = "#A0522D" },
		kitchen_boost_2 = { DisplayName = "Enchanted Rolling Pins", Color = "#D9A35B" },
		kitchen_value_1 = { DisplayName = "Spell-Baked Crusts", Color = "#B98BFF" },
		kitchen_value_2 = { DisplayName = "Golden Pumpkin Pies", Color = "#B98BFF" },
		kitchen_value_3 = { DisplayName = "Moonberry Glaze", Color = "#B98BFF" },
		kitchen_value_4 = { DisplayName = "Legendary Witch Pies", Color = "#B98BFF" },
		kitchen_vendor_1 = { DisplayName = "Creepy Café", Color = "#FF9F43" },
		kitchen_vendor_2 = { DisplayName = "Hot Cocoa Cauldrons", Color = "#FF9F43" },
		kitchen_vendor_3 = { DisplayName = "Pie-Eating Contest", Color = "#FF9F43" },
		kitchen_vendor_4 = { DisplayName = "Midnight Feast Hall", Color = "#FF9F43" },

		attraction_1 = { DisplayName = "Lost Lantern Maze", Color = "#F2C94C" },
		attraction_1_boost = { DisplayName = "Fog Machines", Color = "#B9B4D6" },
		attraction_1_boost_2 = { DisplayName = "Extra Hedge Rows", Color = "#3E8E5A" },
		attraction_1_capacity_1 = { DisplayName = "Secret Passages", Color = "#3FBF6A" },
		attraction_1_capacity_2 = { DisplayName = "Hedge Labyrinth", Color = "#3FBF6A" },
		attraction_1_capacity_3 = { DisplayName = "Twisting Tunnels", Color = "#3FBF6A" },
		attraction_1_capacity_4 = { DisplayName = "Never-Ending Maze", Color = "#3FBF6A" },
		attraction_1_ticket_1 = { DisplayName = "Jump-Scare Hedges", Color = "#FF2A2A" },
		attraction_1_ticket_2 = { DisplayName = "Howling Corridors", Color = "#FF2A2A" },
		attraction_1_ticket_3 = { DisplayName = "Shadow Puppets", Color = "#FF2A2A" },
		attraction_1_ticket_4 = { DisplayName = "Nightmare Maze", Color = "#FF2A2A" },

		attraction_2 = { DisplayName = "Grinning Giant Pumpkin", Color = "#FF9F43" },
		attraction_2_boost = { DisplayName = "Bat Swarm", Color = "#6D35A0" },
		attraction_2_boost_2 = { DisplayName = "Wishing Well", Color = "#7FD3FF" },
		attraction_2_draw_1 = { DisplayName = "Lantern Crown", Color = "#CFE0FF" },
		attraction_2_draw_2 = { DisplayName = "Moonbeam Spotlights", Color = "#CFE0FF" },
		attraction_2_draw_3 = { DisplayName = "Firefly Swarm", Color = "#CFE0FF" },
		attraction_2_draw_4 = { DisplayName = "Harvest Moon Beacon", Color = "#CFE0FF" },
		attraction_2_ticket_1 = { DisplayName = "Crystal Ball Booth", Color = "#8A3DFF" },
		attraction_2_ticket_2 = { DisplayName = "Fortune Cookie Stand", Color = "#8A3DFF" },
		attraction_2_ticket_3 = { DisplayName = "Palm Reading Parlour", Color = "#8A3DFF" },
		attraction_2_ticket_4 = { DisplayName = "Grand Pumpkin Oracle", Color = "#8A3DFF" },

		attraction_3 = { DisplayName = "Phantom Ghost Train", Color = "#9B8EC4" },
		attraction_3_boost = { DisplayName = "Rattling Chains", Color = "#A3A6B3" },
		attraction_3_boost_2 = { DisplayName = "Extra Carriages", Color = "#9B8EC4" },
		attraction_3_seats_1 = { DisplayName = "Double Carriages", Color = "#2FE0C0" },
		attraction_3_seats_2 = { DisplayName = "Sleeper Cars", Color = "#2FE0C0" },
		attraction_3_seats_3 = { DisplayName = "Express Tracks", Color = "#2FE0C0" },
		attraction_3_seats_4 = { DisplayName = "Midnight Express", Color = "#2FE0C0" },
		attraction_3_ticket_1 = { DisplayName = "Screaming Tunnel", Color = "#FF7A1A" },
		attraction_3_ticket_2 = { DisplayName = "Phantom Conductor", Color = "#FF7A1A" },
		attraction_3_ticket_3 = { DisplayName = "Haunted Loop-the-Loop", Color = "#FF7A1A" },
		attraction_3_ticket_4 = { DisplayName = "Terror Train Deluxe", Color = "#FF7A1A" },
		attraction_3_draw_1 = { DisplayName = "Spooky Whistle", Color = "#EEF3FF" },
		attraction_3_draw_2 = { DisplayName = "Skeleton Marching Band", Color = "#EEF3FF" },
		attraction_3_draw_3 = { DisplayName = "Ghostly Fireworks", Color = "#EEF3FF" },
		attraction_3_draw_4 = { DisplayName = "Grand Ghost Parade", Color = "#EEF3FF" },
	},

	-- Each building's paths (see Config/Balance), by building and path id.
	-- Blurb is the short pitch on the pad that picks the path.
	Paths = {
		starter_stall = {
			output = { DisplayName = "Sweet Shop", Color = "#FF6FB5", Blurb = "Heaps more witch apples" },
			vendor = { DisplayName = "Ghoul Grub Bar", Color = "#5CFF4A", Blurb = "Every visitor buys a snack" },
			markup = { DisplayName = "Night Market", Color = "#F2C94C", Blurb = "Everything sells for more" },
		},
		grower = {
			output = { DisplayName = "Bumper Crop", Color = "#E67E22", Blurb = "Way more pumpkins" },
			vendor = { DisplayName = "Pick-Your-Own", Color = "#4FA37A", Blurb = "Visitors pay to pick pumpkins" },
		},
		kitchen = {
			value = { DisplayName = "Enchanted Pies", Color = "#B98BFF", Blurb = "Every pie is worth more" },
			vendor = { DisplayName = "Creepy Café", Color = "#FF9F43", Blurb = "Every visitor buys pie" },
		},
		attraction_1 = {
			capacity = { DisplayName = "Endless Maze", Color = "#3FBF6A", Blurb = "Bigger, with room for crowds" },
			ticket = { DisplayName = "Scream Maze", Color = "#FF2A2A", Blurb = "Scarier, so tickets cost more" },
		},
		attraction_2 = {
			draw = { DisplayName = "Moon Beacon", Color = "#CFE0FF", Blurb = "Draws crowds to everything" },
			ticket = { DisplayName = "Fortune Teller", Color = "#8A3DFF", Blurb = "Every visitor pays for a fortune" },
		},
		attraction_3 = {
			seats = { DisplayName = "Midnight Express", Color = "#2FE0C0", Blurb = "Longer trains, more riders" },
			ticket = { DisplayName = "Terror Train", Color = "#FF7A1A", Blurb = "Scarier rides cost more" },
			draw = { DisplayName = "Ghost Parade", Color = "#EEF3FF", Blurb = "Pulls in visitors for everything" },
		},
	},

	-- Colours the built models and scenery are painted with.
	Palette = {
		Wood = "#7A4E2D",
		DarkWood = "#432A1A",
		Plaster = "#E9DCC0",
		Stone = "#77738A",
		DarkStone = "#4A4658",
		Brick = "#8E4B3A",
		Roof = "#4B2E63",
		Metal = "#5D5F6B",
		Rail = "#A3A6B3",
		Soil = "#4A3222",
		Leaf = "#3F7A3A",
		Hedge = "#2C5E36",
		Stem = "#5A6B2A",
		Pumpkin = "#EE7A1C",
		PumpkinDark = "#C95F12",
		Candle = "#FFD27A",
		Glow = "#FFA43D",
		Moon = "#CFE0FF",
		Ghost = "#EEF3FF",
		Eye = "#1E1A2B",
		Water = "#7FD3FF",
		Gate = "#C9B8FF",
		ButtonRim = "#2A2238",
		AwningStripes = { "#6D35A0", "#F4E7CF" },
		Bunting = { "#F2C94C", "#6D35A0", "#3E8E9E", "#E8741E" },
		StringLights = { "#FFB347", "#F2C94C", "#B9A3FF", "#69E0D0", "#FF7A7A" },
		Foliage = { "#C4511F", "#D9822B", "#8E2F2F", "#E0A93A", "#3E6B3A" },
		Trunk = "#3B2A20",
		Firefly = "#E9F58A",
		Ember = "#FFB04A",
		Hay = "#C9A54A",
		Corn = "#F0C94A",
		CornLeaf = "#7A8F3A",
		Moss = "#5E7A4A",
		Bone = "#E8E2CC",
		Cobweb = "#DCE3F0",
		Bat = "#15121C",
		Mist = "#B9B4D6",
		EerieGlow = "#7DFF9A",
		-- The visitors' costumes and faces.
		Skins = { "#F2CBA8", "#D9A27C", "#B07650", "#7C4E35" },
		WitchSkin = "#A3D07F",
		Robes = { "#4B2E63", "#2A2238", "#2C5E36", "#5A1E3A" },
		Bandage = "#E6DEC6",
		BandageShade = "#BFB496",

		-- Saturated coloured light thrown on the builds, so each one has its
		-- own wash of colour in the fog. Each plot also gets one of the plot
		-- washes for its fence lanterns, in plot order.
		Washes = {
			Purple = "#8A3DFF",
			Red = "#FF2A2A",
			Toxic = "#5CFF4A",
			Orange = "#FF7A1A",
			Teal = "#2FE0C0",
		},
		PlotWashes = { "#FF2A2A", "#5CFF4A", "#8A3DFF", "#FF2A2A", "#5CFF4A", "#8A3DFF" },
	},

	-- The night: settings for Lighting and the effects inside it, applied by
	-- property name. It aims for spooky rather than gory, to stay within
	-- Roblox's "Mild" fear rating for players aged 9 to 12. Hex strings
	-- become colours. Lighting.Technology must be Future for lights to look
	-- right; it is set in default.project.json, because scripts can't change it.
	Look = {
		Lighting = {
			ClockTime = 20.8,
			GeographicLatitude = 25,
			Brightness = 1,
			Ambient = "#1E1A30",
			OutdoorAmbient = "#30305A",
			ColorShift_Top = "#A8C8FF",
			ColorShift_Bottom = "#1A1428",
			EnvironmentDiffuseScale = 0.25,
			EnvironmentSpecularScale = 0.8,
			ExposureCompensation = 0.35,
			ShadowSoftness = 0.3,
		},
		-- Thick, murky haze, so lights glow through it and far plots fade out.
		Atmosphere = {
			Density = 0.5,
			Offset = 0.2,
			Color = "#4C4F78",
			Decay = "#22163A",
			Glare = 0.6,
			Haze = 3,
		},
		-- The engine's own sky, with more stars and a huge full moon.
		Sky = {
			StarCount = 5000,
			MoonAngularSize = 34,
			SunAngularSize = 8,
			CelestialBodiesShown = true,
		},
		BloomEffect = {
			Intensity = 1.1,
			Size = 34,
			Threshold = 0.8,
		},
		ColorCorrectionEffect = {
			Brightness = 0,
			Contrast = 0.2,
			Saturation = 0.2,
			TintColor = "#E6EEFF",
		},
		-- Terrain colours, by terrain material name.
		Terrain = {
			Grass = "#2F4F2B",
			Mud = "#3D2E22",
		},
		WaterColor = "#1E3A5C",
		PlotGround = "#3B6233",
		Path = "#8A7C70",
		Plaza = "#6E6680",
	},

	-- Sounds and music, as Roblox asset ids ("rbxassetid://123"). Empty means
	-- silent. The original sounds for this pack are in assets/audio; upload
	-- them and paste their ids here (see the README). Volume is 0 to 1. Music
	-- and Music2 are two songs that play in turn.
	Sounds = {
		Music = { Id = "", Volume = 0.3 },
		Music2 = { Id = "", Volume = 0.3 },
		Ambience = { Id = "", Volume = 0.35 },
		Claim = { Id = "", Volume = 0.6 },
		Purchase = { Id = "", Volume = 0.6 },
		Build = { Id = "", Volume = 0.5 },
		Payout = { Id = "", Volume = 0.5 },
		-- A held weapon landing: a heavy thump for hammers, a whoosh for the rest.
		Thump = { Id = "", Volume = 0.6 },
		Whoosh = { Id = "", Volume = 0.5 },
	},

	-- Names for the wardrobe: its slots, its lines (one tab each) and every
	-- cosmetic in Config/Cosmetics. Color tints the item's card.
	CosmeticSlots = {
		Head = "Head",
		Back = "Back",
		Hand = "Held",
		Pet = "Pet",
		Aura = "Aura",
		Trail = "Trail",
	},
	CosmeticLines = {
		Earned = "Earned",
		Deluxe = "Deluxe",
		Brainrot = "Brainrot Buddies",
		Legendary = "Legendary",
	},
	Cosmetics = {
		lantern = {
			DisplayName = "Trick-or-Treat Lantern",
			Color = "#F28A1E",
			Blurb = "A candy-striped pole with a glowing lantern.",
		},
		witch_cape = {
			DisplayName = "Witch's Cape",
			Color = "#5B2A86",
			Blurb = "A starry purple cape that swishes behind you.",
		},
		pumpkin_head = {
			DisplayName = "Pumpkin Head",
			Color = "#EE7A1C",
			Blurb = "Swap your head for a grinning, glowing jack-o'-lantern.",
		},
		wooden_mallet = {
			DisplayName = "Big Wooden Mallet",
			Color = "#B5753F",
			Blurb = "A huge mallet. Click to swing it down with a thump.",
		},
		ember_trail = {
			DisplayName = "Ember Trail",
			Color = "#FF7A1A",
			Blurb = "Leave glowing embers wherever you run.",
		},
		witch_broom = {
			DisplayName = "Witch's Broom",
			Color = "#D9B45A",
			Blurb = "A crooked broom for smacking things.",
		},
		pumpkling = {
			DisplayName = "Pumpkling",
			Color = "#FF9F43",
			Blurb = "A tiny floating pumpkin that follows you everywhere.",
		},
		werewolf_claws = {
			DisplayName = "Werewolf Claws",
			Color = "#8A6A50",
			Blurb = "Furry gauntlets with big curved claws.",
		},
		phantom_aura = {
			DisplayName = "Phantom Aura",
			Color = "#8A3DFF",
			Blurb = "Ghostly purple wisps rise all around you.",
		},
		moon_saber = {
			DisplayName = "Crescent Moon Blade",
			Color = "#CFE3FF",
			Blurb = "A glowing crescent sword: the best weapon you can earn.",
		},
		moonstone_mallet = {
			DisplayName = "Moonstone Mallet",
			Color = "#8FB4FF",
			Blurb = "The Big Wooden Mallet in glowing moonstone. Same swing, fancier thump.",
		},
		bat_wings = {
			DisplayName = "Neon Bat Wings",
			Color = "#9B4DFF",
			Blurb = "Glowing purple bat wings on your back.",
		},
		ghostfire_crown = {
			DisplayName = "Ghostfire Crown",
			Color = "#6CFF5A",
			Blurb = "A golden crown with green ghostfire on every point.",
		},
		toxic_aura = {
			DisplayName = "Toxic Ghostfire Aura",
			Color = "#5CFF4A",
			Blurb = "Green ghostfire flickers all around you.",
		},
		rainbow_trail = {
			DisplayName = "Spooky Rainbow Trail",
			Color = "#FF2A2A",
			Blurb = "A ribbon of every colour of the night.",
		},
		pizza_bat = {
			DisplayName = "Pipistrello Pizzetta",
			Color = "#F2C94C",
			Blurb = "Half pizza slice, half bat, all nonsense.",
		},
		gelato_ghost = {
			DisplayName = "Fantasmino Gelatino",
			Color = "#A8F0D0",
			Blurb = "A ghost who is also a scoop of mint gelato.",
		},
		candle_buddy = {
			DisplayName = "Candelino Wobblino",
			Color = "#FFB347",
			Blurb = "A wobbly candle with googly eyes and tiny feet.",
		},
		zombie_zucchini = {
			DisplayName = "Zucchino Zombino",
			Color = "#6FA35A",
			Blurb = "A zucchini that came back. Arms out, always.",
		},
		thunder_hammer = {
			DisplayName = "Storm-Stone Hammer",
			Color = "#5FC8FF",
			Blurb = "A rune-carved warhammer crackling with lightning.",
		},
		ghost_blade = {
			DisplayName = "Ghostlight Blade",
			Color = "#7FF7FF",
			Blurb = "A see-through spirit sword with a bat-wing guard.",
		},
		reaper_scythe = {
			DisplayName = "Reaper's Scythe",
			Color = "#B26BFF",
			Blurb = "A huge scythe with a glowing purple edge.",
		},
		drowned_trident = {
			DisplayName = "Drowned Trident",
			Color = "#3DF5D0",
			Blurb = "A sea-green trident glowing with sunken light.",
		},
		foxfire_fan = {
			DisplayName = "Foxfire Fan",
			Color = "#4FA8FF",
			Blurb = "A folding fan with blue fox-fire on every tip.",
		},
	},
}
