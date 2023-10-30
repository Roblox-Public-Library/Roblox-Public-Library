-- Parses Custom Markdown text into a list of elements.
-- (Also contains unfinished code to reverse this process.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Class = require(Utilities.Class)
local String = require(Utilities.String)
local Table = require(Utilities.Table)

local Format = require(script.Parent.Format)
local Colors = require(script.Parent.Colors)
local Elements = require(script.Parent.Elements)
local Styles = require(script.Parent.Styles)
local PageNumbering = Styles.PageNumbering
local ChapterNaming = Styles.ChapterNaming
local Sizes = require(script.Parent.Sizes)

local CustomMarkdown = {}
local tagSeparator = ";"
local argSeparator = ","
local tagEndFindPattern = "[\\>" .. argSeparator .. tagSeparator .. "<]"
local tagEndFindPatternNoTagSep = "[\\>" .. argSeparator .. "<]"

local Converter = Class.New("Converter")
function Converter.new()
	return setmetatable({
		prevFormat = {},
	}, Converter)
end
local formatSymbols = {
	{"Bold", "**"},
	{"Italics", "*"},
	{"Underline", "__"},
	{"Strikethrough", "~~"},
}
function Converter:HandleText(element)
	local s = {}
	for _, obj in ipairs(formatSymbols) do
		local key, symbol = obj[1], obj[2]
		if self.prevFormat[key] ~= element.Format[key] then
			table.insert(s, symbol)
		end
	end
	table.insert(s, element.Text)
	self.prevFormat = element.Format
	return table.concat(s)
end
function Converter:Finish()
	if not self.prevFormat then return "" end
	local s = {}
	for _, obj in ipairs(formatSymbols) do
		local key, symbol = obj[1], obj[2]
		if self.prevFormat[key] then
			table.insert(s, symbol)
		end
	end
	return table.concat(s)
end
function CustomMarkdown.ConvertElements(elements)
	local converter = Converter.new()
	local all = {}
	for i, element in ipairs(elements) do
		all[i] = converter:HandleText(element)
	end
	table.insert(all, converter:Finish())
	return table.concat(all)
end


-- Parsing

local function toggleItalics(formatting)
	formatting.Italics = if formatting.Italics then nil else true
end
local function toggleBold(formatting)
	formatting.Bold = if formatting.Bold then nil else true
end
local function toggleUnderline(formatting)
	formatting.Underline = if formatting.Underline then nil else true
end
local function toggleStrikethrough(formatting)
	formatting.Strikethrough = if formatting.Strikethrough then nil else true
end

local function isEscaped(text, i) -- returns true if text:sub(i, i) is escaped
	-- We need to look for an odd number of '\' before this point
	local start = i
	while true do
		i -= 1
		if i < 1 or text:sub(i, i) ~= "\\" then
			return (start - i) % 2 == 0
		end
	end
end

local Parser = Class.New("Parser")
-- Parser.__index = function(self, key) -- This block is useful for debugging the parser
-- 	local v = Parser[key]
-- 	return type(v) == "function"
-- 		and function(self, ...)
-- 			print(self.text:sub(1, self.index - 1) .. "|" .. self.text:sub(self.index, self.index) .. "|" .. self.text:sub(self.index + 1) .. "\tParser." .. key, ...)
-- 			return v(self, ...)
-- 		end or v
-- end
function Parser.new(text, args, lineNumOffset, startingFormatting)
	--	Supported arguments:
	--		Images: List of images (otherwise "image1" will not be supported)
	--		Testing: if true, errors are raised rather than returning a list of issues
	--		UseLineCommands: if true, natural newlines are ignored in favour of <line> and <dline> commands
	--		NoNestingTags: if a string (indicating the parent tag), all tags are disabled (except font specifications)
	--		AllowTagSeparator: if true, allows the use of the tag separator (but then it must be escaped if used in tags as content)
	--		LineNumOffset
	return setmetatable({
		text = text:gsub("\t", "     "), -- tabs don't render correctly
		index = 1,
		lineNum = (lineNumOffset or 0) + 1,
		lineStart = 1,
		formatting = if startingFormatting then startingFormatting:Clone() else Format.new(),
		elements = {},
		-- textSoFar = nil,
		images = args and args.Images,
		-- issues = {},
		args = args,
		errorImmediately = args and args.Testing,
		useLineCommands = args and args.UseLineCommands,
		noNestingTags = args and args.NoNestingTags,
		tagEndFindPattern = if args and args.AllowTagSeparator then tagEndFindPattern else tagEndFindPatternNoTagSep,
	}, Parser)
end
function Parser:err(msg, indexOverride)
	local index = indexOverride or self.index
	local text = self.text
	local lineStart = self.lineStart
	local line = text:sub(self.lineStart):match("[^\n]*")
	local numToProblem = index - lineStart
	msg = string.format("On line %d:\n%s\n%s^\n  %s%s",
		self.lineNum,
		line,
		string.rep(" ", numToProblem),
		string.rep(" ", numToProblem - #msg), -- note: string.rep is okay with negative repetitions (it returns "")
		msg)
	if self.errorImmediately then
		error(msg, 2)
	else
		if self.issues then
			table.insert(self.issues, msg)
		else
			self.issues = {msg}
		end
	end
end
local validTypesForBlock = {
	Alignment = true,
	Bar = true,
	Header = true,
	Text = true,
	ParagraphIndent = true,
}
function Parser:add(element)
	local blockElements = self.blockElements
	if blockElements then
		if validTypesForBlock[element.Type] then
			table.insert(blockElements, element)
		else
			self:err("Cannot have " .. element.Type .. " inside a block")
		end
	else
		table.insert(self.elements, element)
	end
end
function Parser:FinishTextElement()
	if self.textSoFar then
		self:add(Elements.Text(table.concat(self.textSoFar), self.formatting:Clone()))
		self.textSoFar = nil
	end
end
function Parser:AppendTextPrevElement(text, indexIncrease)
	if self.textSoFar then
		table.insert(self.textSoFar, text)
	else
		self.textSoFar = {text}
	end
	self.index += indexIncrease
end
function Parser:RemoveTrailingWhitespacePrevElement()
	local textSoFar = self.textSoFar
	if textSoFar then
		local n = #textSoFar
		local line = textSoFar[n]:match("^(.*[^ \t])")
		if line == "" then
			if n == 1 then
				self.textSoFar = nil
			else
				textSoFar[n] = nil
			end
		else
			textSoFar[n] = line
		end
	end
end
function Parser:Apply(formattingAction, indexIncrease)
	self:FinishTextElement()
	formattingAction(self.formatting)
	self.index += indexIncrease
end
local alignmentToValue = {
	left = Enum.TextXAlignment.Left,
	right = Enum.TextXAlignment.Right,
	center = Enum.TextXAlignment.Center,
	centre = Enum.TextXAlignment.Center,
}
function Parser:SetAlignment(alignment)
	self:FinishTextElement()
	self:add(Elements.Alignment(alignment))
end
function Parser:SetFont(font)
	self:FinishTextElement()
	self.formatting:Set("Font", font)
end
function Parser:SetFontColor(color)
	self:FinishTextElement()
	self.formatting:Set("Color", color)
end
function Parser:SetStroke(stroke)
	self:FinishTextElement()
	self.formatting:Set("Stroke", stroke)
end
function Parser:SetFontSize(size)
	self:FinishTextElement()
	self.formatting:Set("Size", size)
end
function Parser:SetSubOrSuper(subOrSuper)
	self:FinishTextElement()
	self.formatting:Set("SubOrSuperScript", subOrSuper)
end
function Parser:Add(element)
	self:FinishTextElement()
	self:add(element)
end
local tags = {}
function Parser:GetElements() -- returns elements, issues : List<msg> or nil if no issues
	self:FinishTextElement()
	if self.blockElements then
		tags.block.close(self)
	end
	return self.elements, self.issues
end

for tag, v in {b = "Bold", u = "Underline", s = "Strikethrough", i = "Italics"} do
	tags[tag] = {
		OkayToNest = true,
		open = function(parser, args)
			if args[1] then parser:err(v .. " tag does not accept arguments") end
			parser:FinishTextElement()
			parser.formatting[v] = true
		end,
		close = function(parser)
			parser:FinishTextElement()
			parser.formatting[v] = nil
		end,
	}
end
local close = function(parser)
	parser:SetFont(nil)
end
for _, const in ipairs(Enum.Font:GetEnumItems()) do
	tags[const.Name:lower()] = {
		open = function(parser, args)
			if args[1] then parser:err("Font tags do not accept arguments") end
			parser:SetFont(const)
		end,
		close = close,
	}
end
tags.font = {close = close}

close = function(parser)
	parser:SetFontColor(nil)
end
local colorLowerToNormal = {}
for colorName, _ in Colors.Light do
	if colorName == "Hex" then continue end
	local lower = colorName:lower()
	colorLowerToNormal[lower] = colorName
	tags[lower] = {
		OkayToNest = true,
		open = function(parser, args)
			if args[1] then parser:err("Color tags do not accept arguments") end
			parser:SetFontColor(colorName)
		end,
		close = close,
	}
end
tags.color = {
	OkayToNest = true,
	open = function(parser, args)
		if not args[1] or args[2] then parser:err("Opening with <color> requires a single color argument") end
		if args[1] then
			parser:SetFontColor(args[1])
		end
	end,
	close = close,
}
tags.colour = tags.color

tags.stroke = {
	OkayToNest = true,
	open = function(parser, args)
		local color, transparency, thickness
		for _, v in ipairs(args) do
			local n = tonumber(v)
			if n then
				if n % 1 == 0 and n >= 1 then
					if thickness then
						parser:err("Multiple thickness arguments (or invalid transparency): " .. v)
					end
					thickness = n
				elseif n < 1 and n >= 0 then
					if transparency then
						parser:err("Multiple transparency arguments (or invalid thickness): " .. v)
					end
					transparency = n
				else
					parser:err("Invalid stroke transparency/thickness: " .. v)
				end
			else
				local normal = colorLowerToNormal[v]
				if not normal and v:match("%(%d+ %d+ %d+%)") then
					normal = v
				end
				if normal then
					if color then
						parser:err("Multiple color arguments: " .. v)
					end
					color = normal
				else
					parser:err("Unknown stroke argument: " .. v)
				end
			end
		end
		parser:SetStroke({Color = color, Transparency = transparency, Thickness = thickness})
	end,
	close = function(parser)
		parser:SetStroke(nil)
	end,
}

close = function(parser)
	parser:SetFontSize(nil)
end
for sizeName, _ in Sizes do
	if sizeName == "Sub" or sizeName == "Super" then continue end
	tags[sizeName:lower()] = {
		OkayToNest = true,
		open = function(parser, args)
			if args[1] then parser:err("Sizing tags do not accept arguments") end
			parser:SetFontSize(sizeName)
		end,
		close = close,
	}
end
tags.normal = { -- normal font size
	OkayToNest = true,
	open = close,
	close = close,
}
tags.size = {close = close}
local function parseNested(parser, text, parentTag)
	--	only provide parentTag if you want to disable tag nesting
	local newArgs
	if parentTag then
		newArgs = Table.Clone(parser.args)
		newArgs.NoNestingTags = parentTag
	else
		newArgs = parser.args
	end
	local elements, issues = parser.new(text, newArgs, nil, parser.formatting):Parse()
	if issues then
		for _, issue in issues do
			parser:err("In <" .. parentTag .. ">:" .. issue)
		end
	end
	return elements
end
local function parseNestedSubSuper(parser, text, parentTag, subOrSuper)
	local elements = parseNested(parser, text, parentTag)
	if not elements then return true end
	--	only provide parentTag if you want to disable tag nesting
	parser:FinishTextElement()
	for _, element in elements do
		if element.Type == "Text" and element.Format.SubOrSuperScript ~= subOrSuper then
			element.Format:Set("SubOrSuperScript", subOrSuper)
		end
		table.insert(parser.elements, element)
	end
end

close = function(parser)
	parser:SetSubOrSuper(nil)
end
tags.sub = {
	KeepSpaces = true,
	open = function(parser, args)
		parser:SetSubOrSuper("Sub")
		if args[1] then
			if parseNestedSubSuper(parser, table.concat(args, argSeparator), "sub", "Sub") then return true end
			parser:SetSubOrSuper(nil)
		end
	end,
	close = close,
}
tags.sup = {
	KeepSpaces = true,
	open = function(parser, args)
		parser:SetSubOrSuper("Super")
		if args[1] then
			if parseNestedSubSuper(parser, table.concat(args, argSeparator), "sup", "Super") then return true end
			parser:SetSubOrSuper(nil)
		end
	end,
	close = close,
}
tags.super = tags.sup

tags.bar = {
	CondenseNewlines = 1,
	open = function(parser, args)
		parser:Add(Elements.Bar(if args[1] then table.concat(args, argSeparator) else nil))
		if args[2] then
			parser:err("Bar's only argument is the text to repeat")
		end
	end,
}
close = function(parser)
	parser:SetAlignment(nil)
end
for key, value in alignmentToValue do
	tags[key] = {
		CondenseNewlines = 1,
		open = function(parser, args)
			if args[1] then parser:err("Alignment tags do not accept arguments") end
			parser:SetAlignment(value)
		end,
	}
end

tags.page = {
	CondenseNewlines = math.huge,
	open = function(parser, args)
		if args[1] then parser:err("page takes no arguments") end
		parser:Add(Elements.Page())
	end,
}
tags.turn = {
	CondenseNewlines = math.huge,
	open = function(parser, args)
		if args[1] then parser:err("turn takes no arguments") end
		parser:Add(Elements.Turn())
	end,
}

local function genCheckSize(parser, desc)
	return function(n)
		if n > 100 then
			parser:err(desc .. " are measured in percent and cannot be > 100")
			return 100
		elseif n <= 0 then
			parser:err(desc .. " cannot be <= 0.")
			return nil
		elseif n <= 1 then
			parser:err(desc .. " are measured in percent (up to 100).")
			return n * 100
		end
		return n
	end
end

tags.image = {
	variantNumSupported = true,
	open = function(parser, args, num)
		local data = {
			Type = "Image",
			Alignment = Enum.TextXAlignment.Center -- by default (overridden below)
		}
		if num then
			if not parser.images then
				parser:err("Image list not provided, so <image#> not supported.")
				return
			end
			local v = parser.images[num]
			if not v then
				parser:err("No image with index " .. num)
				return
			end
			v = tonumber(v)
			if not v then
				parser:err("At index " .. num .. ", invalid image id '" .. parser.images[num] .. "'")
				return
			end
			data.ImageId = v
		end
		local width
		local height
		local noWrap
		local checkSize = genCheckSize(parser, "Image dimensions")
		for _, arg in ipairs(args) do
			arg = arg:gsub(" ", ""):lower()
			local id = tonumber(arg)
			if id then
				if data.ImageId then
					if num then
						parser:err("Image: decal id detected in addition to specifying image index " .. data.ImageIndex .. ". Use 'w'/'h' to specify size, or, for example, <image1" .. argSeparator .. "50x50>")
					else
						parser:err("Image: multiple decal ids detected. Use 'w'/'h' to specify size, or, for example, <image1" .. argSeparator .. "50x50>")
					end
				else
					data.ImageId = id
				end
				continue
			end
			local w, h = arg:match("([.%d]+)x([.%d]+)")
			if w then
				w, h = tonumber(w), tonumber(h)
				if not w or not h then
					parser:err("Malformed numbers in size argument: " .. arg)
				else
					w, h = checkSize(w), checkSize(h)
					if w and h then
						width = w
						height = h
					end
				end
				continue
			end
			local n, axis = arg:match("([.%d]+)(.)")
			if n then
				n = tonumber(n)
				if not n then
					parser:err("Invalid image argument: " .. arg)
				else
					if axis == "w" then
						if width then
							parser:err("Multiple width arguments: " .. arg)
						end
						width = checkSize(n)
					elseif axis == "h" then
						if height then
							parser:err("Multiple height arguments: " .. arg)
						end
						height = checkSize(n)
					elseif axis == "r" then
						if data.AspectRatio then
							parser:err("Multiple aspect ratio arguments: " .. arg)
						end
						data.AspectRatio = n
					else
						parser:err("Unknown size dimension '" .. axis .. "'")
					end
				end
				continue
			end
			if arg == "square" then
				if data.AspectRatio then
					parser:err("Multiple aspect ratio arguments: " .. arg)
				end
				data.AspectRatio = 1
				continue
			end
			if arg == "nowrap" then
				noWrap = true
				continue
			end
			local v = alignmentToValue[arg]
			if v then
				data.Alignment = v
				continue
			end
			parser:err("Unknown image argument '" .. arg .. "'")
		end
		if not num and not data.ImageId then
			parser:err("Image tag needs an index (such as '<image1>') or an id (such as '<image" .. argSeparator .. "1935423>').")
			return
		end
		data.Size = Vector2.new(
			if width then width / 100 else 1,
			if height then height / 100 else 1)
		if data.AspectRatio then
			data.WidthProvided = width
			data.HeightProvided = height
		end
		if noWrap and data.Alignment ~= Enum.TextXAlignment.Center then
			data.NoWrap = true
		end
		parser:Add(data)
	end,
}
tags.img = tags.image

tags.line = {
	open = function(parser, args)
		if not parser.useLineCommands then
			parser:err("Line command not turned on. Or did you mean the 'bar' command?")
			return
		end
		local n = args[1]
		local num
		if n then
			num = tonumber(n)
			if not num then
				parser:err("Unknown 'line' argument: " .. n)
			elseif args[2] then
				parser:err("'line' only takes as argument the number of newlines")
			end
		end
		parser:AppendTextPrevElement(string.rep("\n", num or 1), 0)
	end,
}
local dlineArg = {2}
tags.dline = {
	open = function(parser, args)
		if args[1] then
			parser:err("'dline' takes no arguments")
		end
		tags.line.open(parser, dlineArg)
	end
}

tags.block = {
	CondenseNewlines = 1,
	open = function(parser, args)
		if args[1] then
			parser:err("'block' takes no arguments")
		end
		if parser.blockElements then
			parser:err("Cannot have nested block tags")
			return
		end

		local data = {
			Type = "Block",
			-- Alignment = nil, -- by default (overridden below if specified)
			-- NoWrap = true/false,
			Width = 1, -- 1 == 100%
			-- BorderColor = nil, -- default
			BorderThickness = 1,
		}
		-- <block,[left/right/center],0->100 (% width) [default 100%], nowrap [default false], 2t [to indicate border thickness; 1 is default], color [for border color, black is default]>
		--	todo document
		local checkSize = genCheckSize(parser, "Block width")
		local noWrap
		for _, arg in ipairs(args) do
			arg = arg:gsub(" ", ""):lower()
			if arg == "nowrap" then
				noWrap = true
				continue
			end
			local v = alignmentToValue[arg]
			if v then
				data.Alignment = v
				continue
			end
			v = colorLowerToNormal[arg]
			if v then
				data.BorderColor = v
				continue
			end
			local n = tonumber(arg)
			if n then
				data.Width = checkSize(n) / 100
				continue
			end
			n = arg:sub(-1, -1) == "t" and tonumber(arg:sub(1, -2))
			if n then
				if n < 0 then parser:err("Border thickness cannot be less than 0") n = 0 end
				if n > 10 then parser:err("Border thickness cannot be greater than 10") n = 10 end
				data.BorderThickness = n
			end
			parser:err("Unknown block argument '" .. arg .. "'")
		end
		if noWrap and data.Alignment ~= Enum.TextXAlignment.Center then
			data.NoWrap = true
		end
		parser.blockData = data

		parser:FinishTextElement()
		parser.blockElements = {}
	end,
	close = function(parser)
		if not parser.blockElements then
			parser:err("No open 'block' tag")
			return
		end
		parser:FinishTextElement()
		local element = parser.blockData
		parser.blockData = nil
		element.Elements = parser.blockElements
		parser.blockElements = nil
		parser:add(element)
	end,
}
tags.clear = {
	CondenseNewlines = 1,
	open = function(parser, args)
		if args[1] then
			parser:err("'clear' takes no arguments")
		end
		parser:Add(Elements.Clear())
	end
}

tags.chapternaming = {
	CondenseNewlines = 1,
	open = function(parser, args)
		local arg
		if args[1] then
			arg = args[1]:gsub(" ", ""):lower()
			if not ChapterNaming[arg] then
				parser:err("Unknown chapter naming style '" .. args[1] .. "'")
				arg = "custom"
			end
		else
			arg = "custom"
			parser:err("<chapterNaming> requires the style as an argument")
		end
		if args[2] then
			parser:err("chapterNamingStyle only takes one argument")
		end
		parser:Add(Elements.ChapterNamingStyle(arg))
	end,
}
local function genChapter(elementName, condenseNewlines)
	local Elements_Chapter = Elements[elementName]
	local lowerName = elementName:lower()
	local lowerName2 = lowerName .. "2"
	return {
		CondenseNewlines = condenseNewlines,
		open = function(parser, args)
			local name = if args[1] then String.Trim(table.concat(args, argSeparator)) else nil
			if name then
				name = parseNested(parser, name, lowerName)
				if not name then return true end
			end
			parser:Add(Elements_Chapter(name, nil, parser.formatting:Clone()))
		end
	}, {
		CondenseNewlines = condenseNewlines,
		open = function(parser, args)
			if #args ~= 2 then
				parser:err("chapter2/section2 must have exactly 2 arguments. Commas in the chapter/section name must be escaped.")
				return
			end
			local name = parseNested(parser, String.Trim(args[1]), lowerName2)
			if not name then return true end
			local text = parseNested(parser, String.Trim(args[2]), lowerName2)
			if not text then return true end
			parser:Add(Elements_Chapter(name, text, parser.formatting:Clone()))
		end
	}
end
tags.chapter, tags.chapter2 = genChapter("Chapter", 1)
tags.section, tags.section2 = genChapter("Section", nil)
tags.header = {
	open = function(parser, args)
		if not args[1] then
			parser:err("header tag must be of the format <header" .. argSeparator .. "Header Name>")
			return
		end
		local size = "Header"
		local concatBegin = 1
		if args[1] == "large" then
			size = "LargeHeader"
			concatBegin = 2
		end
		local name = String.Trim(table.concat(args, argSeparator, concatBegin))
		name = parseNested(parser, name, "header")
		parser:Add(Elements.Header(name, size))
	end,
}
tags.pagenumbering = { -- <pageNumbering,styleName,startingNumber[,"invisible"]> -- both arguments default to continuing whatever was happening before. "Invisible" is an optional flag to have the page numbers not show up in the book render. You can also specify "invisible#" to mean "invisible for the first # pages"
	CondenseNewlines = 1,
	open = function(parser, args)
		local style, startingNumber, invisible
		local errReported = false
		for _, arg in ipairs(args) do
			local n = tonumber(arg)
			if n then
				if startingNumber then
					parser:err("Multiple starting numbers indicated in pageNumbering")
					errReported = true
				end
				startingNumber = n
			else
				arg = arg:gsub(" ", ""):lower()
				if arg:sub(1, 9) == "invisible" then
					invisible = tonumber(arg:sub(10)) or true
				elseif PageNumbering[arg] then
					style = arg
				else
					parser:err("Unknown page style '" .. arg .. "'")
					errReported = true
				end
			end
		end
		if not style and not startingNumber and not invisible then
			if not errReported then
				parser:err("pageNumbering tag has no arguments")
			end
			return
		end
		if not style then
			parser:err("pageNumbering tag has no style argument")
			return
		end
		parser:Add(Elements.PageNumbering(style, startingNumber, invisible))
	end,
}
tags.indent = { -- <indent,style> where style is tab/newline/none or an arbitrary indent string or just <indent> for no indent
	CondenseNewlines = 1,
	open = function(parser, args)
		if args[1] == "tab" or args[1] == "newline" then
			if args[2] then
				parser:err("indent only supports 1 argument")
			end
			parser:Add(Elements.ParagraphIndentStyle(args[1]))
		elseif args[1] and args[1] ~= "none" then
			parser:Add(Elements.ParagraphIndent(table.concat(args, argSeparator)))
		else
			parser:Add(Elements.ParagraphIndent(""))
		end
	end,
}
tags.flag = {
	CondenseNewlines = 1,
	open = function(parser, args)
		if #args == 0 then parser:err("flag must have at least one argument") end
		for _, tag in args do
			parser:Add(Elements.Flag(String.Trim(tag):lower()))
		end
	end,
}
local Nav = Class.New("ParserStringNavigator")
function Nav.new(parser)
	return setmetatable({
		parser = parser,
		elementStack = {},
		indexStack = {},
	}, Nav)
end
function Nav:Init()
	-- Initialize to last character
	local parser = self.parser
	local tsf = parser.textSoFar
	self.cur = nil
	if tsf then
		self.textSoFar = tsf
		self.textSoFarIndex = #tsf + 1
		--self.cur = tsf[self.textSoFarIndex]
	else
		self:initAfterTSF()
	end
	return self
end
function Nav:initAfterTSF()
	local parser = self.parser
	self.textSoFarIndex = nil
	table.clear(self.elementStack)
	table.clear(self.indexStack)
	local blockElements = parser.blockElements
	self.elements = blockElements or parser.elements
	self.elementIndex = #self.elements + 1
	if blockElements then
		self.elementStack[1] = parser.elements
		self.indexStack[1] = #parser.elements + 1
	end
	--return self:advanceToPrevTextElement()
end
function Nav:advanceToPrevTextElement()
	local parser = self.parser
	local elements = self.elements
	for i = self.elementIndex - 1, 1, -1 do
		local e = elements[i]
		if e.Type == "Text" then
			local cur = e.Text
			self.cur = cur
			self.elementIndex = i
			return cur
		elseif e.Elements then
			table.insert(self.elementStack, elements)
			table.insert(self.indexStack, i)
			self.elements = e.Elements
			self.elementIndex = #e.Elements + 1
			return self:advanceToPrevTextElement()
		end
	end
	self.elements = table.remove(self.elementStack)
	self.elementIndex = table.remove(self.indexStack)
	if self.elementIndex then
		return self:advanceToPrevTextElement()
	else
		self.cur = nil
	end
end
function Nav:ToPrev() -- navigates to and returns the previous string (if any)
	local textSoFarIndex = self.textSoFarIndex
	if textSoFarIndex then -- go to next textSoFar, if one exists
		if textSoFarIndex > 1 then
			textSoFarIndex -= 1
			self.textSoFarIndex = textSoFarIndex
			local cur = self.textSoFar[textSoFarIndex]
			self.cur = cur
			return cur
		end
		return self:initAfterTSF()
	end
	return self:advanceToPrevTextElement()
end
function Nav:Cur() -- returns nil if nothing left
	return self.cur
end
function Nav:RemoveLastNChars(n, stackDelta) -- from before the current position working backwards
	while n > 0 do
		local cur = self:ToPrev() or error("Not enough characters in parser to remove", 2 + (stackDelta or 0))
		local avail = #cur
		if avail > n then
			if self.textSoFarIndex then
				self.textSoFar[self.textSoFarIndex] = cur:sub(1, -n - 1)
			else
				self.elements[self.elementIndex].Text = cur:sub(1, -n - 1)
			end
			return
		else
			if self.textSoFarIndex then
				table.remove(self.textSoFar, self.textSoFarIndex)
			else
				table.remove(self.elements, self.elementIndex)
			end
			n -= avail
		end
	end
end

local CharNav = Class.New("ParserCharNavigator")
function CharNav.new(nav)
	return setmetatable({
		nav = nav,
	}, CharNav)
end
function CharNav:Init()
	-- Initialize to last character
	self.nav:Init()
	local line = self.nav:ToPrev()
	self.line = line
	self.index = if line then #line + 1 else nil
	self.cur = nil
	--self:advanceToPrevString(self.nav:Cur())
end
function CharNav:ToPrev()
	local line = self.line
	if not line then return end
	local index = self.index - 1
	if index > 0 then
		self.index = index
		self.cur = line:sub(index, index)
		return self.cur
	end
	return self:advanceToPrevString()
end
function CharNav:Cur() return self.cur end
function CharNav:advanceToPrevString() --line)
	--line = line or self.nav:ToPrev()
	local line = self.nav:ToPrev()
	self.line = line
	if line then
		self.index = #line
		self.cur = line:sub(-1, -1)
		return self.cur
	else
		self.cur = nil
	end
end
function Parser:getNav(skipInit)
	local nav = self.nav
	if not nav then
		nav = Nav.new(self)
		self.nav = nav
	end
	if not skipInit then
		nav:Init()
	end
	return nav
end
function Parser:getCharNav() -- the char nav will point to the last character in the parser
	-- Only need 1 char nav per parser since it's only used in 1 coroutine at a time and never recursively
	local charNav = self.charNav
	if not charNav then
		charNav = CharNav.new(self:getNav(true))
		self.charNav = charNav
	end
	charNav:Init()
	return charNav
end
function Parser:getLastChar()
	return self:getCharNav():ToPrev()
end
function Parser:removeLastNChars(n)
	self:getNav():RemoveLastNChars(n)
end

local actions = {
	-- [char] = function(parser) -> true to end parse early; otherwise must advance index
	["\n"] = function(parser)
		if parser.useLineCommands then
			local i = parser.index + 1
			local nextNonSpace = parser.text:find("%S", i)
			if not nextNonSpace then return true end -- nothing left to parse
			local c = parser:getLastChar()
			-- Add a space if 'c' is not a whitespace character
			-- Note: do not add a space if the parser has no text
			if c and not c:match("%s") then
				parser:AppendTextPrevElement(" ", 0)
			end
			parser.index = nextNonSpace
			-- We ignore the \n for the output, but include it in the variables meant to help track down errors
			local _, count
			_, count = parser.text:sub(i, nextNonSpace - 1):gsub("\n", "")
			parser.lineNum += count + 1
			parser.lineStart = parser.index
		else
			parser:RemoveTrailingWhitespacePrevElement()
			parser:AppendTextPrevElement("\n", 1)
			parser.lineNum += 1
			parser.lineStart = parser.index
		end
	end,
	["\\"] = function(parser) -- escape next character unless it's a newline
		local nextIndex = parser.index + 1
		local char = parser.text:sub(nextIndex, nextIndex)
		if char == "\n" then
			parser.index = nextIndex -- this allows the newline to be parsed
		else
			parser:AppendTextPrevElement(char, 2)
		end
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
			parser:AppendTextPrevElement("_", 1)
		end
	end,
	["~"] = function(parser)
		local text, index = parser.text, parser.index
		if text:sub(index, index + 1) == "~~" then
			parser:Apply(toggleStrikethrough, 2)
		else
			parser:AppendTextPrevElement("~", 1)
		end
	end,
	["<"] = function(parser)
		local text, index = parser.text, parser.index
		if text:sub(index - 1, index + 1) == " < " then -- special escape (same as for "*")
			parser:AppendTextPrevElement("< ", 2)
			return
		end
		index += 1
		local beginningOfTag = index
		local tagContentsTable = {}
		while true do -- for each tag (they can be separated by ';')
			-- index is at the first character of the tag (or the '/')
			local firstIndex = text:find("[^ ]", index)
			if not firstIndex then
				parser:err("No non-space found after beginning of tag", index)
				return true
			end
			index = firstIndex
			local closing = text:sub(index, index) == "/"
			local tagName
			local tagContentsStart = if closing then index + 1 else index
			local tagContentsEnd, tagContentsEndChar
			local args
			parser.index = index
			repeat -- identify the tag name and collect args
				table.clear(tagContentsTable)
				local i = tagContentsStart
				while true do
					tagContentsEnd = text:find(parser.tagEndFindPattern, i) -- note: end includes delimiter character (unlike start) and also the "<" character (so we can detect nested tags)
					if not tagContentsEnd then
						return parser:err("Unfinished tag or unescaped '<' detected")
					end
					tagContentsEndChar = text:sub(tagContentsEnd, tagContentsEnd)
					if tagContentsEndChar == "<" then -- nested tag
						-- make sure that this isn't escaped (if so, add to contents and resume)
						-- note: don't need to check for \< because that would be handled by the "\\" detection below
						if text:sub(tagContentsEnd - 1, tagContentsEnd + 1) == " < " then
							table.insert(tagContentsTable, text:sub(i, tagContentsEnd + 1))
							i = tagContentsEnd + 2
							continue
						end
						-- find unescaped close tag
						while true do
							tagContentsEnd = text:find(">", tagContentsEnd + 1)
							if not tagContentsEnd then
								return parser:err("Unfinished tag or unescaped '<' detected")
							end
							if text:find(tagContentsEnd - 1, tagContentsEnd) == "\\>" or text:find(tagContentsEnd - 1, tagContentsEnd + 1) == " > " then
								tagContentsEnd += 2
								continue
							end
							-- we found it
							break
						end
						table.insert(tagContentsTable, text:sub(i, tagContentsEnd))
						i = tagContentsEnd + 1
						continue -- resume parsing the outer tag
					end
					if tagContentsEndChar ~= "\\" then break end
					-- escape next character
					table.insert(tagContentsTable, text:sub(i, tagContentsEnd - 1))
					table.insert(tagContentsTable, text:sub(tagContentsEnd + 1, tagContentsEnd + 1))
					i = tagContentsEnd + 2
				end
				if not tagContentsEnd then
					return parser:err("No end tag detected")
				end
				table.insert(tagContentsTable, text:sub(i, tagContentsEnd - 1))
				local tagContents = table.concat(tagContentsTable)
				if args then
					if closing then
						parser:err("Arguments not allowed on tag close")
					end
					table.insert(args, tagContents)
				else
					args = {}
					tagName = tagContents:gsub(" ", ""):lower()
				end
				tagContentsStart = tagContentsEnd + 1 -- this is now the start of the next argument (if tagContentsEndChar is an arg seperator)
			until tagContentsEndChar ~= argSeparator
			local tag = tags[tagName]
			local baseName, variantNum
			if not tag then
				baseName, variantNum = tagName:match("^(%D+)(%d+)$")
				if baseName then
					tag = tags[baseName]
					if tag and not tag.variantNumSupported then
						tag = nil
					else
						variantNum = tonumber(variantNum)
					end
				end
			end
			if not tag then
				parser:err("No tag with name \"" .. tagName:gsub("\n", " \\ ") .. '"')
			elseif parser.noNestingTags and not tag.OkayToNest then
				parser:err("Tag <" .. tagName .. "> cannot be nested in <" .. parser.noNestingTags .. ">")
			else
				local action = if closing then tag.close else tag.open
				if action then
					action(parser, args, variantNum)
				else
					parser:err(("Tag '%s' does not support being %s"):format(tagName, if closing then "closed" else "opened"))
				end
			end
			if tagContentsEndChar == ">" then
				index = tagContentsEnd + 1

				-- Ignore whitespace after the '>' if it leads to a newline character
				local start, stop = text:find("^[ \t]*\n", index)
				if start then
					index = stop
				end

				local nextChar = text:sub(index, index)
				if (not tag or not tag.KeepSpaces) then -- allowed to condense space
					local prevCharNav = parser:getCharNav()
					local prevChar = prevCharNav:ToPrev()
					if tag and tag.CondenseNewlines then -- we can completely eliminate any/all whitespace (up to 'CondenseNewlines' count on either side)
						local condenseNum = tag.CondenseNewlines -- note: may be negative to indicate "inside only" (between open & closing tags)
						local internalOnly = condenseNum < 0
						if internalOnly then
							condenseNum = -condenseNum
						end
						if prevChar and prevChar:match("%s") and (not internalOnly or closing) then
							local count = condenseNum
							for i = 1, count - 1 do
								local cur = prevCharNav:ToPrev()
								if not cur or not cur:match("%s") then
									count = i
									break
								end
							end
							parser:removeLastNChars(count)
						end
						if nextChar:match("%s") and (not internalOnly or not closing) then
							local a, b = text:find("%s+", index)
							if a then
								index += math.min(b - a + 1, condenseNum)
							end
						end
					elseif (nextChar == "" or nextChar:match("%s")) and (not prevChar or prevChar:match("%s")) then
						if nextChar == " " then
							index += 1
						elseif prevChar == " " then
							parser:removeLastNChars(1)
						elseif nextChar == "\n" and (not prevChar or prevChar == "\n") then
							index += 1
						elseif nextChar == "" and prevChar == "\n" then
							parser:removeLastNChars(1)
						end
					end
				end
				parser.index = index
				break
			else -- tagContentsEndChar is a tag seperator
				index = tagContentsEnd + 1
			end
		end
		-- look for newlines that we've skipped
		local _, numNewLines = text:sub(beginningOfTag, parser.index - 1):gsub("\n", "")
		if numNewLines > 0 then
			parser.lineStart = text:find("\n.-$", beginningOfTag) + 1
			parser.lineNum += numNewLines
		end
	end,
}
local nextSymbol = "[\\*_<~\n]"
function Parser:Parse() -- returns elements, issues/nil
	local text = self.text
	while true do
		local index = self.index -- caution: self.index can be mutated after calling parser functions
		local nextI = text:find(nextSymbol, index)
		if nextI then
			if nextI > index then
				self:AppendTextPrevElement(text:sub(index, nextI - 1), nextI - index)
			end
			-- self.index may have changed at this point
			if actions[text:sub(nextI, nextI)](self) then
				return self:GetElements()
			end
			if self.index <= nextI then
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
function CustomMarkdown.ParseText(text, args, lineNumOffset, startingFormatting)
	--	returns list of elements followed by any issues/parse errors as a list of messages *or* nil if no issues
	return Parser.new(text, args, lineNumOffset, startingFormatting):Parse()
end
function CustomMarkdown.ParseTextErrOnIssue(text, args, lineNumOffset, startingFormatting)
	--	returns list of elements
	args = args or {}
	args.Testing = true
	return Parser.new(text, args, lineNumOffset, startingFormatting):Parse()
end

local ParserChecker = Class.New("ParserChecker", Parser)
function ParserChecker.new(text, args, lineNumOffset)
	return setmetatable(Parser.new(text, args, lineNumOffset), ParserChecker)
end
function ParserChecker:FinishTextElement() end
function ParserChecker:AppendTextPrevElement(text, indexIncrease)
	self.index += indexIncrease
end
function ParserChecker:Apply(formattingAction, indexIncrease)
	self.index += indexIncrease
end
function ParserChecker:SetAlignment(alignment) end
function ParserChecker:SetFont(font) end
function ParserChecker:SetFontColor(color) end
function ParserChecker:SetStroke(stroke) end
function ParserChecker:SetFontSize(size) end
function ParserChecker:SetSubOrSuper(subOrSuper) end
function ParserChecker:Add(element) end
local none = {}
function ParserChecker:GetElements() -- returns elements, issues : List<msg> or nil if no issues
	return none, self.issues
end
function ParserChecker:getLastChar() return nil end
local fakeCharNav = {ToPrev = function() end, Cur = function() end}
function ParserChecker:getCharNav() return fakeCharNav end

function CustomMarkdown.CheckForIssues(text, args, lineNumOffset) -- returns list of issue messages or nil
	local _, issues = ParserChecker.new(text, args, lineNumOffset):Parse()
	return issues
end

return CustomMarkdown