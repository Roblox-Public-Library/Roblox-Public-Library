local TestTime = {} --[[Controllable time that offers functions that mimic Roblox's "task" library combined with os.time(), os.clock(), and RunService.Heartbeat
*Note: does not resume threads on a different coroutine, nor does it protect from errors* (meant to make debugging errors easier)
	If it is necessary to change this, consider tracking tracebacks (also see debug.getinfo which is supposed to be faster)
]]

local Event = require(game:GetService("ReplicatedStorage").Utilities.Event)

local TIME_SLICE = 1 / 60
local function interpretTimeParam(t)
	-- Roblox's task.wait() interprets nil, 0, infinity, NaN as minimum time
	return if not t or t <= TIME_SLICE or t == math.huge or t ~= t then 1 else t
end
local function mergeActionAndArgs(action, ...)
	return if select("#", ...) == 0 then action else coroutine.wrap(function(...)
		coroutine.yield()
		action(...)
	end)(...)
end

TestTime.__index = TestTime
function TestTime.new(now)
	local scheduledActions = {}
	local startTime = os.time()
	local self = setmetatable({
		now = now or 0, -- measured in 60ths of a second
		deferredActions = {},
		deferredActions2 = {}, -- swapped with deferredActions
		scheduledActions = scheduledActions,
	}, TestTime)
	self.delay = function(t, action, ...)
		local data = {
			t = self.now + interpretTimeParam(t),
			action = mergeActionAndArgs(action, ...),
			start = self.now,
		}
		scheduledActions[data] = true
	end
	self.defer = function(action, ...)
		table.insert(self.deferredActions, mergeActionAndArgs(action, ...))
	end
	self.wait = function(t)
		local co = coroutine.running()
		local start = self.clock()
		self.delay(t, function() task.spawn(co) end)
		coroutine.yield()
		return self.clock() - start
	end
	self.spawn = function(action, ...)
		action(...)
	end
	self.clock = function()
		return self.now
	end
	self.time = function()
		return math.floor(self.now) + startTime
	end
	self.Heartbeat = Event.new()
	return self
end
function TestTime:Get() return self.now end
function TestTime:Set(now) -- expected to increase time only
	local deferredActions = self.deferredActions
	if deferredActions[1] then
		for round = 1, 11 do
			if round == 11 then
				error("[From recursive defer] Maximum re-entrancy depth (10) exceeded")
			end
			self.deferredActions, self.deferredActions2 = self.deferredActions2, deferredActions
			for _, action in ipairs(deferredActions) do
				action()
			end
			table.clear(deferredActions)
			deferredActions = self.deferredActions
			if not deferredActions[1] then break end
		end
	end
	local dt = now - self.now
	self.now = now
	local scheduledActions = self.scheduledActions
	for data in pairs(scheduledActions) do
		if data.t <= now then
			scheduledActions[data] = nil
			data.action(now - data.start)
		end
	end
	self.Heartbeat:Fire(dt)
end
function TestTime:Advance(dt)
	self:Set(self.now + dt)
end
function TestTime:Destroy()
	self.Heartbeat:Destroy()
end
return TestTime