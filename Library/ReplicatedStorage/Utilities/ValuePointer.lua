local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assert = require(ReplicatedStorage.Utilities.Assert)
local Class = require(ReplicatedStorage.Utilities.Class)
local Event = require(ReplicatedStorage.Utilities.Event)

local ValuePointer = Class.New("ValuePointer")
function ValuePointer.new(t, key)
	return setmetatable({
		t = t,
		key = key,
		Changed = Event.new(),
	}, ValuePointer)
end
function ValuePointer:Destroy()
	self.Changed:Destroy()
end
function ValuePointer:Get() return self.t[self.key] end
function ValuePointer:Set(v)
	local t, key = self.t, self.key
	if t[key] == v then return true end
	t[key] = v
	self.Changed:Fire(v)
end

function ValuePointer.Override(fns)
	--	Create a new type of ValuePointer
	--	fns.get modifies the value as it is being retrieved from the table
	--	fns.set modifies values that are about to be stored into the table
	local get, set
	if fns then
		Assert.Table(fns)
		get = fns.get and Assert.Function(fns.get)
		set = fns.set and Assert.Function(fns.set)
	end
	local class = setmetatable({}, ValuePointer)
	class.__index = class
	local base = class.new
	function class.new(t, key)
		return setmetatable(base(t, key), class)
	end
	if get then
		local base = class.Get
		function class:Get()
			return get(base(self))
		end
	end
	if set then
		function class:Set(v)
			local t, key = self.t, self.key
			v = set(v)
			if t[key] == v then return true end
			t[key] = v
			self.Changed:Fire(get(v))
		end
	end
	return class
end

return ValuePointer