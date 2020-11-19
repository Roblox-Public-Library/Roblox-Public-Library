return function(tests, t)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Writer = require(ReplicatedStorage.Writer)
local FileContent, DocumentController, Formats = Writer.FileContent, Writer.DocumentController, Writer.Formats

local function assertContent(c, content)
	t.equals(c:ToFormat(Formats.CustomMarkdown.new()), content)
end

local function createController(fileContent)
	local header = nil
	local sections = {Formats.CustomMarkdown.ParseText(fileContent)}
	local c = DocumentController.new(header, sections)
	c:NavToFileEnd()
	return c
end

tests["type text in new file"] = function()
	local c = createController("")
	c:Type("text")
	assertContent(c, "text")
end

local function genTest(fileContent)
	return function(run, expected)
		local c = createController(fileContent)
		run(c)
		assertContent(c, expected)
	end
end

tests["type 'text' & navigate in new file"] = {
	test = genTest("text"),
	argsLists = {
		{name = "backspace", function(c) c:Backspace() end, "tex"},
		{name = "delete nothing", function(c) c:Delete() end, "text"},
		{name = "left & delete", function(c) c:Left(); c:Delete() end, "tex"},
		{name = "start of doc & delete", function(c) c:NavToFileStart(); c:Delete() end, "ext"}
	}
}

tests["formatting sometext"] = {
	test = genTest("some"),
	argsLists = {
		{name = "bold", function(c) c:SetBold(true); c:Type("text") end, "some*text*"},
		{name = "italics", function(c) c:SetItalics(true); c:Type("text") end, "some_text_"},
		{name = "underline", function(c) c:SetUnderline(true); c:Type("text") end, "some__text__"},
	}
}

tests["Highlight & replace mixed formatting"] = function()
	local c = createController("aa*bb*cc")
	c:SetPos(DocumentController.Pos.new(1, 1, 2)) -- right before the second 'a'
	c:StartSelecting()
	c:Right()
	c:Right()
	c:StopSelecting()
	c:Type("x")
	assertContent(c, "ax*b*cc")
end

end