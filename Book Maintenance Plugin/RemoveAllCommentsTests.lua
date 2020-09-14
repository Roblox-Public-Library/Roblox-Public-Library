local Nexus = require("NexusUnitTesting")
local ServerStorage = game:GetService("ServerStorage")
local rac = require(ServerStorage.RemoveAllComments)

local function test(name, input, output)
	Nexus:RegisterUnitTest(name, function(t)
		t:AssertEquals(rac(input), output)
	end)
end

test("Remove comment full line", "1st\n--2nd\n3rd", "1st\n3rd")
test("Remove comment first & only line", "--1st", "")
test("Remove comment mid line & trim", "1st\n2nd -- lol\n3rd", "1st\n2nd\n3rd")
test("Remove multiple comments in a row", "1st\n--2nd\n--3rd\n4th", "1st\n4th")
test("Don't remove comment in double quotes", '"--lol"', '"--lol"')
test("Don't remove comment in single quotes", "'--lol'", "'--lol'")
test("Keep ending newline after comment", '"" --\n', '""\n')
test("Throw away newline before final line comment", '1st\n--', '1st')
test("Don't add extra newline after comment", '"" --', '""')
test("Handle escaping", 's = "\\"--this is in the string" -- this is not', 's = "\\"--this is in the string"')
test("Ignore escaped \\ 1", 's = "\\\\--in string"--out of string', 's = "\\\\--in string"')
test("Ignore escaped \\ 2", 's = "\\\\"--out of string', 's = "\\\\"')
test("Ignore \\\\", 's = "\\\\\\"--in string"--out of string', 's = "\\\\\\"--in string"')
test("Don't remove comments in block string", "[[-- lol]]", "[[-- lol]]")
test("More block string combinations", [==[
s = [["Hi! --" -- there
'--\'--\"--
]] -- comment
]==], [==[
s = [["Hi! --" -- there
'--\'--\"--
]]
]==])
test("Ignore incorrect block endings", [==[
s = [[
--not a comment
]=] -- still not
]] -- this is
]==], [==[
s = [[
--not a comment
]=] -- still not
]]
]==])
test("Ignore nested blocks", [==[
s = [[
[=[--in nested block]=] -- still in block string
]] -- comment
]==], [==[
s = [[
[=[--in nested block]=] -- still in block string
]]
]==])
test("Larger example", [==[
--- Some comment ---
--- Another comment ---
local var = 3 -- desc
local var = "hi" --desc2
for x = 1, 5 do
	-- do something
	print([[x:]], x)
end
]==], [==[
local var = 3
local var = "hi"
for x = 1, 5 do
	print([[x:]], x)
end
]==])
test("Don't remove multiple newlines", [[

a --comment

b


c
]], [[

a

b


c
]])
test("Don't remove multiple newlines with tabs/spaces", "a--c\n\t\n\t\n \n \bb", "a\n\t\n\t\n \n \bb")
test("Block comment removed", [==[
a
--[=[
	/b
]=]--
c]==], [==[
a
c]==])

return true