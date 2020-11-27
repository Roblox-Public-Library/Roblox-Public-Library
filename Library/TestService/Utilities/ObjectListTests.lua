local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ObjectList = require(ReplicatedStorage.Utilities.ObjectList)
return function(tests, t)

tests["AdaptToList and ForEach work"] = {
	setup = function()
		local vars = {}
		vars.f = Instance.new("Folder")
		vars.list = ObjectList.new(function(i)
			local obj = Instance.new("IntValue")
			obj.Name = i
			obj.Parent = vars.f
			return obj
		end)
		return vars
	end,
	cleanup = function(vars)
		vars.list:Destroy()
		vars.f:Destroy()
	end,
	test = function(vars)
		local list, f = vars.list, vars.f
		local objs = {}
		list:AdaptToList({5, 3}, function(obj, item)
			obj.Value = item
			objs[#objs + 1] = obj
		end)
		local all2 = false
		local check; check = function(i, obj)
			t.equals(i, 1, "ForEach starts at 1")
			t.equals(obj.Name, "1", "Init works")
			t.equals(obj.Value, 5, "AdaptToList called adaptObject correctly")
			check = function(i, obj)
				t.equals(i, 2, "ForEach advanced to 2")
				t.equals(obj.Name, "2", "Init works")
				t.equals(obj.Value, 3, "AdaptToList called adaptObject correctly")
				all2 = true
				check = function(i, obj)
					error("ForEach called a 3rd time but should only have 2 objects")
				end
			end
		end
		list:ForEach(function(...)
			check(...)
		end)
		t.equals(all2, true, "All 2 items iterated over")
		t.equals(#f:GetChildren(), 2, "Configuration issue")
		list:Destroy()
		t.equals(#f:GetChildren(), 0, "Destroy worked correctly")
	end,
}

tests["Store system works"] = {
	setup = function()
		local vars = {}
		vars.f = Instance.new("Folder")
		vars.f2 = Instance.new("Folder")
		vars.list = ObjectList.new(function(i)
			local obj = Instance.new("IntValue")
			obj.Name = i
			obj.Parent = vars.f
			return obj
		end, 1, function(obj) obj.Parent = vars.f2 end)
		return vars
	end,
	cleanup = function(vars)
		vars.list:Destroy()
		vars.f:Destroy()
	end,
	test = function(vars)
		local list, f, f2 = vars.list, vars.f, vars.f2
		list:AdaptToList({5, 3}, function(obj, item)
			obj.Value = item
		end)
		t.equals(#f:GetChildren(), 2)
		list:AdaptToList({}) -- This also tests that not providing a function is okay for empty lists
		t.equals(#f:GetChildren(), 0, "All items stored or destroyed")
		t.equals(#f2:GetChildren(), 1, "Item stored")
		t.equals(f2:GetChildren()[1].Name, "1", "Correct item stored")
	end,
}

end