-- Loads modules that build Instances, such as the theme pack's props, the way
-- Roblox would: the Roblox globals they use come from Lune's roblox library,
-- and script.Parent paths map onto the files under src/. Setting a property
-- that doesn't exist, or to the wrong type, errors here just as in Studio.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RobloxLoader = {}

local globals = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
}

local cache = {}

-- A stand-in for a script's place in the tree: indexing a name goes down a
-- folder, and Parent goes up one.
local function scriptAt(path: string): any
	return setmetatable({ path = path }, {
		__index = function(self, key)
			if key == "Parent" then
				return scriptAt(string.match(rawget(self, "path"), "^(.*)/[^/]+$"))
			end
			return scriptAt(`{rawget(self, "path")}/{key}`)
		end,
	})
end

-- Loads the module at path, given without its extension, such as
-- "src/shared/Themes/MoonlightFestival/Props".
function RobloxLoader.require(path: string): any
	if cache[path] == nil then
		local file = if fs.isFile(`{path}.luau`) then `{path}.luau` else `{path}/init.luau`
		local environment = table.clone(globals)
		environment.script = scriptAt(path)
		environment.require = function(target)
			return RobloxLoader.require(rawget(target, "path"))
		end
		local chunk = luau.load(fs.readFile(file), { debugName = file, environment = environment })
		cache[path] = chunk()
	end
	return cache[path]
end

RobloxLoader.roblox = roblox

return RobloxLoader
