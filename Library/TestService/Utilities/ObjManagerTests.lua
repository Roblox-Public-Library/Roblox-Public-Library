return function(tests, t)

do return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ObjManager = require(ReplicatedStorage.Utilities.ObjManager)
local Category = ObjManager.Category

local n = 0

local c1 = Category.new(function() n += 1 return {Value = n, Parent = true, Destroy = function() end} end, 2)

local function test(name, test)
	tests[name] = {
		setup = function() return ObjManager.new() end,
		cleanup = function(m) m:Destroy() end,
		test = test,
	}
end

test(":Get returns different objects", function(m)
	local obj = m:Get(c1)
	t.notEquals(m:Get(c1).Value, obj.Value)
end)
test("ReuseWorks", function(m)
	local obj = m:Get(c1)
	m:Release(obj)
	t.equals(m:Get(c1), obj, "Should re-use objects")
end)
-- todo more tests


end