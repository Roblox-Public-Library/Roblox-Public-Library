local Elements = require(script.Parent.Elements)

local function clone(t)
	local nt = {}
	for k, v in pairs(t) do
		nt[k] = v
	end
	return nt
end

local TextCursor = {}
TextCursor.__index = TextCursor
function TextCursor.new(fileContent)
	return setmetatable({
		fileContent = fileContent,
		elementIndex = 1,
		index = 1,
	}, TextCursor)
end
function TextCursor:NavEndOfFile()
	-- todo this won't work for non-text!
	local elements = self.fileContent.elements
	self.elementIndex = #elements
	self.index = self.elementIndex == 0 and 1 or #elements[self.elementIndex].Text
end
function TextCursor:SetBold(value)
	--fileContent.
end
function TextCursor:Type(text)
	local elements = self.fileContent.elements
	local curElement = elements[self.elementIndex]
	if not curElement then
		curElement = Elements.Text.new(text)
		elements[#elements + 1] = curElement
	else
		curElement.Text = curElement.Text .. text
	end
end
return TextCursor