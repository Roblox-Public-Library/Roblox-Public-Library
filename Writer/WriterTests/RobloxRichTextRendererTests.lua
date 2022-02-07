return function(tests, t)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Writer = require(ReplicatedStorage.Writer)
local Colors, RobloxRichTextRenderer = Writer.Colors, Writer.RobloxRichTextRenderer
local parse = Writer.CustomMarkdown.ParseText

-- Let's use 24/36/54 for small/normal/large. For subscript can use one step down (16 for subscript of small).
local smallSize = 'size="24"'
local largeSize = 'size="54"'
local parseTime = 0
local renderTime = 0
local creationTime = 0
local timesPerRound = 1
tests.TextWorks = {
	test = function(input, expected, expectedProps)
		local parent
		for i = 1, timesPerRound do
			local s = os.clock()
			local elements = type(input) == "string" and parse(input) or input
			parseTime += os.clock() - s
			s = os.clock()
			parent = Instance.new("Folder")
			creationTime += os.clock() - s
			s = os.clock()
			local rrt = RobloxRichTextRenderer.new(
				Writer.SpaceLeft.new(math.huge, math.huge),
				parent,
				Writer.ReaderConfig.new("SourceSans", 36, Colors.Light))
			for i, e in ipairs(elements) do
				rrt:HandleText(e.Text, e.Format)
			end
			local ct = rrt:Finish()
			renderTime += os.clock() - s - ct
			creationTime += ct
		end
		local ch = parent:GetChildren()
		t.equals(#ch, 1, "1 render child")
		local c = ch[1]
		t.equals(c.ClassName, "TextLabel", "ClassName")
		t.equals(c.RichText, true, "RichText")
		t.equals(c.Text, expected, "Text")
		if expectedProps then
			for k, v in pairs(expectedProps) do
				t.equals(c[k], v, "Render label", k)
			end
		end
	end,
	argsLists = {
		{name = "basics work",
			'**bold** *italics* __underline__ ~~strikethrough~~',
			'<b>bold</b> <i>italics</i> <u>underline</u> <s>strikethrough</s>',
		},
		{name = "overlapping formatting",
			'**bold _italics** italics but no bold_ none',
			'<b>bold <i>italics</i></b><i> italics but no bold</i> none',
		},
		{name = "font",
			'<arial>arial<green> +green</arial> just green<large,cartoon> mix <small>small',
			'<font face="Arial">arial<font color="#00FF00"> +green</font></font><font color="#00FF00"> just green<font face="Cartoon"><font size="54"> mix </font><font size="24">small</font></font></font>',
		},
		{name = "don't specify default font",
			'<arial>arial <sourcesans>sourcesans',
			'<font face="Arial">arial </font>sourcesans',
			{Font = Enum.Font.SourceSans},
		},
		{name = "consistent simple formatting put at beginning and end",
			'<arial>*A*<cartoon>*B*',
			'<b><font face="Arial">A</font><font face="Cartoon">B</font></b>',
		},
		{name = "consistent formatting put in label",
			'<cartoon><green>A<arial>B',
			'<font face="Cartoon">A</font><font face="Arial">B</font>',
			{TextColor = Color3.new(0, 1, 0)},
		},
	},
}
function tests.printResults()
	wait(0.1)
	local total = parseTime + renderTime + creationTime
	print("Times:")
	print(("parseTime %.3fms/round"):format(parseTime/timesPerRound*1e3), ("%.1f%%/round"):format(parseTime/total*100))
	print(("renderTime %.3fms/round"):format(renderTime/timesPerRound*1e3), ("%.1f%%/round"):format(renderTime/total*100))
	print(("creationTime %.3fms/round"):format(creationTime/timesPerRound*1e3), ("%.1f%%/round"):format(creationTime/total*100))
	-- A "round" being running all arguments for the above test
end

end