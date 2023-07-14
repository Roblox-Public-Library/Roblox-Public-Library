return function(tests, t)


local PagesSeenManager = require(game:GetService("ReplicatedStorage").Library.PagesSeenManager)

function tests.Works()
	local p = PagesSeenManager.new()
	t.equals(p:GetNum(), 0)
	local items = {1, 3, 7, 22}
	for round = 1, 2 do
		for i, page in items do
			t.truthyEquals(p:RecordSeenPage(page), round == 2)
			if round == 1 then
				t.equals(p:GetNum(), i)
			else
				t.equals(p:GetNum(), #items)
			end
		end
	end
	t.equals(PagesSeenManager.new(p:GetString()):GetNum(), p:GetNum(), "counting in .new works")
end


end -- function(tests, t)