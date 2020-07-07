local Assert = require(script.Parent.Assert)
local Table = require(script.Parent.Table)

local Class = {}

local function is(obj, className)
	Assert.String(className)
	return type(obj) == "table" and type(obj.Class) == "table" and obj.Class[className]
end

function Class.New(name, init)
	--	init: optional function sent the new instance and any constructor arguments
	local Class = {}
	Class.__index = Class
	Class.ClassName = name
	Class.Is = is -- note: not "IsA" to avoid Script Analysis warnings
	Class.Class = {[name] = true}
	if init then
		function Class.new(...)
			local self = setmetatable({}, Class)
			init(self, ...)
			return self
		end
	else
		function Class.new(...)
			return setmetatable({}, Class)
		end
	end
	return Class
end
function Class.Inherit(BaseClass, name, init)
	--	init: optional function sent the new instance and any constructor arguments
	local Class = setmetatable({}, BaseClass)
	Class.__index = Class
	Class.ClassName = name
	Class.Class = Table.Clone(BaseClass.Class)
	Class.Class[name] = true
	local base = BaseClass.new
	if init then
		function Class.new(...)
			local self = base(...)
			init(self, ...)
			return self
		end
	else
		function Class.new(...)
			return setmetatable(base(...), Class)
		end
	end
	return Class
end

return Class