--------------------------------------------------------------------------------
--               Batched Yield-Safe Event Implementation                     --
-- This is a  class which has effectively identical behavior to a       --
-- normal RBXScriptEvent, with the only difference being a couple extra      --
-- stack frames at the bottom of the stack trace when an error is thrown.     --
-- This implementation caches runner coroutines, so the ability to yield in   --
-- the event handlers comes at minimal extra cost over a naive event        --
-- implementation that either always or never spawns a thread.                --
--                                                                            --
-- API:                                                                       --
--   local Event = require(THIS MODULE)                                      --
--   local event = Event.new()                                                 --
--   local connection = event:Connect(function(arg1, arg2, ...) ... end)        --
--   event:Fire(arg1, arg2, ...)                                                --
--   connection:Disconnect()                                                  --
--   event:DisconnectAll()                                                      --
--   local arg1, arg2, ... = event:Wait()                                       --
--                                                                            --
-- Licence:                                                                   --
--   Licenced under the MIT licence.                                          --
--                                                                            --
-- Authors:                                                                   --
--   stravant - July 31st, 2021 - Created the file.                           --
--
-- Changes:
--   Using pull request: https://github.com/stravant/goodevent/pull/3
--   DisconnectAll -> Destroy
--   Use error instead of assert
--   Remove "strict" mode metatables that error on __index and __newindex
--   Private variable names '_' character removed
--   Class integration
--   Added init/deinit arguments
--   On destroy, if an event is mid-fire, the remaining handlers are cancelled
--   Renamed to Event
--
-- Performance:
--   In a simple "Connect and Fire a bunch" test, this class consistently performed 3-4x slower than my Event class
--   It sometimes performed only 1.2x slower when Fire wasn't used
--------------------------------------------------------------------------------

local Class = require(game.ReplicatedStorage.Utilities.Class)

-- The currently idle thread to run the next handler on
local freeRunnerThread = nil

-- Function which acquires the currently idle handler runner thread, runs the
-- function fn on it, and then releases the thread, returning it to being the
-- currently idle one.
-- If there was a currently idle runner thread already, that's okay, that old
-- one will just get thrown and eventually GCed.
local function acquireRunnerThreadAndCallEventHandler(fn, ...)
	local acquiredRunnerThread = freeRunnerThread
	freeRunnerThread = nil
	fn(...)
	-- The handler finished running, this runner thread is free again.
	freeRunnerThread = acquiredRunnerThread
end

-- Coroutine runner that we create coroutines of. The coroutine can be
-- repeatedly resumed with functions to run followed by the argument to run
-- them with.
local function runEventHandlerInFreeThread()
	while true do
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

local Connection = Class.New("Connection")

function Connection.new(event, fn)
	return setmetatable({
		Connected = true,
		event = event,
		fn = fn,
		next = false,
	}, Connection)
end

function Connection:Disconnect()
	if not self.Connected then error("Can't disconnect a connection twice.", 2) end
	self.Connected = false

	-- Unhook the node, but DON'T clear it. That way any fire calls that are
	-- currently sitting on this node will be able to iterate forwards off of
	-- it, but any subsequent fire calls will not hit it, and it will be GCed
	-- when no more fire calls are sitting on it.
	if self.event.handlerListHead == self then
		if self.next then
			self.event.handlerListHead = self.next
		else
			local event = self.event
			event.handlerListHead = false
			if event.deinit then
				if not freeRunnerThread then
					freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
					task.spawn(freeRunnerThread)
				end
				task.spawn(freeRunnerThread, event.deinit, event, event.initReturn)
			end
		end
	else
		local prev = self.event.handlerListHead
		while prev and prev.next ~= self do
			prev = prev.next
		end
		if prev then
			prev.next = self.next
		end
	end
end

local Event = Class.New("Event")

local function runInit(self)
	self.initArg = self:init()
end

function Event.new(init, deinit)
	--	init (optional) : function(event) -> initValue -- called whenever a connection is made when no connections existed
	--	deinit (optional) : function(event, initValue) is called whenever no connections are left; initValue is whatever 'init' returned
	return setmetatable({
		handlerListHead = false,
		init = init,
		deinit = deinit,
	}, Event)
end

function Event:Connect(fn)
	local connection = Connection.new(self, fn)
	if self.handlerListHead then
		connection.next = self.handlerListHead
		self.handlerListHead = connection
	else
		self.handlerListHead = connection
		if self.init then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
				task.spawn(freeRunnerThread)
			end
			task.spawn(freeRunnerThread, runInit, self)
		end
	end
	return connection
end

-- Disconnect all handlers. Since we use a linked list it suffices to clear the
-- reference to the head handler.
function Event:Destroy()
	self.handlerListHead = false
end
Event.Clear = Event.Destroy -- function(self)

-- Event:Fire(...) implemented by running the handler functions on the
-- coRunnerThread, and any time the resulting thread yielded without returning
-- to us, that means that it yielded to the Roblox scheduler and has been taken
-- over by Roblox scheduling, meaning we have to make a new coroutine runner.
function Event:Fire(...)
	local item = self.handlerListHead
	while item do
		if item.Connected then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
				task.spawn(freeRunnerThread)
			end
			task.spawn(freeRunnerThread, item.fn, ...)
			if not self.handlerListHead then break end -- Support :Destroy() mid-Fire
		end
		item = item.next
	end
end

-- Implement Event:Wait() in terms of a temporary connection using
-- a Event:Connect() which disconnects itself.
function Event:Wait()
	local waitingCoroutine = coroutine.running()
	local cn
	cn = self:Connect(function(...)
		cn:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)
	return coroutine.yield()
end

return Event