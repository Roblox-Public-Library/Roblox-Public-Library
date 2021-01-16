--[[This module returns a list of events, each with:
	.Name:string
	.HostedBy:string
	.Desc:string
	.When:UTC Time (number) or nil if CustomWhen exists
	.CustomWhen:string or nil if When exists
	.Duration:number measured in seconds or nil
This module's list also has .LocalTimeZoneOffset (measured in hours from UTC)
]]

local events = require(workspace.CommunityBoards["Upcoming Events"])
local Events = {}

local localTimeZoneOffset do -- in hours
	local now = os.time()
	local here = os.date("*t", now)
	local utc = os.date("!*t", now)
	localTimeZoneOffset = here.hour - utc.hour + (here.min - utc.min) / 60
end
events.LocalTimeZoneOffset = localTimeZoneOffset

local maxFutureSec = 183 * 24 * 3600 -- 6 months (183 days is 365/2 rounded up). Max seconds away that future events can be and still show up
local maxPastSec = maxFutureSec -- Max seconds past events can have taken place and still show up
local secOffset = -localTimeZoneOffset * 3600 -- arbitrary format strings use local time but we're using UTC. To compensate, we subtract the difference to the timestamp in GetTime.
local defaultDuration = 2 * 3600 -- default duration of events before they won't be shown (in seconds)
local Event = {}
Event.__index = Event
function Event.Wrap(event)
	event = setmetatable(event, Event)
	for _, name in ipairs({"Name", "HostedBy", "Desc"}) do
		event["lower" .. name] = event[name]:lower()
	end
	return event
end
function Event:GetTime(format, hoursOffset)
	return self.CustomWhen or os.date(format, self.When + (hoursOffset or localTimeZoneOffset) * 3600 + secOffset)
end
function Event:IsExpired(now)
	return self.When and self.When + (self.Duration or defaultDuration) < (now or os.time())
end
function Event:ContainsText(text)
	--	Does not search the When/CustomWhen fields
	return self.lowerName:find(text, 1, true)
		or self.lowerHostedBy:find(text, 1, true)
		or self.lowerDesc:find(text, 1, true)
end

-- Convert event.When to UTC timestamp
local ampmToOffset = {
	[""] = 0, -- for if no am/pm specified
	am = 0,
	pm = 12,
}
local newEvents = {}
local lastTime = 0
local now = os.time()
local localNow = now + localTimeZoneOffset * 3600
for i, event in ipairs(events) do
	Event.Wrap(event)
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
		if event.When >= localNow - maxPastSec and event.When + (event.Duration or defaultDuration) <= localNow + maxFutureSec then -- ignore very old or far into the future events
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
end
events = newEvents
local currentEvents
local n = #events
for i, event in ipairs(events) do
	if not event:IsExpired() then
		currentEvents = table.create(n - i + 1)
		table.move(events, i, n, 1, currentEvents)
		break
	end
end

function Events:GetAllEvents()
	return events
end
function Events:GetCurrentEvents()
	return currentEvents
end
function Events:Search(text, includePast, formatTime)
	--	includePast:bool = false -- if true, include past events
	--	formatTime:optional function(event) -> time string describing when the event takes place
	text = text:lower()
	local filtered = {}
	for _, event in ipairs(includePast and events or currentEvents) do
		if event:ContainsText(text) or formatTime and formatTime(event):lower():find(text, 1, true) then
			filtered[#filtered + 1] = event
		end
	end
	return filtered
end

return Events