local Format = require(script.Parent.Format)
local Colors = require(script.Parent.Colors)
local Elements = require(script.Parent.Elements)
local Sizes = require(script.Parent.Sizes)

local CustomMarkdown = {} -- Incrementally converts from elements to text and supports parsing from text into elements.
CustomMarkdown.__index = CustomMarkdown
function CustomMarkdown.new()
	return setmetatable({
		prevFormat = {},
	}, CustomMarkdown)
end
local formatSymbols = {
	{"Bold", "**"},
	{"Italics", "*"},
	{"Underline", "__"},
	{"Strikethrough", "~~"},
}
function CustomMarkdown:HandleText(element)
	local s = {}
	for _, obj in ipairs(formatSymbols) do
		local key, symbol = obj[1], obj[2]
		if self.prevFormat[key] ~= element.Format[key] then
			s[#s + 1] = symbol
		end
	end
	s[#s + 1] = element.Text
	self.prevFormat = element.Format
	return table.concat(s)
end
function CustomMarkdown:Finish()
	if not self.prevFormat then return "" end
	local s = {}
	for _, obj in ipairs(formatSymbols) do
		local key, symbol = obj[1], obj[2]
		if self.prevFormat[key] then
			s[#s + 1] = symbol
		end
	end
	return table.concat(s)
end

-- Parsing
local toggleItalics = function(formatting)
	formatting.Italics = not formatting.Italics
end
local isEscaped = function(text, i) -- returns true if text:sub(i, i) is escaped
	-- We need to look for an odd number of '\' before this point
	local start = i
	while true do
		i -= 1
		if i < 1 or text:sub(i, i) ~= "\\" then
			return (start - i) % 2 == 0
		end
	end
end
local function toggleBold(formatting) formatting.Bold = not formatting.Bold end
local function toggleUnderline(formatting) formatting.Underline = not formatting.Underline end
local function toggleStrikethrough(formatting) formatting.Strikethrough = not formatting.Strikethrough end
-- local symbols = {
-- 	-- {Text = "___", Action = function(formatting)
-- 	-- 	formatting.Underline = not formatting.Underline
-- 	-- 	formatting.Italics = not formatting.Italics
-- 	-- end},
-- 	{Text = "__", Action = toggleUnderline},
-- 	{Text = "**", Action = toggleBold},
-- 	{Text = "*", Action = toggleItalics},
-- 	{Text = "_", Action = toggleItalics},
-- 	{Text = "~~", Action = toggleStrikethrough},
-- }
-- local function getNextSymbol(text, startI)
-- 	while true do
-- 		local smallestI, nearestSymbol
-- 		for _, symbol in ipairs(symbols) do
-- 			local i = text:find(symbol.Text, startI, true)
-- 			if i and (not smallestI or i < smallestI) then
-- 				smallestI = i
-- 				nearestSymbol = symbol
-- 			end
-- 		end
-- 		if not smallestI or not isEscaped(text, smallestI) then
-- 			return smallestI, nearestSymbol
-- 		end
-- 		startI = smallestI + 1
-- 	end
-- end

local Parser = {}
-- Parser.__index = function(self, key)
-- 	local v = Parser[key]
-- 	return type(v) == "function"
-- 		and function(self, ...)
-- 			print(self.text:sub(1, self.index - 1) .. "|" .. self.text:sub(self.index, self.index) .. "|" .. self.text:sub(self.index + 1) .. "\tParser." .. key, ...)
-- 			return v(self, ...)
-- 		end or v
-- end
Parser.__index = Parser
function Parser.new(text)
	return setmetatable({
		text = text,
		index = 1,
		formatting = Format.new(),
		elements = {},
	}, Parser)
end
function Parser:FinishTextElement()
	if self.textSoFar then
		table.insert(self.elements, Elements.Text.new(table.concat(self.textSoFar), self.formatting:Clone()))
		self.textSoFar = nil
	end
end
function Parser:NewTextElement(text)
	if self.textSoFar then
		self:FinishTextElement()
	end
	self.textSoFar = {text}
end
function Parser:AppendTextPrevElement(text, indexIncrease)
	if self.textSoFar then
		self.textSoFar[#self.textSoFar + 1] = text
	else
		self:NewTextElement(text, self.formatting)
	end
	self.index += indexIncrease
end
function Parser:Apply(formattingAction, indexIncrease)
	self:FinishTextElement()
	formattingAction(self.formatting)
	self.index += indexIncrease
end
function Parser:SetFontFace(face)
	self:FinishTextElement()
	self.formatting.Face = face
end
function Parser:SetFontColor(color)
	self:FinishTextElement()
	self.formatting.Color = color
end
function Parser:SetFontSize(size)
	self:FinishTextElement()
	self.formatting.Size = size
end
function Parser:GetElements()
	self:FinishTextElement()
	return self.elements
end

local tags = {}
local close = function(parser)
	parser:SetFontFace(nil)
end
for _, const in ipairs(Enum.Font:GetEnumItems()) do
	tags[const.Name:lower()] = {
		open = function(parser)
			parser:SetFontFace(const.Name)
		end,
		close = close,
	}
end

local close = function(parser)
	parser:SetFontColor(nil)
end
for colorName, _ in pairs(Colors.Light) do
	tags[colorName:lower()] = {
		open = function(parser)
			parser:SetFontColor(colorName)
		end,
		close = close,
	}
end

local close = function(parser)
	parser:SetFontSize(nil)
end
for sizeName, _ in pairs(Sizes) do
	tags[sizeName:lower()] = {
		open = function(parser)
			parser:SetFontSize(sizeName)
		end,
		close = close,
	}
end
tags.normal = {
	open = close,
	close = close,
}

local actions = {
	["\\"] = function(parser) -- escape next character no matter what it is
		local nextIndex = parser.index + 1
		parser:AppendTextPrevElement(parser.text:sub(nextIndex, nextIndex), 2)
	end,
	["*"] = function(parser)
		local text, index = parser.text, parser.index
		if text:sub(index, index + 1) == "**" then
			parser:Apply(toggleBold, 2)
		elseif text:sub(index - 1, index + 1) == " * " then -- special escape (note that index - 1 is safe even if index is 1, as sub ignores index 0)
			parser:AppendTextPrevElement("* ", 2)
		else
			parser:Apply(toggleItalics, 1)
		end
	end,
	["_"] = function(parser)
		local text, index = parser.text, parser.index
		if text:sub(index, index + 1) == "__" then
			parser:Apply(toggleUnderline, 2)
		else
			parser:Apply(toggleItalics, 1)
		end
	end,
	["~"] = function(parser)
		local text, index = parser.text, parser.index
		if text:sub(index, index + 1) == "~~" then
			parser:Apply(toggleStrikethrough, 2)
		end
	end,
	["<"] = function(parser)
		local text, index = parser.text, parser.index
		local precedingSpace = text:sub(index - 1, index - 1) == " "
		index += 1
		while true do -- for each tag (they can be separated by ',' and/or '/')
			-- index is at the first character of the tag (or the '/')
			local firstIndex = text:find("[^ ]", index)
			if not firstIndex then
				print(index, text:sub(1, 20))
				error("No non-space found at beginning of tag")
			end
			index = firstIndex
			local closing = text:sub(index, index) == "/"
			local tagName
			local tagContentsStart = closing and index + 1 or index
			local tagContentsEnd, tagContentsEndChar
			local args
			repeat -- collect args
				tagContentsEnd = text:find("[>,;/]", tagContentsStart) -- note: end includes delimiter character (unlike start)
				if not tagContentsEnd then
					print(index, text:sub(index, index + 20))
					error("No end tag detected")
				end
				local tagContents = text:sub(tagContentsStart, tagContentsEnd - 1):gsub(" ", ""):lower()
				local args
				if args then
					args[#args + 1] = tagContents
				else
					args = {}
					tagName = tagContents
				end
				tagContentsEndChar = text:sub(tagContentsEnd, tagContentsEnd)
			until tagContentsEndChar ~= ";"
			parser.index = index
			;(tags[tagName] or error("No tag with name " .. tostring(tagName)))[closing and "close" or "open"](parser, args)
			if tagContentsEndChar == ">" then
				index = tagContentsEnd + 1
				if precedingSpace and text:sub(index, index) == " " then
					index += 1
				end
				parser.index = index
				break
			elseif tagContentsEndChar == "/" then -- another closing tag
				index = tagContentsEnd
			else
				index = tagContentsEnd + 1
			end
		end
	end,
}
local nextSymbol = "[\\*_<~]"
function Parser:Parse()
	local text = self.text
	while true do
		local index = self.index -- caution: self.index can be mutated after calling parser functions
		local nextI = text:find(nextSymbol, index)
		if nextI then
			if nextI > index then
				self:AppendTextPrevElement(text:sub(index, nextI - 1), nextI - index)
			end
			-- self.index may have changed at this point
			actions[text:sub(nextI, nextI)](self)
			if self.index <= nextI then -- todo when completely done with format development can remove this
				error(("Infinite loop detected for handling of symbol '%s' (index %d, nextI %d)"):format(
					text:sub(nextI, nextI),
					self.index,
					nextI))
			end
		else
			local remainder = text:sub(index)
			if #remainder > 0 then
				self:AppendTextPrevElement(remainder, 0) -- 0 is theoretically incorrect but we don't need index anymore
			end
			return self:GetElements()
		end
	end
end
function CustomMarkdown.ParseText(text)
	--	returns list of elements
	return Parser.new(text):Parse()
end
return CustomMarkdown