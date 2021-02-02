--[[Returns function(entries) -> entries (modified)
Entries has .Credits added to it - the list of {.Key .Desc} in the order they should appear
	Key is how to index an entry to find it; Desc is for the player
Each entry in 'entries' is validated and modified to have:
	.Title:string
	.Date:string (ex "5 Feb 2021")
	.LayoutOrder:number
	.Image:string/nil
	.ImageSizeY:number/nil (nil only if Image is nil), limited to a maximum
	[creditsKey] = listOfDisplayName/nil
		A person's display name is calculated via GetNameFromUserIdAsync, falling back on the one provided

Supported entry input format:
	.Title:string
	.Date:string
	.Image:string
	.ImageSize:Vector2/nil - can be any size; will be scaled down
	[creditsKey] = person/listOfPeople
		where each person is {userName[, userId]}
	Also, synonyms and lower-case are handled.
]]
local imageSizeX = 200
local defaultImageSizeY = 200
local maxImageSizeY = 200
local Players = game:GetService("Players")
local handlePerson, waitForPeopleReady do
	local processing = 0
	local queued = {} -- note: treated like a stack since order doesn't matter
	local lookupDone = Instance.new("BindableEvent")
	local lookupDoneEvent = lookupDone.Event
	waitForPeopleReady = function()
		while processing > 0 or #queued > 0 do
			lookupDoneEvent:Wait()
		end
	end
	local function run(person)
		processing += 1
		coroutine.wrap(function()
			local success, value = pcall(function()
				return Players:GetNameFromUserIdAsync(person[2])
			end)
			person.display = success and value or person[1]
			processing -= 1
			lookupDone:Fire()
		end)()
	end
	lookupDoneEvent:Connect(function()
		local n = #queued
		if n > 0 then
			local person = queued[n]
			queued[n] = nil
			run(person)
		end
	end)
	local function queue(person)
		if processing < 20 then
			run(person)
		else
			queued[#queued + 1] = person
		end
	end
	handlePerson = function(person, entryTitle, entryKey)
		if person.handled then return end
		person.handled = true
		if type(person[1]) == "string" then
			if type(person[2]) == "number" then
				queue(person)
			elseif person[2] then
				warn(string.format("Contributions Issue: Person in entry '%s.%s' should have a user id second, not", entryTitle, entryKey), tostring(person[2]))
			else
				person.display = person[1]
			end
		else
			warn(string.format("Contributions Issue: Person in entry '%s.%s' should start with a string name, not", entryTitle, entryKey), tostring(person[1]))
			person.display = "{error}"
		end
	end
end

local synonyms = {
	building = "Builders",
	scripting = "Scripters",
	special = "SpecialThanks",
	desc = "Description",
}
local knownFields = {
	Title = "string",
	Date = "string",
	Description = "string",
	Image = "string",
	ImageSize = "Vector2",
	Builders = "table",
	Scripters = "table",
	UI = "table",
	GFX = "table",
	SpecialThanks = "table",
}
local credits = { -- In the order they should appear
	{Key = "Builders", Desc = "Building"},
	{Key = "GFX", Desc = "GFX"},
	{Key = "UI", Desc = "UI"},
	{Key = "Scripters", Desc = "Scripting"},
	{Key = "SpecialThanks", Desc = "Special Thanks"},
}
for k, v in pairs(knownFields) do
	synonyms[k:lower()] = k
end
local function getLayoutOrder(year, month, day, entryTitle)
	return -(((year or 2021) - 2021) * 1000000 + (month or 0) * 10000 + (day or 0) * 100) - (100 - (entryTitle and math.clamp(string.byte(entryTitle:sub(1, 1):lower()) - 96, 0, 99) or 0))
end
local monthNames = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
local function handleDate(v, entryTitle)
	--	returns display date, layout order
	local mm, day, year = v:match("(%d%d?)/(%d%d?)/(%d%d%d%d)")
	if not mm then
		mm, year = v:match("(%d%d?)/(%d%d%d%d)")
		if not mm then
			year = v:match("(%d%d%d%d)")
			if not year then
				warn(string.format("Contributions Issue: Malformed date in entry '%s'; got", entryTitle), v)
				return v, getLayoutOrder(nil, nil, nil, entryTitle)
			end
		end
	end
	local month
	if year then
		year = tonumber(year)
		if mm then
			mm = tonumber(mm)
			if day then
				day = tonumber(day)
			end
			if mm > 12 then
				if day and day <= 12 then
					mm, day = day, mm
					warn(string.format("Contributions Issue: Date has month & day reversed in entry '%s'; got", entryTitle), v)
				else
					warn(string.format("Contributions Issue: Date has invalid month in entry '%s'; got", entryTitle), v)
				end
			else
				month = monthNames[mm]
			end
		end
	end
	local date
	if year then
		if month then
			if day then
				date = string.format("%d %s %d", day, month, year)
			else
				date = string.format("%s %d", month, year)
			end
		else
			date = tostring(year)
		end
	else
		date = v
	end
	return date, getLayoutOrder(year, mm, day, entryTitle)
end
local function handleFields(entry, i)
	--	Handles synonyms, empty tables, and unknown fields
	local newEntry = {}
	if not entry.Title then
		warn("Contributions Issue: entry #" .. i .. " is missing .Title!")
		entry.Title = "#" .. i
	end
	for k, v in pairs(entry) do
		local t = typeof(v)
		if t == "table" then
			if #v == 0 then -- Don't save empty tables
				continue
			else
				if type(v[1]) ~= "table" then
					v = {v}
				end
				for i, person in ipairs(v) do
					handlePerson(person, entry.Title, k)
				end
			end
		elseif v == "" then -- Don't save empty strings
			continue
		end
		local newKey
		if knownFields[k] then
			newKey = k
		else
			local lower = k:lower()
			newKey = synonyms[lower]
			if not newKey then
				warn(string.format("Contributions Issue: Unknown field '%s' in entry '%s'", k, entry.Title or "(No title!)"))
			end
		end
		if newKey then
			if t == knownFields[newKey] then
				if newKey == "Image" and not v:find("asset", 1, true) then
					warn(string.format("Contributions Issue: Image field in entry '%s' is expected to be in asset format, got", entry.Title or "(No title!)"), v)
				elseif newKey == "Date" then
					newEntry.Date, newEntry.LayoutOrder = handleDate(v, entry.Title)
				else
					newEntry[newKey] = v
				end
			else
				warn(string.format("Contributions Issue: Field '%s' in entry '%s' is expected to be of type %s, got", k, entry.Title or "(No title!)", knownFields[newKey]), tostring(v))
			end
		end
	end
	if not entry.Date then
		warn("Contributions Issue: entry '" .. entry.Title .. "' is missing .Date!")
		entry.Date = ""
		entry.LayoutOrder = getLayoutOrder(nil, nil, nil, entry.Title)
	end
	if newEntry.ImageSize then
		if newEntry.Image then
			local size = newEntry.ImageSize
			newEntry.ImageSizeY = math.min(maxImageSizeY, size.X / imageSizeX * size.Y)
		end
		newEntry.ImageSize = nil
	elseif newEntry.Image then
		newEntry.ImageSizeY = defaultImageSizeY
	end
	return newEntry
end
local function handlePeople(entry)
	for field, t in pairs(knownFields) do
		local v = entry[field]
		if t ~= "table" or not v then continue end
		local new = {}
		for i, person in ipairs(v) do
			new[i] = person.display
		end
		entry[field] = new
	end
end
return function(entries) -- See documentation at top
	for i, entry in ipairs(entries) do
		entries[i] = handleFields(entry, i)
	end
	waitForPeopleReady()
	for i, entry in ipairs(entries) do
		handlePeople(entry)
	end
	entries.Credits = credits
	return entries
end