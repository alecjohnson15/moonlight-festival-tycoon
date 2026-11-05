-- A small test runner for Lune: describe, it and expect, with no packages.

local TestKit = {}

type Test = { name: string, fn: () -> () }

local tests: { Test } = {}
local scope: { string } = {}

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function TestKit.describe(name: string, fn: () -> ())
	table.insert(scope, name)
	fn()
	table.remove(scope)
end

function TestKit.it(name: string, fn: () -> ())
	local fullName = table.concat(scope, " > ") .. " > " .. name
	table.insert(tests, { name = fullName, fn = fn })
end

function TestKit.expect(actual: any)
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				error(`expected {show(expected)}, got {show(actual)}`, 2)
			end
		end,
		toEqual = function(expected: any)
			if not deepEqual(actual, expected) then
				error("tables differ", 2)
			end
		end,
		toContain = function(needle: string)
			for _, item in actual do
				if type(item) == "string" and string.find(item, needle, 1, true) then
					return
				end
			end
			error(`expected a list entry containing {show(needle)}`, 2)
		end,
	}
end

-- Runs every registered test and returns how many failed.
function TestKit.run(): number
	local failures = 0
	for _, test in tests do
		local ok, err = pcall(test.fn)
		if ok then
			print(`  pass  {test.name}`)
		else
			failures += 1
			print(`  FAIL  {test.name}\n        {err}`)
		end
	end
	print(`\n{#tests - failures} passed, {failures} failed`)
	return failures
end

return TestKit
