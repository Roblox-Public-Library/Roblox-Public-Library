return function(tests, t)

local AntiSpamFunctions = require(game:GetService("ServerScriptService").Library.AntiSpamFunctions)

tests["GetPointValue works"] = {
	test = function(msg, points)
		t.equals(AntiSpamFunctions.GetPointValue(msg), points)
	end,
	argsLists = {
		{"GET FREE ROBUX AT YO_MAMA.COM", 10},
		{"GO TO BLOX.JOE FOR FREE ROUX", 10},
		{"blox.page in your browser for FREE REBEX", 22},
		{"r$", 4},
		{"$r", 4},
		{"r", 4},
		{"ayo what the dog {System} Visit YEAS.GROUP in your browser to claim your ROBUX reward!", 20},
		{name = "robux variant duplicates ignored", "$r robux r$", 4},
		{name = "duplicates ignored", "free FREE free", 3},
		{name = "punctuation ignored", "free! go to. browser?", 9},
		{name = "whole words only", "roblox", 0},
		{"Hello, how are you?", 0},
	}
}

end