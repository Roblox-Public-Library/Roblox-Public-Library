local Nexus = require("NexusUnitTesting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SaveableSet = require(ReplicatedStorage.SaveableSet)

local function toList(set)
	local list = {}
	for v, _ in pairs(set) do
		list[#list + 1] = v
	end
	return list
end
local function concatSortSet(set)
	local list = toList(set)
	table.sort(list)
	return table.concat(list, ",")
end

local function test(name, lastRead, cur, newRead, expected)
	Nexus:RegisterUnitTest(name, function(t)
		local ss = SaveableSet.FromList(cur)
		ss:UpdateLastData(lastRead)
		ss:MergeData(newRead)
		local output = concatSortSet(ss.Indices)
		t:AssertEquals(output, expected)
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