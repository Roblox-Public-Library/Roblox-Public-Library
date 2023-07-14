local EventUtilities = {}

function EventUtilities.WaitForEvent(event, filter, timeout)
	--	filter : nil/function(...argsOfEvent) -> true to complete the wait, false to keep waiting (defaults to accepting any event argument)
	--	timeout : in seconds (or nil)
	--	Returns false if timeout hits, otherwise true, ...argsOfEvent
	--	You can do `waitForEvent(event, timeout)` as well
	if type(filter) == "number" then
		timeout = filter
		filter = nil
	end
	local co = coroutine.running()
	local returned = false
	local con
	if timeout then
		task.delay(timeout, function()
			if not returned then
				returned = true
				con:Disconnect()
				task.spawn(co, false)
			end
		end)
	end
	con = event:Connect(function(...)
		if not filter or filter(...) then
			returned = true
			con:Disconnect()
			task.spawn(co, true, ...)
		end
	end)
	return coroutine.yield()
end

function EventUtilities.WaitForAnyEvent(eventFilterList, timeout)
	--	eventFilterList : List of either {event, [filter]} and/or event
	--		Supports table events that have a Connect field
	--		If a filter is not provided, any activation of that event is counted
	--	timeout : in seconds (or nil)
	--	returns the event that fired whose filter returned true, followed by any arguments the event provided
	--	returns false if the timeout was hit first
	--[[Example usage:
		local eventThatFired = WaitForAnyEvent({
			event1,
			{event2, function(arg) return arg == "desired value" end},
		}, 2)
		if not eventThatFired then
			print("In the last 2 seconds, event1 didn't fire and event2 didn't fire with argument 'desired value'")
		end
	]]
	local co = coroutine.running()
	local returned = false
	local cons = table.create(#eventFilterList)
	if timeout then
		task.delay(timeout, function()
			if not returned then
				returned = true
				for _, con in ipairs(cons) do
					con:Disconnect()
				end
				task.spawn(co, false)
			end
		end)
	end
	for i, t in ipairs(eventFilterList) do
		local event, filter
		if type(t) ~= "table" or t.Connect then
			event = t
		else
			event, filter = t[1], t[2]
		end
		cons[i] = event:Connect(function(...)
			if not filter or filter(...) then
				returned = true
				for _, con in ipairs(cons) do
					con:Disconnect()
				end
				task.spawn(co, event, ...)
			end
		end)
	end
	return coroutine.yield()
end
function EventUtilities.CombineConnections(cons)
	if #cons == 1 then return cons[1] end
	return {
		Connected = true,
		Disconnect = function(self)
			if not self.Connected then return end
			self.Connected = false
			for _, con in cons do
				con:Disconnect()
			end
		end,
	}
end

return EventUtilities