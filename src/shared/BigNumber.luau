--!strict
-- Nonnegative scientific notation, roughly 15 significant decimal digits.
-- Tiny additions below floating-point precision may be lost; never wraps to infinity.
export type Value = { m: number, e: number }
local Big = {}
local MAX_EXPONENT = 3000
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end
function Big.new(m: number, e: number?): Value
	local exponent = e or 0
	assert(finite(m) and m >= 0 and finite(exponent) and exponent % 1 == 0, "Invalid number")
	if m == 0 then
		return { m = 0, e = 0 }
	end
	local shift = math.floor(math.log10(m))
	local normalized = if shift < -300 then (m * 1e300) / 10 ^ (shift + 300) else m / 10 ^ shift
	exponent += shift
	if normalized >= 10 then
		normalized /= 10
		exponent += 1
	elseif normalized < 1 then
		normalized *= 10
		exponent -= 1
	end
	assert(exponent >= -300 and exponent <= MAX_EXPONENT, "Number outside supported range")
	return { m = normalized, e = exponent }
end
function Big.valid(value: any): boolean
	return type(value) == "table"
		and type(value.m) == "number"
		and type(value.e) == "number"
		and finite(value.m)
		and finite(value.e)
		and value.e % 1 == 0
		and value.e >= -300
		and value.e <= MAX_EXPONENT
		and ((value.m == 0 and value.e == 0) or (value.m >= 1 and value.m < 10))
end
function Big.compare(a: Value, b: Value): number
	if a.m == 0 or b.m == 0 then
		return if a.m == b.m then 0 elseif a.m == 0 then -1 else 1
	end
	if a.e ~= b.e then
		return if a.e < b.e then -1 else 1
	end
	return if a.m == b.m then 0 elseif a.m < b.m then -1 else 1
end
function Big.add(a: Value, b: Value): Value
	if a.m == 0 then
		return { m = b.m, e = b.e }
	end
	if b.m == 0 then
		return { m = a.m, e = a.e }
	end
	local high, low = a, b
	if a.e < b.e then
		high, low = b, a
	end
	return Big.new(high.m + low.m * 10 ^ math.max(-324, low.e - high.e), high.e)
end
function Big.subtract(a: Value, b: Value): Value
	assert(Big.compare(a, b) >= 0, "Insufficient balance")
	if b.m == 0 then
		return { m = a.m, e = a.e }
	end
	return Big.new(math.max(0, a.m - b.m * 10 ^ math.max(-324, b.e - a.e)), a.e)
end
function Big.scale(a: Value, factor: number): Value
	assert(finite(factor) and factor >= 0, "Invalid multiplier")
	if factor == 0 or a.m == 0 then
		return Big.new(0)
	end
	local b = Big.new(factor)
	return Big.new(a.m * b.m, a.e + b.e)
end
function Big.format(a: Value): string
	if a.m == 0 then
		return "0"
	end
	if a.e < 0 then
		return string.format("%.2f", a.m * 10 ^ a.e)
	end
	local group = math.floor(a.e / 3)
	if group >= #SUFFIXES then
		return string.format("%.3ge%d", a.m, a.e)
	end
	local n = a.m * 10 ^ (a.e - group * 3)
	local rounded = math.floor(n * 10 + 0.5) / 10
	if rounded >= 1000 then
		group += 1
		rounded = 1
	end
	local text = string.format("%.1f", rounded):gsub("%.0$", "")
	return text .. (SUFFIXES[group + 1] or ("e" .. tostring(group * 3)))
end
return table.freeze(Big)
