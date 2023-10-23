return function(tests, t)


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Writer = ReplicatedStorage.Writer
local Elements = require(Writer.Elements)
local Format = require(Writer.Format)
local parseText = require(Writer.CustomMarkdown).ParseText
local defaultParseArgs = {Testing = true, AllowTagSeparator = true}
local function parse(text)
	return parseText(text, defaultParseArgs)
end

local function assertFormatting(t, formatting, expected, i)
	local desc = i and ("#%s "):format(i) or ""
	t.truthy(formatting, "formatting missing")
	t.multi(desc .. "formatting", function(m)
		m.equals("Bold", not not formatting.Bold, not not expected.Bold)
		m.equals("Italics", not not formatting.Italics, not not expected.Italics)
		m.equals("Underline", not not formatting.Underline, not not expected.Underline)
		m.equals("Strikethrough", not not formatting.Strikethrough, not not expected.Strikethrough)
		m.equals("Font", formatting.Font, expected.Font)
		m.equals("Size", formatting.Size, expected.Size)
		m.equals("Color", formatting.Color, expected.Color)
		if expected.Stroke then
			m.tablesEqual("Stroke", formatting.Stroke, expected.Stroke)
		else
			m.truthyEquals("Stroke", formatting.Stroke, expected.Stroke)
		end
		m.equals("SubOrSuper", formatting.SubOrSuperScript, expected.SubOrSuperScript)
	end)
end
local emptyTable = {}
local function assertTextResult(t, result, contentList, formatList)
	t.equals(#result, #contentList, "# elements")
	formatList = formatList or emptyTable
	for i, content in ipairs(contentList) do
		t.equals(result[i].Text, content, "element #" .. i .. " content")
		local format = if formatList[i] then Format.new(formatList[i]) else Format.Plain
		assertFormatting(t, result[i].Format, format, i)
	end
end
local function textTest(name, text, contentList, formatList)
	tests[name] = function()
		assertTextResult(t, parse(text), contentList, formatList)
	end
end

textTest("Format free parse", "text", {"text"})
textTest("Ignore _s", "t_ex_t", {"t_ex_t"})
textTest("Contains bold", "text **is** here",
	{"text ", "is", " here"},
	{nil, {Bold = true}, nil})
textTest("Contains overlapping bold and italics", "text **i*s** here*",
	{"text ", "i", "s", " here"},
	{nil, {Bold = true}, {Bold = true, Italics = true}, {Italics = true}})
textTest("all underlined", "__underline__",
	{"underline"},
	{{Underline = true}})
textTest("strikethrough", "~~strikethrough~~",
	{"strikethrough"},
	{{Strikethrough = true}})
textTest("ignore isolated ~", "here ~ there ~ double ~ ~", {"here ~ there ~ double ~ ~"})
textTest("Ignore escaped", "a \\*b\\* c", {"a *b* c"})
textTest("Escaped backslash doesn't interfere with bold", "a \\\\**b** c",
	{"a \\", "b", " c"},
	{nil, {Bold = true}, nil})
textTest("Ignore multiplication", "x * y * z", {"x * y * z"})
textTest("Ignore <> with spaces", "x < y > z", {"x < y > z"})
local arial = {Font = Enum.Font.Arial}
local red = {Color = "Red"}
local arialRed = {Font = Enum.Font.Arial, Color = "Red"}
textTest("Font name", "normal <Arial>arial",
	{"normal ", "arial"},
	{nil, arial})
textTest("Closing arial tag", "<Arial>arial</arial> normal",
	{"arial", " normal"},
	{arial, nil})
textTest("Closing font tag", "<Arial>arial</font> normal",
	{"arial", " normal"},
	{arial, nil})
textTest("Tags condense spaces", "a <Arial> b",
	{"a ", "b"},
	{nil, arial})
textTest("Starting tag condenses spaces", "<Arial> b",
	{"b"},
	{arial})
textTest("Ending tag condenses spaces", "b <Arial>",
	{"b"},
	{nil})
textTest("Color", "<red>red text",
	{"red text"},
	{red})
textTest("Custom color", "<color,(255 255 0)>text",
	{"text"},
	{{Color = "(255 255 0)"}})
textTest("Color then add font", "<red>red <arial>arial",
	{"red ", "arial"},
	{red, arialRed})
textTest("Color and font immediately", "<red><arial>red arial",
	{"red arial"},
	{arialRed})
textTest("Color and font same tag", "<red;arial>red arial",
	{"red arial"},
	{arialRed})
textTest("End arial not red", "<red;arial>arial</arial> just red",
	{"arial", " just red"},
	{arialRed, red})
textTest("Change color keep arial", "<red;arial>red <green>still arial",
	{"red ", "still arial"},
	{arialRed, {Font = Enum.Font.Arial, Color = "Green"}})
textTest("Stroke", "a <stroke,red,2,0.5>text</stroke> b", {"a ", "text", " b"}, {nil, {Stroke = {Color = "Red", Transparency = 0.5, Thickness = 2}}, nil})
textTest("Font sizes", "<normal>normal<small>small<large>large</large>normal",
	{"normal", "small", "large", "normal"},
	{nil, {Size = "Small"}, {Size = "Large"}, nil})
textTest("Subscript argument", "a<sub,2!>b", {"a", "2!", "b"}, {nil, {SubOrSuperScript = "Sub"}})
textTest("Subscript arg with formatting", "a<sub,b**c**d>e", {"a", "b", "c", "d", "e"}, {nil, {SubOrSuperScript = "Sub"}, {SubOrSuperScript = "Sub", Bold = true}, {SubOrSuperScript = "Sub"}})
textTest("Subscript tag", "a<sub>2!</sub>b", {"a", "2!", "b"}, {nil, {SubOrSuperScript = "Sub"}})
textTest("Formatting then subscript", "**a<sub>b</sub>c**", {"a", "b", "c"}, {{Bold = true}, {SubOrSuperScript = "Sub", Bold = true}, {Bold = true}})
textTest("Superscript 'sup' argument", "a<sup,2!>b", {"a", "2!", "b"}, {nil, {SubOrSuperScript = "Super"}})
textTest("Superscript 'super' argument", "a<super,2!>b", {"a", "2!", "b"}, {nil, {SubOrSuperScript = "Super"}})
textTest("Subscript escaped semicolon", "<sub,a\\,b>", {"a,b"}, {{SubOrSuperScript = "Sub"}})
textTest("Subscript doesn't condense spaces", "a <sub,2!> b", {"a ", "2!", " b"}, {nil, {SubOrSuperScript = "Sub"}})

tests["condense spaces between images"] = function()
	local result = parse("<image,442788848,100h> <image,442788997,100h> <image,442789300,100h> <image,442789437,100h> <image,442789582,100h> <image,442789698,100h> <image,442789837,100h> <image,442789981,100h>")
	for _, e in result do
		if e.Type == "Text" then
			print(result)
			error("No text expected between images")
		end
	end
end

tests["condense whitespace at end of line"] = function()
	local result = parse("line1  \t\nline2")
	t.equals(#result, 1)
	t.equals(result[1].Type, "Text")
	t.equals(result[1].Text, "line1\nline2")
end
tests["condense whitespace at end of line after tag"] = function()
	local result = parse("<image,442788848,10h>  \t\n<image,442788848,10h>")
	t.equals(#result, 2) -- note: sometimes a 3rd element is put between the images, which would be fine
end
tests["condense unlimited whitespace before/after page breaks"] = function()
	local result = parse("a\n\n\n<page>\n \t\nb")
	t.equals(result[1].Text, "a")
	t.equals(result[3].Text, "b")
end
tests["Condense immediate newlines around bar"] = function()
	local result = parse("a\n<bar>\nb")
	t.equals(result[1].Text, "a")
	t.equals(result[3].Text, "b")
end
tests["Condense immediate newlines around bar2"] = function()
	local result = parse("a\n<bar>\n\nb")
	t.equals(result[1].Text, "a")
	t.equals(result[3].Text, "\nb")
end

textTest("Multiline works", "a\nb", {"a\nb"})

tests["Line commands fail when not turned on"] = {
	test = function(text)
		local result, issues = parseText(text)
		t.truthy(issues)
	end,
	args = {"<line>", "<dline>", "<line,1>"},
}

tests["Line commands work"] = {
	test = function(text, expected)
		local result = parseText(text, {UseLineCommands = true, Testing = true})
		t.equals(#result, 1)
		t.equals(result[1].Text, expected)
	end,
	argsLists = {
		{"1\n2<line>3", "1 2\n3"},
		{"1<line>2", "1\n2"},
		{"1<line>\n2\n3<dline>4\n  \n  5\n", "1\n2 3\n\n4 5"},
		{name="Newline is implicit space", "a\nb \nc", "a b c"},
	},
}
tests["Line command condenses newline into space around tags"] = function()
	local result = parseText("a<b>\nb", {UseLineCommands = true, Testing = true})
	t.equals(#result, 2)
	t.equals(result[1].Text, "a")
	t.equals(result[2].Text, " b")
end

local function category(name, args, cases)
	if not cases then cases = args; args = nil end
	args = args or defaultParseArgs
	local focus = cases.focus
	local skip = cases.skip
	cases.focus = nil
	cases.skip = nil
	tests[name] = {
		test = function(text, expected)
			if focus then
				print("text", text)
				print("parse", parseText(text, args))
				print("expected", expected)
			end
			t.tablesEqualRecursive(parseText(text, args), expected)
		end,
		argsLists = cases,
		focus = focus,
		skip = skip,
	}
end
category("Bar", {
	{
		name = "horizontal line",
		"<bar>",
		{{Type = "Bar", Line = true}}
	},
	{
		name = "Horizontal line of +s",
		"<bar,+>",
		{{Type = "Bar", Line = "+"}},
	},
	-- The following help test argument parsing
	{
		name = "Horizontal line of '. 's",
		"<bar,. >",
		{{Type = "Bar", Line = ". "}},
	},
	{
		name = "Horizontal line of '/'s",
		"<bar,/>",
		{{Type = "Bar", Line = "/"}},
	},
	{
		name = "Horizontal line of '>'s",
		"<bar,\\>>",
		{{Type = "Bar", Line = ">"}},
	},
})

category("Image", {Images = {10, 20, 30, 40, "50"}, Testing = true}, {
	{
		"<image1,10x15,right,nowrap>",
		{{Type = "Image", ImageId = 10, Size = Vector2.new(0.1, 0.15), Alignment = Enum.TextXAlignment.Right, NoWrap = true}},
	},
	{
		"<image,left,53,10w,15h>",
		{{Type = "Image", ImageId = 53, Size = Vector2.new(0.1, 0.15), Alignment = Enum.TextXAlignment.Left}},
	},
	{
		name = "defaults",
		"<image5>",
		{{Type = "Image", ImageId = 50, Size = Vector2.new(1, 1), Alignment = Enum.TextXAlignment.Center}},
	},
	{
		name = "nowrap ignored for center alignment",
		"<image5,nowrap>",
		{{Type = "Image", ImageId = 50, Size = Vector2.new(1, 1), Alignment = Enum.TextXAlignment.Center}},
	},
	{
		name = "square support",
		"<image5,40h,square>",
		{{Type = "Image", ImageId = 50, Size = Vector2.new(1, 0.4), AspectRatio = 1, HeightProvided = 40, Alignment = Enum.TextXAlignment.Center}},
	},
	{
		name = "aspect ratio support",
		"<image5,40h,2r>",
		{{Type = "Image", ImageId = 50, Size = Vector2.new(1, 0.4), AspectRatio = 2, HeightProvided = 40, Alignment = Enum.TextXAlignment.Center}},
	},
})

category("misc", {
	{
		name = "stroke and header",
		"<stroke,nearblack><header,Name>",
		{{Type = "Header", Size = "Header", Text = {{Type = "Text", Text = "Name", Format = Format.Plain:With("Stroke", {Color="NearBlack"})}}}},
	},
})

local chapterElements = {Elements.Text("Hello, how are you?", Format.Plain)}
local smallChapterElements = {
	Elements.Text("A", Format.Plain),
	Elements.Text("b", Format.new({Size = "Small"})),
}
category("chapters", {
	{
		name = "chapter",
		"<chapter,Hello, how are you?>",
		{{Type = "Chapter", Name = chapterElements, Text = chapterElements, Format = Format.Plain}},
	},
	{
		name = "section2",
		"<section2,Hello, how are you?>",
		{{Type = "Section", Name = {Elements.Text("Hello", Format.Plain)}, Text = {Elements.Text("how are you?", Format.Plain)}, Format = Format.Plain}},--
	},
	{
		name = "inherited formatting",
		"**<chapter,A><chapter>**",
		{
			{
				Type = "Chapter",
				Name = {Elements.Text("A", Format.new({Bold = true}))},
				Text = {Elements.Text("A", Format.new({Bold = true}))},
				Format = Format.new({Bold = true}),
			},
			{
				Type = "Chapter",
				Format = Format.new({Bold = true}),
			},
		}
	},
	{
		name = "small chapter",
		"<chapter,A<small>b>",
		{{Type = "Chapter", Name = smallChapterElements, Text = smallChapterElements, Format = Format.Plain}},
	},
})

category("pageNumbering", {
	{
		name = "invisible3",
		"<pagenumbering,number,invisible3>",
		{{Type = "PageNumbering", Style = "number", Invisible = 3}}
	}
})

tests["Various non-text tags in a row"] = {
	test = function(text, expectedNum, startNonText)
		local result = parse(text)
		t.equals(#result, expectedNum)
		for i = startNonText or 1, #result do
			t.notEquals(result[i].Type, "Text", "Element", i, "should not be Text")
		end
	end,
	argsLists = {
		{"<indent,tab><turn><pagenumbering,number,1><image,442788848,100h> <image,442788849,100h>", 5, 1}, -- this has triggered a bug in the past; something to do with condensing spaces
	}
}

local function text(txt)
	return {Type = "Text", Text = txt, Format = Format.Plain}
end
local function block(elements)
	return {Type = "Block", BorderThickness = 1, Width = 1, Elements = elements}
end
category("block", {
	{
		"a<block>b</block>c",
		{
			text("a"),
			block({text("b")}),
			text("c"),
		}
	},
	{
		name = "condense 1 newline",
		[[
a

<block>

b1
b2

</block>

c]],
		{
			text("a\n"),
			block({text("\nb1\nb2\n")}),
			text("\nc"),
		}
	},
	{
		name = "condense 1 newline even if font tag",
		[[
a

<block><code>

b1
b2

</code></block>

c]],
		{
			text("a\n"),
			block({text("\nb1\nb2\n")}),
			text("\nc"),
		}
	},
})

tests.goodError = function()
	t.errorsWith("On line 6:", function()
		parseText("Line1\n<line>\n\t Line3<line>\n\nLine5  \n  LineWithErr<line.\nLine7<line>", {UseLineCommands = true, Testing = true})
	end)
end


end