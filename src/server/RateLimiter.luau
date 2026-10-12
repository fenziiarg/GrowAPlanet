--!strict
export type Bucket = { tokens: number, at: number, rate: number, capacity: number }
local Limiter = {}
function Limiter.new(rate: number, capacity: number, now: number): Bucket
	return { tokens = capacity, at = now, rate = rate, capacity = capacity }
end
function Limiter.take(bucket: Bucket, now: number): boolean
	local elapsed = math.max(0, now - bucket.at)
	bucket.at = math.max(now, bucket.at)
	bucket.tokens = math.min(bucket.capacity, bucket.tokens + elapsed * bucket.rate)
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end
return Limiter
