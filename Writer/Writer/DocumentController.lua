local Elements = require(script.Parent.Elements)

local DocumentController = {}
DocumentController.__index = DocumentController
function DocumentController.new(header, sections)
	if not sections or (#sections == 0 or (#sections == 1 and #sections[1] == 0)) then
		sections = {{Elements.Text.new("")}}
	end
	return setmetatable({
		header = header or {}, -- todo assert Header
		-- book is 1+ sections with 0+ elements
		sections = sections,
		sectionIndex = 1, -- which section we're focused on
		elementIndex = 1, -- which element we're focused on in the current section
		index = 1, -- where we're typing in the current element
	}, DocumentController)
end
function DocumentController:SetIndex(v)
	self.index = v
end
function DocumentController:NavFileStart()
	-- todo this won't work for non-text!
	self.sectionIndex = 1
	self.elementIndex = 1
	self.index = 1
end
function DocumentController:NavFileEnd()
	-- todo this won't work for non-text!
	local sections = self.sections
	local elements = sections[#sections]
	local n = #elements
	local element = elements[n]
	if false then -- todo check to see if section is not text
		-- todo create new blank element
	end
	self.elementIndex = n
	self.index = element and element.Text and #element.Text + 1 or 1
end
function DocumentController:OverText()
	local section = self.sections[self.sectionIndex]
	local element = section[self.elementIndex]
	return element.Text ~= nil
end
function DocumentController:modifyFormat(transformFormatting)
	local elements = self.sections[self.sectionIndex]
	local element = elements[self.elementIndex]
	-- todo handle selection
	if not element.Text then error("Cannot apply formatting in the currently selected element") end
	--[[
	if index is 1, insert before current
		before making a new one, if new formatting is identical to previous text element's, then go to max index of previous instead
	if index is max, then check next element. If formatting is identical, go to index 1 of that one. Otherwise, insert new between them.
	]]
	local newFormat = transformFormatting(element.Format)
	if self.index == 1 then
		-- See if previous formatting is identical to desired
		local prevElement = elements[self.elementIndex - 1]
		if prevElement and prevElement.Format == newFormat then -- Move to previous
			self.elementIndex = self.elementIndex - 1
			self.index = #prevElement.Text + 1
		else -- Insert new one
			self:insertTextElement(Elements.Text.new("", newFormat))
		end
	elseif self.index == #element.Text + 1 then
		-- See if next formatting is identical to desired. If not, insert a new one.
		local nextElement = elements[self.elementIndex + 1]
		if not (nextElement and nextElement.Format == newFormat) then
			self:insertTextElement(Elements.Text.new("", newFormat), 1)
		end
		self.elementIndex = self.elementIndex + 1
		self.index = 1
	else -- have to break up the current element
		local origText = element.Text
		element.Text = origText:sub(1, self.index - 1)
		self:insertTextElement(Elements.Text.new("", newFormat), 1)
		self:insertTextElement(Elements.Text.new(origText:sub(self.index), element.Format), 2)
		self.elementIndex = self.elementIndex + 1
		self.index = 1
	end
end
for _, name in ipairs({"Bold", "Italics", "Underline"}) do -- todo get the rest; is there a list of them somewhere?
	DocumentController["Get" .. name] = function(self)
		local section = self.sections[self.sectionIndex]
		local element = section[self.elementIndex]
		return element.Format and element.Format[name]
	end
	DocumentController["Set" .. name] = function(self, value)
		return self:modifyFormat(function(format) return format:With(name, value) end)
	end
	DocumentController["Toggle" .. name] = function(self)
		return self:modifyFormat(function(format) return format:With(name, not format[name]) end)
	end
end
function DocumentController:insertTextElement(element, indexOffset)
	-- efficiency: consider doubly linked list
	local elements = self.sections[self.sectionIndex]
	table.insert(elements, self.elementIndex + (indexOffset or 0), element)
end
function DocumentController:removeTextElement(element, indexOffset)
	-- efficiency: consider doubly linked list
	local elements = self.sections[self.sectionIndex]
	table.remove(elements, self.elementIndex + (indexOffset or 0))
end
function DocumentController:Type(text)
	local elements = self.sections[self.sectionIndex]
	local element = elements[self.elementIndex]
	if not element.Text then
		-- todo get formatting of last text element and send to Text.new
		self:insertTextElement(Elements.Text.new(text), 1)
	else
		element.Text = element.Text .. text
	end
end
function DocumentController:Left()
	self.index = self.index - 1
	if self.index <= 1 then
		if self.elementIndex == 1 then
			self.index = 1
		else
			self.elementIndex = self.elementIndex - 1
			local element = self.sections[self.sectionIndex][self.elementIndex]
			self.index = #element.Text -- todo handle non-text
		end
	end
end
function DocumentController:Right()

end
function DocumentController:Backspace()
	-- todo if selection, just call Delete
	self:Left()
	self:Delete()
end
function DocumentController:Delete()
	-- todo handle selection
	local elements = self.sections[self.sectionIndex]
	local element = elements[self.elementIndex]
	if not element.Text then
		self:deleteTextElement()
	else
		element.Text = element.Text:sub(1, self.index - 1) .. element.Text:sub(self.index + 1)
	end
end
function DocumentController:ToFormat(format)
	--	Export the document
	local s = {}
	-- todo go through header
	for _, elements in ipairs(self.sections) do
		for _, element in ipairs(elements) do
			s[#s + 1] = format["Handle" .. element.ClassName](format, element)
		end
	end
	s[#s + 1] = format:Finish()
	return table.concat(s)
end
return DocumentController