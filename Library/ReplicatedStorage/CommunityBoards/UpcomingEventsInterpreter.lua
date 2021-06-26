--[[This module returns function(events) -> Events, which has:
	.LocalTimeZoneOffset:hours from UTC
	:GetAllEvents() -> events
	:GetCurrentEvents() -> events
	:Search(text, includePast, formatTime) -> events
Each event has:
	.Name:string
	.HostedBy:string
	.Desc:string
	.When:UTC Time (number) or nil if CustomWhen exists
	.CustomWhen:string or nil if When exists
	.Duration:number measured in seconds or nil
]]
return function(events)
--events expected to have the same fields as described above, except When can optionally be a string, either:
--	"mm/dd/yyyy h:mm {am/pm or blank if 24h time} {timezone offset}"
--		ex: "12/31/2020 1:30pm -6". This is converted to UTC time automatically.
--	or any custom string (it will be transferred to CustomWhen)
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
local defaultDuration = 2 * 3600 -- default duration of events before they won't be shown (in seconds)
local Event = {}
Event.__index = Event
function Event.Wrap(event)
	event = setmetatable(event, Event)
	for _, name in ipairs({"Name", "HostedBy", "Desc", "Where"}) do
		event["lower" .. name] = event[name] and event[name]:lower() or ""
	end
	return event
end
-- GetTime & GetUTCTime note:
-- 	Arbitrary format strings convert UTC time to local time.
--	When we want UTC, we compensate by subtracting the localTimeZoneOffset from the hoursOffset.
function Event:GetTime(format, hoursOffset)
	return self.CustomWhen or os.date(format, self.When + (hoursOffset or 0) * 3600)
end
function Event:GetUTCTime(format, hoursOffset)
	return self.CustomWhen or os.date(format, self.When + ((hoursOffset or 0) - localTimeZoneOffset) * 3600)
end
function Event:IsExpired(now)
	return self.When and self.When + (self.Duration or defaultDuration) < (now or os.time())
end
function Event:ContainsText(text)
	--	Does not search the When/CustomWhen fields
	return self.lowerName:find(text, 1, true)
		or self.lowerHostedBy:find(text, 1, true)
		or self.lowerDesc:find(text, 1, true)
		or self.lowerWhere:find(text, 1, true)
end

-- Convert event.When to UTC timestamp
local ampmToOffset = {
	[""] = 0, -- for if no am/pm specified
	am = 0,
	pm = 12,
}
local newEvents = {} -- new list of events (of both past and future events)
local customWhenEvents = {} -- newEvents does not contain these at first so that the rest can be sorted by date
local lastTime = 0
local now = os.time()
local localNow = now + localTimeZoneOffset * 3600
local function eventHasWhen(event)
	if event.When >= localNow - maxPastSec and event.When + (event.Duration or defaultDuration) <= localNow + maxFutureSec then -- ignore very old or far into the future events
		if event.When < lastTime then
			for i = #newEvents, 1, -1 do
				if newEvents[i].When < event.When then
					table.insert(newEvents, i + 1, event)
					return
				end
			end
			table.insert(newEvents, 1, event)
		else
			lastTime = event.When
			table.insert(newEvents, event)
		end
	end
end
local function eventHasCustomWhen(event)
	table.insert(customWhenEvents, event)
end
for i, event in ipairs(events) do
	Event.Wrap(event)
	if type(event.When) == "string" then
		if true then error("This code interprets an old format and shouldn't be in use") end
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
			eventHasWhen(event)
		else -- not time-specific
			event.CustomWhen = event.When
			event.When = nil
			eventHasCustomWhen(event)
		end
	elseif event.When then
		eventHasWhen(event)
	else
		eventHasCustomWhen(event)
	end
end
local currentEvents
local n = #newEvents
local numCustomWhen = #customWhenEvents
for i, event in ipairs(newEvents) do
	if not event:IsExpired() then
		currentEvents = table.create(n - i + 1 + numCustomWhen)
		if numCustomWhen > 0 then
			table.move(customWhenEvents, 1, numCustomWhen, 1, currentEvents)
		end
		table.move(newEvents, i, n, numCustomWhen + 1, currentEvents)
		break
	end
end
currentEvents = currentEvents or customWhenEvents
-- 'events' now becomes "all events", but only newEvents has a sorted order - we want custom when events at the top
events = table.create(n + numCustomWhen)
table.move(customWhenEvents, 1, numCustomWhen, 1, events)
table.move(newEvents, 1, n, numCustomWhen + 1, events)

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
			table.insert(filtered, event)
		end
	end
	return filtered
end

return Events
end