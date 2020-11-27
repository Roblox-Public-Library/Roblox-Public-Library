local Assert = require(script.Parent.Assert)
local Algorithms = {}
local BinarySearch_compareFunc = function(v1, v2) return v1 < v2 and -1 or v1 > v2 and 1 or 0 end
function Algorithms.BinarySearch(getValue, maxIndex, targetValue, compareFunc, bias)
	--	getValue(index):value to compare with targetValue via compareFunc
	--	If you have a sorted list, use List.BinarySearch
	--	returns index of targetValue (if it exists) or else an index where targetValue could be inserted into the sorted list.
	--	Returns whether the targetValue was found in the list as a second return value
	compareFunc = compareFunc and Assert.Function(compareFunc, "compareFunc") or BinarySearch_compareFunc
	bias = bias and Assert.Number(bias, 0, 1, "bias") or 0.5
	local minIndex = 1 -- this and maxIndex are indices we haven't explored yet that could contain targetValue
	local index, value -- index we're currently looking at & relative value between target and current values
	while minIndex <= maxIndex do
		index = math.floor((maxIndex - minIndex) * bias) + minIndex
		value = compareFunc(targetValue, getValue(index))
		if value == 1 then -- targetValue > getValue(index): current index's value too small
			minIndex = index + 1
		elseif value == -1 then -- targetValue < getValue(index): current index's value too big
			maxIndex = index - 1
		else -- Note: A book suggested it is more efficient to not check for this until the end, but this is not the case in Lua, or at least when supporting 'bias' (tested with a variety of table sizes, Aug 2019)
			return index, true
		end
	end
	return minIndex, false
end
return Algorithms