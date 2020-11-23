local module = {}
local children = {
	"Colors",
	"DocumentController",
	"Elements",
	--"Font",
	"Format",
	--"Formats",
	"CustomMarkdown",
	"RobloxRichText",
}
for _, name in ipairs(children) do
	module[name] = require(script:WaitForChild(name))
end
return module