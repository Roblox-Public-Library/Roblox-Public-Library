local Table = require(script.Parent.Table)
local Class = {}

local function IsA(self, name)
	return self.ClassNames[name]
end
function Class.New(name, baseClass)
	local classNames = if baseClass then Table.Clone(baseClass.ClassNames) else {}
	classNames[name] = true
	local class = {ClassNames = classNames}
	class.__index = class
	class.ClassName = name -- useful in debugging and used in ClassRegister
	class.IsA = IsA
	class.Is = IsA -- circumvent Roblox's complaint about asking :IsA("CustomClass")
	if baseClass then
		setmetatable(class, baseClass)
	end
	return class
end

return Class