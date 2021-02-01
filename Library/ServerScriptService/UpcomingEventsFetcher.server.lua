--[[UpcomingEventsFetcher
Creates a Remote, UpcomingEvents
Client can trigger it to say that it is ready to receive info for it
Server will then send the following:
false: gave up on getting info
true: currently loading info (only sent for initial response)
number: seconds left until trying again (this is sent for every new attempt)
list of events, each with
	.Name:string
	.Desc:string (may be "")
	.HostedBy:string/nil
	.When:UTC time/nil
	.Duration:number/nil
	.CustomWhen:string/nil
]]

local RETRY_SECONDS = 15 * 60
local RETRY_RATE_LIMIT_SECONDS = 10

local HttpService = game:GetService("HttpService")
local upcomingEventsConfig = game:GetService("ServerStorage").Trello.UpcomingEvents
local eventsRequest = string.format("https://api.trello.com/1/boards/%s/cards?key=%s&token=%s&customFieldItems=true&fields=name,desc",
	upcomingEventsConfig.Board.Value,
	upcomingEventsConfig.Key.Value,
	upcomingEventsConfig.Token.Value)
local customFieldsRequest = string.format("https://api.trello.com/1/boards/%s/customFields?key=%s&token=%s",
	upcomingEventsConfig.Board.Value,
	upcomingEventsConfig.Key.Value,
	upcomingEventsConfig.Token.Value)

local remotes = game:GetService("ReplicatedStorage").Remotes
local remote = Instance.new("RemoteEvent")
remote.Name = "UpcomingEvents"
remote.Parent = remotes

local playerInit = {} --[player] = true if player is ready to receive data
local attempting = false
local nextRetry -- time when we'll be retrying next (if not currently attempting)
local customFieldIdToName -- [id string] = name; table initialized only when data successfully returned
local upcomingEvents -- list of events from Trello

local function interpretCustomFields(data)
	local t = {}
	for _, entry in ipairs(data) do
		t[entry.id] = entry.name
	end
	return t
end
local function shouldIgnoreName(name)
	name = name:lower():gsub("[%A]", "") -- remove all non-letters
	return name == "readme" or name == "instructions" or name == "example"
end
local customFieldInterpret = {
	["Hosted By"] = function(value) return value.text end,
	["Custom When"] = function(value) return value.text end,
	["Duration"] = function(value) return tonumber(value.number) end,
	["When"] = function(value)
		local year, month, day, hour, min = value.date:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+)")
		if not year then
			error("Failed to parse date '" .. value.date .. "'")
		end
		return os.time({
			year = year,
			month = month,
			day = day,
			hour = hour,
			min = min,
		})
	end,
}
local function getCustomFields(items)
	local fields = {}
	for _, item in ipairs(items) do
		local name = customFieldIdToName[item.idCustomField]
		fields[name] = (customFieldInterpret[name] or error("No custom field interpreter for " .. tostring(name)))(item.value)
	end
	return fields
end
local function interpretEvents(data)
	local events = {}
	for _, entry in ipairs(data) do
		if shouldIgnoreName(entry.name) then continue end
		local fields = getCustomFields(entry.customFieldItems)
		events[#events + 1] = {
			Name = entry.name,
			Desc = entry.desc,
			HostedBy = fields["Hosted By"],
			When = fields.When,
			Duration = fields.Duration,
			CustomWhen = fields["Custom When"],
		}
	end
	return events
end
local function tryDecode(request)
	--	returns success, data/msg, data.error if Trello error
	local success, msg = pcall(function()
		return HttpService:GetAsync(request)
	end)
	if success then
		local data
		success, data = pcall(function()
			return HttpService:JSONDecode(msg)
		end)
		if success then
			if data.error then
				if data.error == "API_TOO_MANY_CARDS_REQUESTED" then
					return false, "UpcomingEventsFetcher: Trello errored with API_TOO_MANY_CARDS_REQUESTED " .. tostring(data.message), data.error
				elseif data.error ~= "API_KEY_LIMIT_EXCEEDED" then
					return false, string.format("UpcomingEventsFetcher: Trello errored with unknown error %s %s", tostring(data.error), tostring(data.message)), data.error
				end
			else
				return true, data
			end
		else
			warn("UpcomingEventsFetcher failed to decode msg:", msg)
			return false, string.format("UpcomingEventsFetcher failed to decode msg with error: %s", data)
		end
	else
		return false, "UpcomingEventsFetcher HttpService:GetAsync failed: " .. tostring(msg)
	end
end
local function tellPlayers(...)
	for player in pairs(playerInit) do
		remote:FireClient(player, ...)
	end
end
coroutine.wrap(function()
	local attemptsLeft = 2*3600 / RETRY_SECONDS -- decreased for unknown errors only
	repeat
		attempting = true
		local tryAgainIn
		if not customFieldIdToName then
			local success, data, trelloError = tryDecode(customFieldsRequest)
			if success then
				customFieldIdToName = interpretCustomFields(data)
			else
				warn(data)
				if trelloError == "API_KEY_LIMIT_EXCEEDED" then
					tryAgainIn = RETRY_RATE_LIMIT_SECONDS
				elseif trelloError then -- unknown error
					attemptsLeft -= 1
				end
			end
		end
		if customFieldIdToName then
			local success, data, trelloError = tryDecode(eventsRequest)
			if success then
				upcomingEvents = interpretEvents(data)
			else
				warn(data)
				if trelloError then
					if trelloError == "API_KEY_LIMIT_EXCEEDED" then
						tryAgainIn = RETRY_RATE_LIMIT_SECONDS
					elseif trelloError == "API_TOO_MANY_CARDS_REQUESTED" then
						attemptsLeft = 0
					else -- unknown error
						attemptsLeft -= 1
						tryAgainIn = RETRY_SECONDS
					end
				end
			end
		end
		attempting = false
		if upcomingEvents or attemptsLeft == 0 then break end
		nextRetry = os.time() + RETRY_SECONDS
		tellPlayers(RETRY_SECONDS)
		wait(RETRY_SECONDS)
		nextRetry = nil
	until upcomingEvents
	tellPlayers(upcomingEvents or false)
end)()
remote.OnServerEvent:Connect(function(player)
	if playerInit[player] then return end
	playerInit[player] = true
	if upcomingEvents then
		remote:FireClient(player, upcomingEvents)
	elseif nextRetry then
		remote:FireClient(player, nextRetry - os.time())
	else
		remote:FireClient(player, attempting)
	end
end)
game:GetService("Players").PlayerRemoving:Connect(function(player)
	playerInit[player] = nil
end)