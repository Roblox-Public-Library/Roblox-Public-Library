return function(tests, t)


local ServerScriptService = game:GetService("ServerScriptService")
local DataStores = require(ServerScriptService.Utilities.DataStores)
local TestUtilities = game:GetService("TestService").Utilities
local Mocks = require(TestUtilities.PersistenceMocks)
local TestTime = require(TestUtilities.TestTime)

function tests.DataStoresBasics()
	local dss = Mocks.DataStoreService.new(Mocks.InstantTime)
	local time = TestTime.new()
	local DS = DataStores.new(dss, nil, time)
	local value1, value2, value3, success, keyInfo1, keyInfo2
	task.spawn(function()
		local ds = DS:GetDataStore("a")
		success, keyInfo1 = ds:SetAsync("k", 1)
		success, value1 = ds:GetAsync("k")
		success, value3 = ds:UpdateAsync("k", function(v)
			value2 = v
			return "v"
		end)
	end)
	for i = 1, 20 do time:Advance(1) end
	t.equals(success, true)
	t.equals(type(keyInfo1), "string", "version returned for SetAsync") -- would be an instance but it's a mock KeyInfo
	t.equals(value1, 1)
	t.equals(value2, 1)
	t.equals(value3, "v")
end

function tests.DataStoresOfflineTest()
	local time = TestTime.new()
	local dss = Mocks.DataStoreService.new(time)
	local DS = DataStores.new(dss, {time = time})
	local value1, value2, value3, success, done, setDone
	dss:SetOnline(false)
	task.spawn(function()
		local ds = DS:GetDataStore("a")
		ds:SetAsync("k", "v")
		setDone = true
		success, value1 = ds:GetAsync("k")
		success, value3 = ds:UpdateAsync("k", function(v)
			value2 = v
			return "v2"
		end)
		done = true
	end)
	for i = 1, 10 do time:Advance(1) end
	t.falsy(setDone, "No requests complete while DataStoreService offline")
	dss:SetOnline(true)
	for i = 1, 10 do time:Advance(1) end
	t.truthy(done, "Requests complete after online back on")
	t.truthy(success, "Requests completed successfully")
	t.equals(value1, "v")
	t.equals(value2, "v")
	t.equals(value3, "v2")
end


end -- function(tests, t)