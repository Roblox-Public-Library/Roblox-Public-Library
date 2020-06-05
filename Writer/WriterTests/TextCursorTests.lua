local Nexus = require("NexusUnitTesting")
local Writer = require(game.ServerStorage.BookWriterPlugin.Writer)
local File, TextCursor, Formats = Writer.File, Writer.TextCursor, Writer.Formats

local Test = Nexus.UnitTest:Extend()
function Test:__new(name, fileContent)
	self:InitializeSuper(name)
	self.fileContent = fileContent or ""
end
function Test:Setup()
	self.f = File.new(self.fileContent)
	self.c = TextCursor.new(self.f)
end
function Test:Teardown()
	--self.f:Destroy()
	--self.c:Destroy()
end
function Test:AssertContent(content)
	self:AssertEquals(content, self.f:ToFormat(Formats.CustomMarkdown))
end

Nexus:RegisterUnitTest(Test.new("type in new file"):SetRun(function(t)
	t.c:Type("hi")
	t:AssertContent("hi")
end))

function smallBold(name, run)
	Nexus:RegisterUnitTest(Test.new(name, "aa*bb*cc"):SetRun(run))
end
smallBold("Highlight & replace mixed formatting", function(t)
	local f, c = t.f, t.c
	c:SetPos(2) -- right before the first 'a'
	c:StartSelection()
	c:Right()
	c:Right()
	c:EndSelection()
	c:Type("x")
	t:AssertContent("ax*b*cc")
end)

return true