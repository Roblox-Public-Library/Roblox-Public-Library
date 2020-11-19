return function(tests, t)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Writer = require(ReplicatedStorage.Writer)
local Formats = Writer.Formats

local parse = Formats.CustomMarkdown.ParseText

local function assertFormatting(t, formatting, bold, italics, underline, i)
	i = i and ("#%s "):format(i) or ""
	t.truthy(formatting, "formatting missing")
	t.equals(not not bold, not not formatting.Bold, i .. "formatting.Bold")
	t.equals(not not italics, not not formatting.Italics, i .. "formatting.Italics")
	t.equals(not not underline, not not formatting.Underline, i .. "formatting.Underline")
end
local emptyTable = {}
local function assertResult(t, result, contentList, formatList)
	t.equals(#contentList, #result, "# elements")
	formatList = formatList or emptyTable
	for i, content in ipairs(contentList) do
		t.equals(content, result[i].Text, "element #" .. i .. " content")
		local format = formatList[i] or emptyTable
		assertFormatting(t, result[i].Format, format.Bold, format.Italics, format.Underline, i)
	end
end
local function performTest(name, text, contentList, formatList)
	tests[name] = function()
		assertResult(t, parse(text), contentList, formatList)
	end
end
performTest("Format free parse", "text", {"text"})
performTest("Contains bold", "text *is* here",
	{"text ", "is", " here"},
	{nil, {Bold = true}, nil})
performTest("Contains overlapping bold and italics", "text *i_s* here_",
	{"text ", "i", "s", " here"},
	{nil, {Bold = true}, {Bold = true, Italics = true}, {Italics = true}})
performTest("all underlined", "__underline__",
	{"underline"},
	{{Underline = true}})

end