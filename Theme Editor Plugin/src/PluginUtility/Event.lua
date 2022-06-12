local TestService = game:GetService("TestService")
local function genErrHandler(intro)
	intro = if intro then string.format("[%s] ", intro) else ""
	return function(msg)
		TestService:Error(intro .. msg)
		TestService:Message(debug.traceback("Stack:", 2))
	end
end
local initErrHandler = genErrHandler("In Init") -- function(msg)
local deinitErrHandler = genErrHandler("In Deinit") -- function(msg)

local Event = {}
Event.__index = Event
function Event.new(init, deinit)
	--	init (optional) : function(Event) -> initValue -- called whenever a connection is made when no connections existed
	--	deinit (optional) : function(Event, initValue) is called whenever no connections are left; initValue is whatever 'init' returned
	--	Neither init nor deinit may yield
	local self = setmetatable({
		init = init,
		-- initVal
		-- head -- doubly linked list of connections of {fn, next, prev, Connected = true/false}
	}, Event)
	self.disconnectCon = function(con)
		if not con.Connected then return end
		con.Connected = false
		local nxt, prev = con.next, con.prev
		if nxt then
			nxt.prev = prev
		end
		if prev then
			prev.next = nxt
		else
			self.head = nxt
			if not self.head and deinit then
				xpcall(deinit, deinitErrHandler, self, self.initVal)
			end
		end
	end
	return self
end
function Event:Connect(fn)
	local nxt = self.head
	if not nxt and self.init then
		local _
		_, self.initVal = xpcall(self.init, initErrHandler, self)
	end
	local con = {
		fn = fn,
		Connected = true,
		Disconnect = self.disconnectCon,
	}
	self.head = con
	if nxt then
		con.next = nxt
		nxt.prev = con
	end
	return con
end
function Event:Fire(...)
	local node = self.head
	while node do
		local nxt = node.next -- get this info now in case node disconnects itself in which case we might destroy this info for connection reusing
		task.spawn(node.fn, ...)
		node = self.head and nxt -- the 'self.head' part confirms that the event hasn't been destroyed
	end
end
function Event:HasConnections()
	return self.head
end
function Event:Wait()
	local co = coroutine.running()
	local con; con = self:Connect(function(...)
		con:Disconnect()
		task.spawn(co, ...)
	end)
	return coroutine.yield()
end
function Event:Destroy()
	local t = self.head
	while t do
		t.Connected = false
		t = t.next
	end
	self.head = nil
end
Event.Clear = Event.Destroy -- function(self)

return Event.new