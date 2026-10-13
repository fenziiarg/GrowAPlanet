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
		"[GrowAPlanet:Phase3] TESTS_PASS passed=%d failed=%d",
		result.successCount,
		result.failureCount
	)
)
-- Bindable bridge uses the running Script VM's module cache, unlike isolated MCP require calls.
local debugTools = require(storage.GrowAPlanetTests.Debug)
local bridge = Instance.new("BindableFunction")
bridge.Name = "Control"
bridge.OnInvoke = function(command: string, ...: any): any
	local args = table.pack(...)
	if command == "Inspect" then
		return debugTools.inspect(args[1])
	end
	if command == "Skip" then
		return debugTools.skip(args[1], args[2])
	end
	if command == "SetGrowth" then
		return debugTools.setGrowth(args[1], args[2], args[3])
	end
	if command == "SetPopulation" then
		return debugTools.setPopulation(args[1], args[2], args[3])
	end
	if command == "Grow" then
		return debugTools.grow(args[1], args[2])
	end
	if command == "Simulate" then
		return debugTools.simulate(args[1], args[2])
	end
	if command == "Persistence" then
		return debugTools.persistence()
	end
	error("Unknown development command")
end
bridge.Parent = storage.GrowAPlanetTests
