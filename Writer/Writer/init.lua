local module = {}
local children = {
	"Colors",
	"Elements",
	"Format",
	"CustomMarkdown",
	"PageSpaceTracker",
	"ReaderConfig",
	"Rendering",
	"RobloxRichTextRenderer",
}
for _, name in ipairs(children) do
	module[name] = require(script:WaitForChild(name))
end
return module