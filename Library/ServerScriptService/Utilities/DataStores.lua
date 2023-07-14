--[[DataStores wraps the DataStoreService to support things like automatic retries.
DataStores:
	:GetDataStore(name, scope, settings) -- scope is still optional
	:GetGlobalDataStore(settings)
	:GetOrderedDataStore(name, scope, settings)
	See defaultSettings below for valid contents of the optional settings table

	.new(dataStoreServiceOverride, settings) -- settings is used as the default for all data stores returned via this instance. DataStoreService can be provided for testing.
	:BindToClose() -- specify that the game should not close until all requests have finished.
	:SucceedOrFail() -- specifies that data stores should error in the event of a failure that cannot be retried, return nil if cancelled, and otherwise return what the request returns.
		-- If this is not called, requests return `false, errorMessage` if unsuccessful/cancelled or else `true, data, keyInfo` if successful
		-- Warning: changing this changes the functionality for all data stores returned by this DataStores instance (past and future).

This module returns a DataStores instance that already points to the real DataStoreService and, if this is not Studio, has BindToClose called.

DataStores functions like GetDataStore will return a custom DataStore interface.
Wrapped data stores (and DataStoreService:ListDataStoresAsync) have all the same functions/functionality, except:
	All Async functions first return a `success` argument (unless `SucceedOrFail` is used)
	All Async functions now have automatic retry
	They also support:
	:DynamicSetAsync(key, getValue, shouldCancel) -> savedValue, version
		Note that :SetAsync still only returns `version` to mimic Roblox's interface.
	:DynamicIncrementAsync(key, getIncrement, shouldCancel) -> savedValue, keyInfo

	Note: More than one wrapper can be made per data store (they will be separate instances)

If the data stores appear to go down, the number of requests will be heavily throttled by this system until they are back online.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = require(ReplicatedStorage.Utilities)
local Event = require(ReplicatedStorage.Utilities.Event)
local Time = require(ReplicatedStorage.Utilities.Time)

local OnlineTracker = require(script.Parent.OnlineTracker)

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataStores = {
	Online = true, -- True while it appears that the Roblox data stores are not down
	OnlineChanged = Event.new(), -- (online) -- Fired when Online changes [this is initialized later]
}
DataStores.__index = DataStores

local defaultSettings = {
	WriteCooldown = 6.1, -- Seconds between successive DataStore calls for the same key
	ErrShouldRetry = function(errNum) -- note: this function is not queried if the error indicates offline
		local hundreds = math.floor(errNum / 100)
		return hundreds == 3 and math.huge -- queue exhausted
			or hundreds == 4 and 1 -- probably won't work but can retry once
			or 0 -- errNum is in 100s or 500s which means bug in user code
	end,
	ErrShouldLog = function(errNum) -- note: this function is not queried if the error indicates offline
		return true
	end,

	-- Online/Offline Config
	OnlineTestSize = 3, -- Number of results maintained
	OfflineThreshold = 0, -- When this many results indicate "online", the whole system is considered offline
	OnlineThreshold = 2, -- When this many results indicate "online", the whole system is considered online

	-- To support testing
	time = Time,
}
local function checkSettings(settings, inherit)
	if not settings then return inherit or defaultSettings end
	for k, v in pairs(settings) do
		if defaultSettings[k] == nil then
			error("Unknown setting property '" .. tostring(k) .. "'", 3)
		end
	end
	for k, v in pairs(defaultSettings) do
		if settings[k] == nil then
			local inheritValue = inherit and inherit[k]
			if inheritValue == nil then
				settings[k] = v
			else
				settings[k] = inheritValue
			end
		end
	end
	return settings
end

local function analyzeError(err, settings)
	--	returns retry:maxTimes (0+), log:bool, offline:bool
	--		offline only indicates whether the error suggests that the data stores are offline
	--		if retry is 1, log if the 2nd attempt is successful (as that means we should promote it to infinite)
	local errNum = tonumber(err:match("%d%d%d"))
	if not errNum then
		return 0, true, false
	end
	local isOffline
	if errNum >= 500 and errNum < 600 then
		-- errNum is usually 502, but 500 has occurred as well
		-- The error checks below are all for 502 (but the 'else' catches the 500 case)
		if err:find("429", 1, true) then -- Too many requests (of a particular type)
			return math.huge, true, false
		elseif err:find("403", 1, true) then -- Studio doesn't have API access
			return 0, false, true
		elseif err:find("400", 1, true) then -- "502: API Services rejected request with error. HTTP 400 (Bad Request)"
			return 0, true, false
		elseif err:find("Error code: 24", 1, true) then -- "502: API Services rejected request with error. Error code: 24 Reason: Key value is not numeric."
			return 0, true, false
		else
			return math.huge, false, true
		end
	end
	return settings.ErrShouldRetry(errNum), settings.ErrShouldLog(errNum), false
end
function DataStores.AnalyzeError(err, settings)
	--	Can also call DataStores:AnalyzeError(err)
	if type(err) == "table" then
		-- This is a DataStores:AnalyzeError(err) call; err is 'self' while 'settings' is actually 'err'
		return analyzeError(settings, err.defaultSettings)
	else
		return analyzeError(err, checkSettings(settings))
	end
end

local function create_RecordOnlineEvent(DataStores)
	local s = DataStores.defaultSettings
	local tracker = OnlineTracker.new(s.OnlineTestSize, s.OfflineThreshold, s.OnlineThreshold)
	tracker.Changed:Connect(function(value, duration)
		if value then
			warn("Roblox data stores restored", os.time(), ("(down for %.1f seconds)"):format(duration))
		else
			warn("Roblox data stores offline", os.time())
		end
		DataStores.Online = value
		DataStores.OnlineChanged:Fire(value)
	end)
	return function(online)
		tracker:Record(online)
	end
end

local ThreadTracker = {}
ThreadTracker.__index = ThreadTracker
function ThreadTracker.new(time)
	return setmetatable({
		wait = time and time.wait or task.wait,
	}, ThreadTracker)
end
function ThreadTracker:AddSelf()
	self[coroutine.running()] = true
end
function ThreadTracker:RemoveSelf()
	self[coroutine.running()] = false
end
function ThreadTracker:IsEmpty()
	while true do
		local co = next(self)
		if co then
			if coroutine.status(co) == "dead" then
				self[co] = nil
			else
				return false
			end
		else
			return true
		end
	end
end
function ThreadTracker:YieldUntilEmpty()
	while not self:IsEmpty() do
		self.wait() -- in case one of the threads dies, we don't use an event. Also, events would fire too soon if :RemoveSelf is called as anything other than a thread's last action if the thread then starts a new operation
	end
end

local function NewStore(ds, desc, settings, dataStores)
	return {
		dataStore = ds,
		dataStoreDesc = desc,
		settings = checkSettings(settings),
		dataStores = dataStores,
	}
end

local StandardStore = {}
StandardStore.__index = StandardStore
function StandardStore.new(dss, name, scope, settings, dataStores)
	local ds = dss:GetDataStore(name, scope) or error("No dataStore")
	local desc = string.format("{DS %s/%s}", name, scope or "global")
	return setmetatable(NewStore(ds, desc, settings, dataStores), StandardStore)
end
function StandardStore:attemptRequest(requestFn, shouldCancel, genContext, isUpdateAsync)
	--	requestFn: function() -> value1, value2
	--		value1 and value2 are typically `data` and `keyInfo`
	--		(For this class's usage of UpdateAsync only, requestFn should assign to fields lastTransformSuccess and lastTransformTime)
	--	Returns `false, errorMessage` or `true, value1, value2` (from requestFn). In the event of cancellation, `false[, errorMessage]` is returned.
	--	Repeats any failed requests if the error message suggests that retrying may succeed
	--	If shouldCancel is provided, it is invoked before retrying any failed requests
	local settings = self.settings
	local time = settings.time
	local dataStores = self.dataStores
	local requestThreads = dataStores.requestThreads
	requestThreads:AddSelf()
	local data, keyInfo -- note: some requests will only return keyInfo, so 'data' will end up being 'keyInfo' while keyInfo is nil
	local cancelled
	local success, errorMessage
	local errMaxRetry, logErr, errIsOffline, prevErrorMessage
	local function isUserError(msg)
		if not msg:find("%d%d%d") then
			return true
		end
		local errMaxRetry, logErr, errIsOffline = analyzeError(msg, settings)
		return errMaxRetry == 0 -- note: this happens to work at time of writing but isn't general
	end
	for retryNum = 0, math.huge do
		local initial = time.clock()
		local userError = false
		success, errorMessage = xpcall(function()
			data, keyInfo = requestFn()
		end, function(msg)
			if isUserError(msg) then
				warn(genContext() .. " experienced user error:")
				Utilities.outputErrorFromXPCall(msg)
				userError = true
			end
			return msg
		end)
		if userError then break end -- we already emit an error message for these
		if success then
			if isUpdateAsync and not self.lastTransformSuccess then -- definitely a user error
				errorMessage = genContext() .. "'s transform function errored"
				warn(errorMessage)
				success = false
			elseif prevErrorMessage and errMaxRetry == 1 then
				warn(genContext() .. " experienced error '" .. prevErrorMessage .. "' and succeeded on 2nd try! Promote to infinite tries in the future.") -- todo log somewhere since this is extremely unlikely so no one's going to see it if it's just in Output
			end
			self.dataStores.RecordOnlineEvent(true)
			break
		else
			if prevErrorMessage ~= errorMessage then
				errMaxRetry, logErr, errIsOffline = analyzeError(errorMessage, settings)
				prevErrorMessage = errorMessage
				if logErr then
					warn(genContext() .. ": " .. errorMessage)
				end
			end
			if errIsOffline then
				self.dataStores.RecordOnlineEvent(false)
			end
			if retryNum >= errMaxRetry then break end
			local timeValue = isUpdateAsync and self.lastTransformTime or initial -- note: self.lastTransformTime can be nil (hence the `and or`)
			time.wait(settings.WriteCooldown - (time.clock() - timeValue))
			if shouldCancel and shouldCancel() then
				cancelled = true
				break
			end
		end
	end
	requestThreads:RemoveSelf()
	if dataStores.succeedOrFail then
		if cancelled then
			return nil
		elseif success then
			return data, keyInfo
		else
			error(errorMessage, 3)
		end
	else
		if success and not cancelled then
			return success, data, keyInfo
		else
			return false, errorMessage -- note: errorMessage is likely nil if cancelled (since 'success' is likely true)
		end
	end
end
local actionToVerb = {
	UpdateAsync = " with ",
	SetAsync = " = ",
	DynamicSetAsync = " = ",
	IncrementAsync = " += ",
	DynamicIncrementAsync = " += ",
}
local function ts(v)
	v = tostring(v)
	return if #v > 100 then v:sub(1, 97) .. "..." else v
end
function StandardStore:context(action, key, value)
	return ("%s.%s %s%s%s"):format(
		self.dataStoreDesc,
		action,
		tostring(key),
		actionToVerb[action] or (if value == nil then "" else ", "),
		if actionToVerb[action] then ts(value) else "")
end
function StandardStore:contextArgs(action, ...)
	local s = {self.dataStoreDesc, ".", action, "(", ts(select(1, ...))}
	for i = 2, select("#", ...) do
		local v = select(i, ...)
		table.insert(s, ",")
		table.insert(s, ts(v))
	end
	return table.concat(s)
end
function StandardStore:GetAsync(key, shouldCancel)
	return self:attemptRequest(
		function() return self.dataStore:GetAsync(key) end,
		shouldCancel,
		function() return self:context("GetAsync", key) end)
end
local function shouldCancelOrUserIds(userIds, options, shouldCancel)
	if type(userIds) == "function" then
		return nil, nil, userIds
	else
		return userIds, options, shouldCancel
	end
end
function StandardStore:SetAsync(key, value, userIds, options, shouldCancel) -- or :SetAsync(key, value, shouldCancel)
	if type(userIds) == "function" then
		userIds, options, shouldCancel = nil, nil, userIds
	end
	return self:attemptRequest(
		function() return self.dataStore:SetAsync(key, value, userIds, options) end,
		shouldCancel,
		function() return self:context("SetAsync", key, value) end)
end
function StandardStore:DynamicSetAsync(key, getValue, userIds, options, shouldCancel)
	if type(userIds) == "function" then
		userIds, options, shouldCancel = nil, nil, userIds
	end
	local value
	return self:attemptRequest(
		function()
			value = getValue()
			return value, self.dataStore:SetAsync(key, value, userIds, options)
		end,
		shouldCancel,
		function() return self:context("DynamicSetAsync", key, value) end)
end
function StandardStore:IncrementAsync(key, delta, userIds, options, shouldCancel)
	if type(userIds) == "function" then
		userIds, options, shouldCancel = nil, nil, userIds
	end
	return self:attemptRequest(
		function() return self.dataStore:IncrementAsync(delta, userIds, options) end,
		shouldCancel,
		function() return self:context("IncrementAsync", key, delta) end)
end
function StandardStore:DynamicIncrementAsync(key, getDelta, userIds, options, shouldCancel)
	if type(userIds) == "function" then
		userIds, options, shouldCancel = nil, nil, userIds
	end
	local delta
	return self:attemptRequest(
		function()
			delta = getDelta()
			return self.dataStore:IncrementAsync(delta, userIds, options)
		end,
		shouldCancel,
		function() return self:context("IncrementAsync", key, delta) end)
end
function StandardStore:UpdateAsync(key, transform, shouldCancel)
	--	Important: transform : function(data, keyInfo) -> `newData, userIds, metadata` or `nil` to cancel. You may also return `newData, true` to maintain metadata and userIds as they are
	--	If the transform function returns nil, this function call will return failure
	local transformedData
	local function ourTransform(data, keyInfo)
		self.dataStores.RecordOnlineEvent(true)
		if shouldCancel and shouldCancel() then
			return nil
		end
		local success, userIds, metadata
		success, transformedData, userIds, metadata = Utilities.xpcall(transform, data, keyInfo)
		self.lastTransformSuccess = success
		if not success or transformedData == nil then
			return nil
		end
		self.lastTransformTime = self.settings.time.clock()
		if userIds == true then
			return transformedData, keyInfo:GetUserIds(), keyInfo:GetMetadata()
		else
			return transformedData, userIds, metadata
		end
	end
	return self:attemptRequest(
		function() return self.dataStore:UpdateAsync(key, ourTransform) end,
		shouldCancel,
		function() return self:context("UpdateAsync", key, transformedData) end,
		true) -- is UpdateAsync
end
function StandardStore:RemoveAsync(key, shouldCancel)
	return self:attemptRequest(
		function() return self.dataStore:RemoveAsync(key) end,
		shouldCancel,
		function() return self:context("RemoveAsync", key) end)
end
function StandardStore:GetVersionAsync(key, version, shouldCancel)
	return self:attemptRequest(
		function() return self.dataStore:GetVersionAsync(key, version) end,
		shouldCancel,
		function() return self:contextArgs("GetVersionAsync", key, version) end)
end
function StandardStore:ListKeysAsync(prefix, pageSize, shouldCancel)
	return self:attemptRequest(
		function() return self.dataStore:ListKeysAsync(prefix, pageSize) end,
		shouldCancel,
		function() return self:contextArgs("ListKeysAsync", prefix, pageSize) end)
end
function StandardStore:ListVersionsAsync(key, sortDirection, minDate, maxDate, pageSize, shouldCancel)
	return self:attemptRequest(
		function() return self.dataStore:ListVersionsAsync(key, sortDirection, minDate, maxDate, pageSize) end,
		shouldCancel,
		function() return self:contextArgs("ListVersionsAsync", key, sortDirection, minDate, maxDate, pageSize) end)
end
function StandardStore:RemoveVersionAsync(key, version, shouldCancel)
	return self:attemptRequest(
		function() return self.dataStore:RemoveVersionAsync(key, version) end,
		shouldCancel,
		function() return self:contextArgs("RemoveVersionAsync", key, version) end)
end

local OrderedStore = setmetatable({}, StandardStore)
OrderedStore.__index = OrderedStore
function OrderedStore.new(dss, name, scope, settings, dataStores)
	local ds = dss:GetOrderedDataStore(name, scope) or error("No dataStore")
	local desc = string.format("{ODS %s/%s}", name, scope or "global")
	return setmetatable(NewStore(ds, desc, settings, dataStores), OrderedStore)
end
function OrderedStore:GetSortedAsync(ascending, pageSize, minValue, maxValue, shouldCancel)
	return self:attemptRequest(
		function() return self.dataStore:GetSortedAsync(ascending, pageSize or 100, minValue, maxValue) end,
		shouldCancel,
		function() return self:contextArgs("GetSortedAsync", ascending, pageSize, minValue, maxValue) end)
end


function DataStores:GetDataStore(name, scope, settings)
	return StandardStore.new(self.dss, name, scope, checkSettings(settings, self.defaultSettings), self)
end
function DataStores:GetGlobalDataStore(settings)
	if not self.globalDataStore then
		self.globalDataStore = setmetatable({
			dss = self.dss,
			dataStoreDesc = "{Global DS}",
			dataStore = self.dss:GetGlobalDataStore(),
			settings = checkSettings(settings, self.defaultSettings),
			dataStores = self,
		}, StandardStore)
	end
	return self.globalDataStore
end
function DataStores:GetOrderedDataStore(name, scope, settings)
	return OrderedStore.new(self.dss, name, scope, checkSettings(settings, self.defaultSettings), self.requestThreads)
end
function DataStores:GetRequestBudgetForRequestType(...)
	return self.dss:GetRequestBudgetForRequestType(...)
end
function DataStores:ListDataStoresAsync(prefix, pageSize, shouldCancel)
	return self:attemptRequest(
		function() return self.dss:ListDataStoresAsync(prefix, pageSize) end,
		shouldCancel,
		function() return "DataStoreService:ListDataStoresAsync(" .. ts(prefix) .. ", " .. ts(pageSize) .. ")" end,
		self.defaultSettings or defaultSettings
		)
end
function DataStores.new(dataStoreServiceOverride, defaultDataStoreSettings)
	local self = setmetatable({
		dss = dataStoreServiceOverride or DataStoreService,
		Online = true,
		OnlineChanged = Event.new(),
		defaultSettings = checkSettings(defaultDataStoreSettings),
	}, DataStores)
	self.requestThreads = ThreadTracker.new(self.defaultSettings.time)
	self.RecordOnlineEvent = create_RecordOnlineEvent(self)
	return self
end
function DataStores:BindToClose()
	if self.boundToClose then return end
	self.boundToClose = true
	game:BindToClose(function()
		-- Wait for other requests that may be triggered in response to the game closing
		local co = coroutine.running()
		task.defer(co)
		coroutine.yield(co)
		self.requestThreads:YieldUntilEmpty()
	end)
	return self
end
function DataStores:SucceedOrFail()
	self.succeedOrFail = true
	return self
end

local dataStores = DataStores.new()
if RunService:IsStudio() then
	local success, msg = pcall(function()
		local ds = DataStoreService:GetDataStore("onlineCheck") -- can result in error "You must publish this place to the web to access DataStore."
		-- The following would also catch errors when you're in a template place, but at the cost of not returning this module immediately
		-- ds:GetAsync("test") -- can result in error "502: API Services rejected request with error. HTTP 403 (Forbidden)"
	end)
	if not success and ((msg:find("publish") and msg:find("access")) or msg:find("Forbidden")) then
		local TestUtilities = game:GetService("TestService").Utilities
		local PersistenceMocks = require(TestUtilities.PersistenceMocks)
		local Time = require(ReplicatedStorage.Utilities.Time)
		warn("Test data stores will be used because of error:", msg)
		dataStores = DataStores.new(PersistenceMocks.DataStoreService.new(Time))
	end
else
	dataStores:BindToClose()
end
return dataStores