local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = require(ReplicatedStorage.Utilities)
local Event = Utilities.Event

local ServerScriptService = game:GetService("ServerScriptService")
local DataStores = require(ServerScriptService.Utilities.DataStores)
local sync = require(ServerScriptService.Utilities.SyncTimeWithGoogle)

local eventsDS = DataStores:GetDataStore("Events")

local Value = {}
Value.__index = Value
function Value.new(value)
	return setmetatable({
		Value = value,
		Changed = Event.new(),
	}, Value)
end
function Value:Set(value)
	self.Value = value
	self.Changed:Fire(value)
end

local Events = {
	MSWipe = Value.new(false),
}
local TIME_BUFFER = 11 * 60
task.spawn(function() -- MSWipe
	--[[To trigger this event
	1. Assign startTime and stopTime using https://www.unixtimestamp.com/
	2. Run:
	game:GetService("DataStoreService"):GetDataStore("Events"):SetAsync("MSWipe", {startTime or error("need startTime"), stopTime or error("need stopTime")})
	]]
	sync.WaitForSync()
	while true do
		local d
		local success, v = eventsDS:UpdateAsync("MSWipe", function(data)
			if data and data[2] + TIME_BUFFER < sync.time() then
				d = false
				return false
			end
			d = data
			return nil
		end)
		if not success then
			warn("Abandoning MSWipe check due to UpdateAsync failure:", v)
			break
		end
		if d then
			local start, stop = d[1] - TIME_BUFFER, d[2] + TIME_BUFFER
			if sync.time() < start then
				task.wait(start - sync.time())
			end
			Events.MSWipe:Set(true)
			task.wait(stop - sync.time() + 1) -- +1 to ensure that sync.time will be far enough ahead so that the MSWipe key can be cleared
			Events.MSWipe:Set(false)
		else
			task.wait(3600)
		end
	end
end)
return Events