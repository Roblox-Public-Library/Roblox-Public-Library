local Nexus = require("NexusUnitTesting")
local ServerStorage = game:GetService("ServerStorage")
local ris = require(ServerStorage.ReplaceInStrings)

local function test(name, input, replaceFunc, output)
	--	if output is a number, 'replaceFunc' must run that many times
	local times = 0
	Nexus:RegisterUnitTest(name, function(t)
		local result = ris(input, function(a, b) times += 1; return replaceFunc(a, b, t, times) end)
		if type(output) == "string" then
			t:AssertEquals(result, output)
		elseif output then
			t:AssertEquals(times, output)
		end
	end)
end
test("Simple double quote", [=[
s = "hi"
]=], function(s, open, t, times)
	t:AssertEquals(s, "hi")
	t:AssertEquals(open, '"')
end, 1)

test("Two single quotes", [=[
s = 'hi'
print('there')
]=], function(s, open, t, times)
	t:AssertEquals(open, "'")
	t:AssertEquals(s, times == 1 and "hi" or "there")
end, 2)

local simple = "s = [[s]]"
for _, replace in ipairs({"", "'", '"'}) do
	local newSimple = simple
	if replace ~= "" then
		newSimple = simple:gsub("%[%[", replace):gsub("%]%]", replace)
	end
	test("No replace in " .. (replace or "[["), newSimple, function() end, newSimple)
	test("Replace in " .. (replace or "[["), newSimple, function() return "!" end, "s" .. newSimple:sub(2):gsub("s", "!"))
end

test("Not confused by nested blocks", "print([=[x[==[y]]=]", function(s, open, t)
	t:AssertEquals(s, "x[==[y]")
	t:AssertEquals(open, "[=[")
end, 1)

test("All types of strings",
	[==[print("'a", '"b', "c[[d]]", [[e'']], [=[f]][[g]]]=], "") --"comment"]==],
	function(_, _, _, n) return tostring(n) end,
	[==[print("1", '2', "3", [[4]], [=[5]=], "6") --"comment"]==])

return true