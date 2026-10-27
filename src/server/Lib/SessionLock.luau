--!strict
-- Decides whether this server may take a player's save. The server holding a
-- save refreshes its lock on every autosave, so a lock older than STALE_AFTER
-- means that server stopped without releasing it.

export type Lock = {
	JobId: string,
	Time: number,
}

export type Decision = "Acquire" | "Steal" | "Wait"

local SessionLock = {}

SessionLock.STALE_AFTER = 300

function SessionLock.decide(lock: Lock?, jobId: string, now: number): Decision
	if lock == nil or lock.JobId == jobId then
		return "Acquire"
	end
	if now - lock.Time > SessionLock.STALE_AFTER then
		return "Steal"
	end
	return "Wait"
end

function SessionLock.new(jobId: string, now: number): Lock
	return { JobId = jobId, Time = now }
end

-- True when the stored lock still belongs to this server, so it may write.
function SessionLock.isHeldBy(lock: Lock?, jobId: string): boolean
	return lock ~= nil and lock.JobId == jobId
end

return SessionLock
