--[[This module returns a list of events, each with:
	.Name:string
	.HostedBy:string
	.Desc:string
	.When:UTC Time or nil if CustomWhen exists
	.CustomWhen:string or nil if When exists
	.Duration:number measured in hours or nil
This module's list also has .LocalTimeZoneOffset (measured in hours from UTC)
]]

local events = require(workspace.CommunityBoards["Upcoming Events"])

local localTimeZoneOffset do -- in hours
	local now = os.time()
	local here = os.date("*t", now)
	local utc = os.date("!*t", now)
	localTimeZoneOffset = here.hour - utc.hour + (here.min - utc.min) / 60
end
events.LocalTimeZoneOffset = localTimeZoneOffset

local secOffset = -localTimeZoneOffset * 3600 -- arbitrary format strings use local time but we're using UTC. To compensate, we subtract the difference to the timestamp in GetTime.
local Event = {}
Event.__index = Event
function Event:GetTime(format, hoursOffset)
	return self.CustomWhen or os.date(format, self.When + (hoursOffset or localTimeZoneOffset) * 3600 + secOffset)
end

-- Convert event.When to UTC timestamp
local ampmToOffset = {
	[""] = 0, -- for if no am/pm specified
	am = 0,
	pm = 12,
}
local newEvents = {}
local now = os.time()
local defaultDuration = 2 * 3600 -- default duration of events before they won't be shown (in seconds)
local lastTime = 0
for i, event in ipairs(events) do
	local month, day, year, hour, min, ampm, offset = event.When:match("(%d+)/(%d+)/(%d+)%s+(%d+):(%d+)(%w*)%s*%+?(%-?[%d%.]*)")
	if month then
		hour = tonumber(hour)
		if hour == 12 and ampm == "am" then
			hour = 0
		end
		offset = offset == "" and 0
			or tonumber(offset)
			or warn(("In event #%d '%s', offset of '%s' is not a number"):format(i, event.Name or "?", offset))
			or 0
		local ampmOffset = ampmToOffset[ampm:lower()]
			or warn(("In event #%d '%s', 'am' or 'pm' or '' expected but got '%s'"):format(i, event.Name or "?", ampm))
			or 0
		hour += ampmOffset + offset
		min = tonumber(min) + (hour % 1) * 60
		event.When = os.time({
			year = year,
			month = month,
			day = day,
			hour = hour,
			min = min,
		})
		if event.When + (event.Duration or defaultDuration) >= now then -- Only add events that aren't over
			if event.When < lastTime then
				for i = #newEvents, 1, -1 do
					if newEvents[i].When and newEvents[i].When < event.When then
						table.insert(newEvents, i + 1, event)
					end
				end
			else
				lastTime = event.When
				newEvents[#newEvents + 1] = event
			end
		end
	else -- not time-specific
		event.CustomWhen = event.When
		event.When = nil
		newEvents[#newEvents + 1] = event
	end
	setmetatable(event, Event)
end
table.sort(events, function(a, b) return a.When and b.When and a.When < b.When end)
while events[1] and events[1].When < os.time() do
	table.remove(events, 1)
end
return events