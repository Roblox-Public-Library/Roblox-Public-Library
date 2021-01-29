--[[Cursors deal with (pre)rendering Elements (using Roblox's RichText format where appropriate)
Cursor(availSpace, config) - keeps track of where the next element can be placed
	:AtStartOfFullLine and other common functionality
	abstract :Handle___(element)
PreRender:Cursor - (List<element> for a book) -> List<List<element> on a page>
	NOTE Will probably need more complexity in return value to handle navigation support
	:FinishAndGetPages()
Render(..., pageInstance):Cursor - (List<element> for one page) are rendered onto the specified page
	Note: Render is not meant for multi-page elements ('page' and 'turn')
	:Finish()

Plan - examples of PreRender vs Render:
PreRender
	:HandleLine
		line element on the current page
	:HandleText(textElement which has .Format .Text)
		must be aware of availSpace (AND/OR is that the Text element?). Can get a new page for PreRender!
		May split textElement onto various pages
Render
	:HandleLine
		line instance parented to the only page instance in the cursor
	:HandleText
		TODO must ensure that no text element has too many characters in it (16384 is the max, including font tag characters)

'*' means not valid for Render (PreRender figures out what gets on which page)
page*: ends the current page
turn*: ends pages until on a left page
header: new line & different font may add navigation data [note: *can* be beside an image]
chapter: similar to page & header
image: left/right lanes & center or nowrap means nothing to either side
box: text with a border around it
quote: more margin/padding in addition to potentially a different font
text
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local ObjectPool = require(Utilities.ObjectPool)

local Format = require(script.Parent.Format)
local startTag = "<%s>"
local startTagArgs = "<%s %s>"
local endTag = "</%s>"
local function simpleTag(key, letter)
	local open = startTag:format(letter)
	local close = endTag:format(letter)
	return {
		Key = key,
		Open = function() return open end,
		Close = function() return close end,
	}
end
local closeFont = function() return "</font>" end
local function fontTag(name, open)
	return {
		Key = name,
		Open = open,
		Close = closeFont,
	}
end
local formatTags = {
	-- In this list of tags, if one is likely to be toggled frequently (and/or is short in length) it should be last
	fontTag("Face", function(config, face)
		-- todo consider user's font preferences!
		return string.format('<font face="%s">', face)
	end),
	fontTag("Color", function(config, color)
		return string.format('<font color="%s">', config.Colors.Hex[color])
	end),
	fontTag("Size", function(config, size)
		return string.format('<font size="%d">', config:GetSizeFor(size))
	end),
	simpleTag("Strikethrough", "s"),
	simpleTag("Underline", "u"),
	simpleTag("Bold", "b"),
	simpleTag("Italics", "i"),
}
local formatKeyToTag = {}
for _, tag in ipairs(formatTags) do
	formatKeyToTag[tag.Key] = tag
end

local function handleEscapes(text)
	--	Escape user text to avoid conflict with Roblox's RichText formatting
	return text
		:gsub("<", "&lt;")
		:gsub("&", "&amp;")
		-- Quotation marks and '>' can be escaped but they don't currently have to be (at least not outside of tags)
end
local formatKeyToProp = { -- formatting key to Roblox property, if non-tag version supported
	Color = "TextColor3",
	Face = "Font",
	Size = "TextSize",
}
do -- todo used by RenderLabel:handleFormatting (not moved over yet)
	local keyToDefault = {
		Face = "DefaultFont",
		Color = "DefaultColor",
		-- Size already won't ever use the default so no entry for that is needed
	}
	local function getFormatValue(config, format, key)
		local value = format[key]
		return (not value or value ~= config[keyToDefault[key]]) and value or nil
	end
end
local function generateFormatStringForFormatting(config, format)
	--	If format has bold and a non-standard font, returned value could be <b><font face="Arial">%s</font></b>
	--	This is useful for measuring RichText
	error("TODO - merge config defaults into temporary new format and use that for this function so that measureText doesn't need config")
	local formatString = {}
	local n = 0
	local stack = {}
	for key, value in pairs(format) do
		local tag = formatKeyToTag[key]
		n += 1
		formatString[n] = tag.Open(config, value)
		stack[n] = key
	end
	n += 1
	formatString[n] = "%s"
	for i = #stack, 1, -1 do
		local tag = stack[i]
		n += 1
		formatString[n] = tag.Close(config, format[tag.Key])
	end
	return table.concat(formatString)
end

local lineHeight = 15 -- (TODO) temporary variable for line height
local Cursor = {}

local Base = {}
Base.__index = Base
function Base.new(availSpace, config)
	return setmetatable({
		availSpace = availSpace,
		config = config,
		format = Format.new(),
		nextAlignment = Enum.TextXAlignment.Left,
	}, Base)
end
function Base:SetNextAlignment(alignment)
	self.nextAlignment = alignment
end
function Base:AtStartOfFullLine()
	return self.availSpace:FullWidthAvailable()
end
function Base:AdvanceToNextFullLine()
	-- todo this is supposed to go to below images/text which may be below the current availSpace entirely
	self.availSpace:NewLine() -- todo spaceBetweenLines
end
function Base:EnsureAtStartOfFullLine()
	if not self:AtStartOfFullLine() then
		self:AdvanceToNextFullLine()
	end
end

local PreRender = setmetatable({}, Base)
Cursor.PreRender = PreRender
PreRender.__index = PreRender
local base = PreRender.new
function PreRender.new(pageSpace, config)
	local self = setmetatable(base(pageSpace:Clone(), config), PreRender)
	self.pageSpace = pageSpace
	self.curPage = {} -- List of elements for the current page
	self.nElements = 0 -- on current page
	self.pages = {} -- List of pages so far
	self.nPages = 0
	return self
end
function PreRender:addPageToPages()
	local n = self.nPages + 1
	self.nPages = n
	self.pages[n] = self.curPage
end
function PreRender:NewPage()
	self.availSpace = self.pageSpace:Clone()
	self:addPageToPages()
	self.curPage = {}
end
function PreRender:FinishAndGetPages()
	if self.curPage and #self.curPage > 0 then
		self:addPageToPages()
		self.curPage = nil
	end
	return self.pages
end

function PreRender:addToPage(element)
	-- todo which was found to be most efficient/easy to understand?
	--	and how costly is it to be in a function?
	-- local n = self.nElements + 1
	-- self.nElements = n
	-- self.curPage[n] = element
	-- -- or
	-- self.nElements += 1
	-- self.curPage[self.nElements] = element
	-- -- or
	table.insert(self.curPage, element) -- todo
end
function PreRender:addFullWidthElement(element, height)
	--	Add a full-page-width element (that cannot be broken up) to the next page it fits on
	self.availSpace:EnsureNewLine() -- todo spaceBetweenLines
	if not self.availSpace:DoesItFitFullWidth(height) then
		self:NewPage()
	end
	self:addToPage(element)
end
function PreRender:addElement(element, width, height)
	--	Add an element (that cannot be broken up) to the next page it fits on
	local result = self.availSpace:DoesItFit(width, height)
	if result == "newline" then
		self.availSpace:NewLine() -- todo spaceBetweenLines
		result = self.availSpace:DoesItFit(width, height)
		if result == "newline" then
			print(element)
			error("element does not fit on new line")
		end
	end
	if not result then
		self:NewPage()
		result = self.availSpace:DoesItFit(width, height)
		if not result then
			print(element)
			error("element does not fit on a new page")
		elseif result == "newline" then
			print(element)
			error("element does not fit on new line")
		end
	end
	self.availSpace:UseSpace(width, height)
	self:addToPage(element)
end

function PreRender:HandleLine(line)
	self:addFullWidthElement(line, lineHeight)
end
function PreRender:HandleText(text)

end


local n = 0
local linePool = ObjectPool.new(function()
	local line = Instance.new("Frame")
	n += 1; line.Name ..= n
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Size = UDim2.new(1, 0, 0, 1) -- todo width of line (that is, height offset)?
	line.BackgroundColor3 = line.BorderColor3
	line.BorderSizePixel = 0
	return line
end, 5)

local Render = setmetatable({}, Base)
Render.__index = Render
Cursor.Render = Render
local base = Render.new
function Render.new(availSpace, config, pageInstance) -- todo might need offset if render can be for part of a page
	local self = setmetatable(base(availSpace, config), Render)
	self.pageInstance = pageInstance
	--.currentLabel:RenderLabel
	return self
end
function Render:finishCurrentLabel()
	if self.currentLabel then
		self.currentLabel:Finish()
		self.currentLabel = nil
	end
end
function Render:HandleLine(line)
	self:finishCurrentLabel()
	if line.Char then
		error("todo - char based line")
	else
		local line = linePool:Get()
		line.Position = UDim2.new(0.5, 0, 0, self.availSpace:UseHeight(lineHeight) + lineHeight / 2) -- todo implement self.availSpace:UseHeight(lineHeight) - subtacts the desired lineHeight from availSpace and returns the previous number; check udim2 stuff
		line.Parent = self.pageInstance
	end
end
--[[
If we're at the start of a line, we can use availSpace entirely
Natural wrapping is okay - we just want to keep adding text until Bounds.Y > max

If we're in the middle of a line, we have to have a single-line RenderLabel
	Its height restriction is still availSpace.Y!

If we have HandleText 2x, we can re-use label in certain circumstances
]]
function Render:HandleText(text) -- text element
	local currentLabel = self.currentLabel
	while true do
		if not currentLabel then
			if self:AtStartOfFullLine() then
				currentLabel = RenderLabel.new(self.availSpace, self.parent, self.config)
			else
				currentLabel = RenderSingleLineLabel.new(self.availSpace, self.parent, self.config)
			end
		end
		local nonDisplayedText = currentLabel:AppendText(text.Text, text.Formatting) -- todo AppendText also needs to adjust availSpace
		if nonDisplayedText then
			-- Label ran out of available space (ex can happen if an image on the left side ends)
			error("todo how to figure out availSpace after image ended")
		else
			break
		end
	end
	self.currentLabel = currentLabel
end
function Render:Finish()
	self:finishCurrentLabel()
end

return Cursor