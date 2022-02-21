--[[DataStores wraps the DataStoreService so that functions like GetDataStore will return a custom DataStore interface.
DataStore:
	:Get()
	:GetSorted
	:Set()
	:SetFunc
	:Update
	:Increment
]]
local DataStoreService = game:GetService("DataStoreService")
local DataStores = {}
local OrderedDataStore

local isStudio = game:GetService("RunService"):IsStudio()

local maxTries = {
	-- Defaults to 1
	-- [404] = 1, -- "The OrderedDataStore associated with this request has been removed."
	-- [503] = 1, -- "The key requested was not found in the data store. Ensure the data for the key is set first, then try again."
	-- [504] = 1, -- "Data retrieved from GlobalDataStore was malformed. Data may be corrupted."
	-- [505] = 1, -- "Data retrieved from OrderedDataStore was malformed. Data may be corrupted."
	[502] = math.huge, -- Roblox trouble
}
for i = 301, 306 do maxTries[i] = math.huge end -- queue exhausted
local waitTimeBetweenAttempts = 6

if isStudio then -- Set up fake data stores for studio testing
	if not pcall(function() DataStoreService:GetGlobalDataStore() end) then
		local global = {}
		local ds = {} -- name -> scope -> ds
		local ods = {} -- name -> scope -> ds
		local function get(t, name, scope)
			scope = scope or "global"
			local a = t[name]
			if not a then
				a = {}
				t[name] = a
			end
			local b = a[scope]
			if not b then
				b = {}
				a[scope] = b
			end
			return b
		end
		DataStoreService = {
			GetGlobalDataStore = function() return global end,
			GetDataStore = function(name, scope) return get(ds, name, scope) end,
			GetOrderedDataStore = function(name, scope) return get(ods, name, scope) end,
		}
	end

	local dataStoreToData = {}
	local function add(name, func)
		DataStores[name] = function(dataStore, ...)
			local data = dataStoreToData[dataStore]
			if not data then
				data = {}
				dataStoreToData[dataStore] = data
			end
			return func(data, ...)
		end
	end
	add("Get", function(data, key) return true, data[key] end)
	-- todo GetSorted
	add("GetSorted", function(data, isAscending, pageSize, minValue, maxValue)

	end)
	add("Set", function(data, key, value) data[key] = value; return true, value end)
	add("SetFunc", function(data, key, getValue)
		local value = getValue()
		data[key] = value
		return true, value
	end)
	add("Remove", function(data, key) data[key] = nil; return true end)
	add("Update", function(data, key, func)
		local value = func(data[key])
		data[key] = value
		return true, value
	end)
	add("Increment", function(data, key, amount)
		local value = data[key] + amount
		data[key] = value
		return true, value
	end)
else
	local function attemptRequest(requestFunc, shouldCancel, genContext, keepRetrying)
		local tries = 0
		while true do
			local success, data = pcall(requestFunc)
			if success then
				return true, data
			end
			tries = tries + 1
			local errNum = tonumber(data:find("%d%d%d"))
			local max = maxTries[errNum]
			if not errNum or not max or (tries >= maxTries and not keepRetrying) then
				local context = genContext and genContext()
				return false, ("%sDataStore failed: %s"):format(
					context and context .. " " or "",
					tostring(data))
			end
			if shouldCancel and shouldCancel() then return nil, "Cancelled" end
			local context = genContext and genContext()
			warn(("%sDataStore error (but trying again): %s"):format( -- todo not needed past debugging
					context and context .. " " or "",
					tostring(data)))
			wait(waitTimeBetweenAttempts)
		end
	end
	local function merge(context, action, dataStore, key, value)
		return ("%s%s %s.%s%s"):format(
			context and ("(%s) "):format(tostring(context)) or "",
			action,
			dataStore.Name or "Global",
			tostring(key),
			value and (action == "Update" and " with " or " = ") .. tostring(value))
	end
	function DataStores.Get(dataStore, key, shouldCancel, keepRetrying, context)
		return attemptRequest(
			function() return dataStore:GetAsync(key) end,
			shouldCancel,
			function() return merge(context, "Get", dataStore, key) end,
			keepRetrying)
	end
	function DataStores.GetSorted(dataStore, isAscending, pageSize, minValue, maxValue, shouldCancel, keepRetrying, context)
		assert(dataStore:IsA("OrderedDataStore"), "GetSorted only valid for OrderedDataStores")
		return attemptRequest(
			function() return dataStore:GetSortedAsync(isAscending, pageSize, minValue, maxValue) end,
			shouldCancel,
			function() return merge(context, "Get", dataStore, "{SortedAsync}") end,
			keepRetrying)
	end
	function DataStores.Set(dataStore, key, value, shouldCancel, keepRetrying, context)
		attemptRequest(
			function() dataStore:SetAsync(key, value); return value end,
			shouldCancel,
			function() return merge(context, "Set", dataStore, key, value) end,
			keepRetrying)
	end
	function DataStores.SetFunc(dataStore, key, getValue, shouldCancel, keepRetrying, context)
		local value
		attemptRequest(
			function()
				value = getValue()
				dataStore:SetAsync(key, value)
			end,
			shouldCancel,
			function() return merge(context, "Set", dataStore, key, value or getValue()) end,
			keepRetrying)
		return value
	end
	function DataStores.Update(dataStore, key, updateFunc, keepRetrying, context)
		return attemptRequest(function()
				return dataStore:UpdateAsync(key, updateFunc)
			end,
			function() return merge(context, "Update", dataStore, key, updateFunc) end,
			keepRetrying)
	end
	function DataStores.Remove(dataStore, key, keepRetrying, context)
		return attemptRequest(function()
				return dataStore:RemoveAsync(key)
			end,
			function() return merge(context, "Remove", dataStore, key) end,
			keepRetrying)
	end
end

function DataStores.Wrap(dataStore)
	--	Returns an object that allows you to say obj:Set(key, value, shouldCancel=nil, context=nil) and so on
	return setmetatable({}, {
		__index = function(_, key)
			local v = DataStores[key]
			if v == nil then v = dataStore[key] end
			return type(v) == "function"
				and function(_, ...)
						return v(dataStore, ...)
					end
				or v
		end,
		__newindex = dataStore,
	})
end
for _, name in ipairs({"GetDataStore", "GetGlobalDataStore", "GetOrderedDataStore"}) do
	DataStores[name] = function(_, ...)
		return DataStores.Wrap(DataStoreService[name](DataStoreService, ...))
	end
end
function DataStores:GetRequestBudgetForRequestType(...)
	return DataStoreService:GetRequestBudgetForRequestType(...)
end

return DataStores