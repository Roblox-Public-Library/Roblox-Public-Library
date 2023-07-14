local MemoryStores = {}
--[[MemoryStore Limits (Feb 2023):
Key length: 128
Value length: 32*1024
	To get effective length of a string or table, use #JSONEncode(value)
	(For strings this is equal to #s + 2)
	Also applies to queues
]]
local userErrors = {
	"Argument %d missing or nil",
	"Unable to cast %w+ to",
	"Code: 1", -- "Code: 1, Error: There is a problem with the request." (occurs when there is something wrong with the SortedMap name and the key)
	"Code: 2", -- Code 2 is often raised when an invalid argument is sent
		-- "Code: 2, Error: The field universeId must be between 1 and 9.223372036854776E+18."
		-- "Code: 2, Error: The name field is required." (also occurs if you provide a name that has only whitespace)
		-- "Code: 2, Error: The provided sorted map name is not valid." (if it's > 128 characters long)
		-- "Code: 2, Error: The key field is required." (if you provide " " as the key, this also happens)
		-- "Code: 2, Error: The provided key is not valid." (if you provide a key whose length is > 128 or if it contains invalid characters, such as \0 - \31)
		-- "Code: 2, Error: The field expires must be between 0 and 3888000000." (that time is measured in ms; the true maximum for the expiry is 3888000)
		--		This particular error message is sent when you pass in a negative expiration time
		-- "Code: 2, Error: The field count must be between 1 and 200." (It does support 200 even though it didn't when the service just came out)
		-- "Code: 2, Error: The provided lower bound is not valid" (or "upper bound") (occurs with a bound of "\0", "\1", etc)
	"expiration.-must be between", -- "The field 'expiration' time must be between 0 and 2,592,000" (this is an outdated message; the true maximum is 3888000, which is 45 days). Note that this error does not come with "Code: 2"
	"Failed to invoke transformation function", -- occurs if transformation function in UpdateAsync errors
	"Code: 4", -- "Code: 4, Error: The provided value is too long." (such as if you provide a string whose length is > 1024 * 32 - 2)
}
local repeatableErrors = {
	"Code: 6", -- "Code: 6, The rate of requests exceeds the allowed limit."
	"Request Failed", -- occurs if you run out of requests. Possibly it used to (or still does) occur for certain invalid argument names?
	"Code: 5", --"Code: 5, Error: Memory usage of %d bytes would exceed the quota of %d bytes"
	"Failed to read response.",
	"Code: 18", --"Code: 18, Error: There was an internal server error."
}
-- Other errors that used to exist:
--	"Code: 0, Error: An unexpected error has occurred." (occurred in the past for putting in a too-high expiry)
local memoryStoreDownError = "Request Failed." -- todo detect when this is happening and add event/status for it
local defaultSecBetweenAttempts = 5
local triesPer10Min = 10 * 60 / (defaultSecBetweenAttempts + 0.5)
local function maxTriesForError(msg)
	if msg == memoryStoreDownError then
		-- todo add event that MSS may be down
		return triesPer10Min * 6
	end
	for _, pattern in ipairs(userErrors) do
		if msg:match(pattern) then return 0 end
	end
	for _, pattern in ipairs(repeatableErrors) do
		if msg:match(pattern) then return triesPer10Min * 6 end
	end
	warn("Unknown Memory Store error: ", debug.traceback(msg, 2):sub(1, -2)) -- debug.traceback ends in a newline
	return triesPer10Min
end

local function retry(fn, shouldCancel, secBetweenAttempts)
	--	Retries 'fn' until shouldCancel : function(numAttempted[, errMsg]) returns a truthy value
	--		numAttempted will be 1 after the first failure (if any)
	--		errMsg not always provided (shouldCancel can be called multiple times for the same numAttempted and errMsg is only provided the first time)
	--	Supports 'fn' returning up to 2 return values
	--	If 'shouldCancel' is not provided, the request will be attempted indefinitely, depending on what error message results
	local attempt = 1
	while true do
		local success, msg, v2 = pcall(fn)
		if success then
			return success, msg, v2
		else -- TODO debugging only
			warn("MS retrying due to err", msg)
		end
		-- TODO intentionally trigger some errors from incorrect usage and detect them here
		if shouldCancel and shouldCancel(attempt, msg) then
			return false, msg
		else
			local maxAttempts = maxTriesForError(msg)
			if attempt > maxAttempts then
				warn("Memory Store error (hit retry limit): ", debug.traceback(msg, 2):sub(1, -2)) -- debug.traceback ends in a newline
			end
		end
		task.wait(secBetweenAttempts or defaultSecBetweenAttempts)
		if shouldCancel and shouldCancel(attempt) then
			return false, msg
		end
		attempt += 1
	end
end
return {
	Retry = retry,
}