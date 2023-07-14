return function(tests, t)


local Mocks = require(script.Parent.PersistenceMocks)
local TestTime = require(script.Parent.TestTime)

function tests.DataStoreBasics()
	local dss = Mocks.DataStoreService.new(Mocks.InstantTime)
	local store1 = dss:GetDataStore("store1")
	local store2 = dss:GetDataStore("store2")
	store1:SetAsync("key", "value")
	t.equals(store2:GetAsync("key"), nil, "stores do not share data")
	t.equals(store1:GetAsync("key"), "value", "stores can save data")
	local received
	store1:UpdateAsync("key", function(data)
		received = data
		return "value2"
	end)
	t.equals(received, "value", "UpdateAsync retrieves old data")
	t.equals(store1:GetAsync("key"), "value2", "UpdateAsync saves new data")
	store1:UpdateAsync("key", function(data)
		received = data
		return nil
	end)
	t.equals(store1:GetAsync("key"), "value2", "UpdateAsync knows how to cancel")
	store1:RemoveAsync("key")
	t.equals(store1:GetAsync("key"), nil, "RemoveAsync works")
end
function tests.DataStoreScopesUseSameData()
	local dss = Mocks.DataStoreService.new(Mocks.InstantTime)
	dss:GetDataStore("name", "scope1/scope2"):SetAsync("key", "value")
	t.equals(dss:GetDataStore("name", "scope1"):GetAsync("scope2/key"), "value")
end
function tests.OrderedDataStore()
	local dss = Mocks.DataStoreService.new(Mocks.InstantTime)
	local o = dss:GetOrderedDataStore("o")
	o:SetAsync("a", 1)
	o:SetAsync("b", 3)
	o:SetAsync("c", 2)
	o:SetAsync("d", -1)
	local pages = o:GetSortedAsync(true, 2)
	t.equals(pages.IsFinished, false, "multiple pages of results")
	local page = pages:GetCurrentPage()
	t.tablesEqual(page[1], {key = "d", value = -1})
	t.tablesEqual(page[2], {key = "a", value = 1})
	pages:AdvanceToNextPageAsync()
	page = pages:GetCurrentPage()
	t.tablesEqual(page[1], {key = "c", value = 2})
	t.tablesEqual(page[2], {key = "b", value = 3})
	t.equals(pages.IsFinished, true, "only 2 pages of results")

	pages = o:GetSortedAsync(true, 2, 3)
	t.equals(pages.IsFinished, true, "only 1 page of results with minValue")
	page = pages:GetCurrentPage()
	t.equals(page[1] and page[1].value, 3)

	pages = o:GetSortedAsync(true, 2, 1, 2)
	t.equals(pages.IsFinished, true, "only 1 page of results with minValue and maxValue")
	page = pages:GetCurrentPage()
	t.equals(page[1] and page[1].value, 1)
	t.equals(page[2] and page[2].value, 2)

	pages = o:GetSortedAsync(true, 2, nil, 1)
	t.equals(pages.IsFinished, true, "only 1 page of results with maxValue")
	page = pages:GetCurrentPage()
	t.equals(#page, 2, "2 results with maxValue")

	pages = o:GetSortedAsync(false, 10)
	t.equals(pages.IsFinished, true, "only 1 page of results")
	page = pages:GetCurrentPage()
	t.equals(#page, 4)
	t.tablesEqual(page[1], {key = "b", value = 3}, "descending sort order works")
end

function tests.UpdateAsyncCollision()
	local time = TestTime.new()
	local ds = Mocks.DataStoreService.new(time):GetGlobalDataStore()
	local calls = 0
	local threads = 0
	for i = 1, 3 do
		threads += 1
		task.spawn(function()
			ds:UpdateAsync("key", function(v)
				calls += 1
				return (v or 0) + i ^ 2
			end)
			threads -= 1
		end)
	end
	t.greaterThan(threads, 0, "ds:UpdateAsync yields")
	for i = 1, 18 do
		time:Advance(1)
		if i == 2 then
			t.equals(calls, 3, "UpdateAsync should call transform function for all 3 threads right away")
		end
		if threads == 0 then break end
	end
	t.equals(threads, 0, "UpdateAsync should resolve within 18 seconds")
	t.greaterThan(calls, 3, "UpdateAsync called transform function more than once for collisions")
	local value
	task.spawn(function()
		value = ds:GetAsync("key")
	end)
	time:Advance(1) -- todo this should cache and so shouldn't yield -- test for that
	t.equals(value, 14, "UpdateAsyncs worked")
end
--[[TODO Other Tests:
Versions
Metadata/Options and UserIds
UpdateAsync collision (confirm that it retries)
]]


end -- function(tests, t)