local Event = require(script.Parent.Event)
local EventedSet = {}
EventedSet.__index = EventedSet
function EventedSet.new()
	return setmetatable({
		Count = Instance.new("IntValue"),
		Added = Event.new(),
		Removed = Event.new(),
		set = {},
	}, EventedSet)
end
function EventedSet:Destroy()
	self.Count:Destroy()
	self.Added:Destroy()
	self.Removed:Destroy()
end
function EventedSet:Add(obj)
	if self.set[obj] then return true end
	self.set[obj] = true
	self.Count.Value += 1
	self.Added:Fire(obj)
end
function EventedSet:Contains(obj)
	return self.set[obj]
end
function EventedSet:IsEmpty()
	return self.Count.Value == 0
end
function EventedSet:ForEach(fn)
	for v in pairs(self.set) do
		if fn(v) then return end
	end
end
function EventedSet:Remove(obj)
	if not self.set[obj] then return true end
	self.set[obj] = nil
	self.Count.Value -= 1
	self.Removed:Fire(obj)
end
return EventedSet