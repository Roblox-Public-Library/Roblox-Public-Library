return function(tests, t)


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BookPouch = require(ReplicatedStorage.Library.BookPouch)
function tests.BookPouchDataWorks()
	local b = BookPouch.new({})
	b:SetInPouch(1, true)
	b:SetInPouch(5, true)

	local b2 = BookPouch.new(b.data)
	t.truthy(b2:Contains(1))
	t.truthy(b2:Contains(5))
end


end