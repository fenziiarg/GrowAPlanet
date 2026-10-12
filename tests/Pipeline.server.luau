--!strict
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local storage = game:GetService("ServerStorage")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("GrowAPlanet")
local config = shared:WaitForChild("config")
assert(#config:GetChildren() == 6, "Expected six central config modules")
local function assertEmpty<T>(values: { [string]: T })
	assert(next(values) == nil, "Phase 0 config must be empty")
	assert(table.isfrozen(values), "Config registry must be immutable")
end
assertEmpty(require(config.economy))
assertEmpty(require(config.planet))
assertEmpty(require(config.regions))
assertEmpty(require(config.terrain))
assertEmpty(require(config.eras))
assertEmpty(require(config.buildings))
local profileStore = storage:WaitForChild("GrowAPlanetDependencies"):WaitForChild("ProfileStore")
assert(profileStore:IsA("ModuleScript"), "ProfileStore is not server-only")
local testEZ = require(storage:WaitForChild("GrowAPlanetTests"):WaitForChild("TestEZ"))
assert(type(testEZ.TestBootstrap.run) == "function", "TestEZ bootstrap missing")
print(
	"[GrowAPlanet:Phase0] PIPELINE_PASS revision=2 configs=6 ProfileStore=server-only TestEZ=loaded"
)
