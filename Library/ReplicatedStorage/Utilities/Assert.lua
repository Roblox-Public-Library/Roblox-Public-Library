local DoNothing = require(script.Parent.Functions).DoNothing
local Assert = {}
--[[Example usage:
Assert.IsA(player, "Player") -- will error if 'player' isn't an Instance of class Player; otherwise it returns the value passed into it
local Validate = Assert.Validate -- Validate has the same functions as Assert but when not debugging simply returns false if there's a problem (also printing out the problem if not in an online server)
if Validate.List(myVar) then return end

Use:
	Validate to validate client input
	Assert to verify that a non-Remote function has been called correctly.
	Check to query whether something is true (it will return nil when Assert would error)
]]
local RunService = game:GetService("RunService")
local published = not RunService:IsStudio()

local function returnFalse() return false end
local errorIgnoresMsg = {
	[DoNothing] = true,
	[returnFalse] = true,
}

local function StringDictKeysToList(dict)
	local list = {}
	local n = 0
	for k, v in pairs(dict) do
		if type(k) == "string" then
			n = n + 1
			list[n] = k
		end
	end
	return list
end

local function limitString(s, n)
	return #s > n
		and s:sub(1, n - 3) .. "..."
		or s
end
local function describePlainTable(t)
	local s = {}
	local n = 1
	for k, v in pairs(t) do
		if type(k) == "string" then
			s[n] = (type(v) == "function" and ":" or ".") .. tostring(k)
			n = n + 1
		end
	end
	if n == 1 and #t > 0 then -- no string keys but has numeric ones in a list format
		for i, v in ipairs(t) do
			s[i] = tostring(v)
		end
		return ("list with {%s}"):format(limitString(table.concat(s, ","), 120))
	end
	return ("table with {%s}"):format(limitString(table.concat(s, " "), 120))
end
local function describeTable(t)
	return t.ClassName
		or (type(t.Class) == "table" and string.format("(%s)", table.concat(StringDictKeysToList(t.Class), ",")))
		or describePlainTable(t)
end

local function objToClassString(var)
	return type(var) == "userdata" and (typeof(var) == "Instance"
			and var.ClassName
			or typeof(var))
		or type(var) == "table" and describeTable(var)
		or type(var) == "string" and ('"%s"'):format(var)
		or tostring(var)
end
Assert.ObjToClassString = objToClassString

local fakeIsA
if not published then -- FakeIsA section (for testing only)
	fakeIsA = {} -- used by IsA
	function Assert.AddFakeIsA(self, func)
		self.IsA = func
		self[fakeIsA] = true
		return self
	end
end

function NewAsserts(self, error, format, objToClassString)
	function self.Is(var, class, desc)
		if type(var) ~= "table" or not var.Is or not var:Is(class) then
			return error(format("%s must be of class '%s', got: %s", desc or "argument", class, objToClassString(var)), 3)
		end
		return var
	end
	if published then
		function self.IsA(var, class, desc)
			if typeof(var) ~= "Instance" or not var:IsA(class) then
				return error(format("%s must be of Instance class '%s', got: %s", desc or "argument", class, objToClassString(var)), 3)
			end
			return var
		end
	else -- support for FakeIsA
		function self.IsA(var, class, desc)
			if (typeof(var) ~= "Instance" and (type(var) ~= "table" or not var[fakeIsA])) or not var:IsA(class) then
				return error(format("%s must be of Instance class '%s', got: %s", desc or "argument", class, objToClassString(var)), 3)
			end
			return var
		end
	end
	self.Instance = self.IsA -- todo deprecate in favour of IsA
	function self.Typeof(var, theType, desc)
		if typeof(var) ~= theType then
			return error(format("%s must be of '%s', got: %s", desc or "argument", theType, objToClassString(var)), 3)
		end
		return var
	end
	function self.Bool(var, desc)
		if var ~= false and var ~= true then
			return error(format("%s must be a boolean, got: %s", desc or "argument", objToClassString(var)), 3)
		end
		return var
	end
	self.Boolean = self.Bool
	function self.Number(var, min, max, desc)
		if type(min) == "string" then
			desc = min; min = nil
		elseif type(max) == "string" then
			desc = max; max = nil
		end
		if type(var) ~= "number" or (min and var < min) or (max and var > max) then
			local minMaxDesc = min and max and format(" between %s and %s", tostring(min), tostring(max))
				or min and format(" greater than %s", tostring(min))
				or max and format(" less than %s", tostring(max))
				or ""
			return error(format("%s must be a number%s, got: %s", desc or "argument", minMaxDesc, objToClassString(var)), 3)
		end
		return var
	end
	function self.String(var, minLength, maxLength, desc)
		if type(minLength) == "string" then
			desc = minLength; minLength = nil
		elseif type(maxLength) == "string" then
			desc = maxLength; maxLength = nil
		end
		if type(var) ~= "string" or (minLength and #var < minLength) or (maxLength and #var > maxLength) then
			local minMaxDesc = minLength and maxLength and format(" between %s and %s", tostring(minLength), tostring(maxLength))
				or minLength and format(" greater than %s", tostring(minLength))
				or maxLength and format(" less than %s", tostring(maxLength))
				or ""
			if minMaxDesc ~= "" then minMaxDesc = " with length" .. minMaxDesc end
			return error(format("%s must be a string%s, got: %s", desc or "argument", minMaxDesc, objToClassString(var)), 3)
		end
		return var
	end
	function self.List(var, desc)
		if type(var) ~= "table" then
			return error(format("%s must be a list, got: %s", desc or "argument", objToClassString(var)), 3)
		end
		return var
	end
	function self.Dict(var, desc)
		if type(var) ~= "table" then
			return error(format("%s must be a dictionary, got: %s", desc or "argument", objToClassString(var)), 3)
		end
		return var
	end
	function self.Table(var, desc)
		if type(var) ~= "table" then
			return error(format("%s must be a table, got: %s", desc or "argument", objToClassString(var)), 3)
		end
		return var
	end
	function self.Function(var, desc)
		if type(var) ~= "function" and not (type(var) == "table" and getmetatable(var) and getmetatable(var).__call) then
			return error(format("%s must be a function, got: %s", desc or "argument", objToClassString(var)), 3)
		end
		return var
	end
	function self.Event(var, desc)
		--	Asserts that 'var' is a Roblox event or else is a table with the expected functions
		if typeof(var) ~= "RBXScriptSignal" and (type(var) ~= "table" or (not var.Connect or not var.Fire or not var.Wait or not var.Destroy)) then
			return error(format("%s must be an event, got: %s", desc or "argument", objToClassString(var)), 3)
		end
		return var
	end
	function self.Integer(var, min, max, desc)
		if type(min) == "string" then desc = min; min = nil end
		if type(max) == "string" then desc = max; max = nil end
		if type(var) ~= "number" or var % 1 ~= 0 or (min and var < min) or (max and var > max) then
			local minMaxDesc = min and max and format(" between %d and %d", min, max)
				or min and format(" greater than %d", min)
				or max and format(" less than %d", max)
				or ""
			return error(format("%s must be an integer%s, got: %s", desc or "argument", minMaxDesc, objToClassString(var)), 3)
		end
		return var
	end
	function self.NewCondition(mustBeDesc, func, desc) -- Create a reusable custom condition for self.Conditions
		assert(type(func) == "function")
		assert(type(mustBeDesc) == "string")
		return function(var) -- returns problem as a string or nil if no problem
			if not func(var) then
				return string.format("%s must be %s, got: %s", desc or "argument", mustBeDesc, objToClassString(var))
			end
		end
	end -- todo not 'self' dependent
	--ex
	--local AtLeast0 = self.NewCondition("at least 0", function(v) return v >= 0 end)
	function self.Conditions(var, ...) -- Ensures that 'var' satisfies all specified conditions
		local t = {...}
		local msg
		for i = 1, #t do
			msg = t[i](var)
			if msg then return error(msg, 3) end
		end
		return var
	end
	if errorIgnoresMsg[error] then
		function self.Check(cond)
			if not cond then
				return error()
			end
			return cond
		end
	else
		function self.Check(cond, msg, ...)
			if not cond then
				local t = {...}
				for i = 1, #t do t[i] = tostring(t[i]) end
				return error(msg and format("Validation check failed: %s", format(msg, unpack(t))) or "Condition failed")
			end
			return cond
		end
	end
end
NewAsserts(Assert, error, string.format, objToClassString)
Assert.NewAsserts = NewAsserts
local Validate = {}
Assert.Validate = Validate
NewAsserts(Validate, -- Note: error messages here that ignore the message they're given should be added to errorIgnoresMsg
	published and returnFalse or function(...) print(...) return false end,
	published and DoNothing or string.format,
	published and DoNothing or objToClassString)
local Check = {}
Assert.Check = Check
NewAsserts(Check, -- Note: error messages here that ignore the message they're given should be added to errorIgnoresMsg
	DoNothing, -- will return nil
	DoNothing,
	DoNothing)
return Assert