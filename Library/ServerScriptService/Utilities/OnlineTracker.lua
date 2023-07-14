local Utilities = require(game:GetService("ReplicatedStorage").Utilities)
local Class = Utilities.Class
local Event = Utilities.Event

local OnlineTracker = Class.New("OnlineTracker")
function OnlineTracker.new(onlineSize, offlineThreshold, onlineThreshold)
	onlineSize = onlineSize or 3
	offlineThreshold = offlineThreshold or 0
	onlineThreshold = onlineThreshold or onlineSize - 1
	local onlineEvents = table.create(onlineSize, true)
	local onlineCount = onlineSize
	local offlineStartTime
	local disabled = false
	local self
	local function markOffline()
		offlineStartTime = os.clock()
		self.Online = false
		self.Changed:Fire(false)
	end
	local function markOnline()
		self.Online = true
		self.Changed:Fire(true, os.clock() - offlineStartTime)
	end
	local recordsSayOnline = true
	local function updateOnline()
		local new = recordsSayOnline and not disabled
		if self.Online ~= new then
			(if new then markOnline else markOffline)()
		end
	end
	self = setmetatable({
		Online = true,
		Changed = Event.new(),
		SetDisabled = function(self, value) -- While disabled, the system will appear offline regardless of Record
			disabled = if value then true else false
			updateOnline()
		end,
		Record = function(self, online)
			onlineCount = onlineCount
				- (if table.remove(onlineEvents, 1) then 1 else 0)
				+ (if online then 1 else 0)
			onlineEvents[onlineSize] = online
			if recordsSayOnline then
				if onlineCount <= offlineThreshold then
					recordsSayOnline = false
					updateOnline()
				end
			else
				if onlineCount >= onlineThreshold then
					recordsSayOnline = true
					updateOnline()
				end
			end
		end,
	}, OnlineTracker)
	return self
end
return OnlineTracker