local Elements = require(script.Parent.Elements)

local DocumentController = {}
DocumentController.__index = DocumentController

local Pos = {}
DocumentController.Pos = Pos
Pos.__index = Pos
function Pos.new(sectionIndex, elementIndex, index)
	return setmetatable({
		SectionIndex = sectionIndex, -- todo assert numbers
		ElementIndex = elementIndex,
		Index = index,
	}, Pos)
end
function Pos:Clone()
	local new = {}
	for k, v in pairs(self) do
		new[k] = v
	end
	return setmetatable(new, Pos)
end

function DocumentController.new(header, sections)
	--	Each section must be a list with 0+ elements. There is an implicit page break between each section.
	if not sections or (#sections == 0 or (#sections == 1 and #sections[1] == 0)) then
		sections = {{Elements.Text.new("")}}
	end
	return setmetatable({
		header = header or {}, -- todo assert Header
		-- book is 1+ sections with 0+ elements
		sections = sections,
		pos = Pos(1, 1, 1), -- where the virtual text cursor is. Treat as immutable.
		--selecting:Pos where selection started or false if not selecting
		--selection:List<{.SectionIndex .ElementIndex .StartIndex .EndIndex}>
	}, DocumentController)
end
function DocumentController:GetPos()
	return self.pos
end
function DocumentController:SetPos(pos)
	self.pos = pos
end

function DocumentController:StartSelecting()
	self.selecting = self.pos:Clone()
end
function DocumentController:StopSelecting()
	self.selecting = false
end

function DocumentController:NavToFileStart()
	-- todo this won't work for non-text!
	self.pos = Pos(1, 1, 1)
end
function DocumentController:GetCurrentElement()
	return self.sections[self.pos.SectionIndex][self.pos.ElementIndex]
end
function DocumentController:OverText()
	return self:GetCurrentElement().Text ~= nil
end
function DocumentController:NavToFileEnd()
	-- todo this won't work for non-text!
	local sections = self.sections
	local numSections = #sections
	local elements = sections[numSections]
	local numElements = #elements
	local element = elements[numElements]
	-- todo if current element is not text, go backwards until we find one with text or hit the beginning of the section (in which case we create a new one)
	self.pos = Pos(numSections, numElements, element and element.Text and #element.Text + 1 or 1)
end
function DocumentController:modifyFormat(transformFormatting)
	local elements = self.sections[self.pos.SectionIndex]
	local element = elements[self.pos.ElementIndex]
	-- todo handle selection
	if not element.Text then error("Cannot apply formatting in the currently selected element") end
	--[[
	if index is 1, insert before current
		before making a new one, if new formatting is identical to previous text element's, then go to max index of previous instead
	if index is max, then check next element. If formatting is identical, go to index 1 of that one. Otherwise, insert new between them.
	]]
	local newFormat = transformFormatting(element.Format)
	local pos = self.pos
	if pos.Index == 1 then
		-- See if previous formatting is identical to desired
		local prevElement = elements[pos.ElementIndex - 1]
		if prevElement and prevElement.Format == newFormat then -- Move to previous
			--pos.ElementIndex -= 1
			pos.Index = #prevElement.Text + 1
		else -- Insert new one
			self:insertTextElement(Elements.Text.new("", newFormat))
		end
	elseif pos.Index == #element.Text + 1 then
		-- See if next formatting is identical to desired. If not, insert a new one.
		local nextElement = elements[pos.ElementIndex + 1]
		if not (nextElement and nextElement.Format == newFormat) then
			self:insertTextElement(Elements.Text.new("", newFormat), 1)
		end
		--pos
		self.pos = Pos(pos.SectionIndex, pos.ElementIndex + 1, 1)
	else -- have to break up the current element
		local origText = element.Text
		element.Text = origText:sub(1, pos.Index - 1)
		self:insertTextElement(Elements.Text.new("", newFormat), 1)
		self:insertTextElement(Elements.Text.new(origText:sub(pos.Index), element.Format), 2)
		self.pos = Pos(pos.SectionIndex, pos.ElementIndex + 1, 1)
	end
end
for _, name in ipairs({"Bold", "Italics", "Underline"}) do -- todo get the rest; is there a list of them somewhere?
	DocumentController["Get" .. name] = function(self)
		local element = self:GetCurrentElement()
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
	local elements = self.sections[self.pos.SectionIndex]
	table.insert(elements, self.pos.ElementIndex + (indexOffset or 0), element)
end
function DocumentController:removeTextElement(element, indexOffset)
	-- efficiency: consider doubly linked list
	local elements = self.sections[self.pos.SectionIndex]
	table.remove(elements, self.pos.ElementIndex + (indexOffset or 0))
end
function DocumentController:Type(text)
	local element = self:GetCurrentElement()
	if not element.Text then
		-- todo get formatting of last text element and send to Text.new
		self:insertTextElement(Elements.Text.new(text), 1)
	else
		element.Text = element.Text .. text
	end
end
function DocumentController:Left()
	local newIndex = self.pos.Index - 1
	local newElementIndex = self.pos.ElementIndex
	if newIndex <= 1 then
		if newElementIndex == 1 then
			newIndex = 1
		else
			newElementIndex = newElementIndex - 1
			local element = self.sections[self.pos.SectionIndex][newElementIndex]
			newIndex = #element.Text -- todo handle non-text
		end
	end
	self.pos = Pos(self.pos.SectionIndex, newElementIndex, newIndex)
end
function DocumentController:Right()
	-- todo
end
function DocumentController:Backspace()
	-- todo if selection, just call Delete
	if not self.selection then
		self:Left()
	end
	self:Delete()
end
function DocumentController:Delete()
	-- todo handle selection
	local element = self:GetCurrentElement()
	if not element.Text then
		self:deleteTextElement()
	else
		element.Text = element.Text:sub(1, self.pos.Index - 1) .. element.Text:sub(self.pos.Index + 1)
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