return function(tests, t)


local Writer = game:GetService("ReplicatedStorage").Writer
local Elements = require(Writer.Elements)
local PreRender = require(Writer.PreRender)
local TBF_MERGES_BLOCKS = require(Writer.TextBlockFactory).TBF_MERGES_BLOCKS
local CustomMarkdown = require(Writer.CustomMarkdown)
local ReaderConfig = require(Writer.ReaderConfig)
local Colors = require(Writer.Colors)
local Format = require(Writer.Format)

local parseArgs = {Testing = true}
local function parse(text)
	return CustomMarkdown.ParseText(text, parseArgs)
end

local innerPageSize = Vector2.new(400, 200)
local pageSize = PreRender.GetOuterPageSize(innerPageSize)

local defaultPageNumbering = {PreRender.DefaultStartingPageNumbering}
local config = ReaderConfig.new(Enum.Font.SourceSans, 12, Colors.Light)
config.DisableSize0Newline = true
local function PreRender_new(pageSize, _config)
	return PreRender.new(pageSize, _config or config, nil, true)
end
local function PreRender_All(elements, pageSize, config)
	return PreRender_new(pageSize, config):HandleAll(elements)
end

local function checkBookHasDefaults(book)
	t.equals(#book.Chapters, 1)
	t.equals(book.Chapters[1].StartingPageIndex, 1)
	t.tablesEqualRecursive(book.PageNumbering, defaultPageNumbering, "PageNumbering is default")
end

function tests.twoBarsOnOnePageWithCorrectPosSize()
	local elements = {
		Elements.Bar(),
		Elements.Bar(),
	}
	local book = PreRender_All(elements, pageSize, config)
	checkBookHasDefaults(book)
	local pages = book.Pages
	t.equals(#pages, 1)
	local pg = pages[1]
	t.equals(pg.Index, 1)
	t.tablesEqualRecursive(pg.Elements, {
		{Type = "Bar", Line = true, Position = Vector2.new(0, 0), Size = Vector2.new(400, 12)},
		{Type = "Bar", Line = true, Position = Vector2.new(0, 12), Size = Vector2.new(400, 12)},
	})
end

function tests.pageCommandAdvances()
	local book = PreRender_All({
		Elements.Bar(),
		Elements.Page(),
		Elements.Bar(),
	}, pageSize, config)

	t.equals(#book.Pages, 2, "2 pages")
	t.equals(#book.Pages[1].Elements, 1, "1 bar on 1st page")
	t.equals(#book.Pages[2].Elements, 1, "1 bar on 2nd page")
end

function tests.turnCommandAdvancesToLeftPage()
	local book = PreRender_All({
		Elements.Bar(),
		Elements.Turn(),
		Elements.Bar(),
		Elements.Page(), -- Make sure Turn doesn't always advance 2 pages
		Elements.Turn(),
		Elements.Bar(),
	}, pageSize, config)

	t.equals(#book.Pages, 5)
	t.equals(#book.Pages[1].Elements, 1, "1 bar on 1st page")
	t.equals(#book.Pages[2].Elements, 0, "Blank 2nd page")
	t.equals(#book.Pages[3].Elements, 1, "1 bar on 3rd page")
	t.equals(#book.Pages[4].Elements, 0, "Blank 4th page")
	t.equals(#book.Pages[3].Elements, 1, "1 bar on 5th page")
end

function tests.pageOverflowWorks()
	local list = table.create(100)
	for i = 1, 100 do
		list[i] = Elements.Bar()
	end
	local book = PreRender_All(list, nil, config)

	t.greaterThan(#book.Pages, 1, "More than 1 page")
	t.greaterThan(#book.Pages[1].Elements, 1, "More than 1 bar on a page")
end

function tests.textWorks()
	local pr = PreRender_new(pageSize, config)
	pr:SetParagraphIndent("> ")
	local book = pr:HandleAll(parse("some **text** as an *example*"))

	t.equals(#book.Pages[1].Elements, 1)
	local textBlock = book.Pages[1].Elements[1]
	t.equals(textBlock.Type, "TextBlock")
	t.equals(textBlock.RichText, "> some <b>text</b> as an <i>example</i>")
end

tests.paragraphIndentWorks = {
	test = function(txt, check, pageOverride)
		local pr = PreRender_new(pageSize, config)
		local book = pr:HandleAll(parse(txt))
		check(book.Pages[pageOverride or 1].Elements)
	end,
	argsLists = {
		{name="custom indent char", "<indent,\\> >some **text** as an *example*", function(elements)
			t.equals(#elements, 1)
			local textBlock = elements[1]
			t.equals(textBlock.Type, "TextBlock")
			t.equals(textBlock.RichText, "> some <b>text</b> as an <i>example</i>")
		end},
		{name="newline indent on top line", "<indent,newline> some text\nnew paragraph", function(elements)
			t.equals(#elements, 2)
			local textBlock = elements[1]
			t.equals(textBlock.Type, "TextBlock")
			t.equals(textBlock.Position.Y, 0)
			t.equals(textBlock.RichText, "some text")

			textBlock = elements[2]
			t.equals(textBlock.Type, "TextBlock")
			t.equals(textBlock.Position.Y, config:GetSize() * 2)
			t.equals(textBlock.RichText, "new paragraph")
		end},
		{name="newline indent condenses newline", "\n<indent,newline>\nsome text", function(elements)
			t.equals(#elements, 1)
			local textBlock = elements[1]
			t.equals(textBlock.Type, "TextBlock")
			t.equals(textBlock.Position.Y, 0)
			t.equals(textBlock.RichText, "some text")
		end},
		{name="newline indent, text & bar & text", "<indent,newline>text<bar>text", function(elements)
			t.equals(#elements, 3)

			local bar = elements[2]
			t.equals(bar.Type, "Bar")
			t.equals(bar.Position.Y, config:GetSize() * 2, "bar after text positioned correctly")

			local txt = elements[3]
			t.equals(txt.Position.Y, config:GetSize() * 4, "text after bar positioned correctly")
		end},
		{name="newline indent & 2 bars", "<indent,newline><bar><bar>", function(elements)
			t.equals(#elements, 2)
			t.equals(elements[1].Position.Y, 0)
			t.equals(elements[2].Position.Y, config:GetSize() * 2, "2nd bar positioned correctly")
		end},
		{name="newline indent bar & section", "<indent,newline><bar><section,s>", function(elements)
			t.equals(#elements, 2)
			local e = elements[2]
			t.equals(e.Type, "TextBlock")
			t.equals(e.Position.Y, config:GetSize() * 2)
		end},
		{name="newline indent & new page & header", "<indent,newline><page>\n<header,Hi>", function(elements)
			t.equals(#elements, 1)
			local textBlock = elements[1]
			t.equals(textBlock.Type, "TextBlock")
			t.equals(textBlock.Position.Y, 0)
			t.equals(textBlock.RichText, "Hi")
		end, 2},
		{name="newline indent & turn & header", "<indent,newline><turn>\n<header,Hi>", function(elements)
			t.equals(#elements, 1)
			local textBlock = elements[1]
			t.equals(textBlock.Type, "TextBlock")
			t.equals(textBlock.Position.Y, 0)
			t.equals(textBlock.RichText, "Hi")
		end, 3},
		{name="newline indent & page & section", "<indent,newline><page><section>", function(elements)
			t.equals(#elements, 1)
			local textBlock = elements[1]
			t.equals(textBlock.Type, "TextBlock")
			t.equals(textBlock.Position.Y, 0)
		end, 2},
		{name="newline indent & turn & section", "<indent,newline><turn><section>", function(elements)
			t.equals(#elements, 1)
			local textBlock = elements[1]
			t.equals(textBlock.Type, "TextBlock")
			t.equals(textBlock.Position.Y, 0)
		end, 3},
		{name="indent starts on blank line", "text1<indent>text2\n<indent>\ntext3", function(elements)
			t.equals(#elements,3)
			t.equals(elements[1].Position.Y,0)
			t.equals(elements[2].Position.Y,config:GetSize())
			t.equals(elements[3].Position.Y,2*config:GetSize())
		end}
	}
}
tests.spacing = {
	test = function(txt, check, pageOverride)
		local pr = PreRender_new(pageSize, config)
		local book = pr:HandleAll(parse(txt))
		check(book.Pages[pageOverride or 1].Elements)
	end,
	argsLists = {
		{name="chapter & text", "<chapter,CName>\nText", function(elements)
			t.equals(#elements, 2)
			t.equals(elements[1].Position.Y, 0)
			t.equals(elements[2].Position.Y, config:GetSize("Chapter"))
		end},
		{name="center text & left text", "<center>text1<left>text2", function(elements)
			t.equals(#elements, 4)
			t.equals(elements[2].Position.Y, 0)
			t.equals(elements[4].Position.Y, config:GetSize())
		end},
		{name="center large text & normal left text", "<center><large>text1</large><left>\ntext2", function(elements)
			t.equals(elements[#elements].Position.Y, config:GetSize("Large"))
		end},
	}
}

local function size(text, n)
	return string.format('<font size="%d">%s</font>', n, text)
end

--local indent = PreRender.DefaultParagraphIndent
local function verifyIndented(element, text)
	-- t.equals(element.RichText, indent .. text) -- Original
	t.equals(element.RichText, text)
	t.gt(element.Position.X, 0, "element should be indented over")
end
local function assertSubWorking(e, text, subOrSuper, sizeKey, configOverride)
	t.equals(e.RichText, text)
	t.equals(e.TextSize, (configOverride or config):GetSize(sizeKey, subOrSuper))
end
local function analyzeRichText(elements, expected, msg)
	if TBF_MERGES_BLOCKS then
		t.equals(#elements, 1, "only need 1 TextBlock", msg)
		t.equals(elements[1].RichText, expected, msg)
	else
		local i = 0
		for line in expected:gmatch("[^\n]+") do
			i += 1
			t.equals(elements[i] and elements[i].RichText, line, msg)
		end
		t.equals(#elements, i, msg)
	end
end
tests.text = {
	test = function(text, check)
		check(PreRender_All(parse(text), pageSize, config))
	end,
	argsLists = {
		{name = "right alignment", "<right>text", function(book)
			t.equals(#book.Pages, 1)
			local elements = book.Pages[1].Elements
			t.equals(#elements, 2)
			t.equals(elements[1].Alignment, Enum.TextXAlignment.Right)
			t.equals(elements[2].RichText, "text")
			t.equals(elements[2].Alignment, Enum.TextXAlignment.Right)
		end},
		{name = "right alignment subscript", "<right>text<sub,sub>", function(book)
			t.equals(#book.Pages, 1)
			local elements = book.Pages[1].Elements
			t.equals(#elements, 3)
			local tb = elements[2]
			t.equals(tb.RichText, "text")
			t.equals(tb.Alignment, Enum.TextXAlignment.Right)
			t.greaterThan(tb.Position.X, 0)
		end},
		{name = "multiline subscript", "Line1<sub,sub>\nLine2<sup,sup>", function(book)
			t.equals(#book.Pages, 1)
			local elements = book.Pages[1].Elements
			t.equals(#elements, 4)
			verifyIndented(elements[1], "Line1")
			assertSubWorking(elements[2], "sub", "Sub")
			t.equals(elements[2].RichText, "sub")
			verifyIndented(elements[3], "Line2")
			assertSubWorking(elements[4], "sup", "Super")
			-- Note: these tests fail for some configurations of the Sizes module and text size in 'config' (though the result isn't far off)
			t.greaterThanEqual(elements[2].Position.Y, elements[1].Position.Y, "top of subscript is lower than rest of line")
			t.greaterThanEqual(elements[2].Position.Y + elements[2].Size.Y, elements[1].Position.Y + elements[1].Size.Y, "bottom of subscript is lower than rest of line")
			t.lessThan(elements[4].Position.Y, elements[3].Position.Y, "top of superscript is higher than rest of line")
			t.lessThan(elements[4].Position.Y + elements[2].Size.Y, elements[3].Position.Y + elements[3].Size.Y, "bottom of superscript is higher than rest of line")
		end},
		{name = "multi-subscript same line", "Line1<sub,sub><small> Text<sub,sub></small>", function(book)
			t.equals(#book.Pages, 1)
			local elements = book.Pages[1].Elements
			t.equals(#elements, 4)
			verifyIndented(elements[1], "Line1")
			assertSubWorking(elements[2], "sub", "Sub")
			t.greaterThanEqual(elements[2].Position.Y, elements[1].Position.Y, "top of subscript is lower than rest of line")
			t.greaterThanEqual(elements[2].Position.Y + elements[2].Size.Y, elements[1].Position.Y + elements[1].Size.Y, "bottom of subscript is below bottom of line")
			t.equals(elements[3].RichText, " Text")
			t.equals(elements[3].TextSize, config:GetSize("Small"))
			assertSubWorking(elements[4], "sub", "Sub", "Small")
			t.greaterThanEqual(elements[4].Position.Y, elements[3].Position.Y, "top of subscript is lower than rest of line")
			t.greaterThanEqual(elements[4].Position.Y + elements[4].Size.Y, elements[3].Position.Y + elements[3].Size.Y, "bottom of subscript is below bottom of line")
		end},
		{name = "multiline then subscript", "Line1\nLine2<sub,sub>", function(book)
			t.equals(#book.Pages, 1)
			local elements = book.Pages[1].Elements
			t.equals(#elements, 3)
			verifyIndented(elements[1], "Line1")
			verifyIndented(elements[2], "Line2")
			assertSubWorking(elements[3], "sub", "Sub")
			t.greaterThanEqual(elements[3].Position.Y, elements[2].Position.Y, "top of subscript is lower than rest of line")
			t.greaterThanEqual(elements[3].Position.Y + elements[3].Size.Y, elements[2].Position.Y + elements[2].Size.Y, "bottom of subscript is lower than rest of line")
		end},
		{name = "smaller font at bottom of line", "Line1<sub,.><small> text</small>", function(book)
			t.equals(#book.Pages, 1)
			local elements = book.Pages[1].Elements
			t.equals(#elements, 3)
			t.greaterThanEqual(elements[3].Position.Y, elements[1].Position.Y, "top of smaller text should be lower than rest of line")
			t.lessThan(elements[3].Position.Y + elements[3].Size.Y, elements[1].Position.Y + elements[1].Size.Y, "bottom of smaller text should be higher up than larger text")
		end},
		{name = "\\n align", "a\n<right>b", function(book)
			t.equals(#book.Pages, 1)
			local elements = book.Pages[1].Elements
			t.equals(elements[1].RichText, "a")
			t.equals(elements[3].RichText, "b")
		end},
		{name = "indented! align \\n", "<indent,!>a<right>\nb", function(book)
			t.equals(#book.Pages, 1)
			local elements = book.Pages[1].Elements
			t.equals(elements[1].RichText, "!a")
			t.equals(elements[3].RichText, "b")
		end},
	},
}

local bigConfig = ReaderConfig.new(Enum.Font.SourceSans, 100, Colors.Light)
bigConfig.DisableSize0Newline = true
tests.textWrappingWorks = {
	test = function(list, check, custom)
		-- Widths: '!' is 23, 'a' is 40, ' ' is 16
		local pr = PreRender_new(PreRender.GetOuterPageSize(Vector2.new(121, 300)), bigConfig)
		pr:SetParagraphIndent("!")
		if custom then custom(pr) end
		for _, s in ipairs(list) do
			pr:Handle(parse(s))
		end
		check(pr:FinishAndGetBookContent())
	end,
	argsLists = {
		{{"a", " ", "a"}, function(book)
			t.equals(#book.Pages, 1)
			t.equals(#book.Pages[1].Elements, 1, "only need 1 TextBlock")
			local tb = book.Pages[1].Elements[1]
			t.equals(tb.RichText, "!a a")
		end},
		{name = "wrapped spaces ignored", {"a", " ", "a", " ", "aaa", " ", "aaa"}, function(book)
			t.equals(#book.Pages, 1, "spaces at the beginning of wrapped lines should be ignored")
			local elements = book.Pages[1].Elements
			analyzeRichText(elements, "!a a\naaa\naaa")
			if TBF_MERGES_BLOCKS then
				t.equals(elements[1].Size, Vector2.new(121, 300), "Regardless of actual line size, when wrapping, use full line width for the sake of alignment")
			end
		end},
		{{"aaaaaaa"}, function(book)
			local pages = book.Pages
			t.equals(#pages, 1, "only 1 page required")
			t.equals(#pages[1].Elements, 3, "Should have 3 TextBlocks")
			local tb = pages[1].Elements[1]
			for i = 1, 2 do
				t.equals(pages[1].Elements[i].RichText, "aa", "#" .. i)
			end
			t.equals(pages[1].Elements[3].RichText, "aaa", "#3")
		end, function(pr)
			local availSpace = pr.availSpace
			availSpace:PlaceLeft(40, 100)
			availSpace:PlaceRight(1, 100)
			availSpace:PlaceRight(40, 100)
			pr:SetParagraphIndent("")
		end},
		{name = "newlines are paragraphs", {"a\na", "\n", "a"}, function(book)
			t.equals(#book.Pages, 1)
			analyzeRichText(book.Pages[1].Elements, "!a\n!a\n!a", "explicit newlines should have paragraph indent")
		end},
		{name = "2x newline is respected", {"a\n\na"}, function(book)
			t.equals(#book.Pages, 1)
			analyzeRichText(book.Pages[1].Elements, "!a\n\n!a")
		end},
		{name = "line height change", {"<small>a</small> a"}, function(book)
			t.equals(#book.Pages, 1)
			t.equals(#book.Pages[1].Elements, 1)
			local tb = book.Pages[1].Elements[1]
			t.equals(tb.RichText, "!a" .. size(" a", bigConfig:GetSize("Normal")))
		end},
		{name = "line height change above image", {"<small>a</small> a"}, function(book)
			t.equals(#book.Pages, 1)
			local e = book.Pages[1].Elements
			t.equals(#e, 1)
			t.equals(e[1].RichText, "!a" .. size(" a", bigConfig:GetSize("Normal")))
		end, function(pr)
			pr.availSpace:PlaceLeft(1, 80)
			pr.availSpace:PlaceLeft(60, 20) -- leaves room for both the 'a' and the ' ' (since the ' ' is not trimmed, being mid-line)
		end},
		{name = "subscript", {"a<sub>2</sub>"}, function(book)
			t.equals(#book.Pages, 1)
			local elements = book.Pages[1].Elements
			t.equals(#elements, 2)
			t.equals(elements[1].RichText, "!a")
			assertSubWorking(elements[2], "2", "Sub", nil, bigConfig)
			t.greaterThan(elements[2].Position.Y, elements[1].Position.Y)
			t.lessThan(elements[2].Size.Y, elements[1].Size.Y)
		end},
		{name = "superscript", {"a<sup>2</sup>"}, function(book)
			t.equals(#book.Pages, 1)
			local elements = book.Pages[1].Elements
			t.equals(#elements, 2)
			t.equals(elements[1].RichText, "!a")
			assertSubWorking(elements[2], "2", "Super", nil, bigConfig)
			t.lessThan(elements[2].Position.Y, elements[1].Position.Y)
			t.lessThan(elements[2].Size.Y, elements[1].Size.Y)
		end},
	},
}

tests.image = {
	test = function(text, check)
		local book = PreRender_All(parse(text), pageSize, config)
		t.equals(#book.Pages, 1)
		check(book.Pages[1].Elements)
	end,
	argsLists = {
		{"<image,1>", function(e)
			e = e[1]
			t.equals(e.Position.X, 0)
			t.equals(e.Size.X, 400)
			t.equals(e.Alignment, Enum.TextXAlignment.Center)
		end},
		{name = "square 25%h", "<image,1,25h,square>", function(e)
			e = e[1]
			local size = innerPageSize.Y / 4
			t.equals(e.Size, Vector2.new(size, size))
		end},
		{name = "square 100%h", "<image,1,100h,square>", function(e)
			e = e[1]
			local size = innerPageSize.Y
			t.equals(e.Size, Vector2.new(size, size))
		end},
		{name = "2r 25%h", "<image,1,25h,2r>", function(e)
			e = e[1]
			local height = innerPageSize.Y / 4
			t.equals(e.Size, Vector2.new(height * 2, height))
		end},
	}
}

tests.chapter = {
	test = function(text, check)
		check(PreRender_All(parse(text), pageSize, config))
	end,
	argsLists = {
		{"<chapternaming,chapter><chapter><chapter, Name >", function(book)
			t.equals(#book.Chapters, 2)
			t.equals(book.Chapters[1]:GetName(), "<b>Chapter 1</b>")
			t.equals(book.Chapters[2]:GetName(), "<b>Chapter 2: Name</b>")

			t.equals(#book.Pages, 2)
			local e = book.Pages[2].Elements
			t.equals(#e, 1)
			t.truthy(e[1].RichText:find("Name"))
		end},
		{name = "inherited formatting", "__<chapter,A><chapter>__", function(book)
			t.equals(#book.Pages, 2)
			t.equals(book.Pages[1].Elements[1].RichText, "<u><b>A</b></u>")
			t.equals(book.Pages[2].Elements[1].RichText, "<u><b>Chapter 2</b></u>")
		end},
		{name="small chapter", "<chapter,A<small>b>", function(book)
			t.equals(#book.Chapters, 1)
			local chapterElement = book.Pages[1].Elements[1]
			t.equals(#chapterElement.Elements, 2)
			t.equals(chapterElement.RichText, '<b>A<font size="15">b</font></b>')
			t.equals(chapterElement.TextSize, config:GetSize("Chapter"))
			t.equals(chapterElement.Size.Y, chapterElement.TextSize)
		end},
		{name="section surrounded by text", "Text. <section,Section Name> More Text.", function(book)
			t.equals(#book.Chapters, 1)
			local chapterElement = book.Pages[1].Elements[2]
			t.equals(chapterElement.Position.X, 0, "should be on a new line and be left-aligned")
			t.equals(chapterElement.Position.Y, config:GetSize("Normal"))
		end},
		{name="newline indent with consecutive sections", "<indent,newline><section><section>", function(book)
			t.equals(#book.Chapters, 2)
			local elements = book.Pages[1].Elements
			local chapterElementOne = elements[1]
			local chapterElementTwo = elements[2]
			t.equals(chapterElementTwo.Position.Y, config:GetSize("Chapter") + config:GetSize("Normal"))
		end},
	}
}

tests.pageNumbering = {
	test = function(text, check)
		check(PreRender_All(parse(text), pageSize, config))
	end,
	argsLists = {
		{"<pageNumbering,roman,invisible,3><page><pageNumbering,number>", function(book)
			t.equals(book:GetFormattedPageNumberForRender(1), "")
			t.equals(book:GetFormattedPageNumberForRender(2), "4")
		end},
	}
}

tests.formatNonText = {
	test = function(text, check)
		local book = PreRender_All(parse(text), pageSize, config)
		t.equals(#book.Pages, 1)
		check(book.Pages[1].Elements)
	end,
	argsLists = {
		{name="header uses TextSize", "<header,Title:Name>", function(elements)
			local e = elements[1]
			t.equals(e.TextSize, config:GetSize("Header"))
			t.equals(e.RichText, "Title:Name", "no font tags necessary")
		end},
		{name="stroke and header", "<stroke,nearblack,1,0><header,Title: Name>", function(elements)
			local e = elements[1].Elements[1]
			t.equals(e.Type, "Text")
			t.equals(e.Format.Size, "Header")
			t.truthy(e.Format.Stroke, "stroke must exist")
			t.equals(e.Format.Stroke.Color, "NearBlack")
			t.equals(#elements, 1)
		end},
		{name="header \\n text position test", "<header,large,Title: Name>\nBy: Author", function(elements)
			t.greaterThan(elements[1].Size.Y, 0)
			t.equals(elements[2].Position.Y, elements[1].Position.Y + elements[1].Size.Y, "position.Y correct")
		end},
	}
}

tests.block = {
	test = function(text, numPages, check)
		local book = PreRender_All(parse(text), pageSize, config)
		t.equals(#book.Pages, numPages)
		check(function(i) return book.Pages[i].Elements end)
	end,
	argsLists = {
		{name="block is on new lines", "a<block>b</block>c", 1, function(get)
			local e = get(1)
			local b = e[2]
			t.equals(e[1].Elements[1].Text, "a")
			t.equals(b.Type, "Block")
			t.equals(e[3].Elements[1].Text, "c")
			-- Ensure positions are good
			t.equals(e[1].Position.Y, 0)
			local extra = b.Margin + b.BorderThickness
			t.equals(b.Position.Y, 12 + extra)
			t.equals(b.Size.Y, 12 + b.Padding * 2, "block correct height") -- since size doesn't include margins/border
			t.equals(b.Size.X, 400 - extra * 2, "block correct width")
			t.equals(b.Elements[1].Size.X, 400 - (extra + b.Padding) * 2, "text in block correct width")
			local indentX = e[1].Position.X
			t.equals(b.Elements[1].Position.X, 0, "no indent inside block by default")
			t.equals(e[3].Position.X, indentX, "after block should be on new line")
			t.equals(e[3].Position.Y, b.Position.Y + b.Size.Y + extra)
		end},
		{name="block can be multiple lines", "a<block>b\nc</block>d", 1, function(get)
			local e = get(1)
			local b = e[2]
			local extra = b.Margin + b.BorderThickness
			t.equals(e[1].Elements[1].Text, "a")
			t.equals(b.Type, "Block")
			t.equals(e[3].Elements[1].Text, "d")
			-- Check size
			t.equals(b.Size.Y, 24 + b.Padding * 2, "block correct height")
			t.equals(b.Size.X, 400 - extra * 2, "block correct width")
			-- Check pos of last element
			t.equals(e[3].Position.Y, b.Position.Y + b.Size.Y + extra)
		end},
	}
}


end -- return function(tests, t)