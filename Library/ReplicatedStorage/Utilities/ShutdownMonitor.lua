--[[ShutdownMonitor
Monitors when the server is shutting down
	.Value -- true if shutting down
	.Event -- fired when shutting down
	.Check() -> true if shutting down
Prevents the server from shutting down if given tasks to run through
	:RunTask(fn, ...)
	:WrapTask(fn) -> wrapped fn (will call RunTask when invoked)
	:BindToClose(fn) -> Connection

Recommended construction line:
local isShuttingDown = ShutdownMonitor.new()

Warning: ShutdownMonitor cannot be destroyed; do not create huge numbers of instances
]]
local Utilities = game:GetService("ReplicatedStorage").Utilities
local Class = require(Utilities.Class)
local Event = require(Utilities.Event)
Utilities = require(Utilities.Utilities)

local isStudio = game:GetService("RunService"):IsStudio()
local TIMEOUT = if isStudio then 3 else math.huge
local getTraceback = if isStudio then debug.traceback else function() return true end


local ShutdownMonitor = Class.New("ShutdownMonitor")
function ShutdownMonitor.new()
	local self = setmetatable({
		Value = false,
		Event = Event.new(),
		runningTasks = {},
		tasksToRun = {}, -- {[{task}] = true} -- the task is wrapped in a function so that the same function can be bound multiple times
	}, ShutdownMonitor)
	self.Check = function() return self.Value end
	game:BindToClose(function()
		local timeout = os.clock() + TIMEOUT
		self.Value = true
		self.Event:Fire()
		self.Event:Destroy()
		for arg, trace in self.tasksToRun do
			task.spawn(function()
				self.trace = trace
				self:RunTask(arg[1])
			end)
		end
		local co = coroutine.running()
		local runningTasks = self.runningTasks
		while next(runningTasks) do
			task.defer(co)
			coroutine.yield()
			if not next(runningTasks) then break end
			task.wait()
			if os.clock() >= timeout then
				print("ShutdownMonitor timeout! Forcefully closing tasks...")
				for co, trace in runningTasks do
					print(">", trace)
					coroutine.close(co)
				end
				break
			end
		end
		self.bindToCloseDone = true
	end)
	return self
end
function ShutdownMonitor:RunTask(fn, ...)
	--	Run 'fn', preventing the game from closing while 'fn' is running
	if self.bindToCloseDone then
		warn("BindToClose function already finished; RunTask ineffective!", debug.traceback("", 2):sub(1, -2))
	end
	local co = coroutine.running()
	self.runningTasks[co] = self.trace or getTraceback("", 2)
	self.trace = nil
	local function finish(success, ...)
		self.runningTasks[co] = nil
		if success then
			return ...
		else
			error("fn failed: " .. (...), 3)
		end
	end
	return finish(Utilities.xpcall(fn, ...))
end
function ShutdownMonitor:WrapTask(fn)
	return function(...)
		return self:RunTask(fn, ...)
	end
end
local Connection = Class.New("Connection")
function ShutdownMonitor:BindToClose(fn)
	--	Returns a connection that you can use to disconnect 'fn' from BindToClose
	local arg = {fn}
	self.tasksToRun[arg] = getTraceback("", 2)
	return Connection.new({
		Connected = true,
		Disconnect = function(con)
			con.Connected = false
			self.tasksToRun[arg] = nil
		end,
	})
end
return ShutdownMonitor