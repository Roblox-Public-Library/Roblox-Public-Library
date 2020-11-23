local Format = require(script.Parent.Format)
local Colors = require(script.Parent.Colors)
local Elements = require(script.Parent.Elements)
local Sizes = require(script.Parent.Sizes)

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
	fontTag("Face", function(rrt, face)
		-- todo consider user's font preferences!
		return string.format('<font face="%s">', face)
	end),
	fontTag("Color", function(rrt, color)
		return string.format('<font color="%s">', rrt.colors.Hex[color])
	end),
	fontTag("Size", function(rrt, size)
		return string.format('<font size="%d">', math.floor(rrt.normalSize * Sizes[size] + 0.5))
	end),
	simpleTag("Strikethrough", "s"),
	simpleTag("Underline", "u"),
	simpleTag("Bold", "b"),
	simpleTag("Italics", "i"),
}

local RobloxRichText = {}
RobloxRichText.__index = RobloxRichText
function RobloxRichText.new(defaultFont, normalSize, colors)
	return setmetatable({
		defaultFont = defaultFont,
		-- todo not just default font but also user font choices
		normalSize = normalSize,
		colors = colors,

		depth = 0,
		format = {}, -- [key] = value -- current format
		formatStack = {}, -- formatStack is a list of tags from formatTags in the order applied
		--	Roblox forbids <b><i></b></i>, so this lets us figure out which formatting to temporarily drop
	}, RobloxRichText)
end
function RobloxRichText:handleFormatting(newFormat)
	--	formats need not have the Format metatable on them
	local s = {}
	local ns = 0
	local format = self.format
	local formatStack = self.formatStack
	local nFormatStack = #formatStack
	local minDropRequired = nFormatStack + 1
	for i = 1, nFormatStack do
		local key = formatStack[i].Key
		if format[key] ~= newFormat[key] then
			minDropRequired = i
			break
		end
	end
	for i = nFormatStack, minDropRequired, -1 do
		local tag = formatStack[i]
		ns += 1
		s[ns] = tag.Close(self, format[tag.Key])
		format[tag.Key] = nil
		formatStack[i] = nil
	end
	nFormatStack = minDropRequired - 1
	for _, tag in ipairs(formatTags) do
		local key = tag.Key
		local newValue = newFormat[key]
		if newValue and not format[key] then -- format[key] being truthy means they're already the same
			ns += 1
			s[ns] = tag.Open(self, newValue)
			nFormatStack += 1
			formatStack[nFormatStack] = tag
			format[key] = newValue
		end
	end
	return table.concat(s)
end
local function handleEscapes(text)
	return text
		:gsub("<", "&lt;")
		:gsub("&", "&amp;")
		-- Quotation marks and '>' can be escaped but they don't currently have to be (at least not outside of tags)
end
function RobloxRichText:HandleText(element)
	local formatting = self:handleFormatting(element.Format)
	self.prevFormat = element.Format
	return formatting .. handleEscapes(element.Text or "")
end
function RobloxRichText:Finish()
	return self:handleFormatting({})
end
return RobloxRichText