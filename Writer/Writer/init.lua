local module = {}
local children = {
	"Elements",
	"FileContent",
	"Formats",
	"TextCursor",
}
for _, name in ipairs(children) do
	module[name] = require(script:WaitForChild(name))
end
return module