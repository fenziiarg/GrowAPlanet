--!strict
local Schema = require(script.Parent.ProfileSchema)
local Session = {}
-- Injectable loader for deterministic failure tests. Never falls back to empty defaults.
function Session.load(load: () -> any, cancelled: () -> boolean): (any?, string?)
	local ok, profile = pcall(load)
	if not ok or profile == nil then
		return nil, "load_failed"
	end
	if cancelled() or not profile:IsActive() then
		profile:EndSession()
		return nil, "cancelled"
	end
	local upgraded = Schema.upgrade(profile.Data)
	if upgraded == nil then
		profile:EndSession()
		return nil, "invalid_schema"
	end
	if upgraded ~= profile.Data then
		-- Apply a fully validated migration only; ProfileStore keeps the same Data table.
		table.clear(profile.Data)
		for key, value in upgraded do
			profile.Data[key] = value
		end
	end
	return profile, nil
end
return Session
