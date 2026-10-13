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
-- Bindable bridge uses the running Script VM's module cache, unlike isolated MCP require calls.
local debugTools = require(storage.GrowAPlanetTests.Debug)
local bridge = Instance.new("BindableFunction")
bridge.Name = "Control"
bridge.OnInvoke = function(command: string, player: Player?, seconds: number?, clicks: number?): any
	if command == "Inspect" and player then
		return debugTools.inspect(player)
	end
	if command == "Skip" and player and seconds then
		return debugTools.skip(player, seconds)
	end
	if command == "Simulate" and seconds and clicks then
		return debugTools.simulate(seconds, clicks)
	end
	if command == "Persistence" then
		return debugTools.persistence()
	end
	error("Unknown development command")
end
bridge.Parent = storage.GrowAPlanetTests
