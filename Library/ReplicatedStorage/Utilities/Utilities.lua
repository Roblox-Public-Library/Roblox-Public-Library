local TestService = game:GetService("TestService")
local Utilities = {}
function Utilities.xpcall(fn, ...) -- errors are sent to Output window
	local success, msg = xpcall(fn, function(msg)
		Utilities.outputErrorFromXPCall(msg)
		return msg
	end, ...)
	return success, msg
end
function Utilities.outputErrorFromXPCall(msg)
	TestService:Error(msg)
	local traceback = debug.traceback(nil, 3):match("^%s*(.*%S)")
	for line in traceback:gmatch("[^\n]+") do
		TestService:Message(line)
	end
end

function Utilities.coroutine_close(co)
	--	Use this instead of coroutine.close or task.cancel if 'co' might not be in a "normal" (or even "running") state
	local status = coroutine.status(co)
	if status == "suspended" then
		coroutine.close(co)
	elseif status == "normal" then
		task.defer(Utilities.coroutine_close, co)
	elseif status == "running" then
		task.defer(Utilities.coroutine_close, co)
		coroutine.yield()
	end
end
return Utilities