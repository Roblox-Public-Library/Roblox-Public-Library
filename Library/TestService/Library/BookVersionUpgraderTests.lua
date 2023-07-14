return function(tests, t)


local ServerScriptService = game:GetService("ServerScriptService")
local BookVersionUpgrader = require(ServerScriptService.Library.BookVersionUpgrader)

tests.IsChapter = {
	test = function(line, result)
		t.truthyEquals(BookVersionUpgrader.IsChapter(line), result)
	end,
	argsLists = {
		{"Chapter 1", true},
		{"ARTICLE XIV", true},
		{"~~Chapter Four: The End!", true},
		-- {"This is a Chapter 3 reference", false} -- need to have a symbol before "Chapter"
		-- {"This is a - Section 3 reference", true}, -- in this case, 'reference' is inferred to be part of the chapter name.
		{"--Section two Ongoing", true},
		{"Chapter 6: A really " .. string.rep("long ", 20) .. "line", false},
	},
}
tests.GetChapterPieces = {
	test = function(line, term, num, sep, title)
		local a, b, c, d = BookVersionUpgrader.GetChapterPieces(line)
		t.multi("all correct", function(m)
			m.equals("term", a, term)
			m.equals("num", b, num or "")
			m.equals("sep", c, sep or "")
			m.equals("title", d, title or "")
		end)
	end,
	argsLists = {
		{"Chapter 1", "Chapter", "1"},
		{"ARTICLE XIV", "ARTICLE", "XIV"},
		{"~~Chapter Four: The End!", "Chapter", "Four", ": ", "The End!"},
		{"--Section two -- Ongoing", "Section", "two", " -- ", "Ongoing"},
		{"Chapter 1 - 1", "Chapter", "1", " - ", "1"},
		{"Chapter 1 (Hello)", "Chapter", "1", " (", "Hello)"},
	},
}


end -- function(tests, t)