return function(tests, t)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Writer = require(ReplicatedStorage.Writer)
local Colors, RobloxRichText = Writer.Colors, Writer.RobloxRichText
local parse = Writer.CustomMarkdown.ParseText

-- Let's use 24/36/54 for small/normal/large. For subscript can use one step down (16 for subscript of small).
local smallSize = 'size="24"'
local largeSize = 'size="54"'
tests.RobloxRichTextWorks = {
	test = function(input, expected)
		local elements = type(input) == "string" and parse(input) or input
		local rrt = RobloxRichText.new("SourceSans", 36, Colors.Light)
		local s = {}
		for i, e in ipairs(elements) do
			s[i] = rrt:HandleText(e)
		end
		s[#s + 1] = rrt:Finish()
		t.equals(table.concat(s), expected)
	end,
	argsLists = {
		{name = "basics work",
			'**bold** *italics* __underline__ ~~strikethrough~~',
			'<b>bold</b> <i>italics</i> <u>underline</u> <s>strikethrough</s>'
		},
		{name = "overlapping formatting",
			'**bold _italics** italics but no bold_ none',
			'<b>bold <i>italics</i></b><i> italics but no bold</i> none'
		},
		{name = "font",
			'<arial>arial<green> +green</arial> just green<large,sourcesans> mix <small>small',
			'<font face="Arial">arial<font color="#00FF00"> +green</font></font><font color="#00FF00"> just green<font face="SourceSans"><font size="54"> mix </font><font size="24">small</font></font></font>'
		},
		-- {name = "preserve tag order",
		-- 	-- Premise is that if someone chooses a color and never changes it, the color shouldn't be reapplied
		-- }
	},
}

end