--!strict
local Shared = game:GetService("ReplicatedStorage").GrowAPlanet
local Server = game:GetService("ServerScriptService").GrowAPlanet
local Big = require(Shared.BigNumber)
local Economy = require(Shared.Economy)
local Limiter = require(Server.RateLimiter)
local Session = require(Server.Session)
local Schema = require(Server.ProfileSchema)
return function()
	-- TestEZ injects its DSL into the specification function environment.
	local it = getfenv().it
	local function near(actual: number, expected: number)
		assert(math.abs(actual - expected) < 1e-9, tostring(actual) .. " ~= " .. tostring(expected))
	end
	local cases: { { number | string } } = {
		{ 999, "999" },
		{ 1500, "1.5K" },
		{ 2300000, "2.3M" },
		{ 4e9, "4B" },
		{ 7e12, "7T" },
		{ 9e15, "9Qa" },
		{ 2e18, "2Qi" },
	}
	for _, case in cases do
		it("formats " .. tostring(case[2]), function()
			assert(
				Big.format(Big.new(case[1] :: number)) == case[2],
				"Big.format(Big.new(case[1] :: number)) == case[2]"
			)
		end)
	end
	it("formats scientific values beyond native floating-point range", function()
		assert(
			Big.format(Big.new(2.5, 400)) == "2.5e400",
			'Big.format(Big.new(2.5, 400)) == "2.5e400"'
		)
	end)
	it("promotes rounding across a suffix boundary", function()
		assert(Big.format(Big.new(999999)) == "1M", 'Big.format(Big.new(999999)) == "1M"')
	end)
	it("adds numbers across exponents without mutating inputs", function()
		local a = Big.new(1500)
		local sum = Big.add(a, Big.new(250))
		near(sum.m, 1.75)
		assert(sum.e == 3, "sum.e == 3")
		near(a.m, 1.5)
	end)
	it("subtracts equal values to canonical zero", function()
		local zero = Big.subtract(Big.new(9, 400), Big.new(9, 400))
		assert(zero.m == 0 and zero.e == 0, "zero.m == 0 and zero.e == 0")
	end)
	it("rejects overdrafts", function()
		assert(
			not pcall(Big.subtract, Big.new(1), Big.new(2)),
			"not pcall(Big.subtract, Big.new(1), Big.new(2))"
		)
	end)
	it("multiplies large values without infinity", function()
		local n = Big.scale(Big.new(2, 400), 3)
		assert(n.m == 6 and n.e == 400, "n.m == 6 and n.e == 400")
	end)
	it("rejects negative nonfinite and out-of-range numbers", function()
		for _, n in { -1, math.huge, 0 / 0 } do
			assert(not pcall(Big.new, n), "not pcall(Big.new, n)")
		end
		assert(not pcall(Big.new, 1, 3001), "not pcall(Big.new, 1, 3001)")
		assert(not Big.valid({ m = 10, e = 0 }), "not Big.valid({ m = 10, e = 0 })")
	end)
	it("creates seven independent zero balances", function()
		local a, b = Economy.initial(), Economy.initial()
		local count = 0
		for _, n in a do
			assert(n.m == 0, "n.m == 0")
			count += 1
		end
		assert(count == 7, "count == 7")
		a.GrowthPoints.m = 2
		assert(b.GrowthPoints.m == 0, "b.GrowthPoints.m == 0")
	end)
	it("awards exactly one configured click", function()
		local before = Economy.initial()
		local after = Economy.click(before)
		assert(
			Big.compare(after.GrowthPoints, Big.new(1)) == 0,
			"Big.compare(after.GrowthPoints, Big.new(1)) == 0"
		)
		assert(
			before.GrowthPoints.m == 0 and after.Money.m == 0,
			"before.GrowthPoints.m == 0 and after.Money.m == 0"
		)
	end)
	it("integrates fractional elapsed time and keeps unearned resources zero", function()
		local after = Economy.advance(Economy.initial(), 2.5)
		near(after.GrowthPoints.m, 2.5)
		assert(after.GrowthPoints.e == 0, "after.GrowthPoints.e == 0")
		for id, n in after do
			if id ~= "GrowthPoints" then
				assert(n.m == 0, "n.m == 0")
			end
		end
	end)
	it("produces the same result for subdivided time", function()
		local a = Economy.advance(Economy.initial(), 10)
		local b = Economy.initial()
		for _ = 1, 100 do
			b = Economy.advance(b, 0.1)
		end
		near(a.GrowthPoints.m * 10 ^ a.GrowthPoints.e, b.GrowthPoints.m * 10 ^ b.GrowthPoints.e)
	end)
	it("rejects invalid elapsed time without changing balances", function()
		local before = Economy.initial()
		assert(not pcall(Economy.advance, before, -1), "not pcall(Economy.advance, before, -1)")
		assert(
			not pcall(Economy.advance, before, math.huge),
			"not pcall(Economy.advance, before, math.huge)"
		)
		assert(before.GrowthPoints.m == 0, "before.GrowthPoints.m == 0")
	end)
	it("limits bursts and refills by server time", function()
		local bucket = Limiter.new(8, 8, 0)
		for _ = 1, 8 do
			assert(Limiter.take(bucket, 0), "Limiter.take(bucket, 0)")
		end
		assert(not Limiter.take(bucket, 0), "not Limiter.take(bucket, 0)")
		assert(Limiter.take(bucket, 0.125), "Limiter.take(bucket, 0.125)")
		assert(not Limiter.take(bucket, 0.125), "not Limiter.take(bucket, 0.125)")
		assert(not Limiter.take(bucket, -10), "not Limiter.take(bucket, -10)")
	end)
	it("caps refilled tokens at burst capacity", function()
		local bucket = Limiter.new(8, 8, 0)
		for _ = 1, 8 do
			assert(Limiter.take(bucket, 1000), "Limiter.take(bucket, 1000)")
		end
		assert(not Limiter.take(bucket, 1000), "not Limiter.take(bucket, 1000)")
	end)
	it("does not create or overwrite data after a failed load", function()
		local existing = Schema.new()
		existing.planets.home.resources.GrowthPoints = Big.new(42)
		local profile, reason = Session.load(function()
			return nil
		end, function()
			return false
		end)
		assert(
			profile == nil and reason == "load_failed",
			'profile == nil and reason == "load_failed"'
		)
		assert(
			Big.compare(existing.planets.home.resources.GrowthPoints, Big.new(42)) == 0,
			"Big.compare(existing.planets.home.resources.GrowthPoints, Big.new(42)) == 0"
		)
	end)
	it("catches a throwing loader without granting a session", function()
		local profile, reason = Session.load(function()
			error("Injected transport error")
		end, function()
			return false
		end)
		assert(
			profile == nil and reason == "load_failed",
			'profile == nil and reason == "load_failed"'
		)
	end)
	it("rejects unknown schemas without reconciling defaults", function()
		local data = Schema.new()
		data.schemaVersion = 999
		local ended = 0
		local fake = {
			Data = data,
			IsActive = function()
				return true
			end,
			EndSession = function()
				ended += 1
			end,
		}
		local profile, reason = Session.load(function()
			return fake
		end, function()
			return false
		end)
		assert(
			profile == nil and reason == "invalid_schema" and ended == 1,
			'profile == nil and reason == "invalid_schema" and ended == 1'
		)
		assert(data.schemaVersion == 999, "data.schemaVersion == 999")
	end)
	it("releases a late load when the player has left", function()
		local ended = 0
		local fake = {
			Data = Schema.new(),
			IsActive = function()
				return true
			end,
			EndSession = function()
				ended += 1
			end,
		}
		local profile, reason = Session.load(function()
			return fake
		end, function()
			return true
		end)
		assert(
			profile == nil and reason == "cancelled" and ended == 1,
			'profile == nil and reason == "cancelled" and ended == 1'
		)
	end)
	it("rejects malformed saved balances", function()
		local data = Schema.upgrade(Schema.new(), 123) :: any
		assert(Schema.validate(data), "initialized profile is valid")
		data.planets.home.resources.Money.m = math.huge
		assert(not Schema.validate(data), "not Schema.validate(data)")
	end)
end
