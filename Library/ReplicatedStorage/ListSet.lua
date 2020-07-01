local ListSet = {}
ListSet.__index = ListSet
function ListSet.new()
	--	A set that maintains a list for fast iteration
	--	Note that the order of the list is considered irrelevant.
	--		If the order matters, use an OrderedListSet instead.
	-- Efficiency tip: this is more efficient than a plain dictionary if you add/remove at most 1 element for every 13 elements you iterate over.
	--	Example: if you hold 100 elements and every time you iterate over them you add/remove at most 13 of them, then ListSet is more efficient.
	return setmetatable({
		-- Note: You are encouraged to read and use iterators on these variables, but do not modify them directly
		List = {}, -- List of values
		Indices = {}, -- Dictionary<value, index in List>
	}, ListSet)
end
function ListSet.FromList(list)
	local indices = {}
	for i, v in ipairs(list) do
		indices[v] = i
	end
	return setmetatable({
		List = list,
		Indices = indices,
	}, ListSet)
end
function ListSet:Add(value)
	if self.Indices[value] then return false end
	local i = #self.List + 1
	self.List[i] = value
	self.Indices[value] = i
	return true
end
function ListSet:Contains(value)
	return self.Indices[value]
end
function ListSet:Remove(value) -- returns value removed or nil
	local list = self.List
	local indices = self.Indices
	local index = indices[value]
	if not index then return nil end
	-- Replace value with last value in list so we don't have to shift everything down
	local lastValue = list[#list]
	list[index] = lastValue
	indices[lastValue] = index
	indices[value] = nil
	list[#list] = nil
	return value
end
-- Note: Roblox optimizes iteration only if ipairs/pairs is used right in the for loop
function ListSet:ForEach(func)
	for _, value in ipairs(self.List) do
		if func(value) then break end
	end
end
function ListSet:Count()
	return #self.List
end

return ListSet