--[[Elements represent various book-related concepts
These includes things that can be displayed (ex Text, Image) or modify what is to be displayed (Alignment, Page, Turn)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)

local Format = require(script.Parent.Format)
local Styles = require(script.Parent.Styles)

local Elements = {}
function Elements.Alignment(alignment)
	return {
		Type = "Alignment",
		Alignment = alignment,
	}
end
function Elements.Bar(ofString)
	return {
		Type = "Bar",
		Line = ofString or true,
	}
end
function Elements.Chapter(name, text, format)
	--	Note that 'name' and 'text' are lists of elements
	return {
		Type = "Chapter",
		Name = name, -- for navigation
		Text = text or name, -- for display
		Format = format or Format.Plain, -- note: this is removed after PreRender
	}
end
function Elements.Section(name, text, format)
	--	Note that 'name' and 'text' are lists of elements
	return {
		Type = "Section",
		Name = name, -- for navigation
		Text = text or name, -- for display
		Format = format or Format.Plain, -- note: this is removed after PreRender
	}
end
function Elements.ChapterNamingStyle(style)
	return {
		Type = "ChapterNamingStyle",
		Style = style,
	}
end
function Elements.Clear()
	return {Type = "Clear"}
end
function Elements.Flag(name)
	return {
		Type = "Flag",
		Name = name,
	}
end
function Elements.Header(text, size)
	--	Note that 'text' is a list of elements
	return {
		Type = "Header",
		Text = text,
		Size = size,
	}
end
function Elements.Page()
	return {Type = "Page"}
end
function Elements.PageNumbering(style, startingNumber, invisible)
	return {
		Type = "PageNumbering",
		Style = style,
		StartingNumber = startingNumber,
		Invisible = invisible, -- true or the number of pages whose page number should be invisible
	}
end
function Elements.ParagraphIndentStyle(style)
	return {
		Type = "ParagraphIndent",
		Indent = Styles.ParagraphIndent[style],
	}
end
function Elements.ParagraphIndent(indent)
	return {
		Type = "ParagraphIndent",
		Indent = indent,
	}
end
function Elements.Turn()
	return {Type = "Turn"}
end
function Elements.Text(text, format)
	Assert.Is(format, "Format")
	return {
		Type = "Text",
		Text = text,
		Format = format or Format.new(),
	}
end
function Elements.TextBlock(elements)
	return {
		Type = "TextBlock",
		Elements = elements or {},
	}
end

-- local Quote = new("Quote")
-- function Quote:Handle(cursor)
-- 	-- go to next line then indent each new line until end tag
-- 	--[[

-- [IMAGE]
-- [IMAGE] >>>quote
-- [IMAGE] >>>quote
-- >>>quote 				<-- TODO don't allow this
-- >>>quote


-- 	]]
-- end

return Elements