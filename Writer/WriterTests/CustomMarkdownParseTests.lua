return function(tests, t)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Writer = require(ReplicatedStorage.Writer)
local Format = Writer.Format
local parse = Writer.CustomMarkdown.ParseText

-- local function assertFont(t, font, expected, desc)
-- 	t.multi((desc and desc .. " " or "") .. "Font", function(m)
-- 		m.equals("Face", font.Face, expected.Face)
-- 		m.equals("Size", font.Size, expected.Size)
-- 		m.equals("Color", font.Color, expected.Color)
-- 	end)
-- end
local function assertFormatting(t, formatting, expected, i)
	local desc = i and ("#%s "):format(i) or ""
	t.truthy(formatting, "formatting missing")
	t.multi(desc .. "formatting", function(m)
		m.equals("Bold", not not formatting.Bold, not not expected.Bold)
		m.equals("Italics", not not formatting.Italics, not not expected.Italics)
		m.equals("Underline", not not formatting.Underline, not not expected.Underline)
		m.equals("Strikethrough", not not formatting.Strikethrough, not not expected.Strikethrough)
		--assertFont(t, formatting.Font, expected.Font, i and "#" .. i)
		m.equals("Face", formatting.Face, expected.Face)
		m.equals("Size", formatting.Size, expected.Size)
		m.equals("Color", formatting.Color, expected.Color)
	end)
end
local emptyTable = {}
local function assertResult(t, result, contentList, formatList)
	t.equals(#result, #contentList, "# elements")
	formatList = formatList or emptyTable
	for i, content in ipairs(contentList) do
		t.equals(result[i].Text, content, "element #" .. i .. " content")
		local format = Format.new(formatList[i])
		assertFormatting(t, result[i].Format, format, i)
	end
end
local function performTest(name, text, contentList, formatList)
	tests[name] = function()
		assertResult(t, parse(text), contentList, formatList)
	end
end
performTest("Format free parse", "text", {"text"})
performTest("Contains bold", "text **is** here",
	{"text ", "is", " here"},
	{nil, {Bold = true}, nil})
performTest("Contains overlapping bold and italics", "text **i_s** here_",
	{"text ", "i", "s", " here"},
	{nil, {Bold = true}, {Bold = true, Italics = true}, {Italics = true}})
performTest("all underlined", "__underline__",
	{"underline"},
	{{Underline = true}})
performTest("Ignore escaped", "a \\*b\\* c", {"a *b* c"})
performTest("Ignore multiplication", "x * y * z", {"x * y * z"})
local arial = {Face = "Arial"}
local red = {Color = "Red"}
local arialRed = {Face = "Arial", Color = "Red"}
performTest("Font name", "normal <Arial>arial",
	{"normal ", "arial"},
	{nil, arial})
performTest("Closing arial tag", "<Arial>arial</arial> normal",
	{"arial", " normal"},
	{arial, nil})
performTest("Tags condense spaces", "a <Arial> b",
	{"a ", "b"},
	{nil, arial})
performTest("Color", "<red>red text",
	{"red text"},
	{red})
performTest("Color then add font", "<red>red <arial>arial",
	{"red ", "arial"},
	{red, arialRed})
performTest("Color and font immediately", "<red><arial>red arial",
	{"red arial"},
	{arialRed})
performTest("Color and font same tag", "<red,arial>red arial",
	{"red arial"},
	{arialRed})
performTest("End arial not red", "<red,arial>arial</arial> just red",
	{"arial", " just red"},
	{arialRed, red})
performTest("Change color keep arial", "<red,arial>red <green>still arial",
	{"red ", "still arial"},
	{arialRed, {Face = "Arial", Color = "Green"}})
performTest("Font sizes", "<small>small<normal>normal<large>large</large>normal",
	{"small", "normal", "large", "normal"},
	{{Size = "Small"}, nil, {Size = "Large"}, nil})

end