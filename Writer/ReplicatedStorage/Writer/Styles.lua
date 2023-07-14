local RomanNumerals = require(script.Parent.RomanNumerals)
return {
	PageNumbering = {
		number = tostring,
		dash = function(i) return "- " .. i .. " -" end,
		roman = function(i) return RomanNumerals.ToRomanNumerals(i):lower() end,
		page = function(i) return "Page " .. i end,
		pg = function(i) return "Pg " .. i end,
	},
	PageNumberingSemiFormatted = {
		number = tostring,
		dash = tostring,
		roman = function(i) return RomanNumerals.ToRomanNumerals(i):lower() end,
		page = tostring,
		pg = tostring,
	},
	ChapterNaming = {
		--[[style = {
			{no name text list}
			{name text list, where 'true' means "replace with Name/Title elements"}
			"$Num" is replaced with the chapter number
		}]]
		chapter = {
			{"Chapter $Num"},
			{"Chapter $Num: ", true},
		},
		chapter2 = {
			{"Chapter $Num"},
			{"Chapter $Num\n", true},
		},
		number = {
			{"$Num"},
			{"$Num: ", true},
		},
		number2 = {
			{"$Num"},
			{"$Num\n", true},
		},
		dot2 = {
			{"\\*$Num\\*"},
			{"\\*$Num\\*\n", true},
		},
		custom = {
			{"Chapter $Num"},
			{true},
		},
	},
	ParagraphIndent = {
		tab = "     ",
		newline = "\n",
	}
}