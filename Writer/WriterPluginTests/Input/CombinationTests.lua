local Nexus = require("NexusUnitTesting")
local Combination = require(game.ServerStorage.BookWriterPlugin.Plugin.Input.Combination)

local Shift = Enum.ModifierKey.Shift
local Ctrl = Enum.ModifierKey.Ctrl
local Alt = Enum.ModifierKey.Alt
local Meta = Enum.ModifierKey.Meta
Nexus:RegisterUnitTest("Combinations work as expected", function(t) -- t:UnitTest (see below)
	for alt = 0, 1 do
		for shift = 0, 1 do
			for ctrl = 0, 1 do
				for meta = 0, 1 do
					local combination = Combination.Get(shift == 1, ctrl == 1, alt == 1, meta == 1)
					t:AssertEquals((shift == 1), Combination.Contains(combination, Shift), "shift")
					t:AssertEquals((ctrl == 1), Combination.Contains(combination, Ctrl), "ctrl")
					t:AssertEquals((alt == 1), Combination.Contains(combination, Alt), "alt")
					t:AssertEquals((meta == 1), Combination.Contains(combination, Meta), "meta")
				end
			end
		end
	end
end)
return true