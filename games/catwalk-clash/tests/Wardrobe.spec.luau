local TestKit = require("./TestKit")
local RobloxLoader = require("./RobloxLoader")

local Wardrobe = RobloxLoader.require("src/shared/Config/Wardrobe")
local Themes = RobloxLoader.require("src/shared/Config/Themes")
local Palette = RobloxLoader.require("src/shared/Config/Palette")
local Catalog = RobloxLoader.require("src/shared/Config/Catalog")
local Season = RobloxLoader.require("src/shared/Config/Season")
local Poses = RobloxLoader.require("src/shared/Config/Poses")
local Entrances = RobloxLoader.require("src/shared/Config/Entrances")
local Pieces = RobloxLoader.require("src/shared/Build/Pieces")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local passIds = {}
for _, item in Catalog do
	passIds[item.Id] = item.Kind
end

-- Which season tier gives each reward, by kind.
local seasonRewards = { Piece = {}, Pose = {}, Entrance = {} }
for tier, rewards in Season.Tiers do
	for _, track in { "Free", "Premium" } do
		for kind, list in seasonRewards do
			local id = rewards[track][kind]
			if id then
				list[id] = tier
			end
		end
	end
end

local function checkSource(item, kind: string)
	if item.Pass then
		assert(passIds[item.Pass] == "GamePass", `{item.Id} names a pass that isn't in the catalog`)
	end
	if item.Season then
		assert(seasonRewards[kind][item.Id] == item.Season, `{item.Id} isn't a reward at Style Pass tier {item.Season}`)
	end
	assert(type(item.Price) == "number" and item.Price >= 0, `{item.Id} has a bad price`)
end

describe("Wardrobe", function()
	it("has unique ids and known slots, tags and colours", function()
		local seen = {}
		for _, piece in Wardrobe.Pieces do
			assert(not seen[piece.Id], `duplicate id {piece.Id}`)
			seen[piece.Id] = true
			assert(table.find(Wardrobe.Slots, piece.Slot), `{piece.Id} has unknown slot {piece.Slot}`)
			assert(#piece.Tags >= 1, `{piece.Id} has no tags`)
			for _, tag in piece.Tags do
				assert(table.find(Themes.Tags, tag), `{piece.Id} has unknown tag {tag}`)
			end
			assert(Palette.indexOf(piece.Main), `{piece.Id} has unknown main colour {piece.Main}`)
			assert(Palette.indexOf(piece.Accent), `{piece.Id} has unknown accent colour {piece.Accent}`)
			assert(Palette.isFinish(piece.Finish), `{piece.Id} has unknown finish {piece.Finish}`)
			for _, shape in piece.Shapes do
				if type(shape.c) == "string" and shape.c ~= "Main" and shape.c ~= "Accent" then
					assert(Palette.indexOf(shape.c), `{piece.Id} paints with unknown colour {shape.c}`)
				end
				if shape.m then
					assert(Palette.isFinish(shape.m), `{piece.Id} uses unknown finish {shape.m}`)
				end
			end
			checkSource(piece, "Piece")
		end
	end)

	it("offers free pieces in every slot", function()
		for _, slot in Wardrobe.Slots do
			local free = 0
			for _, piece in Wardrobe.inSlot(slot) do
				if Wardrobe.source(piece) == "Free" then
					free += 1
				end
			end
			assert(free >= 1, `no free pieces in {slot}`)
		end
	end)

	it("can dress for every theme with free pieces alone", function()
		for _, theme in Themes.List do
			local fitting = 0
			for _, piece in Wardrobe.Pieces do
				if Wardrobe.source(piece) == "Free" then
					for _, tag in piece.Tags do
						if table.find(theme.Tags, tag) then
							fitting += 1
							break
						end
					end
				end
			end
			assert(fitting >= 3, `only {fitting} free pieces fit {theme.Id}`)
		end
	end)

	it("builds every piece without errors", function()
		local parts = 0
		for _, piece in Wardrobe.Pieces do
			local accessories = Pieces.buildDefault(piece)
			expect(#accessories).toBe(if piece.Pair then 2 else 1)
			for _, accessory in accessories do
				local handle = accessory:FindFirstChild("Handle")
				assert(handle, `{piece.Id} has no handle`)
				assert(handle:FindFirstChildOfClass("Attachment"), `{piece.Id} has no attachment`)
				for _, child in accessory:GetChildren() do
					if child:IsA("BasePart") then
						parts += 1
						assert(child.Anchored == false and child.CanCollide == false, `{piece.Id} has a solid part`)
					end
				end
			end
		end
		print(`        {#Wardrobe.Pieces} pieces, {parts} parts`)
	end)

	it("keeps every piece small enough for phones", function()
		for _, piece in Wardrobe.Pieces do
			local count = 0
			for _, accessory in Pieces.buildDefault(piece) do
				for _, child in accessory:GetChildren() do
					if child:IsA("BasePart") then
						count += 1
					end
				end
			end
			assert(count <= 40, `{piece.Id} has {count} parts`)
		end
	end)
end)

describe("Poses and entrances", function()
	it("have unique ids and real sources", function()
		for kind, list in { Pose = Poses.List, Entrance = Entrances.List } do
			local seen = {}
			for _, item in list do
				assert(not seen[item.Id], `duplicate {kind} {item.Id}`)
				seen[item.Id] = true
				checkSource(item, kind)
			end
		end
		assert(Poses.get(Poses.Default), "the default pose is missing")
		assert(Entrances.get(Entrances.Default), "the default entrance is missing")
	end)

	it("only turn joints an R15 body has", function()
		local joints = {
			Neck = true,
			Waist = true,
			Root = true,
			RightShoulder = true,
			RightElbow = true,
			RightWrist = true,
			LeftShoulder = true,
			LeftElbow = true,
			LeftWrist = true,
			RightHip = true,
			RightKnee = true,
			RightAnkle = true,
			LeftHip = true,
			LeftKnee = true,
			LeftAnkle = true,
		}
		for _, pose in Poses.List do
			for joint in pose.Joints do
				assert(joints[joint], `{pose.Id} turns unknown joint {joint}`)
			end
		end
	end)
end)
