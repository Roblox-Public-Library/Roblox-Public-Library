local Elements = {}
local Text = {ClassName = "Text"}
Elements.Text = Text
Text.__index = Text
function Text.new(text, format)
	return setmetatable({
		Text = text,
		Format = format or {},
	}, Text)
end
return Elements