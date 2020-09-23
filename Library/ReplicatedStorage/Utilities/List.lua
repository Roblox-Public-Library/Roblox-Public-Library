local Assert = require(script.Parent.Assert)
local Table = require(script.Parent.Table)
local List = {}

function List.Add(list, value) -- Maybe useful for common "collection" interface?
	list[#list + 1] = value
end
List.Clone = Table.Clone
List.DeepClone = Table.DeepClone
function List.Contains(list, value)
	for i = 1, #list do
		if list[i] == value then return true end
	end
	return false
end
function List.Count(list)
	return #list
end
function List.IndexOf(list, value) -- returns index or nil
	for i = 1, #list do
		if list[i] == value then return i end
	end
end
function List.Remove(list, item) -- returns item removed or nil
	for i = 1, #list do
		if list[i] == item then return List.remove(list, i) end
	end
	return nil
end
function List.Shuffle(list, rnd)
	local index
	local n = #list
	for i = 1, n - 1 do
		index = rnd and rnd:NextNumber(i, n) or math.random(i, n)
		list[i], list[index] = list[index], list[i]
	end
	return list
end
function List.ToSet(list)
	local set = {}
	for _, v in ipairs(list) do
		set[v] = true
	end
	return set
end
function List.ToEnglish(list)
    --  {"a", "b", "c"} -> "a, b, and c"
	local n = #list
	return n == 0 and ""
    	or n == 1 and list[1]
        or n == 2 and ("%s and %s"):format(list[1], list[2])
        or ("%s, and %s"):format(table.concat(list, ", ", 1, n - 1), list[n])
end

local BinarySearch_compareFunc = function(v1, v2) return v1 < v2 and -1 or v1 > v2 and 1 or 0 end
function List.BinarySearch(sortedList, targetValue, compareFunc, bias)
	--	returns index of targetValue (if it exists) or else an index where targetValue could be inserted into the sorted list.
	--	Returns whether the targetValue was found in the list as a second return value
	Assert.Table(sortedList, "sortedList")
	compareFunc = compareFunc and Assert.Function(compareFunc, "compareFunc") or BinarySearch_compareFunc
	bias = bias and Assert.Number(bias, 0, 1, "bias") or 0.5
	local minIndex, maxIndex = 1, #sortedList -- indices we haven't explored yet that could contain targetValue
	local index, value -- index we're currently looking at & relative value between target and current values
	while minIndex <= maxIndex do
		index = math.floor((maxIndex - minIndex) * bias) + minIndex
		value = compareFunc(targetValue, sortedList[index])
		if value == 1 then -- targetValue > sortedList[index]: current index's value too small
			minIndex = index + 1
		elseif value == -1 then -- targetValue < sortedList[index]: current index's value too big
			maxIndex = index - 1
		else -- Note: A book suggested it is more efficient to not check for this until the end, but this is not the case in Lua, or at least when supporting 'bias' (tested with a variety of table sizes, Aug 2019)
			return index, true
		end
	end
	return minIndex, false
end

return List