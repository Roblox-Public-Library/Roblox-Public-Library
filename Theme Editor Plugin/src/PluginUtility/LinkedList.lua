local Event = require(script.Parent.Event)

local LinkedList = {}
LinkedList.__index = LinkedList
function LinkedList.new()
	return setmetatable({
		Count = Instance.new("IntValue"),
		Added = Event.new(),
		Removed = Event.new(),
		valueToNode = {}, -- [value] = node
		-- header = nil,
		-- current = nil, -- for GetNext iteration
	}, LinkedList)
end
function LinkedList:Destroy()
	self.Count:Destroy()
	self.Added:Destroy()
	self.Removed:Destroy()
end
function LinkedList:Add(obj) -- Returns true if value is already in the list
	local valueToNode = self.valueToNode
	if valueToNode[obj] then return true end
	local header = self.header
	local node
	if header then
		local last = header.Prev
		node = {Value = obj, Prev = last, Next = header}
		header.Prev = node
        last.Next = node
	else
		node = {Value = obj}
		node.Prev = node
		node.Next = node
		self.header = node
	end
	valueToNode[obj] = node
	self.Count.Value += 1
	self.Added:Fire(obj)
end
function LinkedList:Contains(obj)
	return self.valueToNode[obj]
end
function LinkedList:IsEmpty()
	return not self.header
end
function LinkedList:ForEach(fn) -- Note: does not support removal during iteration
	local header = self.header
	if not header then return end
    local current = header
	repeat
		if fn(current) then return end
		current = current.Next
	until current == header
end
function LinkedList:GetNext() -- Supports removal/addition of items during iteration. Returns nil only if the list is empty.
	local current = self.current or self.header and self.header.Prev
	if current then
        current = current.Next
		self.current = current
		return current.Value
	end
end
function LinkedList:Remove(value) -- Returns true if value is not in the list
	local node = self.valueToNode[value]
	if not node then return true end
	self.valueToNode[value] = nil
    local header = self.header
	if header == node then -- first node in list
        if header.Next == header then -- only node in list
            self.header = nil
            self.current = nil
            return
        else
            self.header = header.Next
		end
	end
	if self.current == node then
		self.current = node.Prev
    end
    node.Prev.Next = node.Next
    node.Next.Prev = node.Prev
	self.Count.Value -= 1
	self.Removed:Fire(value)
end
return LinkedList