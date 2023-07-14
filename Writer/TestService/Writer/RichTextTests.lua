return function(tests, t)


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Writer = ReplicatedStorage.Writer
local RichText = require(Writer.RichText)
local Colors = require(Writer.Colors)
local ReaderConfig = require(Writer.ReaderConfig)
local parseText = require(Writer.CustomMarkdown).ParseText
local parseArgs = {Testing = true, AllowTagSeparator = true}
local function parse(text)
	return parseText(text, parseArgs)
end

local config = ReaderConfig.new(Enum.Font.SourceSans, 30, require(Writer.Colors).Light)
local plainFormat = require(Writer.Format).new()

if false then -- Visual Test
	local sg = game.StarterGui:FindFirstChild("RichTextVisualTest")
	if sg then
		sg:ClearAllChildren()
	else
		sg = Instance.new("ScreenGui")
		sg.Name = "RichTextVisualTest"
		sg.Parent = game.StarterGui
	end
	Instance.new("UIListLayout", sg)

	tests.VisualTest = {
		test = function(text)
			local x = Instance.new("TextLabel")
			x.RichText = true
			x.Font = "SourceSans"
			x.TextSize = 30
			local other
			x.Text, other = RichText.GetFittingText(config, text, plainFormat, 200)
			print(x.Text, "|", other)
			x.Size = UDim2.new(0, 200, 0, 30)
			x.Parent = sg
		end,
		args = {
			"hi there, how are you?",
			"second \240\159\152\128 line\240\159\152\128\240\159\152\128\240\159\152\128",
			"aReallyReallyReallyReallyLongWord",
		}
	}
end

tests.GetFittingText = {
	test = function(text, expectedFits)
		local fits, rest = RichText.GetFittingText(config, text, plainFormat, 200)
		t.equals(fits, expectedFits)
		t.equals(rest, text:sub(#expectedFits + 1))
	end,
	argsLists = {
		{name = "simple", "hi there, how are you?", "hi there, how are "},
		-- This next one is commented out because utf8 is no longer allowed to be split on (but the one after that is a variant assuming utf8 cannot be split on)
		--{name = "utf8", "second \240\159\152\128 line\240\159\152\128\240\159\152\128\240\159\152\128", "second \240\159\152\128 line\240\159\152\128"},
		{name = "utf8", "second \240\159\152\128 line\240\159\152\128\240\159\152\128\240\159\152\128", "second \240\159\152\128 "},
		{name = "long word", "aReallyReallyReallyReallyLongWord", "aReallyReallyReall"}
	}
}

local normalSize = 36
local config = ReaderConfig.new(Enum.Font.SourceSans, normalSize, Colors.Light)
local smallSize = ('size="%d"'):format(config:GetSize("Small"))
local largeSize = ('size="%d"'):format(config:GetSize("Large"))
local subSize = ('size="%d"'):format(config:GetSize("Normal", "Sub"))
tests.FromTextElements = {
	test = function(input, expected)
		t.equals(RichText.FromTextElements(parse(input), config), expected)
	end,
	argsLists = {
		{name = "basics work",
			'**bold** *italics* __underline__ ~~strikethrough~~',
			'<b>bold</b> <i>italics</i> <u>underline</u> <s>strikethrough</s>',
		},
		{name = "overlapping formatting",
			'**bold *italics** italics but no bold* none',
			'<b>bold <i>italics</i></b><i> italics but no bold</i> none',
		},
		{name = "font",
			'<arial>arial<green> +green</arial> just green<large;cartoon> mix <small>small',
			'<font face="Arial">arial<font color="#00FF00"> +green</font></font><font color="#00FF00"> just green<font face="Cartoon"><font ' .. largeSize .. '> mix </font><font ' .. smallSize .. '>small</font></font></font>',
		},
		{name = "don't specify default font",
			'text <arial>arial <sourcesans>sourcesans',
			'text <font face="Arial">arial </font>sourcesans',
			{Font = Enum.Font.SourceSans},
		},
		{name = "subscript",
			-- Note: sub/super reduce size but don't affect position, so it's wrong for using code to mix them
			'text<sub>sub</sub> after',
			'text<font ' .. subSize .. '>sub</font> after',
		},
		-- Unimplemented optimizations:
		-- {name = "consistent simple formatting put at beginning and end",
		-- 	'<arial>*A*<cartoon>*B*',
		-- 	'<b><font face="Arial">A</font><font face="Cartoon">B</font></b>',
		-- },
	},
}


end -- function(tests, t)