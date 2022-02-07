return function(tests, t)


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Writer = ReplicatedStorage.Writer
local Format = require(Writer.Format)
local parse = require(Writer.CustomMarkdown).ParseText

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
local function assertTextResult(t, result, contentList, formatList)
	t.equals(#result, #contentList, "# elements")
	formatList = formatList or emptyTable
	for i, content in ipairs(contentList) do
		t.equals(result[i].Text, content, "element #" .. i .. " content")
		local format = Format.new(formatList[i])
		assertFormatting(t, result[i].Format, format, i)
	end
end
local function textTest(name, text, contentList, formatList)
	tests[name] = function()
		assertTextResult(t, parse(text), contentList, formatList)
	end
end

textTest("Format free parse", "text", {"text"})
textTest("Contains bold", "text **is** here",
	{"text ", "is", " here"},
	{nil, {Bold = true}, nil})
textTest("Contains overlapping bold and italics", "text **i_s** here_",
	{"text ", "i", "s", " here"},
	{nil, {Bold = true}, {Bold = true, Italics = true}, {Italics = true}})
textTest("all underlined", "__underline__",
	{"underline"},
	{{Underline = true}})
textTest("Ignore escaped", "a \\*b\\* c", {"a *b* c"})
textTest("Ignore multiplication", "x * y * z", {"x * y * z"})
-- TODO also allow `<` and `>` to have spaces in the same way as multiplication!
textTest("Ignore <> with spaces", "x < y > z", {"x < y > z"})
local arial = {Face = "Arial"}
local red = {Color = "Red"}
local arialRed = {Face = "Arial", Color = "Red"}
textTest("Font name", "normal <Arial>arial",
	{"normal ", "arial"},
	{nil, arial})
textTest("Closing arial tag", "<Arial>arial</arial> normal",
	{"arial", " normal"},
	{arial, nil})
textTest("Closing font tag", "<Arial>arial</font> normal",
	{"arial", " normal"},
	{arial, nil})
textTest("Closing face tag", "<Arial>arial</face> normal",
	{"arial", " normal"},
	{arial, nil})
textTest("Tags condense spaces", "a <Arial> b",
	{"a ", "b"},
	{nil, arial})
textTest("Color", "<red>red text",
	{"red text"},
	{red})
textTest("Color then add font", "<red>red <arial>arial",
	{"red ", "arial"},
	{red, arialRed})
textTest("Color and font immediately", "<red><arial>red arial",
	{"red arial"},
	{arialRed})
textTest("Color and font same tag", "<red,arial>red arial",
	{"red arial"},
	{arialRed})
textTest("End arial not red", "<red,arial>arial</arial> just red",
	{"arial", " just red"},
	{arialRed, red})
textTest("Change color keep arial", "<red,arial>red <green>still arial",
	{"red ", "still arial"},
	{arialRed, {Face = "Arial", Color = "Green"}})
textTest("Font sizes", "<normal>normal<small>small<large>large</large>normal",
	{"normal", "small", "large", "normal"},
	{nil, {Size = "Small"}, {Size = "Large"}, nil})
tests["Horizontal line"] = function()
	local result = parse("<line>")
	t.tablesEqualRecursive(result, {{Line = true}})
end
tests["Horizontal line of +s"] = function()
	local result = parse("<line;+>")
	t.tablesEqualRecursive(result, {{Line = "+"}})
end


end