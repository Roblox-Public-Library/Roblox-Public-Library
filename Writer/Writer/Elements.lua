--[[Elements represent various book-related concepts
These includes things that can be displayed (ex Text, Image) or modify what is to be displayed (Alignment, Page, Turn)
]]

local Format = require(script.Parent.Format)

local Elements = {}
-- Element:Handle implementations should not consider/reference pages, only lines
--	Some PreRender specific ones (like Page and Turn) will need to and that's fine since they aren't to be passed to Render

local function new(name)
	local class = {}
	class.__index = class
	Elements[name] = class
	return class
end
local Text = new("Text")
function Text.new(text, format)
	if format and getmetatable(format) ~= Format then error("Not a Format") end -- todo proper Assert
	return setmetatable({
		Text = text,
		Format = format or Format.new(),
	}, Text)
end

local Alignment = new("Alignment")
function Alignment.new(alignment)
	return setmetatable({
		alignment = alignment,
	}, Alignment)
end
function Alignment:Handle(cursor)
	if not cursor:AtStartOfLine() then
		cursor:AdvanceToNextLine()
	end
	cursor:SetNextAlignment(self.alignment) -- todo to be used when a label is created next
end

local HLine = new("HLine")
function HLine.new(char)
	return setmetatable({
		Line = char or true, -- true indicates solid line
	}, HLine)
end
function HLine:Handle(cursor)
	cursor:EnsureAtStartOfFullLine()
	cursor:HandleLine(self) -- and depending on type of cursor it eithers creates the line or just reserves the space for it
end

local Image = new("Image")
function Image.new(decalId, width, height, alignment, noWrap)
	--	alignment:Enum.TextXAlignment.Left/Center/Right
	--	noWrap:bool - has no effect if alignment is Center
	return setmetatable({
		DecalId = decalId,
		Width = width,
		Height = height,
		Alignment = alignment,
		NoWrap = noWrap,
	}, Image)
end
function Image:Handle(cursor)

	cursor:HandleImage(self)
end

local Quote = new("Quote")
function Quote:Handle(cursor)
	-- go to next line then indent each new line until end tag
	--[[

[IMAGE]
[IMAGE] >>>quote
[IMAGE] >>>quote
>>>quote 				<-- TODO don't allow this
>>>quote


	]]
end

return Elements