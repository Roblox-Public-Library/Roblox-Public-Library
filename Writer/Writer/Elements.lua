local Format = require(script.Parent.Format)
local Elements = {}
local Text = {ClassName = "Text"}
Elements.Text = Text
Text.__index = Text
function Text.new(text, format)
	if format and getmetatable(format) ~= Format then error("Not a Format") end -- todo proper Assert
	return setmetatable({
		Text = text,
		Format = format or Format.new(),
	}, Text)
end
return Elements