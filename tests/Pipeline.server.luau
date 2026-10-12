--!strict
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local storage = game:GetService("ServerStorage")
local testEZ: any = require(storage.GrowAPlanetTests.TestEZ)
local result = testEZ.TestBootstrap:run({ storage.GrowAPlanetTests.Specs })
assert(result.failureCount == 0 and #result.errors == 0, "Unit tests failed")
print(
	string.format(
		"[GrowAPlanet:Phase1] TESTS_PASS passed=%d failed=%d",
		result.successCount,
		result.failureCount
	)
)
