return function(tests, t)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Text = require(ReplicatedStorage.Utilities.Text)

tests.CountWords = {
	test = function(input, num)
		t.equals(Text.CountWords(input), num)
	end,
	argsLists = {
		{"hi there", 2},
		{" justOne ", 1},
		{"a!b!c.d?", 4},
		{"a\tb\nc", 3},
	}
}

tests.IterWords = {
	test = function(input, list)
		local n = 1
		for word, spacing in Text.IterWords(input) do
			t.multi(n, function(m)
				m.equals("word", word, list[2*n-1])
				m.equals("spacing", spacing, list[2*n])
			end)
			n += 1
		end
	end,
	argsLists = {
		{"hi there", {"hi", " ", "there", ""}},
		{" justOne ", {"", " ", "justOne", " "}},
		{"a!b!c.d?", {"a!", "", "b!", "", "c.", "", "d?", ""}},
		{"a\tb\nc", {"a", "\t", "b", "\n", "c", ""}},
	}
}

end