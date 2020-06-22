local Nexus = require("NexusUnitTesting")
local Writer = require(game.ReplicatedStorage.Writer)
local FileContent, DocumentController, Formats = Writer.FileContent, Writer.DocumentController, Writer.Formats

local Test = Nexus.UnitTest:Extend()
function Test:__new(name, fileContent)
	self:InitializeSuper(name)
	self.fileContent = fileContent or ""
end
function Test:Setup()
	local header = nil
	local sections = {Formats.CustomMarkdown.ParseText(self.fileContent or "")}
	self.c = DocumentController.new(header, sections)
	self.c:NavToFileEnd()
end
function Test:Teardown()
	--self.c:Destroy()
end
function Test:AssertContent(content)
	self:AssertEquals(content, self.c:ToFormat(Formats.CustomMarkdown.new()))
end
local function genRegisterTest(whereToRegister, baseFileContent)
	--	whereToRegister: which unit test (or Nexus) to make tests a child of
	--	baseFileContent: default file content (it can be overridden in the registerTest)
	--	returned function: registerTest(name, fileContent, run)
	whereToRegister = whereToRegister or Nexus
	return function(name, fileContent, run)
		--	fileContent can be omitted: RegisterTest(name, run)
		if type(fileContent) == "function" then -- shift argument
			run = fileContent
			fileContent = nil
		end
		whereToRegister:RegisterUnitTest(Test.new(name, fileContent or baseFileContent):SetRun(run))
	end
end
local function genRegisterTestInGroup(groupName, baseFileContent, parent)
	local group = Test.new(groupName or error("groupName mandatory"))
	;(parent or Nexus):RegisterUnitTest(group)
	return genRegisterTest(group, baseFileContent), group
end
local registerTest = genRegisterTest()

registerTest("type text in new file", function(t)
	t.c:Type("text")
	t:AssertContent("text")
end)

local afterText = genRegisterTestInGroup("type 'text' & navigate in new file", "text")
afterText("backspace", function(t)
	t.c:Backspace()
	t:AssertContent("tex")
end)
afterText("delete nothing", function(t)
	t.c:Delete()
	t:AssertContent("text")
end)
afterText("left & delete", function(t)
	t.c:Left()
	t.c:Delete()
	t:AssertContent("tex")
end)
afterText("start of doc & delete", function(t)
	t.c:NavToFileStart()
	t.c:Delete()
	t:AssertContent("ext")
end)


local formatting = genRegisterTestInGroup("formatting sometext", "some")
formatting("bold", function(t)
	t.c:SetBold(true)
	t.c:Type("text")
	t:AssertContent("some*text*")
end)
formatting("italics", function(t)
	t.c:SetItalics(true)
	t.c:Type("text")
	t:AssertContent("some_text_")
end)
formatting("underline", function(t)
	t.c:SetUnderline(true)
	t.c:Type("text")
	t:AssertContent("some__text__")
end)

local function smallBold(name, run)
	registerTest(name, "aa*bb*cc", run)
end
smallBold("Highlight & replace mixed formatting", function(t)
	local f, c = t.f, t.c
	c:SetIndex(2) -- right before the first 'a'
	c:StartSelecting()
	c:Right()
	c:Right()
	c:StopSelecting()
	c:Type("x")
	t:AssertContent("ax*b*cc")
end)

return true