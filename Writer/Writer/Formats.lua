local Formats = {}
local Elements = require(script.Parent.Elements)

local CustomMarkdown = {}
Formats.CustomMarkdown = CustomMarkdown
CustomMarkdown.__index = CustomMarkdown
function CustomMarkdown.new()
	return setmetatable({
		prevFormat = {},
	}, CustomMarkdown)
end
local formatSymbols = {
	{"Bold", "*"},
	{"Italics", "_"},
	{"Underline", "__"},
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

-- Parsing
local symbols = {
	{Text = "___", Action = function(formatting)
		formatting.Underline = not formatting.Underline
		formatting.Italics = not formatting.Italics
	end},
	{Text = "__", Action = function(formatting)
		formatting.Underline = not formatting.Underline
	end},
	{Text = "*", Action = function(formatting)
		formatting.Bold = not formatting.Bold
	end},
	{Text = "_", Action = function(formatting)
		formatting.Italics = not formatting.Italics
	end},
}
local function clone(t)
	local nt = {}
	for k, v in pairs(t) do
		nt[k] = v
	end
	return nt
end
local function getNextSymbol(text, startI)
	local smallestI, nearestSymbol
	for _, symbol in ipairs(symbols) do
		local i = text:find(symbol.Text, startI)
		if i and (not smallestI or i < smallestI) then
			smallestI = i
			nearestSymbol = symbol
		end
	end
	return smallestI, nearestSymbol
end
function CustomMarkdown.ParseText(text)
	--	returns list of elements
	local formatting = {} -- no formatting to start with
	local elements = {}
	local index = 1
	while true do
		local nextI, nextSymbol = getNextSymbol(text, index)
		if nextI then
			if nextI > index then
				elements[#elements + 1] = Elements.Text.new(text:sub(index, nextI - 1), clone(formatting))
			end
			index = nextI + #nextSymbol.Text
			nextSymbol.Action(formatting)
		else
			local remainder = text:sub(index)
			if #remainder > 0 then
				elements[#elements + 1] = Elements.Text.new(remainder, formatting)
			end
			return elements
		end
	end
end

return Formats