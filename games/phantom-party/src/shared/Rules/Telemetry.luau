--!strict
-- The pure part of analytics: cleaning an event to what Config/Telemetry
-- allows, and a per-player limit on how many go out a minute. Pure, so the
-- tests can try junk and floods (tests/Telemetry.spec).

local TelemetryConfig = require(script.Parent.Parent.Config.Telemetry)

export type Limiter = { Times: { number } }

local Telemetry = {}

local function allowed(field: string, value: any): string
	local rule = TelemetryConfig.Values[field]
	if rule == "Count" then
		local number = tonumber(value)
		if number == nil or number ~= number then
			return "Other"
		end
		return tostring(math.clamp(math.floor(number), 0, 99))
	elseif type(rule) == "table" and type(value) == "string" and table.find(rule, value) then
		return value
	end
	return "Other"
end

-- The event as it may be sent: (true, value, fields) or (false) if the
-- event isn't listed, is off, or telemetry is off. Fields come back in the
-- listed order with anything unlisted replaced by "Other", and extra
-- fields dropped.
function Telemetry.clean(name: string, value: any, fields: { any }?, config: any?): (boolean, number, { string })
	local settings = config or TelemetryConfig
	local event = settings.Events[name]
	if not settings.Enabled or not event or event.Off then
		return false, 0, {}
	end
	local number = tonumber(value) or 1
	if number ~= number then
		number = 1
	end
	number = math.clamp(math.floor(number), 0, settings.MaxValue)
	local clean = {}
	for index, field in event.Fields do
		clean[index] = allowed(field, if fields then fields[index] else nil)
	end
	return true, number, clean
end

function Telemetry.limiter(): Limiter
	return { Times = {} }
end

-- Whether one more event may go out at time now (seconds), keeping at most
-- perMinute in any 60 seconds.
function Telemetry.allow(limiter: Limiter, now: number, perMinute: number?): boolean
	local limit = perMinute or TelemetryConfig.PerMinute
	local times = limiter.Times
	while #times > 0 and now - times[1] >= 60 do
		table.remove(times, 1)
	end
	if #times >= limit then
		return false
	end
	table.insert(times, now)
	return true
end

return Telemetry
