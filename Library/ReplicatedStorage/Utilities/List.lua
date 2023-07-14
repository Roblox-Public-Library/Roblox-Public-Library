local Assert = require(script.Parent.Assert)
local Table = require(script.Parent.Table)
local List = {}

List.Add = table.insert -- function(list, value)
List.Clone = Table.Clone
List.DeepClone = Table.DeepClone
List.Contains = table.find -- function(list, value) -- returns truthy value if list contains 'value'
function List.Count(list)
	return #list
end
function List.SetContains(list, value, contains)
	--	Sets whether the list contains 'value' or not
	--	If 'contains' is true, 'value' will be added, otherwise it will be removed
	--	Returns true if nothing changed
	local index = table.find(list, value)
	if (not contains) == (not index) then return true end -- nothing to change
	if contains then
		table.insert(list, value)
	else
		table.remove(list, index)
	end
end
function List.Extend(list, otherList)
	table.move(otherList, 1, #otherList, #list + 1, list)
end
List.IndexOf = table.find -- function(list, value) -- returns index or nil
function List.Remove(list, item) -- returns item removed or nil
	local i = table.find(list, item)
	return if i then table.remove(list, i) else nil
end
function List.RemoveSet(list, set) -- removes all items from 'list' that are contained in 'set'. Returns true if nothing removed.
	local found = false
	for i = #list, 1, -1 do
		if set[list[i]] then
			table.remove(list, i)
			found = true
		end
	end
	return found
end
function List.LargeRemoveSet(list, set) -- removes all items from 'list' that are contained in 'set'. Returns true if nothing removed.
	--	More efficient than List.RemoveSet for scenarios like:
	--		#list >= 50 and removing ~10% of the items or less
	--		#list >= 110 and removing even 50% of the items
	local nList = #list
	local destI = 1 -- index to move new elements into
	local prev = 0 -- previously skipped index
	for i, v in ipairs(list) do
		if set[v] then
			-- Skip moving value 'i'
			local n = i - 1 - prev
			if n > 0 then
				if prev > 0 then
					table.move(list, prev + 1, i - 1, destI)
				end -- if prev == 0 then items are already where they're supposed to be
				destI += n
			end
			prev = i
		end
	end
	if prev > 0 then
		-- move remaining elements (if any)
		local n = nList - prev
		if n > 0 then
			table.move(list, prev + 1, nList, destI)
		end
		destI += n
		-- Fill in the rest with nil elements
		local numNilNeeded = nList - destI + 1
		table.move(list, nList + 1, nList + numNilNeeded, destI)
	else -- nothing removed
		return true
	end
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
function List.FromSet(set)
	local list = {}
	for k in set do
		table.insert(list, k)
	end
	return list
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