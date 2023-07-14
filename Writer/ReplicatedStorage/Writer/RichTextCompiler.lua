local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utilities = ReplicatedStorage.Utilities
local Assert = require(Utilities.Assert)
local Class = require(Utilities.Class)

local RichTextCompiler = Class.New("RichTextCompiler")

local startTag = "<%s>"
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
local function formatColor(config, color)
	return string.format(' color="%s"', if color:sub(1, 3) == "rgb"
		then config:GetColorCode(color)
		else config:GetHexColor(color))
end
local formatTags = {
	-- In this list of tags, if one is likely to be toggled frequently (and/or is short in length) it should be last
	fontTag("Font", function(config, font)
		return string.format('<font face="%s">', config:GetFont(font).Name)
	end),
	{
		Key = "Stroke",
		Open = function(config, stroke)
			return string.format("<stroke%s%s%s>",
				if stroke.Color then formatColor(config, stroke.Color) else "",
				if stroke.Thickness then string.format(' thickness="%d"', stroke.Thickness) else "",
				if stroke.Transparency then string.format(' transparency="%.2f"', stroke.Transparency) else "")
		end,
		Close = function() return "</stroke>" end,
	},
	fontTag("Color", function(config, color)
		return string.format("<font%s>", formatColor(config, color))
	end),
	fontTag("Size", function(config, size, format)
		return string.format('<font size="%d">', config:GetSize(size, format.SubOrSuperScript))
	end),
	simpleTag("Strikethrough", "s"),
	simpleTag("Underline", "u"),
	simpleTag("Bold", "b"),
	simpleTag("Italics", "i"),
}
RichTextCompiler.FormatTags = formatTags
local formatKeyToTag = {}
for _, tag in ipairs(formatTags) do
	formatKeyToTag[tag.Key] = tag
end
RichTextCompiler.FormatKeyToTag = formatKeyToTag

function RichTextCompiler.HandleEscapes(text)
	--	Escape user text to avoid conflict with Roblox's RichText formatting
	-- Note: return wrapped in () to ensure function only returns the text
	return (text:gsub("<", "&lt;")) -- Quotation marks and '>' can be escaped but they don't currently have to be. No issues result by not escaping '&' - it merely enables people to type things like "&lt;" to get a "<".
end
function RichTextCompiler.Unescape(text) -- useful if you want to measure the size of unformatted text quickly (TextService:GetTextSize is much faster than RichText.MeasureText)
	return (text
		:gsub("&lt;", "<")
		:gsub("&gt;", ">")
		:gsub("&quot;", '"')
		:gsub("&apos;", "'")
		:gsub("&amp;", "&"))
end

function RichTextCompiler.new(config)
	return setmetatable({
		config = config,
		content = {}, -- list of strings that will be concatenated to produce RichText
		format = {}, -- [key] = value -- current format (where values can be modified/normalized by getNewFormatValue; they're nil if default)
		formatStack = {}, -- formatStack is a list of tags from formatTags in the order applied
		--	Roblox forbids <b><i></b></i>, so this lets us figure out which formatting to temporarily drop
		-- initialSize : string key to Sizes; the size of the first element compiled
		-- initialSubOrSuper : string key "Sub" or "Super" or nil (goes with initialSize)
	}, RichTextCompiler)
end
local keyToDefault = {
	Font = "DefaultFont",
	Color = "DefaultColor",
	Size = "NormalSize",
}
function RichTextCompiler:handleFormat(newFormat)
	local config = self.config
	local content = self.content
	local format = self.format
	local formatStack = self.formatStack
	local function getNewFormatValue(key)
		--	returns normalized value for "format" table followed by the value to pass to tag.Open
		if key == "Size" then
			local size = newFormat.Size
			local subOrSuper = newFormat.SubOrSuperScript
			size = size or "Normal"
			if not self.initialSize then
				self.initialSize = size
				self.initialSubOrSuper = subOrSuper
			end
			if self.initialSize == size then
				size = nil
			end
			if self.initialSubOrSuper == subOrSuper then
				subOrSuper = nil
			end
			if subOrSuper then
				return (size or "") .. subOrSuper, size
			else
				return size, size
			end
		else
			local value = newFormat[key]
			return if not value or value == config[keyToDefault[key]] then nil else value, value
		end
	end
	local minDropRequired
	for i, tag in ipairs(formatStack) do
		local key = tag.Key
		if format[key] ~= getNewFormatValue(key) then
			minDropRequired = i
			break
		end
	end
	if minDropRequired then
		self:dropFormattingTo(minDropRequired)
	end
	for _, tag in ipairs(formatTags) do
		local key = tag.Key
		local newValue, openValue = getNewFormatValue(key)
		if newValue and not format[key] then -- format[key] being truthy means they're already the same
			table.insert(content, tag.Open(config, openValue, newFormat) or error(tostring(key) .. "'s Open returned nil"))
			table.insert(formatStack, tag)
			format[key] = newValue
		end
	end
end
function RichTextCompiler:dropFormattingTo(level)
	local config = self.config
	local content = self.content
	local format = self.format
	local formatStack = self.formatStack
	for i = #formatStack, level, -1 do
		local tag = formatStack[i]
		local key = tag.Key
		table.insert(content, tag.Close(config, format[key]) or error(tostring(key) .. "'s Close returned nil"))
		format[key] = nil
		formatStack[i] = nil
	end
end
function RichTextCompiler:Append(text, format, alreadyEscaped)
	self:handleFormat(format)
	table.insert(self.content, if alreadyEscaped then text else RichTextCompiler.HandleEscapes(text))
end
function RichTextCompiler:Finish()
	self:dropFormattingTo(1)
	return table.concat(self.content), self.config:GetSize(self.initialSize, self.initialSubOrSuper)
end

function RichTextCompiler.FromTextElements(elements, config, alreadyEscaped)
	--	returns richText, textSize
	--	Note: elements with SubOrSuperScript are merged as if they didn't have SubOrSuperScript, except that their size is impacted
	local compiler = RichTextCompiler.new(Assert.Is(config, "ReaderConfig"))
	for _, element in ipairs(elements) do
		compiler:Append(element.Text, element.Format, alreadyEscaped)
	end
	return compiler:Finish()
end

return RichTextCompiler