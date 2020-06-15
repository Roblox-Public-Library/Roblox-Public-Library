local Nexus = require("NexusUnitTesting")
local Writer = require(game.ReplicatedStorage.Writer)
local Formats = Writer.Formats

local parse = Formats.CustomMarkdown.ParseText

local function AssertFormatting(t, formatting, bold, italics, underline, i)
	i = i and ("#%s "):format(i) or ""
	t:AssertNotNil(formatting, "formatting missing")
	t:AssertEquals(not not bold, not not formatting.Bold, i .. "formatting.Bold")
	t:AssertEquals(not not italics, not not formatting.Italics, i .. "formatting.Italics")
	t:AssertEquals(not not underline, not not formatting.Underline, i .. "formatting.Underline")
end
local emptyTable = {}
local function AssertResult(t, result, contentList, formatList)
	t:AssertEquals(#contentList, #result, "# elements")
	formatList = formatList or emptyTable
	for i, content in ipairs(contentList) do
		t:AssertEquals(content, result[i].Text, "element #" .. i .. " content")
		local format = formatList[i] or emptyTable
		AssertFormatting(t, result[i].Format, format.Bold, format.Italics, format.Underline, i)
	end
end
local function PerformTest(name, text, contentList, formatList)
	Nexus:RegisterUnitTest(name, function(t)
		AssertResult(t, parse(text), contentList, formatList)
	end)
end
PerformTest("Format free parse", "text", {"text"})
PerformTest("Contains bold", "text *is* here",
	{"text ", "is", " here"},
	{nil, {Bold = true}, nil})
PerformTest("Contains overlapping bold and italics", "text *i_s* here_",
	{"text ", "i", "s", " here"},
	{nil, {Bold = true}, {Bold = true, Italics = true}, {Italics = true}})
PerformTest("all underlined", "__underline__",
	{"underline"},
	{{Underline = true}})

return true