local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Plugin = {}

function Plugin.GenLog(script)
	local intro = script.Parent.Name .. ":"
	return function(...)
		print(intro, ...)
	end
end
function Plugin.Undoable(desc, fn)
	ChangeHistoryService:SetWaypoint("Before " .. desc)
	local success, msg = xpcall(fn, function(msg) return debug.traceback(msg, 2) end)
	ChangeHistoryService:SetWaypoint(desc)
	if not success then error(msg) end
end

return Plugin