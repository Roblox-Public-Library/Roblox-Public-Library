local Formats = require(script.Parent.Formats)
local Elements = require(script.Parent.Elements)
local FileContent = {}
FileContent.__index = FileContent
-- TODO FileContent is maybe just a list of elements and doesn't need its own class
function FileContent.new(elements)
	if type(elements) == "string" then
		elements = Formats.CustomMarkdown.ParseText(elements)
	end
	return setmetatable({
		elements = elements
	}, FileContent)
end
function FileContent:ToFormat(format)
	local s = {}
	for i, element in ipairs(self.elements) do
		s[i] = format["Handle" .. element.ClassName](format, element)
	end
	return table.concat(s)
end

return FileContent