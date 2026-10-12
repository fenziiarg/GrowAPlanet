--!strict
local Janitor = {}
function Janitor.new()
	local callbacks: { () -> () } = {}
	local cleaned = false
	return {
		add = function(cleanup: () -> ())
			if cleaned then
				cleanup()
			else
				table.insert(callbacks, cleanup)
			end
		end,
		cleanup = function()
			if cleaned then
				return
			end
			cleaned = true
			for i = #callbacks, 1, -1 do
				callbacks[i]()
			end
			table.clear(callbacks)
		end,
	}
end
return Janitor
