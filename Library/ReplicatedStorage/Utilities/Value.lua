local Class = require(script.Parent.Class)
local Event = require(script.Parent.Event)
local Value = Class.New("Value")
function Value.new(value)
	return setmetatable({
		Value = value,
		Changed = Event.new(),
	}, Value)
end
function Value:Destroy()
	self.Changed:Destroy()
end
function Value:Get() return self.Value end
function Value:Set(value)
	if self.Value == value then return true end
	self.Value = value
	self.Changed:Fire(value)
end
return Value