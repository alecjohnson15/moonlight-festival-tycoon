local TestKit = require("./TestKit")
local RateLimiter = require("../src/server/Lib/RateLimiter")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("RateLimiter", function()
	local time = 0
	local function clock()
		return time
	end

	it("allows the first call, blocks within the cooldown, then allows again", function()
		time = 0
		local limiter = RateLimiter.new(2, clock)
		expect(limiter:allow("a")).toBe(true)
		time = 1.9
		expect(limiter:allow("a")).toBe(false)
		time = 2
		expect(limiter:allow("a")).toBe(true)
	end)

	it("tracks each key on its own", function()
		time = 0
		local limiter = RateLimiter.new(2, clock)
		expect(limiter:allow("a")).toBe(true)
		expect(limiter:allow("b")).toBe(true)
	end)

	it("forgets a key so a returning player starts fresh", function()
		time = 0
		local limiter = RateLimiter.new(2, clock)
		limiter:allow("a")
		limiter:forget("a")
		expect(limiter:allow("a")).toBe(true)
	end)
end)

return nil
