--!strict
-- Per-key cooldown for anything a client can trigger repeatedly, such as
-- remote requests and proximity prompts.

export type RateLimiter = {
	allow: (self: RateLimiter, key: any) -> boolean,
	forget: (self: RateLimiter, key: any) -> (),
}

local RateLimiter = {}

function RateLimiter.new(cooldownSeconds: number, clock: (() -> number)?): RateLimiter
	local now = clock or os.clock
	local lastAllowed: { [any]: number } = {}

	local limiter = {}

	function limiter.allow(_self: RateLimiter, key: any): boolean
		local time = now()
		local last = lastAllowed[key]
		if last and time - last < cooldownSeconds then
			return false
		end
		lastAllowed[key] = time
		return true
	end

	function limiter.forget(_self: RateLimiter, key: any)
		lastAllowed[key] = nil
	end

	return limiter :: RateLimiter
end

return RateLimiter
