-- Every source file compiles as Luau, including the server and client
-- scripts the other tests can't load outside Roblox.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local TestKit = require("./TestKit")

local describe, it = TestKit.describe, TestKit.it

local function walk(dir: string, into: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			walk(path, into)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(into, path)
		end
	end
	return into
end

describe("source", function()
	it("compiles, every file", function()
		local files = walk("src", {})
		table.sort(files)
		assert(#files > 40, "expected the whole game's source")
		for _, path in files do
			local ok, err = pcall(luau.compile, fs.readFile(path))
			assert(ok, `{path}: {err}`)
		end
	end)
end)

return nil
