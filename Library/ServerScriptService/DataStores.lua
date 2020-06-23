local DataStores = {}

local studioPrint = false -- if true, all DataStore accesses will be printed out in studio
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

if isStudio then
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
	add("Get", function(data, key) return data[key] end)
	add("Set", function(data, key, value) data[key] = value end)
	add("Remove", function(data, key) data[key] = nil end)
	add("Update", function(data, key, func) data[key] = func(data[key]) end)
else
	local function attemptRequest(requestFunc, shouldCancel, genContext)
		local tries = 0
		while true do
			local success, data = pcall(requestFunc)
			if success then
				return data
			end
			tries = tries + 1
			local errNum = tonumber(data:find("%d%d%d"))
			local max = maxTries[errNum]
			if not errNum or not max or tries >= maxTries then
				local context = genContext and genContext()
				error(("%sDataStore failed: %s"):format(
					context and context .. " " or "",
					tostring(data)))
			end
			if shouldCancel and shouldCancel() then return nil end
			local context = genContext and genContext()
			warn(("%sDataStore error (but trying again): %s"):format(
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
	function DataStores.Get(dataStore, key, shouldCancel, context)
		return attemptRequest(
			function() return dataStore:GetAsync(key) end,
			shouldCancel,
			function() return merge(context, "Get", dataStore, key) end)
	end
	function DataStores.Set(dataStore, key, value, shouldCancel, context)
		attemptRequest(
			function() dataStore:SetAsync(key, value) end,
			shouldCancel,
			function() return merge(context, "Set", dataStore, key, value) end)
	end
	function DataStores.SetFunc(dataStore, key, getValue, shouldCancel, context)
		local value
		attemptRequest(
			function()
				value = getValue()
				dataStore:SetAsync(key, value)
			end,
			shouldCancel,
			function() return merge(context, "Set", dataStore, key, value or getValue()) end)
		return value
	end
	function DataStores.Update(dataStore, key, updateFunc, context)
		return attemptRequest(function()
			return dataStore:UpdateAsync(key, updateFunc)
		end, function() return merge(context, "Update", dataStore, key, updateFunc) end)
	end
	function DataStores.Remove(dataStore, key, context)
		return attemptRequest(function()
			return dataStore:RemoveAsync(key)
		end, function() return merge(context, "Remove", dataStore, key) end)
	end
end

function DataStores.new(dataStore)
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

return DataStores