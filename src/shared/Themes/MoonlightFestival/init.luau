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

		-- Hover text on the music button in the corner of the screen.
		MusicOn = "Music on",
		MusicOff = "Music off",
	},

	-- The goods in the production chain, named as a plural for rate labels.
	Items = {
		handmade = { DisplayName = "Witch Apples", Color = "#B3202A" },
		raw = { DisplayName = "Pumpkins", Color = "#E67E22" },
		cooked = { DisplayName = "Pumpkin Pies", Color = "#D9A35B" },
	},

	-- Clothes colours for the visitors in costume walking around plots.
	VisitorColors = { "#5B7DB1", "#9B8EC4", "#4FA37A", "#D9644A", "#E8C547", "#3E8E9E" },

	Upgrades = {
		starter_stall = { DisplayName = "Creepy Treat Stall", Color = "#E8A33D" },
		stall_counter = { DisplayName = "Cobweb Counter", Color = "#C98A2E" },
		grower = { DisplayName = "Haunted Pumpkin Patch", Color = "#E07B24" },
		kitchen = { DisplayName = "Witch's Pie Kitchen", Color = "#B5651D" },
		grower_boost = { DisplayName = "Swamp Sprinklers", Color = "#5FAF6A" },
		kitchen_boost = { DisplayName = "Cauldron Oven", Color = "#A0522D" },
		attraction_1 = { DisplayName = "Lost Lantern Maze", Color = "#F2C94C" },
		attraction_2 = { DisplayName = "Grinning Giant Pumpkin", Color = "#FF9F43" },
		attraction_3 = { DisplayName = "Phantom Ghost Train", Color = "#9B8EC4" },
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
	},
}
