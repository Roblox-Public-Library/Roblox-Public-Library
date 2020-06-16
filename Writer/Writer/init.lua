local module = {}
local children = {
	"DocumentController",
	"Elements",
	"Format",
	"Formats",
}
for _, name in ipairs(children) do
	module[name] = require(script:WaitForChild(name))
end
return module