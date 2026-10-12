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
	if not Schema.validate(profile.Data) then
		profile:EndSession()
		return nil, "invalid_schema"
	end
	return profile, nil
end
return Session
