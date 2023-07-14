local HttpService = game:GetService("HttpService")
local PersistenceMocks = {}
--[[Contains:
DataStoreService
DataStoreOptions
InstantTime -- all waits resume instantly (useful in certain tests)

Differences to Roblox:
- Data stores typically error when you pass in instances, unless they're a table key, in which case they're converted to a string of the form "<Instance> (Name)" -- in the same way, keys that are also tables are converted to `"<Table> (" .. tostring(t) .. ")"`. HttpService:JSONEncode is responsible for the key behaviour, but produces `null` for Instances that are values instead of erroring.

TODO
- Caching
- Request budgets (per DataStoreService)
- Write queues (per key in a data store)
- Add a function to DataStoreService that simulates the data stores going down (and another one to restore it)
]]
local keyCooldown = 7

local function deepClone(t)
	if type(t) ~= "table" then return t end
	local nt = {}
	for k, v in pairs(t) do
		nt[k] = deepClone(v)
	end
	return nt
end

local Storage = {}
function Storage.new()
	return {data = {}, storage = {}}
end

local KeyInfo = {}
KeyInfo.__index = KeyInfo
function KeyInfo.new(now, userIds, metadata)
	return setmetatable({
		userIds = userIds or {},
		metadata = metadata or {},
		versionToData = {}, -- Version string -> data
		CreatedTime = now * 1000,
		UpdatedTime = now * 1000,
	}, KeyInfo)
end
function KeyInfo:GetMetadata()
	return deepClone(self.metadata)
end
function KeyInfo:GetUserIds()
	return deepClone(self.userIds)
end
function KeyInfo:save(value, now)
	self.Version = tostring((tonumber(self.Version) or 0) + 1)
	self.versionToData[self.Version] = value
	self.UpdatedTime = now * 1000
end

local Options = {}
PersistenceMocks.DataStoreOptions = Options
Options.__index = Options
function Options.new(metadata)
	local self = setmetatable({
		metadata = {}
	}, Options)
	if metadata then
		self:SetMetadata(metadata)
	end
	return self
end
function Options:GetMetadata()
	return deepClone(self.metadata)
end
function Options:SetMetadata(t)
	if t == nil then
		error("Argument 1 missing or nil", 2)
	elseif type(t) ~= "table" then
		error("Unable to cast to Dictionary", 2)
	else
		for k, v in pairs(t) do
			if type(k) ~= "string" then
				error("Unable to cast to Dictionary due to key " .. tostring(k):sub(1, 100), 2)
			end -- documentation claims that the key size cannot exceed 50 characters, but experimentally (Mar 2022) this is not the case
		end
		if #HttpService:JSONEncode(t) > 299 then -- technically this fails when you try to use the options table in a request
			error("511: Metadata attribute size exceeds 300 bytes limit.", 2)
		end
		self.metadata = t
	end
end

local MockDataStore = {}
MockDataStore.__index = MockDataStore
function MockDataStore.new(dss, scope, data, keyInfos)
	local time = dss.time
	return setmetatable({
		dss = dss,
		wait = time and time.wait or task.wait,
		time = time and time.time or os.time,
		clock = time and time.clock or os.clock,
		scopePrefix = (scope or "global") .. "/",
		data = data,
		keyInfos = keyInfos,
	}, MockDataStore)
end
function MockDataStore:pause(duration)
	if not self.dss.online then
		error("502: Data stores simulated unavailable", 0) -- Note: this is not the real error message (though it does contain 502)
		-- Error level 0 avoids showing file & line number in error message
	end
	self.wait(duration or 0.1)
end
function MockDataStore:getKeyInfo(key)
	return self.keyInfos[self.scopePrefix .. key]
end
function MockDataStore:getRaw(key)
	key = self.scopePrefix .. key
	local data = self.data[key]
	if data then
		return data, self.keyInfos[key]
	end
end
function MockDataStore:get(key) -- key without scopePrefix
	key = self.scopePrefix .. key
	local data = self.data[key]
	if data then
		return HttpService:JSONDecode(data), self.keyInfos[key]
	end
end
function MockDataStore:setNoClone(key, value, userIds, options) -- key without scopePrefix
	key = self.scopePrefix .. key
	local encoded = if value ~= nil then HttpService:JSONEncode(value) else nil
	self.data[key] = encoded
	local keyInfo = self.keyInfos[key]
	if encoded then
		if not keyInfo then
			keyInfo = KeyInfo.new(self.time())
			self.keyInfos[key] = keyInfo
		end
		keyInfo:save(encoded, self.time())
		if not userIds then
			table.clear(keyInfo.userIds)
		elseif type(userIds) ~= "table" then
			error("Unable to cast to Array", 3)
		elseif #userIds > 4 then
			error("512: UserID size exceeds limit of 4", 3)
		else
			-- Make sure table is valid and then transfer ids
			for i, v in ipairs(userIds) do
				if type(v) ~= "number" then
					error("513: Attribute userId format is invalid", 3)
				end
			end
			table.clear(keyInfo.userIds)
			for i, v in ipairs(userIds) do -- rounding takes place
				keyInfo.userIds[i] = math.floor(v + 0.5)
			end
		end
		if not options then
			table.clear(keyInfo.metadata)
		else
			keyInfo.metadata = options:GetMetadata()
		end
	end
	return value, keyInfo, encoded
end
function MockDataStore:set(key, value, userIds, options) -- key without scopePrefix
	local value, keyInfo, encoded = self:setNoClone(key, value, userIds, options)
	return if encoded == nil then nil else HttpService:JSONDecode(encoded), keyInfo
end
function MockDataStore:GetAsync(key)
	self:pause()
	return self:get(key)
end
function MockDataStore:SetAsync(key, value, userIds, options)
	self:pause()
	local data, keyInfo = self:setNoClone(key, value, userIds, options)
	return keyInfo.Version
end
function MockDataStore:IncrementAsync(key, delta, userIds, options)
	self:pause()
	return self:setNoClone(key, (self:get(key) or 0) + delta, userIds, options)
end
function MockDataStore:RemoveAsync(key)
	self:pause()
	local data, info = self:get(key)
	self:set(key, nil)
	return data, info
end
function MockDataStore:UpdateAsync(key, transform)
	local i = 0
	while true do
		local initial = self.clock()
		self:pause()
		local previous, keyInfo = self:get(key)
		local prevVersion = keyInfo and keyInfo.Version
		local transformed, userIds, metadata = transform(previous, keyInfo)
		if transformed == nil then return end
		self:pause()
		if not keyInfo then
			keyInfo = self:getKeyInfo(key)
		end
		if prevVersion == (keyInfo and keyInfo.Version) then
			return self:set(key, transformed, userIds, metadata and Options.new(metadata))
		else
			local encoded = HttpService:JSONEncode(transformed)
			local newEncoded = self:getRaw(key)
			if encoded == newEncoded then -- Mimics Roblox functionality (although it might also check metadata/user ids)
				return HttpService:JSONDecode(newEncoded), self:getKeyInfos(key)
			end
		end
		self.wait(keyCooldown - (self.clock() - initial))
		i += 1
		if i >= 1000 then
			error("Infinite loop detected or extreme UpdateAsync collisions")
		end
	end
end

local Pages = {}
Pages.__index = Pages
function Pages.new(list, size, pause)
	return setmetatable({
		IsFinished = #list <= size,
		list = list,
		i = 1,
		size = size,
		pause = pause, -- how to pause when advancing to next page
	}, Pages)
end
function Pages:GetCurrentPage()
	local new = table.create(self.size)
	table.move(self.list, self.i, self.i + self.size - 1, 1, new)
	return new
end
function Pages:AdvanceToNextPageAsync()
	self.pause()
	self.i += self.size
	self.IsFinished = #self.list <= self.i + self.size - 1
end

local MockOrderedDataStore = setmetatable({}, MockDataStore)
MockOrderedDataStore.__index = MockOrderedDataStore
local base = MockOrderedDataStore.new
function MockOrderedDataStore.new(dss, scope, data, keyInfos)
	return setmetatable(base(dss, scope, data, keyInfos), MockOrderedDataStore)
end
local base = MockOrderedDataStore.set
function MockOrderedDataStore:set(key, value, userIds, options)
	if type(value) ~= "number" then
		error("103: " .. type(value) .. " is not allowed in data stores.", 3)
	elseif userIds then
		error("517: Additional parameter UserIds not allowed", 3)
	elseif options then
		error("517: Additional parameter Options not allowed", 3)
	elseif value % 1 ~= 0 or value ~= value then
		error("double is not allowed in data stores", 3)
	elseif math.abs(value) == math.huge then
		error("502: API Services rejected request with error. HTTP 400 (Bad Request)", 3)
	end
	base(key, value)
end
function MockOrderedDataStore:GetSortedAsync(ascending, pageSize, minValue, maxValue)
	local list = {}
	local skipScope = #self.scopePrefix + 1
	for k, v in pairs(self.data) do
		v = tonumber(v) -- JSONEncode just converts it to a string; tonumber can handle the various things JSONEncode may output
		if (not minValue or v >= minValue) and (not maxValue or v <= maxValue) then
			table.insert(list, {key = k:sub(skipScope), value = v})
		end
	end
	table.sort(list, if ascending then function(a, b) return a.value < b.value end else function(a, b) return a.value > b.value end)
	return Pages.new(list, pageSize, function() self:pause() end)
end

local StoreInfo = {}
StoreInfo.__index = StoreInfo
function StoreInfo.new(constructor, dss)
	return setmetatable({
		constructor = constructor,
		dss = dss,
		data = {}, -- key -> data
		versions = {}, -- key -> version
		ds = {}, -- scope -> MockDataStore
	}, StoreInfo)
end
function StoreInfo:Get(scope)
	scope = scope or "global"
	local ds = self.ds[scope]
	if not ds then
		ds = self.constructor(self.dss, scope, self.data, self.versions)
		self.ds[scope] = ds
	end
	return ds
end

local MockDataStoreService = {}
PersistenceMocks.DataStoreService = MockDataStoreService
MockDataStoreService.__index = MockDataStoreService
function MockDataStoreService.new(time) -- Always yields briefly
	local self = setmetatable({
		time = if type(time) == "table" then time else error("'time' must be a table, got: " .. tostring(time), 2),
		ds = {}, -- name -> DataStoreInfo
		ods = {}, -- name -> OrderedDataStoreInfo
		online = true,
	}, MockDataStoreService)
	self.global = MockDataStore.new(self, nil, {}, {})
	return self
end
function MockDataStoreService:GetGlobalDataStore()
	return self.global
end
function MockDataStoreService:GetDataStore(name, scope)
	local info = self.ds[name]
	if not info then
		info = StoreInfo.new(MockDataStore.new, self)
		self.ds[name] = info
	end
	return info:Get(scope)
end
function MockDataStoreService:GetOrderedDataStore(name, scope)
	local info = self.ods[name]
	if not info then
		info = StoreInfo.new(MockOrderedDataStore.new, self)
		self.ods[name] = info
	end
	return info:Get(scope)
end
function MockDataStoreService:GetOnline()
	return self.online
end
function MockDataStoreService:SetOnline(online)
	self.online = online
end
PersistenceMocks.InstantTime = {
	clock = os.clock,
	defer = task.defer,
	delay = task.spawn,
	spawn = task.spawn,
	time = os.time,
	wait = function() end,
}

return PersistenceMocks