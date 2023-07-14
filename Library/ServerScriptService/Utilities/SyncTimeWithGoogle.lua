--[[Sync os.time() with Google
In the event of a problem, will warn, but will continue to operate as if Roblox's os.time is correct
Module contains:
	.time()
	.Synced : bool
	.WaitForSync() : module

Derived from: https://devforum.roblox.com/t/os-time-is-not-synced-across-roblox-servers/238733/9
]]

local module = {Synced = false}
local HttpService = game:GetService("HttpService")
local months = {Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6, Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12}
local offset = 0

module.time = function()
	return os.time() + offset
end
local waitingThreads = {}
local function recordSync(_offset)
	offset = _offset
	module.Synced = true
	for _, t in waitingThreads do
		task.spawn(t)
	end
	waitingThreads = nil
	module.WaitForSync = function() return module end
end

local requestData = {Url = "https://google.com"}
local function getOffset(triesLeft, finalAttempt) -- returns offset (or nil if failed or false if ran out of tries but might be able to get the time in the future)
	--	Doesn't warn if it returns false.
	triesLeft = triesLeft or 3
	for i = 1, triesLeft do
		local success, response = pcall(HttpService.RequestAsync, HttpService, requestData)
		local now = os.time()
		local date = success and response.Success and response.Headers.date
		if date then
			local day, month, year, hour, min, sec, tz = date:match("%a+, (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) (%a+)")
			if day then
				if tz == "GMT" then
					success, response = pcall(os.time, {day = day, month = months[month], year = year, hour = hour, min = min, sec = sec})
					if success then
						return response - now
					else
						warn("Google date header failed to convert to time!", date)
					end
				else
					warn("Google date header returned non GMT timezone!", date)
				end
			else
				warn("Failed to parse Google date header!", date)
			end
			return nil
		elseif i ~= triesLeft then
			task.wait(2)
		end
	end
	return false
end
local function updateTime()
	-- Try to get the same offset 2x and choose that one
	-- If that fails, use the average
	local seen = {}
	local offsetTotal = 0
	local offsetNum = 0
	local roundsLeft = 3
	local waitTime = 15
	while roundsLeft > 0 do
		local curOffset = getOffset()
		if curOffset == nil then
			break
		elseif curOffset == false then -- might be down temporarily
			warn("Failed to get time response from Google (retrying in " .. waitTime .. " sec)")
			task.wait(waitTime)
			if waitTime < 60 then
				waitTime *= 2
			end
			continue
		elseif seen[curOffset] then
			recordSync(curOffset)
			return
		else
			seen[curOffset] = true
			offsetTotal += curOffset
			offsetNum += 1
			roundsLeft -= 1
			if roundsLeft == 0 then break end
		end
	end
	recordSync(math.floor(offsetTotal / offsetNum + 0.5))
end

task.spawn(function()
	wait(1) -- Try to avoid the heavy processing when the place is loading so that, when the http call returns, we can deal with the results promptly. Use of `wait` over `task.wait` is intentional.
	updateTime()
end)
function module.WaitForSync() -- returns the module when done
	table.insert(waitingThreads, coroutine.running())
	coroutine.yield()
	return module
end

return module