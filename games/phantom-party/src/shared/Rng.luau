--!strict
-- A repeatable random sequence (Park and Miller's), so scenery comes out the
-- same every time and the tests can check dealing and crates exactly. The
-- server seeds it from the clock for anything players should not predict.

export type Rng = {
	-- A number from 0 up to (not including) 1.
	next: () -> number,
	number: (min: number, max: number) -> number,
	integer: (min: number, max: number) -> number,
	pick: <T>(list: { T }) -> T,
	shuffle: <T>(list: { T }) -> { T },
}

local Rng = {}

function Rng.new(seed: number): Rng
	local state = math.floor(seed) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local random = {}
	function random.next(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
	function random.number(min: number, max: number): number
		return min + (max - min) * random.next()
	end
	function random.integer(min: number, max: number): number
		return math.min(max, math.floor(random.number(min, max + 1)))
	end
	function random.pick<T>(list: { T }): T
		return list[random.integer(1, #list)]
	end
	-- A shuffled copy of list.
	function random.shuffle<T>(list: { T }): { T }
		local copy = table.clone(list)
		for i = #copy, 2, -1 do
			local j = random.integer(1, i)
			copy[i], copy[j] = copy[j], copy[i]
		end
		return copy
	end
	return random :: Rng
end

return Rng
