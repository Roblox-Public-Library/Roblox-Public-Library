local Nexus = require("NexusUnitTesting")
local SaveableSet = require(game.ReplicatedStorage.SaveableSet)

local function toList(dict)
	local list = {}
	for v, _ in pairs(dict) do
		list[#list + 1] = v
	end
	return list
end
local function concatSortDict(dict)
	local list = toList(dict)
	table.sort(list)
	return table.concat(list, ",")
end

local function test(name, lastRead, cur, newRead, expected)
	Nexus:RegisterUnitTest(name, function(t)
		local ss = SaveableSet.FromList(cur)
		ss:UpdateLastData(lastRead)
		ss:MergeData(newRead)
		local output = concatSortDict(ss.Indices)
		t:AssertEquals(expected, output)
	end)
end
test("No contents",	{}, {}, {}, "")
test("Merge",
	{1,5,6}, -- last
	{1,5,6,9}, -- cur
	{1,2,5,7}, -- new
	"1,2,5,7,9")
test("No read change",
	{}, -- last
	{3}, -- cur
	{}, -- new
	"3")
test("Double remove",
	{1},
	{3},
	{2},
	"2,3")

return true