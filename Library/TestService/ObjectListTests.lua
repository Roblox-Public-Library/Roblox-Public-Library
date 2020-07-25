local Nexus = require("NexusUnitTesting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ObjectList = require(ReplicatedStorage.Utilities.ObjectList)

local objectListTest = Nexus.UnitTest.new("AdaptToList and ForEach work")
function objectListTest:Setup()
	self.f = Instance.new("Folder")
	self.list = ObjectList.new(function(i)
		local obj = Instance.new("IntValue")
		obj.Name = i
		obj.Parent = self.f
		return obj
	end)
end
function objectListTest:Teardown()
	self.list:Destroy()
	self.f:Destroy()
end
objectListTest:SetRun(function(t)
	local list, f = t.list, t.f
	local objs = {}
	list:AdaptToList({5, 3}, function(obj, item)
		obj.Value = item
		objs[#objs + 1] = obj
	end)
	local all2 = false
	local check; check = function(i, obj)
		t:AssertEquals(i, 1, "ForEach starts at 1")
		t:AssertEquals(obj.Name, "1", "Init works")
		t:AssertEquals(obj.Value, 5, "AdaptToList called adaptObject correctly")
		check = function(i, obj)
			t:AssertEquals(i, 2, "ForEach advanced to 2")
			t:AssertEquals(obj.Name, "2", "Init works")
			t:AssertEquals(obj.Value, 3, "AdaptToList called adaptObject correctly")
			all2 = true
			check = function(i, obj)
				error("ForEach called a 3rd time but should only have 2 objects")
			end
		end
	end
	list:ForEach(function(...)
		check(...)
	end)
	t:AssertEquals(all2, true, "All 2 items iterated over")
	t:AssertEquals(#f:GetChildren(), 2, "Configuration issue")
	list:Destroy()
	t:AssertEquals(#f:GetChildren(), 0, "Destroy worked correctly")
end)
Nexus:RegisterUnitTest(objectListTest)

local storeTest = Nexus.UnitTest.new("Store system works")
function storeTest:Setup()
	self.f = Instance.new("Folder")
	self.f2 = Instance.new("Folder")
	self.list = ObjectList.new(function(i)
		local obj = Instance.new("IntValue")
		obj.Name = i
		obj.Parent = self.f
		return obj
	end, 1, function(obj) obj.Parent = self.f2 end)
end
function storeTest:Teardown()
	self.list:Destroy()
	self.f:Destroy()
end
storeTest:SetRun(function(t)
	local list, f, f2 = t.list, t.f, t.f2
	list:AdaptToList({5, 3}, function(obj, item)
		obj.Value = item
	end)
	t:AssertEquals(#f:GetChildren(), 2)
	list:AdaptToList({}) -- This also tests that not providing a function is okay for empty lists
	t:AssertEquals(#f:GetChildren(), 0, "All items stored or destroyed")
	t:AssertEquals(#f2:GetChildren(), 1, "Item stored")
	t:AssertEquals(f2:GetChildren()[1].Name, "1", "Correct item stored")
end)
Nexus:RegisterUnitTest(storeTest)

return true