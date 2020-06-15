local Elements = require(script.Parent.Elements)

local function clone(t)
	local nt = {}
	for k, v in pairs(t) do
		nt[k] = v
	end
	return nt
end



local DocumentController = {}
DocumentController.__index = DocumentController
function DocumentController.new(header, chapters)
	return setmetatable({
		header = header or {}, -- todo assert Header
		-- book is 1+ chapters each with 1+ sections with 0+ elements
		contents = contents or {}, -- todo assert list<element>?
		chapters = {},
		elementIndex = 1,
		index = 1,
	}, DocumentController)
end
function DocumentController:NavEndOfFile()
	-- todo this won't work for non-text!
	local elements = self.fileContent.elements
	self.elementIndex = #elements
	self.index = self.elementIndex == 0 and 1 or #elements[self.elementIndex].Text
end
function DocumentController:SetBold(value)
	--fileContent.
end
function DocumentController:Type(text)
	local elements = self.fileContent.elements
	local curElement = elements[self.elementIndex]
	if not curElement then
		curElement = Elements.Text.new(text)
		elements[#elements + 1] = curElement
	else
		curElement.Text = curElement.Text .. text
	end
end
return DocumentController